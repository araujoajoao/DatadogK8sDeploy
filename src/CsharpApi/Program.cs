using Microsoft.AspNetCore.Mvc;
using Serilog;
using Serilog.Enrichers.Span;
using Serilog.Formatting.Compact;
using StackExchange.Redis;

Log.Logger = new LoggerConfiguration()
    .Enrich.FromLogContext()
    .Enrich.WithSpan()
    .WriteTo.Console(new RenderedCompactJsonFormatter())
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    builder.Services.AddHttpClient();

    var redisHost = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis.default.svc.cluster.local";
    var redisPort = Environment.GetEnvironmentVariable("REDIS_PORT") ?? "6379";
    builder.Services.AddSingleton<IConnectionMultiplexer>(sp =>
        ConnectionMultiplexer.Connect(new ConfigurationOptions
        {
            EndPoints = { $"{redisHost}:{redisPort}" },
            AbortOnConnectFail = false,
            ConnectTimeout = 3000
        }));

    builder.Host.UseSerilog((ctx, sp, cfg) => cfg
        .ReadFrom.Configuration(ctx.Configuration)
        .Enrich.FromLogContext()
        .Enrich.WithSpan()
        .Enrich.With(new CsharpApi.Enrichers.DatadogSpanTagEnricher())
        .Enrich.WithProperty("service", "csharp-app")
        .Enrich.WithProperty("env", "mentoria")
        .Enrich.WithProperty("dd.service", "csharp-app")
        .Enrich.WithProperty("dd.env", "mentoria")
        .Enrich.WithProperty("dd.version", "latest")
        .WriteTo.Console(new RenderedCompactJsonFormatter()));

    var app = builder.Build();

    app.MapGet("/health", async ([FromServices] IConnectionMultiplexer redis) =>
    {
        var db = redis.GetDatabase();
        var hits = await db.StringIncrementAsync("hit_count:csharp-app");
        return Results.Ok(new { status = "ok", service = "csharp-app", redis_hits = hits });
    });

    app.MapGet("/redis", async (string? key, string? value, [FromServices] IConnectionMultiplexer redis, ILogger<Program> logger) =>
    {
        var k = key ?? "test-key";
        var db = redis.GetDatabase();
        if (!string.IsNullOrEmpty(value))
        {
            await db.StringSetAsync(k, value);
            logger.LogInformation("Redis SET {Key} to {Value}", k, value);
            return Results.Ok(new { service = "csharp-app", action = "set", key = k, value });
        }
        else
        {
            var val = await db.StringGetAsync(k);
            var hits = await db.StringIncrementAsync("hit_count:csharp-app:custom");
            logger.LogInformation("Redis GET {Key} = {Value}, hits={Hits}", k, val.ToString(), hits);
            return Results.Ok(new { service = "csharp-app", action = "get", key = k, value = val.ToString(), custom_hits = hits });
        }
    });


    app.MapGet("/db", async (ILogger<Program> logger) =>
    {
        var host = Environment.GetEnvironmentVariable("POSTGRES_HOST") ?? "postgres.default.svc.cluster.local";
        var port = Environment.GetEnvironmentVariable("POSTGRES_PORT") ?? "5432";
        var user = Environment.GetEnvironmentVariable("POSTGRES_USER") ?? "labuser";
        var password = Environment.GetEnvironmentVariable("POSTGRES_PASSWORD") ?? "labpass";
        var db = Environment.GetEnvironmentVariable("POSTGRES_DB") ?? "labdb";
        var connStr = $"Host={host};Port={port};Username={user};Password={password};Database={db}";

        await using var conn = new Npgsql.NpgsqlConnection(connStr);
        await conn.OpenAsync();
        await using var cmd = new Npgsql.NpgsqlCommand(
            "SELECT id, message, created_at FROM greetings ORDER BY id", conn);
        await using var reader = await cmd.ExecuteReaderAsync();

        var rows = new List<object>();
        while (await reader.ReadAsync())
        {
            rows.Add(new
            {
                id = reader.GetInt32(0),
                message = reader.GetString(1),
                created_at = reader.GetDateTime(2)
            });
        }

        logger.LogInformation("DB query returned {Count} rows", rows.Count);
        return Results.Ok(rows);
    });

    app.MapGet("/orders/{id}", (string id) =>
    {
        // Datadog APM: tag explícita no span ativo (o enricher pega as outras via log)
        var scope = global::Datadog.Trace.Tracer.Instance.ActiveScope;
        scope?.Span.SetTag("order.source", "manual-api");

        // Log com propriedades estruturadas → enricher converte em tags do span
        Log.Information("Order {OrderId} processed for customer {CustomerId}", id, "acme-corp");

        return Results.Ok(new
        {
            order_id = id,
            status = "processed",
            customer = "acme-corp",
            source = "manual-api"
        });
    });

    app.MapGet("/chain/order/{id}", async (string id, [FromServices] HttpClient http, ILogger<Program> logger) =>
    {
        // Span raiz customizado para a operação chain (visível na UI com esse nome).
        // O Datadog .NET tracer JÁ auto-instrumenta HttpClient via CLR Profiler — não precisa
        // de código extra pra propagação de trace context (traceparent header vai no GET).
        using var chainScope = global::Datadog.Trace.Tracer.Instance.StartActive("chain.process-order");
        chainScope.Span.SetTag("chain.id", id);
        chainScope.Span.SetTag("chain.source", "manual-api");

        // Step 1: log estruturado → enricher copia OrderId como span tag automaticamente
        logger.LogInformation("Chain start: processing order {OrderId}", id);

        try
        {
            // Step 2: HttpClient call → python-app /api/dotnet
            //         O tracer auto-instrumenta e injeta traceparent; python-app ddtrace
            //         cria span filho com mesmo trace_id. python-app internamente chama
            //         dotnet-app /weatherforecast → span neto (mesmo trace_id).
            var pyResponse = await http.GetStringAsync("http://python-app:5000/api/dotnet");
            chainScope.Span.SetTag("step.python.status", "200");
            logger.LogInformation("Chain step 1 OK: python returned {Length} bytes", pyResponse.Length);

            return Results.Ok(new
            {
                chain_id = id,
                trace_id = chainScope.Span.TraceId.ToString(),
                span_id = chainScope.Span.SpanId.ToString(),
                python_response_snippet = pyResponse.Length > 100
                    ? pyResponse[..100] + "..."
                    : pyResponse,
                steps = 3  // csharp → python → dotnet
            });
        }
        catch (Exception ex)
        {
            chainScope.Span.SetTag("error", "true");
            chainScope.Span.SetTag("error.message", ex.Message);
            logger.LogError(ex, "Chain failed for order {OrderId}", id);
            return Results.Problem(detail: ex.Message, statusCode: 502);
        }
    });

    app.MapGet("/hello", (string? name) =>
    {
        var who = string.IsNullOrWhiteSpace(name) ? "world" : name;
        Log.Information("Saying hello to {Name}", who);
        return Results.Ok(new { message = $"Hello, {who}!" });
    });

    app.MapGet("/chain", async ([FromServices] HttpClient http, ILogger<Program> logger) =>
    {
        logger.LogInformation("Calling python-app for distributed trace chain");
        try
        {
            var response = await http.GetStringAsync("http://python-app:5000/api/dotnet");
            return Results.Content(response, "application/json");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Chain call to python-app failed");
            return Results.Problem(detail: ex.Message, statusCode: 502);
        }
    });

    Log.Information("csharp-app starting up");
    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "csharp-app terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}

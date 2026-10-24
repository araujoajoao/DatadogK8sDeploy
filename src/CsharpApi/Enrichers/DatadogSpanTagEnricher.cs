using Datadog.Trace;
using Serilog.Core;
using Serilog.Events;

namespace CsharpApi.Enrichers;

/// <summary>
/// Serilog enricher que copia as propriedades estruturadas de cada log event
/// para o span ativo do Datadog como tags.
///
/// Uso: adicione no pipeline Serilog:
///   .Enrich.With(new DatadogSpanTagEnricher())
///
/// Aí, este código:
///   Log.Information("Order {OrderId} processed", "ord-123");
/// Cria automaticamente a tag "OrderId" = "ord-123" no span ativo.
///
/// Apenas valores escalares são enviados. Chaves reservadas pelo Datadog
/// (dd.*) e pelo ASP.NET Core (RequestId, SpanId, TraceId, etc.) são ignoradas
/// para evitar recursão.
/// </summary>
public class DatadogSpanTagEnricher : ILogEventEnricher
{
    // Chaves que não devem virar span tag (são metadados do framework)
    private static readonly HashSet<string> ReservedKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        // Datadog
        "dd.service", "dd.env", "dd.version", "dd.trace_id", "dd.span_id",
        // ASP.NET Core / Serilog diagnostics
        "SourceContext", "ConnectionId",
        "ActionId", "ActionName", "RequestId", "SpanId", "TraceId",
        "ParentId", "EventId", "Source",
        // Já enriquecidos manualmente em Program.cs
        "service", "env",
    };

    public void Enrich(LogEvent logEvent, ILogEventPropertyFactory propertyFactory)
    {
        var scope = Tracer.Instance.ActiveScope;
        if (scope?.Span is null) return;

        foreach (var (key, value) in logEvent.Properties)
        {
            if (ReservedKeys.Contains(key)) continue;

            // Só envia valores escalares (string, número, bool). Dicionários e
            // sequences não fazem sentido como span tag — ficariam muito longos.
            if (value is ScalarValue scalar && scalar.Value is not null)
            {
                scope.Span.SetTag(key, scalar.Value.ToString() ?? string.Empty);
            }
        }
    }
}

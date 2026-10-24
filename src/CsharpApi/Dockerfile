# syntax=docker/dockerfile:1.7
# Imagem mínima. O tracer Datadog é injetado via SSI (cluster-agent admissionController)
# quando o pod é criado — ver datadog-values.yaml (clusterAgent.admissionController.enabled=true)
# e apm.instrumentation.targets[].

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Restore (cached layer)
COPY CsharpApi.csproj ./
RUN dotnet restore

# Publish
COPY . ./
RUN dotnet publish -c Release -o /app --no-restore /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Carry the published app
COPY --from=build /app ./

# ASP.NET Core
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
ENV DOTNET_RUNNING_IN_CONTAINER=true

EXPOSE 8080

# Run as non-root for least privilege
RUN groupadd --gid 10001 csharp && useradd --uid 10001 --gid csharp --shell /bin/bash --create-home csharp \
    && chown -R csharp:10001 /app || true

USER csharp

ENTRYPOINT ["dotnet", "CsharpApi.dll"]

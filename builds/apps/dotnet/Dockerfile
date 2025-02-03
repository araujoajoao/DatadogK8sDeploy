# Use the .NET SDK base image
FROM mcr.microsoft.com/dotnet/aspnet:6.0

# Set environment variables for Datadog APM
ENV DD_AGENT_HOST=datadog-agent
ENV DD_TRACE_ENABLED=true
ENV DD_SERVICE=dotnet-app
ENV DD_ENV=production
ENV DD_VERSION=1..0.0

# Install the Datadog .NET tracer
RUN curl -LO https://github.com/DataDog/dd-trace-dotnet/releases/latest/download/datadog-dotnet-apm.deb && \
    dpkg -i datadog-dotnet-apm.deb && \
    rm datadog-dotnet-apm.deb

# Copy your application files
COPY bin/Release/net6.0/publish/ /app

# Expose the application port
EXPOSE 5000

# Run the application
CMD ["dotnet", "/app/my-dotnet-app.dll"]
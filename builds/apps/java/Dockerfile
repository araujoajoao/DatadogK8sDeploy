# Use an OpenJDK base image
FROM openjdk:11-jre-slim

# Set environment variables for Datadog APM
ENV DD_AGENT_HOST=datadog-agent
ENV DD_TRACE_ENABLED=true
ENV DD_SERVICE=java-app
ENV DD_ENV=production
ENV DD_VERSION=1.0.0

# Install the Datadog Java tracer
RUN curl -Lo dd-java-agent.jar https://dtdg.co/latest-java-tracer

# Copy your application JAR file
COPY target/my-java-app.jar /app/my-java-app.jar

# Expose the application port
EXPOSE 8080

# Run the application with the Datadog tracer
CMD ["java", "-javaagent:dd-java-agent.jar", "-jar", "/app/my-java-app.jar"]
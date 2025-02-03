# Use a Python base image
FROM python:3.9-slim

# Set environment variables for Datadog APM
ENV DD_AGENT_HOST=datadog-agent
ENV DD_TRACE_ENABLED=true
ENV DD_SERVICE=python-app
ENV DD_ENV=production
ENV DD_VERSION=1.0.0

# Install the Datadog Python tracer
RUN pip install ddtrace

# Copy your application code
COPY . /app
WORKDIR /app

# Install application dependencies
RUN pip install -r requirements.txt

# Expose the application port
EXPOSE 8000

# Run the application with the Datadog tracer
CMD ["ddtrace-run", "python", "app.py"]
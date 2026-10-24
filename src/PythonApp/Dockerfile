# syntax=docker/dockerfile:1.7
# Imagem mínima. O tracer Datadog Python (ddtrace) é injetado via SSI no pod startup
# (init container pip install ddtrace + env vars injetados pelo webhook).

FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 5000

CMD ["python", "app.py"]

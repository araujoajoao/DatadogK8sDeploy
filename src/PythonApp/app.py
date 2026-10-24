"""python-app — Flask com ddtrace baked-in + JSON logging em stdout."""
import json
import logging
import os
import sys
import urllib.request
from datetime import datetime, timezone

from flask import Flask, request as flask_request
from pythonjsonlogger import jsonlogger

# ── JSON logging to stdout ──
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(jsonlogger.JsonFormatter(
    "%(asctime)s %(levelname)s %(name)s %(message)s",
    rename_fields={"asctime": "timestamp", "levelname": "level", "name": "logger"}
))

root = logging.getLogger()
root.handlers = [handler]
root.setLevel(logging.INFO)

logger = logging.getLogger("python-app")

import redis


# ── Redis client ──
REDIS_HOST = os.getenv("REDIS_HOST", "redis.db.svc.cluster.local")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))

def get_redis_client():
    return redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True, socket_timeout=3)

# ── Flask app ──
app = Flask(__name__)


@app.before_request
def log_request():
    logger.info("request_started", extra={
        "method": flask_request.method,
        "path": flask_request.path,
        "remote_addr": flask_request.remote_addr,
    })


@app.after_request
def log_response(response):
    logger.info("request_completed", extra={
        "method": flask_request.method,
        "path": flask_request.path,
        "status": response.status_code,
    })
    return response


@app.route("/")
def hello():
    redis_hits = None
    try:
        r = get_redis_client()
        redis_hits = r.incr("hit_count:python-app")
        logger.info("hello_called", extra={"redis_hits": redis_hits})
    except Exception as e:
        logger.error("redis_error", extra={"error": str(e)})

    return {
        "message": "Hello from Python app with Datadog tracing!",
        "service": "python-app",
        "redis_hits": redis_hits,
    }, 200


@app.route("/redis")
def redis_endpoint():
    """Endpoint direto para operações Redis (auto-instrumentado pelo ddtrace)."""
    key = flask_request.args.get("key", "test-key")
    val = flask_request.args.get("value")
    try:
        r = get_redis_client()
        if val is not None:
            r.set(key, val)
            logger.info("redis_set", extra={"key": key, "value": val})
            return {"service": "python-app", "action": "set", "key": key, "value": val}, 200
        else:
            value = r.get(key)
            hits = r.incr("hit_count:python-app:custom")
            logger.info("redis_get", extra={"key": key, "value": value, "hits": hits})
            return {"service": "python-app", "action": "get", "key": key, "value": value, "custom_hits": hits}, 200
    except Exception as e:
        logger.error("redis_failed", extra={"error": str(e), "key": key})
        return {"service": "python-app", "error": str(e)}, 500


@app.route("/health")
def health():
    return {"status": "ok", "service": "python-app"}, 200



@app.route("/db")
def db_query():
    """Consulta PostgreSQL — gera queries visíveis no DBM e correlacionadas com o trace."""
    import psycopg2

    conn = psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "postgres.db.svc.cluster.local"),
        port=int(os.getenv("POSTGRES_PORT", "5432")),
        user=os.getenv("POSTGRES_USER", "labuser"),
        password=os.getenv("POSTGRES_PASSWORD", "labpass"),
        dbname=os.getenv("POSTGRES_DB", "labdb"),
    )
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, message, created_at FROM greetings ORDER BY id")
            rows = cur.fetchall()
        logger.info("db_query_success", extra={"row_count": len(rows)})
        return json.dumps([
            {"id": r[0], "message": r[1], "created_at": r[2].isoformat()}
            for r in rows
        ]), 200, {"Content-Type": "application/json"}
    except Exception as e:
        logger.error("db_query_failed", extra={"error": str(e)})
        return json.dumps({"error": str(e)}), 500, {"Content-Type": "application/json"}
    finally:
        conn.close()


@app.route("/api/dotnet")
def api_dotnet():
    """Encaminha para dotnet-app."""
    dotnet_url = os.getenv("DOTNET_APP_URL", "http://dotnet-app:80") + "/weatherforecast"
    try:
        with urllib.request.urlopen(dotnet_url, timeout=5) as req:
            data = req.read().decode()
        logger.info("dotnet_proxy_success", extra={"url": dotnet_url})
        return (data, 200, {"Content-Type": "application/json"})
    except Exception as e:
        logger.error("dotnet_proxy_failed", extra={"error": str(e), "url": dotnet_url})
        return (json.dumps({"error": str(e), "dotnet_url": dotnet_url}), 502, {"Content-Type": "application/json"})


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    logger.info("server_starting", extra={"port": port})
    app.run(host="0.0.0.0", port=port)
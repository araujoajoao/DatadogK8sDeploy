const express = require('express');
const winston = require('winston');
const Redis = require('ioredis');

// Logger estruturado em JSON com timestamp
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [new winston.transports.Console()]
});

// Redis client (auto-instrumented by dd-trace-js)
const redisHost = process.env.REDIS_HOST || 'redis.default.svc.cluster.local';
const redisPort = parseInt(process.env.REDIS_PORT || '6379', 10);
const redis = new Redis({
  host: redisHost,
  port: redisPort,
  retryStrategy(times) {
    const delay = Math.min(times * 100, 3000);
    return delay;
  },
  maxRetriesPerRequest: 3,
  lazyConnect: true
});

redis.connect().then(() => {
  logger.info(`Connected to Redis at ${redisHost}:${redisPort}`);
}).catch((err) => {
  logger.error('Initial Redis connection failed', { error: err.message });
});

const app = express();
const port = parseInt(process.env.PORT || '3000', 10);

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'nodejs-app' });
});

app.get('/', async (req, res) => {
  logger.info('Requisição recebida na rota raiz do Node.js');
  let hits = null;
  try {
    hits = await redis.incr('hit_count:nodejs-app');
    logger.info('Redis increment hit_count:nodejs-app', { hits });
  } catch (err) {
    logger.error('Redis increment failed', { error: err.message });
  }
  res.json({
    message: 'Hello from Node.js! Datadog APM is automatically tracing this.',
    service: 'nodejs-app',
    redis_hits: hits
  });
});

app.get('/redis', async (req, res) => {
  const key = req.query.key || 'test-key';
  const val = req.query.value;
  try {
    if (val !== undefined) {
      await redis.set(key, val);
      logger.info(`Redis SET ${key} = ${val}`);
      return res.json({ service: 'nodejs-app', action: 'set', key, value: val });
    } else {
      const value = await redis.get(key);
      const hits = await redis.incr('hit_count:nodejs-app:custom');
      logger.info(`Redis GET ${key} = ${value}, hits=${hits}`);
      return res.json({ service: 'nodejs-app', action: 'get', key, value, custom_hits: hits });
    }
  } catch (err) {
    logger.error('Redis operation error', { error: err.message, key });
    return res.status(500).json({ service: 'nodejs-app', error: err.message });
  }
});

app.listen(port, () => {
  logger.info(`App listening on port ${port}`);
});
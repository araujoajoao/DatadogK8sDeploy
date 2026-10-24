package com.lab.javaapp;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import redis.clients.jedis.Jedis;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.HashMap;
import java.util.Map;

@RestController
public class AppController {

    private static final Logger logger = LoggerFactory.getLogger(AppController.class);

    private static final String DB_HOST = System.getenv().getOrDefault("DB_HOST", "postgres.default.svc.cluster.local");
    private static final String DB_NAME = System.getenv().getOrDefault("DB_NAME", "labdb");
    private static final String DB_USER = System.getenv().getOrDefault("DB_USER", "labuser");
    private static final String DB_PASS = System.getenv().getOrDefault("DB_PASS", "labpass");

    private static final String REDIS_HOST = System.getenv().getOrDefault("REDIS_HOST", "redis.default.svc.cluster.local");
    private static final int REDIS_PORT = Integer.parseInt(System.getenv().getOrDefault("REDIS_PORT", "6379"));

    private ResponseEntity<Map<String, Object>> handleRequest(String path) {
        logger.info("Request received on {}", path);

        Map<String, Object> response = new HashMap<>();
        response.put("service", "java-app");
        response.put("status", "ok");

        // 1. PostgreSQL query (APM + DBM trace correlation)
        try {
            String url = String.format("jdbc:postgresql://%s:5432/%s", DB_HOST, DB_NAME);
            Connection conn = DriverManager.getConnection(url, DB_USER, DB_PASS);
            logger.info("Database connected successfully");

            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT count(*) FROM pg_stat_statements");

            int totalStatements = 0;
            if (rs.next()) {
                totalStatements = rs.getInt(1);
            }
            logger.info("pg_stat_statements query executed, total_statements={}", totalStatements);

            response.put("total_statements", totalStatements);
            response.put("database", DB_NAME);

            rs.close();
            stmt.close();
            conn.close();

        } catch (Exception e) {
            logger.error("Database error: {}", e.getMessage(), e);
            response.put("db_error", e.getMessage());
        }

        // 2. Redis operation (APM Redis trace span auto-instrumented by dd-trace-java)
        try (Jedis jedis = new Jedis(REDIS_HOST, REDIS_PORT)) {
            long hits = jedis.incr("hit_count:java-app");
            logger.info("Redis incremented hit_count:java-app={}", hits);
            response.put("redis_hits", hits);
        } catch (Exception e) {
            logger.error("Redis error: {}", e.getMessage(), e);
            response.put("redis_error", e.getMessage());
        }

        logger.info("Request completed on {}", path);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/")
    public ResponseEntity<Map<String, Object>> index() {
        return handleRequest("/");
    }

    @GetMapping("/greeting")
    public ResponseEntity<Map<String, Object>> greeting() {
        return handleRequest("/greeting");
    }

    @GetMapping("/redis")
    public ResponseEntity<Map<String, Object>> redis(@RequestParam(value = "key", defaultValue = "test-key") String key,
                                                     @RequestParam(value = "value", required = false) String value) {
        logger.info("Redis endpoint called for key={}", key);
        Map<String, Object> response = new HashMap<>();
        response.put("service", "java-app");

        try (Jedis jedis = new Jedis(REDIS_HOST, REDIS_PORT)) {
            if (value != null) {
                jedis.set(key, value);
                logger.info("Redis SET key={} value={}", key, value);
                response.put("action", "set");
                response.put("key", key);
                response.put("value", value);
            } else {
                String val = jedis.get(key);
                long hits = jedis.incr("hit_count:java-app:custom");
                logger.info("Redis GET key={} value={} hits={}", key, val, hits);
                response.put("action", "get");
                response.put("key", key);
                response.put("value", val);
                response.put("custom_hits", hits);
            }
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            logger.error("Redis operation failed: {}", e.getMessage(), e);
            response.put("error", e.getMessage());
            return ResponseEntity.status(500).body(response);
        }
    }
}


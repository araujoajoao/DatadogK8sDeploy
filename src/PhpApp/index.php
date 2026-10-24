<?php
// Datadog trace-log correlation headers
$traceId = getenv('DD_TRACE_ID') ?: (function_exists('DDTrace\\active_span') ? DDTrace\active_span()?->id : '');
$spanId  = getenv('DD_SPAN_ID') ?: '';

// Database config via env vars
$host = getenv('DB_HOST') ?: 'postgres.default.svc.cluster.local';
$port = getenv('DB_PORT') ?: '5432';
$db   = getenv('DB_NAME') ?: 'labdb';
$user = getenv('DB_USER') ?: 'postgres';
$pass = getenv('DB_PASS') ?: '';

// Simple logger to stderr (collected by Datadog via containerCollectAll)
function dd_log(string $level, string $message, array $context = []): void {
    $entry = json_encode([
        'timestamp'   => date('c'),
        'level'       => $level,
        'message'     => $message,
        'service'     => 'php-app',
        'dd.trace_id' => \DDTrace\logs_correlation_trace_id(),
        'dd.span_id'  => (string)(\DDTrace\active_span()?->id ?? ''),
        'context'     => $context ?: null,
    ], JSON_UNESCAPED_SLASHES);
    error_log($entry);
}

dd_log('info', 'Request received', [
    'method' => $_SERVER['REQUEST_METHOD'],
    'uri'    => $_SERVER['REQUEST_URI'],
    'ip'     => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
]);

echo "<h1>PHP App - Mentoria Lab</h1>";
echo "<p>Environment: " . (getenv('DD_ENV') ?: 'mentoria') . "</p>";
echo "<p>Version: " . (getenv('DD_VERSION') ?: '1.0.0') . "</p>";

// Database connection
try {
    $dsn = "pgsql:host=$host;port=$port;dbname=$db";
    $pdo = new PDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);

    dd_log('info', 'Database connected successfully', ['host' => $host, 'db' => $db]);
    echo "<p style='color: green;'>Conexao com PostgreSQL estabelecida!</p>";

    // Sample query to generate DBM data
    $stmt = $pdo->query("SELECT version() as pg_version");
    $row = $stmt->fetch();
    echo "<p>PostgreSQL: " . htmlspecialchars($row['pg_version']) . "</p>";

    // Query to exercise pg_stat_statements
    $stmt = $pdo->query("SELECT count(*) as total FROM pg_stat_statements LIMIT 1");
    $row = $stmt->fetch();
    dd_log('info', 'pg_stat_statements query executed', ['total_statements' => $row['total']]);

} catch (\PDOException $e) {
    dd_log('error', 'Database connection failed', [
        'error' => $e->getMessage(),
        'host'  => $host,
        'db'    => $db,
    ]);
    echo "<p style='color: red;'>DB Error: " . htmlspecialchars($e->getMessage()) . "</p>";
}

// Redis connection (auto-instrumented by dd-trace-php)
$redisHost = getenv('REDIS_HOST') ?: 'redis.default.svc.cluster.local';
$redisPort = (int)(getenv('REDIS_PORT') ?: 6379);

try {
    if (class_exists('Redis')) {
        $redis = new Redis();
        $redis->connect($redisHost, $redisPort, 2.5);
        $hits = $redis->incr('hit_count:php-app');
        dd_log('info', 'Redis hit count incremented', [
            'host'  => $redisHost,
            'port'  => $redisPort,
            'hits'  => $hits,
        ]);
        echo "<p style='color: green;'>Conexao com Redis estabelecida! Total Hits: " . htmlspecialchars((string)$hits) . "</p>";

        if (isset($_GET['key'])) {
            $key = $_GET['key'];
            if (isset($_GET['value'])) {
                $redis->set($key, $_GET['value']);
                echo "<p>Redis SET [$key] = " . htmlspecialchars($_GET['value']) . "</p>";
            } else {
                $val = $redis->get($key);
                echo "<p>Redis GET [$key] = " . htmlspecialchars((string)$val) . "</p>";
            }
        }
    } else {
        echo "<p style='color: orange;'>Extensao Redis nao carregada.</p>";
    }
} catch (\Throwable $e) {
    dd_log('error', 'Redis connection failed', [
        'error' => $e->getMessage(),
        'host'  => $redisHost,
        'port'  => $redisPort,
    ]);
    echo "<p style='color: red;'>Redis Error: " . htmlspecialchars($e->getMessage()) . "</p>";
}


dd_log('info', 'Request completed', [
    'status' => http_response_code(),
]);
?>
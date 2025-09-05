# Any Logger MySQL

A MySQL database appender extension for [Any Logger](https://pub.dev/packages/any_logger) that enables persistent log storage, advanced querying, audit trails, and analytics capabilities with automatic table management and rotation support.

## Features

- **Automatic Table Management** - Creates and maintains log tables with optimal schema
- **Batch Inserts** - Efficient batching for high-volume logging
- **Connection Pooling** - Automatic reconnection and connection management
- **Table Rotation** - Automatic archiving to manage table size
- **Custom Fields** - Add application-specific columns
- **Query API** - Built-in methods for log analysis
- **Index Management** - Configurable indices for query performance
- **Compression Support** - Optional table compression for storage efficiency

## Installation

```yaml
dependencies:
  any_logger: ^x.y.z  
  any_logger_mysql: ^x.y.z  # See Installing
```

To register the MySQL appender you have to import the library

```dart
import 'package:any_logger/any_logger.dart';
import 'package:any_logger_mysql/any_logger_mysql.dart';
```
and call:

```dart
AnyLoggerMySqlExtension.register();
```

## Quick Start

### Simple Setup

```dart
await LoggerFactory.builder()
    .console(level: Level.INFO)
    .mysql(
      host: 'localhost',
      database: 'app_logs',
      user: 'logger',
      password: 'secure_password',
      level: Level.INFO,
    )
    .build();

Logger.info('This log goes to console and MySQL');
Logger.error('Errors are automatically indexed for fast querying');
```

### Production Configuration

```dart
await LoggerFactory.builder()
    .mysqlProduction(
      host: 'db.example.com',
      database: 'production',
      user: 'app_user',
      password: 'strong_password',
      table: 'app_logs',
      enableRotation: true, // Auto-archive old logs
    )
    .build();
```

## Configuration Options

### Using Builder Pattern

```dart
final appender = await mySqlAppenderBuilder()
    .withConnection('db.example.com', 3306, 'myapp')
    .withCredentials('logger', 'password')
    .withTable('logs')
    .withLevel(Level.INFO)
    .withBatchSize(100)
    .withBatchInterval(Duration(seconds: 10))
    .withSSL(true)
    .withCompression(true)
    .withRotation(
      maxRows: 10000000, // Rotate at 10M rows
      checkInterval: 3600, // Check hourly
      archivePrefix: 'archive_',
    )
    .withIndices(['timestamp', 'level', 'tag', 'logger_name'])
    .withCustomFields({
      'user_id': 'VARCHAR(100)',
      'request_id': 'VARCHAR(100)',
      'duration_ms': 'INT',
    })
    .build();
```

### Using Configuration Map

```dart
final config = {
  'appenders': [
    {
      'type': 'MYSQL',
      'host': 'localhost',
      'port': 3306,
      'database': 'logs',
      'user': 'logger',
      'password': 'password',
      'table': 'app_logs',
      'level': 'INFO',
      'useSSL': false,
      'connectionTimeout': 30,
      'autoCreateTable': true,
      'tableEngine': 'InnoDB',
      'charset': 'utf8mb4',
      'useCompression': false,
      'batchSize': 100,
      'batchIntervalSeconds': 10,
      'usePreparedStatements': true,
      'maxReconnectAttempts': 5,
      'reconnectDelaySeconds': 2,
      'enableRotation': true,
      'maxRows': 10000000,
      'rotationCheckInterval': 3600,
      'archiveTablePrefix': 'archive_',
      'createIndices': true,
      'indexColumns': ['timestamp', 'level', 'tag'],
      'customFields': {
        'user_id': 'VARCHAR(100)',
        'session_id': 'VARCHAR(100)',
      },
    }
  ]
};

await LoggerFactory.init(config);
```

### Configuration Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `host` | String | Required | MySQL server hostname |
| `port` | int | 3306 | MySQL server port |
| `database` | String | Required | Database name |
| `user` | String | null | MySQL username |
| `password` | String | null | MySQL password |
| `table` | String | 'logs' | Table name for logs |
| `useSSL` | bool | false | Use SSL connection |
| `connectionTimeout` | int | 30 | Connection timeout in seconds |
| `autoCreateTable` | bool | true | Auto-create table if missing |
| `tableEngine` | String | 'InnoDB' | MySQL table engine |
| `charset` | String | 'utf8mb4' | Table character set |
| `useCompression` | bool | false | Enable table compression |
| `level` | Level | INFO | Minimum log level |
| `batchSize` | int | 50 | Records per batch insert |
| `batchIntervalSeconds` | int | 10 | Max seconds before flush |
| `usePreparedStatements` | bool | true | Use prepared statements |
| `maxReconnectAttempts` | int | 3 | Max reconnection attempts |
| `reconnectDelaySeconds` | int | 2 | Delay between reconnects |
| `enableRotation` | bool | false | Enable table rotation |
| `maxRows` | int | 1000000 | Max rows before rotation |
| `rotationCheckInterval` | int | 3600 | Rotation check interval (seconds) |
| `archiveTablePrefix` | String | null | Prefix for archive tables |
| `createIndices` | bool | true | Create table indices |
| `indexColumns` | List | [...] | Columns to index |
| `customFields` | Map | {} | Custom table columns |

## Table Schema

The default table schema includes:

```sql
CREATE TABLE logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  timestamp DATETIME(3) NOT NULL,
  level VARCHAR(10) NOT NULL,
  level_value INT NOT NULL,
  tag VARCHAR(255),
  message TEXT NOT NULL,
  logger_name VARCHAR(255),
  class_name VARCHAR(255),
  method_name VARCHAR(255),
  file_location VARCHAR(500),
  line_number INT,
  error TEXT,
  stack_trace TEXT,
  mdc_context JSON,
  app_version VARCHAR(50),
  device_id VARCHAR(100),
  session_id VARCHAR(100),
  hostname VARCHAR(255),
  -- Plus any custom fields you define
  INDEX idx_timestamp (timestamp),
  INDEX idx_level (level),
  INDEX idx_tag (tag),
  INDEX idx_logger_name (logger_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
```

## Use Cases

### Audit Logging

```dart
final appender = await mySqlAppenderBuilder()
    .withConnection('audit-db.internal', 3306, 'compliance')
    .withCredentials('audit_user', 'secure_pass')
    .withTable('audit_trail')
    .withAuditPreset() // Configures for audit compliance
    .build();

// Adds custom audit fields:
// - user_id, action, ip_address, user_agent
// - Never rotates (keeps all records)
// - Uses InnoDB for ACID compliance
```

### High-Volume Application Logging

```dart
await LoggerFactory.builder()
    .mysqlHighVolume(
      host: 'db-cluster.example.com',
      database: 'logs',
      user: 'app',
      password: 'pass',
      level: Level.INFO,
    )
    .build();

// Optimized for high throughput:
// - Batch size: 200
// - Compression enabled
// - Minimal indices
// - Fast inserts
```

### Analytics and Event Tracking

```dart
final appender = await mySqlAppenderBuilder()
    .withConnection('analytics-db.example.com', 3306, 'events')
    .withAnalyticsPreset()
    .withCustomField('revenue', 'DECIMAL(10,2)')
    .withCustomField('user_segment', 'VARCHAR(50)')
    .build();

// Configured for analytics:
// - Large batch sizes (500)
// - JSON event_data field
// - Compression enabled
// - Optimized indices
```

### Development and Debugging

```dart
await LoggerFactory.builder()
    .console(level: Level.DEBUG)
    .mysql(
      host: 'localhost',
      database: 'dev_logs',
      level: Level.DEBUG,
      batchSize: 1, // Insert immediately
      autoCreateTable: true,
      createIndices: true,
      indexColumns: ['timestamp', 'level', 'tag', 'class_name'],
    )
    .build();
```

### Microservices Architecture

```dart
final config = MySqlPresets.microservicesWithMySql(
  host: 'shared-db.k8s.local',
  database: 'microservices',
  user: 'service_user',
  password: 'service_pass',
  serviceName: 'payment-service',
  table: 'service_logs',
);

// Includes fields for distributed tracing:
// - service_name, trace_id, span_id
// - correlation_id for request tracking
// - Optimized for multi-service queries
```

## Querying Logs

The appender includes a built-in query API:

```dart
// Get the appender instance
final appender = logger.appenders
    .whereType<MySqlAppender>()
    .firstOrNull;

// Query recent errors
final errors = await appender.queryLogs(
  minLevel: Level.ERROR,
  startTime: DateTime.now().subtract(Duration(hours: 1)),
  limit: 100,
);

// Query by tag
final paymentLogs = await appender.queryLogs(
  tag: 'PAYMENT',
  loggerName: 'PaymentService',
  orderBy: 'timestamp DESC',
  limit: 50,
);

// Complex query with pagination
final results = await appender.queryLogs(
  minLevel: Level.WARN,
  startTime: DateTime.now().subtract(Duration(days: 7)),
  endTime: DateTime.now(),
  tag: 'API',
  limit: 20,
  offset: 40, // Page 3
);

// Analyze the results
for (var log in results) {
  print('${log['timestamp']}: ${log['level']} - ${log['message']}');
}
```

## Presets

### Production Preset

```dart
.withProductionPreset()
// Configures:
// - Batch size: 100
// - Prepared statements: true
// - Reconnect attempts: 5
// - Table rotation: enabled
// - Max rows: 10M
// - Hourly rotation checks
```

### High Volume Preset

```dart
.withHighVolumePreset()
// Configures:
// - Batch size: 200
// - Short intervals: 5s
// - Compression: enabled
// - Minimal indices
// - Optimized for writes
```

### Audit Preset

```dart
.withAuditPreset()
// Configures:
// - InnoDB engine (ACID)
// - No rotation (keep all)
// - Custom audit fields
// - Comprehensive indices
// - Transaction support
```

### Analytics Preset

```dart
.withAnalyticsPreset()
// Configures:
// - Large batches: 500
// - JSON event_data field
// - Compression: enabled
// - Analytics-focused indices
// - Custom metrics fields
```

## Best Practices

### 1. Choose Appropriate Batch Sizes

```dart
// High volume: larger batches
.withBatchSize(200)

// Critical logs: smaller batches  
.withBatchSize(10)

// Development: immediate insert
.withBatchSize(1)
```

### 2. Configure Indices Wisely

```dart
// Minimal for write performance
.withIndices(['timestamp', 'level'])

// Comprehensive for query performance
.withIndices(['timestamp', 'level', 'tag', 'logger_name', 'user_id'])
```

### 3. Set Up Rotation for Large Tables

```dart
.withRotation(
  maxRows: 10000000, // 10M rows
  checkInterval: 3600, // Check hourly
  archivePrefix: 'logs_archive_',
)
```

### 4. Use Connection Pooling

```dart
.withMaxReconnectAttempts(5)
.withReconnectDelay(Duration(seconds: 2))
```

### 5. Secure Your Credentials

```dart
// Use environment variables
final password = Platform.environment['MYSQL_PASSWORD'];

// Or use a secrets manager
final password = await SecretManager.getSecret('mysql-password');
```

## Performance Optimization

### For Write Performance

- Use larger batch sizes (100-500)
- Minimize indices
- Enable compression
- Use MyISAM engine (if ACID not required)
- Disable prepared statements for bulk inserts

### For Query Performance

- Create appropriate indices
- Use InnoDB engine
- Partition large tables
- Regular table optimization
- Archive old data

### For Reliability

- Enable automatic reconnection
- Use prepared statements
- Configure appropriate timeouts
- Monitor connection health
- Set up rotation for large tables

## Troubleshooting

### Connection Issues

1. **Check network connectivity** to MySQL server
2. **Verify credentials** are correct
3. **Check firewall rules** for port 3306
4. **Enable SSL** if required by server
5. **Increase timeout** for slow networks

### Performance Issues

- Increase `batchSize` to reduce insert frequency
- Enable `useCompression` for large messages
- Reduce number of indices
- Consider table partitioning
- Archive old data regularly

### Table Size Issues

Enable rotation:
```dart
.withRotation(maxRows: 5000000)
```

Or manually archive:
```sql
CREATE TABLE logs_archive_2024 LIKE logs;
INSERT INTO logs_archive_2024 SELECT * FROM logs WHERE timestamp < '2025-01-01';
DELETE FROM logs WHERE timestamp < '2025-01-01';
```

## Testing

For unit tests, use test mode to avoid database connections:

```dart
final appender = await mySqlAppenderBuilder()
    .withConnection('localhost', 3306, 'test')
    .withTable('test_logs')
    .build(test: true); // No actual database operations
```

## Database Permissions

Minimum required permissions:

```sql
GRANT SELECT, INSERT, CREATE, INDEX ON database.* TO 'logger'@'%';

-- For rotation support, also need:
GRANT DROP, ALTER ON database.* TO 'logger'@'%';
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- Main Package: [any_logger](https://pub.dev/packages/any_logger)
- Issues: [GitHub Issues](https://github.com/raoulsson/any_logger_mysql/issues)
- Examples: See `/example` folder in the package

---

Part of the [Any Logger](https://pub.dev/packages/any_logger) ecosystem.

## 💚 Funding

- 🏅 https://github.com/sponsors/raoulsson
- 🪙 https://www.buymeacoffee.com/raoulsson

---

**Happy Logging! 🎉**
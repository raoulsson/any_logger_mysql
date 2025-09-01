import 'package:any_logger/any_logger.dart';
import 'package:any_logger_mysql/any_logger_mysql.dart';

/// Example configurations for MySQL appender
///
/// These examples demonstrate various configuration options
/// without actually connecting to a database.
void main() async {
  // Ensure the MYSQL appender is registered
  AnyLoggerMySqlExtension.register();

  print('MySQL Appender Configuration Examples\n');
  print('=' * 50);

  // Example 1: Basic configuration
  example1_basicConfig();

  // Example 2: Advanced table configuration
  example2_tableConfig();

  // Example 3: Performance and optimization
  example3_performance();

  // Example 4: Using the builder pattern
  await example4_builder();

  // Example 5: Integration with LoggerFactory
  await example5_loggerFactory();

  // Example 6: Query examples
  await example6_queries();

  print('\n' + '=' * 50);
  print('Examples completed (no actual database connections made)');
}

/// Example 1: Basic MySQL configuration
void example1_basicConfig() {
  print('\n### Example 1: Basic Configuration ###\n');

  final config = {
    'type': 'MYSQL',
    'host': 'localhost',
    'port': 3306,
    'database': 'app_logs',
    'user': 'logger',
    'password': 'secure_password',
    'table': 'logs',
    'level': 'INFO',
    'batchSize': 50,
    'batchIntervalSeconds': 10,
  };

  print('Basic config:');
  config.forEach((key, value) {
    if (key == 'password') {
      print('  $key: ******');
    } else {
      print('  $key: $value');
    }
  });

  // With SSL
  final sslConfig = {
    'type': 'MYSQL',
    'host': 'secure-db.example.com',
    'port': 3306,
    'database': 'production',
    'user': 'app_user',
    'password': 'strong_password',
    'useSSL': true,
    'connectionTimeout': 60,
    'level': 'WARN',
  };

  print('\nSSL config:');
  sslConfig.forEach((key, value) {
    if (key == 'password') {
      print('  $key: ******');
    } else {
      print('  $key: $value');
    }
  });
}

/// Example 2: Advanced table configuration
void example2_tableConfig() {
  print('\n### Example 2: Table Configuration ###\n');

  // Custom table structure
  final customTableConfig = {
    'type': 'MYSQL',
    'host': 'localhost',
    'database': 'analytics',
    'table': 'events',
    'autoCreateTable': true,
    'tableEngine': 'InnoDB',
    'charset': 'utf8mb4',
    'useCompression': true,
    'customFields': {
      'user_id': 'VARCHAR(100)',
      'event_type': 'VARCHAR(50)',
      'event_data': 'JSON',
      'ip_address': 'VARCHAR(45)',
      'duration_ms': 'INT',
      'cost': 'DECIMAL(10,2)',
    },
    'createIndices': true,
    'indexColumns': ['timestamp', 'level', 'user_id', 'event_type'],
  };

  print('Custom table configuration:');
  customTableConfig.forEach((key, value) {
    if (value is Map) {
      print('  $key:');
      value.forEach((k, v) => print('    $k: $v'));
    } else if (value is List) {
      print('  $key: ${value.join(', ')}');
    } else {
      print('  $key: $value');
    }
  });

  // Audit logging table
  final auditConfig = {
    'type': 'MYSQL',
    'host': 'audit-db.internal',
    'database': 'compliance',
    'table': 'audit_trail',
    'tableEngine': 'InnoDB', // ACID compliance
    'customFields': {
      'user_id': 'VARCHAR(100) NOT NULL',
      'action': 'VARCHAR(255) NOT NULL',
      'resource': 'VARCHAR(255)',
      'result': 'ENUM("SUCCESS", "FAILURE", "ERROR")',
      'ip_address': 'VARCHAR(45)',
      'session_id': 'VARCHAR(100)',
    },
    'enableRotation': false, // Never delete audit logs
    'createIndices': true,
    'indexColumns': ['timestamp', 'user_id', 'action', 'result'],
  };

  print('\nAudit table configuration:');
  print('  Table: ${auditConfig['table']}');
  print('  Engine: ${auditConfig['tableEngine']}');
  print('  Rotation: ${auditConfig['enableRotation']}');
  print(
      '  Custom fields: ${(auditConfig['customFields'] as Map).keys.join(', ')}');
}

/// Example 3: Performance and optimization settings
void example3_performance() {
  print('\n### Example 3: Performance Configuration ###\n');

  // High-volume configuration
  final highVolumeConfig = {
    'type': 'MYSQL',
    'host': 'db-cluster.example.com',
    'database': 'logs',
    'table': 'high_volume',
    'batchSize': 500,
    'batchIntervalSeconds': 5,
    'usePreparedStatements': true,
    'useCompression': true,
    'maxReconnectAttempts': 5,
    'reconnectDelaySeconds': 2,
    'enableRotation': true,
    'maxRows': 10000000, // 10 million rows
    'rotationCheckInterval': 3600, // Check hourly
    'archiveTablePrefix': 'archive_',
    'createIndices': true,
    'indexColumns': ['timestamp', 'level'], // Minimal for performance
  };

  print('High-volume configuration:');
  highVolumeConfig.forEach((key, value) {
    if (value is List) {
      print('  $key: ${value.join(', ')}');
    } else {
      print('  $key: $value');
    }
  });

  // Development configuration (immediate insert)
  final devConfig = {
    'type': 'MYSQL',
    'host': 'localhost',
    'database': 'dev_logs',
    'table': 'debug',
    'batchSize': 1, // Insert immediately
    'batchIntervalSeconds': 1,
    'autoCreateTable': true,
    'createIndices': true,
    'indexColumns': ['timestamp', 'level', 'tag', 'logger_name', 'class_name'],
    'level': 'DEBUG',
  };

  print('\nDevelopment configuration:');
  devConfig.forEach((key, value) {
    if (value is List) {
      print('  $key: ${value.join(', ')}');
    } else {
      print('  $key: $value');
    }
  });
}

/// Example 4: Using the builder pattern
Future<void> example4_builder() async {
  print('\n### Example 4: Builder Pattern ###\n');

  // Create appender using builder (in test mode)
  final appender = await mySqlAppenderBuilder()
      .withConnection('localhost', 3306, 'myapp')
      .withCredentials('user', 'password')
      .withTable('logs')
      .withLevel(Level.INFO)
      .withBatchSize(100)
      .withBatchIntervalSeconds(10)
      .withIndices(['timestamp', 'level', 'tag'])
      .withRotation(maxRows: 5000000, checkInterval: 1800)
      .build(test: true);

  print('Built appender with:');
  print('  Host: ${appender.host}:${appender.port}');
  print('  Database: ${appender.database}');
  print('  Table: ${appender.table}');
  print('  Level: ${appender.level}');
  print('  Batch size: ${appender.batchSize}');
  print('  Rotation enabled: ${appender.enableRotation}');

  // Using presets
  final productionAppender = await mySqlAppenderBuilder()
      .withConnection('prod-db.example.com', 3306, 'production')
      .withCredentials('app_user', 'secure_pass')
      .withProductionPreset()
      .build(test: true);

  print('\nProduction preset appender:');
  print('  Batch size: ${productionAppender.batchSize}');
  print('  Reconnect attempts: ${productionAppender.maxReconnectAttempts}');
  print('  Rotation enabled: ${productionAppender.enableRotation}');
  print('  Max rows: ${productionAppender.maxRows}');

  // Audit preset
  final auditAppender = await mySqlAppenderBuilder()
      .withConnection('audit-db.internal', 3306, 'compliance')
      .withCredentials('audit_user', 'audit_pass')
      .withTable('audit_trail')
      .withAuditPreset()
      .build(test: true);

  print('\nAudit preset appender:');
  print('  Table: ${auditAppender.table}');
  print('  Custom fields: ${auditAppender.customFields.keys.join(', ')}');
  print('  Rotation: ${auditAppender.enableRotation}');

  await appender.dispose();
  await productionAppender.dispose();
  await auditAppender.dispose();
}

/// Example 5: Integration with LoggerFactory
Future<void> example5_loggerFactory() async {
  print('\n### Example 5: LoggerFactory Integration ###\n');

  // Configuration-based setup
  final config = {
    'appenders': [
      {
        'type': 'CONSOLE',
        'level': 'INFO',
        'format': '[%l] %m',
      },
      {
        'type': 'MYSQL',
        'host': 'localhost',
        'port': 3306,
        'database': 'app_logs',
        'user': 'logger',
        'password': 'password',
        'table': 'logs',
        'level': 'INFO',
        'batchSize': 100,
        'batchIntervalSeconds': 10,
      }
    ]
  };

  print('LoggerFactory configuration:');
  final appenders = config['appenders'] as List<Map<String, dynamic>>;
  print('  Appenders: ${appenders.length}');
  for (var i = 0; i < appenders.length; i++) {
    final appender = appenders[i];
    print(
        '    ${i + 1}. Type: ${appender['type']}, Level: ${appender['level']}');
  }

  // Initialize in test mode to avoid actual database connections
  await LoggerFactory.init(config, test: true);

  // Get the logger and check appenders
  final logger = LoggerFactory.getRootLogger();
  print('\nLogger configured with ${logger.appenders.length} appenders:');
  for (var appender in logger.appenders) {
    print('  - ${appender.getType()} (Level: ${appender.level})');
  }

  // Clean up
  await LoggerFactory.dispose();

  // Builder-based setup
  print('\nUsing LoggerBuilder:');
  await LoggerFactory.builder()
      .replaceAll()
      .console(level: Level.INFO)
      .mysql(
        host: 'localhost',
        database: 'app_logs',
        user: 'logger',
        password: 'password',
        level: Level.WARN,
        batchSize: 50,
      )
      .build(test: true);

  final logger2 = LoggerFactory.getRootLogger();
  print('Builder created ${logger2.appenders.length} appenders');

  await LoggerFactory.dispose();

  // Using presets
  print('\nUsing production preset with MySQL:');
  final prodConfig = MySqlPresets.productionWithMySql(
    host: 'prod-db.example.com',
    database: 'production',
    user: 'app_user',
    password: 'secure_password',
    table: 'app_logs',
  );

  await LoggerFactory.init(prodConfig, test: true);
  final logger3 = LoggerFactory.getRootLogger();
  print('Production preset created ${logger3.appenders.length} appenders');

  await LoggerFactory.dispose();
}

/// Example 6: Query examples (demonstrating the query API)
Future<void> example6_queries() async {
  print('\n### Example 6: Query API Examples ###\n');

  // Note: These are examples of how to query logs
  // In test mode, these won't actually execute

  print('Query API examples:');
  print('');
  print('// Query last 100 errors:');
  print('final errors = await appender.queryLogs(');
  print('  minLevel: Level.ERROR,');
  print('  limit: 100,');
  print(');');
  print('');
  print('// Query logs from last hour:');
  print('final recent = await appender.queryLogs(');
  print('  startTime: DateTime.now().subtract(Duration(hours: 1)),');
  print('  orderBy: "timestamp DESC",');
  print(');');
  print('');
  print('// Query by tag and logger:');
  print('final tagged = await appender.queryLogs(');
  print('  tag: "PAYMENT",');
  print('  loggerName: "PaymentService",');
  print('  limit: 50,');
  print(');');
  print('');
  print('// Query with pagination:');
  print('final page2 = await appender.queryLogs(');
  print('  limit: 20,');
  print('  offset: 20,');
  print('  orderBy: "timestamp DESC",');
  print(');');
  print('');
  print('// Complex query:');
  print('final complex = await appender.queryLogs(');
  print('  minLevel: Level.WARN,');
  print('  startTime: DateTime.now().subtract(Duration(days: 7)),');
  print('  endTime: DateTime.now(),');
  print('  tag: "API",');
  print('  limit: 1000,');
  print(');');
}

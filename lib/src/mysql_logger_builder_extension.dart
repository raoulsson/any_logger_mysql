import 'package:any_logger/any_logger.dart';

import '../any_logger_mysql.dart';

/// Builder extension for MySqlAppender
extension MySqlLoggerBuilderExtension on LoggerBuilder {
  /// Adds a MySQL appender to the logger configuration.
  LoggerBuilder mysql({
    required String host,
    required String database,
    int port = 3306,
    String? user,
    String? password,
    String table = 'logs',
    bool useSSL = false,
    int connectionTimeout = 30,
    bool autoCreateTable = true,
    bool useCompression = false,
    String? tableEngine,
    String? charset,
    Map<String, String>? customFields,
    Level level = Level.INFO,
    int batchSize = 50,
    int batchIntervalSeconds = 10,
    bool usePreparedStatements = true,
    int maxReconnectAttempts = 3,
    int reconnectDelaySeconds = 2,
    bool enableRotation = false,
    int maxRows = 1000000,
    int rotationCheckInterval = 3600,
    String? archiveTablePrefix,
    bool createIndices = true,
    List<String>? indexColumns,
    String format = Appender.defaultFormat,
    String dateFormat = Appender.defaultDateFormat,
  }) {
    final config = <String, dynamic>{
      'type': MySqlAppender.appenderName,
      'host': host,
      'port': port,
      'database': database,
      'table': table,
      'useSSL': useSSL,
      'connectionTimeout': connectionTimeout,
      'autoCreateTable': autoCreateTable,
      'useCompression': useCompression,
      'level': level.name,
      'format': format,
      'dateFormat': dateFormat,
      'batchSize': batchSize,
      'batchIntervalSeconds': batchIntervalSeconds,
      'usePreparedStatements': usePreparedStatements,
      'maxReconnectAttempts': maxReconnectAttempts,
      'reconnectDelaySeconds': reconnectDelaySeconds,
      'enableRotation': enableRotation,
      'maxRows': maxRows,
      'rotationCheckInterval': rotationCheckInterval,
      'createIndices': createIndices,
    };

    if (user != null) config['user'] = user;
    if (password != null) config['password'] = password;
    if (tableEngine != null) config['tableEngine'] = tableEngine;
    if (charset != null) config['charset'] = charset;
    if (customFields != null && customFields.isNotEmpty) {
      config['customFields'] = customFields;
    }
    if (archiveTablePrefix != null) {
      config['archiveTablePrefix'] = archiveTablePrefix;
    }
    if (indexColumns != null && indexColumns.isNotEmpty) {
      config['indexColumns'] = indexColumns;
    }

    return addAppenderConfig(config);
  }

  /// Adds a MySQL appender with high-volume configuration (convenience method).
  LoggerBuilder mysqlHighVolume({
    required String host,
    required String database,
    String? user,
    String? password,
    String table = 'logs',
    Level level = Level.INFO,
  }) {
    return mysql(
      host: host,
      database: database,
      user: user,
      password: password,
      table: table,
      level: level,
      batchSize: 200,
      batchIntervalSeconds: 5,
      useCompression: true,
      usePreparedStatements: true,
      createIndices: true,
      indexColumns: ['timestamp', 'level'],
    );
  }

  /// Adds a MySQL appender with production configuration (convenience method).
  LoggerBuilder mysqlProduction({
    required String host,
    required String database,
    required String user,
    required String password,
    String table = 'logs',
    Level level = Level.INFO,
    bool enableRotation = true,
  }) {
    return mysql(
      host: host,
      database: database,
      user: user,
      password: password,
      table: table,
      level: level,
      batchSize: 100,
      batchIntervalSeconds: 10,
      usePreparedStatements: true,
      maxReconnectAttempts: 5,
      reconnectDelaySeconds: 2,
      enableRotation: enableRotation,
      maxRows: 10000000,
      rotationCheckInterval: 3600,
      useCompression: false,
      createIndices: true,
    );
  }

  /// Adds a MySQL appender for audit logging (convenience method).
  LoggerBuilder mysqlAudit({
    required String host,
    required String database,
    required String user,
    required String password,
    String table = 'audit_logs',
    Level level = Level.INFO,
  }) {
    return mysql(
      host: host,
      database: database,
      user: user,
      password: password,
      table: table,
      level: level,
      batchSize: 50,
      batchIntervalSeconds: 5,
      tableEngine: 'InnoDB',
      enableRotation: false,
      // Keep all audit logs
      customFields: {
        'user_id': 'VARCHAR(100)',
        'action': 'VARCHAR(255)',
        'ip_address': 'VARCHAR(45)',
        'user_agent': 'TEXT',
      },
      createIndices: true,
      indexColumns: ['timestamp', 'level', 'user_id', 'action'],
    );
  }
}

import 'package:any_logger/any_logger.dart';

import '../any_logger_mysql.dart';

/// Extension methods for adding MySqlAppender to presets
extension MySqlPresets on LoggerPresets {
  /// Production preset with MySQL logging
  static Map<String, dynamic> productionWithMySql({
    required String host,
    required String database,
    required String user,
    required String password,
    String table = 'logs',
    String? appVersion,
  }) {
    return {
      'appenders': [
        {
          'type': 'CONSOLE',
          'format': '[%sid][%l] %m',
          'level': 'WARN',
          'dateFormat': 'HH:mm:ss',
        },
        {
          'type': MySqlAppender.appenderName,
          'host': host,
          'port': 3306,
          'database': database,
          'user': user,
          'password': password,
          'table': table,
          'level': 'INFO',
          'batchSize': 100,
          'batchIntervalSeconds': 10,
          'usePreparedStatements': true,
          'maxReconnectAttempts': 5,
          'enableRotation': true,
          'maxRows': 10000000,
          'createIndices': true,
          'indexColumns': ['timestamp', 'level', 'tag'],
        }
      ]
    };
  }

  /// Development preset with MySQL for debugging
  static Map<String, dynamic> developmentWithMySql({
    required String host,
    required String database,
    String? user,
    String? password,
    String table = 'dev_logs',
  }) {
    return {
      'appenders': [
        {
          'type': 'CONSOLE',
          'format': '[%d][%l][%c] %m [%f]',
          'level': 'DEBUG',
          'dateFormat': 'HH:mm:ss.SSS',
        },
        {
          'type': MySqlAppender.appenderName,
          'host': host,
          'port': 3306,
          'database': database,
          'user': user,
          'password': password,
          'table': table,
          'level': 'DEBUG',
          'batchSize': 1, // Insert immediately for debugging
          'batchIntervalSeconds': 1,
          'autoCreateTable': true,
          'createIndices': true,
          'indexColumns': ['timestamp', 'level', 'tag', 'logger_name', 'class_name'],
        }
      ]
    };
  }

  /// Analytics preset with MySQL for event tracking
  static Map<String, dynamic> analyticsWithMySql({
    required String host,
    required String database,
    required String user,
    required String password,
    String table = 'events',
  }) {
    return {
      'appenders': [
        {
          'type': 'CONSOLE',
          'format': '[%l] %m',
          'level': 'ERROR',
          'dateFormat': 'HH:mm:ss',
        },
        {
          'type': MySqlAppender.appenderName,
          'host': host,
          'port': 3306,
          'database': database,
          'user': user,
          'password': password,
          'table': table,
          'level': 'INFO',
          'batchSize': 500,
          'batchIntervalSeconds': 30,
          'useCompression': true,
          'customFields': {
            'event_type': 'VARCHAR(100)',
            'event_data': 'JSON',
            'duration_ms': 'INT',
            'user_segment': 'VARCHAR(50)',
            'revenue': 'DECIMAL(10,2)',
          },
          'createIndices': true,
          'indexColumns': ['timestamp', 'event_type', 'user_segment'],
        }
      ]
    };
  }

  /// Audit logging preset with MySQL
  static Map<String, dynamic> auditWithMySql({
    required String host,
    required String database,
    required String user,
    required String password,
    String table = 'audit_logs',
  }) {
    return {
      'appenders': [
        {
          'type': 'FILE',
          'format': '[%d][%l] %m [%user_id]',
          'level': 'INFO',
          'dateFormat': 'yyyy-MM-dd HH:mm:ss.SSS',
          'filePattern': 'audit',
          'path': 'logs/',
          'rotationCycle': 'DAY',
        },
        {
          'type': MySqlAppender.appenderName,
          'host': host,
          'port': 3306,
          'database': database,
          'user': user,
          'password': password,
          'table': table,
          'level': 'INFO',
          'batchSize': 50,
          'batchIntervalSeconds': 5,
          'tableEngine': 'InnoDB', // For ACID compliance
          'enableRotation': false, // Never delete audit logs
          'customFields': {
            'user_id': 'VARCHAR(100) NOT NULL',
            'action': 'VARCHAR(255) NOT NULL',
            'resource': 'VARCHAR(255)',
            'result': 'ENUM("SUCCESS", "FAILURE", "ERROR")',
            'ip_address': 'VARCHAR(45)',
            'user_agent': 'TEXT',
            'session_id': 'VARCHAR(100)',
            'request_id': 'VARCHAR(100)',
          },
          'createIndices': true,
          'indexColumns': ['timestamp', 'user_id', 'action', 'result', 'session_id'],
        }
      ]
    };
  }

  /// High-volume logging preset with MySQL
  static Map<String, dynamic> highVolumeWithMySql({
    required String host,
    required String database,
    required String user,
    required String password,
    String table = 'high_volume_logs',
    int partitionDays = 7,
  }) {
    return {
      'appenders': [
        {
          'type': 'CONSOLE',
          'format': '[%l] %m',
          'level': 'ERROR',
        },
        {
          'type': MySqlAppender.appenderName,
          'host': host,
          'port': 3306,
          'database': database,
          'user': user,
          'password': password,
          'table': table,
          'level': 'INFO',
          'batchSize': 500,
          'batchIntervalSeconds': 5,
          'usePreparedStatements': true,
          'useCompression': true,
          'tableEngine': 'InnoDB',
          'enableRotation': true,
          'maxRows': 50000000,
          // 50 million rows
          'rotationCheckInterval': 1800,
          // Check every 30 minutes
          'archiveTablePrefix': '${table}_archive',
          'createIndices': true,
          'indexColumns': ['timestamp', 'level'],
          // Minimal indices for performance
        }
      ]
    };
  }

  /// Microservices preset with MySQL for distributed logging
  static Map<String, dynamic> microservicesWithMySql({
    required String host,
    required String database,
    required String user,
    required String password,
    required String serviceName,
    String table = 'service_logs',
  }) {
    return {
      'appenders': [
        {
          'type': 'CONSOLE',
          'format': '[$serviceName][%l] %m',
          'level': 'INFO',
          'dateFormat': 'HH:mm:ss',
        },
        {
          'type': MySqlAppender.appenderName,
          'host': host,
          'port': 3306,
          'database': database,
          'user': user,
          'password': password,
          'table': table,
          'level': 'INFO',
          'batchSize': 100,
          'batchIntervalSeconds': 10,
          'customFields': {
            'service_name': 'VARCHAR(50) DEFAULT "$serviceName"',
            'service_version': 'VARCHAR(20)',
            'trace_id': 'VARCHAR(100)',
            'span_id': 'VARCHAR(100)',
            'parent_span_id': 'VARCHAR(100)',
            'correlation_id': 'VARCHAR(100)',
            'environment': 'VARCHAR(20)',
          },
          'createIndices': true,
          'indexColumns': ['timestamp', 'level', 'service_name', 'trace_id', 'correlation_id'],
        }
      ]
    };
  }
}

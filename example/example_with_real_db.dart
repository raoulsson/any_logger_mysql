import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:any_logger/any_logger.dart';
import 'package:any_logger_mysql/any_logger_mysql.dart';

// docker exec -it mysql-test mysql -uroot -pyourpassword testdb
// 
// -- Count by level (fixed for MySQL 5.7)
// SELECT level, COUNT(*) as count
// FROM app_logs
// GROUP BY level
// ORDER BY MIN(level_value);
// 
// -- Alternative: include level_value in GROUP BY
// SELECT level, level_value, COUNT(*) as count
// FROM app_logs
// GROUP BY level, level_value
// ORDER BY level_value;
// 
// -- Check timestamp precision (milliseconds working?)
// SELECT id, timestamp, message
// FROM app_logs
// ORDER BY timestamp DESC, id DESC;
// 
// -- See logs per second (without window functions)
// SELECT
//     DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i:%s') as second,
//     COUNT(*) as logs_in_second
// FROM app_logs
// GROUP BY second
// ORDER BY second DESC;
// 
// -- Activity timeline
// SELECT
//     HOUR(timestamp) as hour,
//     MINUTE(timestamp) as minute,
//     COUNT(*) as logs,
//     GROUP_CONCAT(DISTINCT tag) as tags
// FROM app_logs
// GROUP BY hour, minute
// ORDER BY hour DESC, minute DESC;
// 
// -- Performance check - see batching working
// SELECT
//     timestamp,
//     COUNT(*) as batch_size,
//     GROUP_CONCAT(SUBSTRING(message, 1, 20)) as messages
// FROM app_logs
// GROUP BY timestamp
// HAVING COUNT(*) > 1
// ORDER BY timestamp DESC;
void main() async {
  print('MySQL Logger Console Application');
  print('=================================\n');

  AnyLoggerMySqlExtension.register();

  try {
    // Initialize the logger with MySQL appender
    await initializeLogger();

    // Run the demo application
    await runDemoApp();
  } catch (e) {
    print('Fatal error: $e');
    exit(1);
  }
}


/// Initialize the logger with MySQL configuration
Future<void> initializeLogger() async {
  print('Initializing logger with MySQL appender...');

  // Method 1: Using JSON configuration
  await LoggerFactory.init({
    'appenders': [
      {
        'type': 'CONSOLE',
        'format': '[%d][%l][%c] %m',
        'level': 'DEBUG',
        'dateFormat': 'HH:mm:ss.SSS',
      },
      {
        'type': 'MYSQL',
        'host': 'localhost',
        'port': 3306,
        'database': 'testdb',
        'user': 'root',
        'password': 'yourpassword',
        'table': 'app_logs',
        'level': 'DEBUG',
        'autoCreateTable': true,
        'batchSize': 10,
        'batchIntervalSeconds': 5,
        'createIndices': true,
        'indexColumns': ['timestamp', 'level', 'tag', 'logger_name'],
        'customFields': {
          'app_module': 'VARCHAR(100)',
          'user_action': 'VARCHAR(255)',
          'response_time_ms': 'INT',
        },
      }
    ]
  });

  // Alternative Method 2: Using builder pattern (commented out)
  /*
  await LoggerFactory.initialize((builder) {
    builder
      .console(
        level: Level.DEBUG,
        format: '[%d][%l][%c] %m',
      )
      .mysql(
        host: 'localhost',
        port: 3306,
        database: 'testdb',
        user: 'root',
        password: 'yourpassword',
        table: 'app_logs',
        level: Level.DEBUG,
        autoCreateTable: true,
        batchSize: 10,
        batchIntervalSeconds: 5,
      );
  });
  */

  print('Logger initialized successfully!\n');
}

/// Main demo application
Future<void> runDemoApp() async {
  final logger = LoggerFactory.getLogger('DemoApp');

  // Set some MDC values for context
  LoggerFactory.setMdcValue('session_id', generateSessionId());
  LoggerFactory.setMdcValue('environment', 'development');

  print('Starting demo application...\n');

  bool running = true;
  while (running) {
    printMenu();

    stdout.write('\nEnter your choice: ');
    String? choice = stdin.readLineSync();

    switch (choice) {
      case '1':
        await simulateUserActivity(logger);
        break;
      case '2':
        await simulateErrorScenarios(logger);
        break;
      case '3':
        await performBulkLogging(logger);
        break;
      case '4':
        await simulateBusinessOperations(logger);
        break;
      case '5':
        await queryLogs();
        break;
      case '6':
        await testLogLevels(logger);
        break;
      case '7':
        await showStatistics();
        break;
      case '8':
        await flushLogs();
        break;
      case '9':
        running = false;
        await cleanup();
        break;
      default:
        print('Invalid choice. Please try again.');
    }

    if (running) {
      print('\nPress Enter to continue...');
      stdin.readLineSync();
    }
  }
}

void printMenu() {
  print('\n╔════════════════════════════════════════╗');
  print('║     MySQL Logger Demo Application      ║');
  print('╠════════════════════════════════════════╣');
  print('║ 1. Simulate User Activity              ║');
  print('║ 2. Simulate Error Scenarios            ║');
  print('║ 3. Perform Bulk Logging                ║');
  print('║ 4. Simulate Business Operations        ║');
  print('║ 5. Query Logs from Database            ║');
  print('║ 6. Test Different Log Levels           ║');
  print('║ 7. Show Statistics                     ║');
  print('║ 8. Flush Logs to Database              ║');
  print('║ 9. Exit                                ║');
  print('╚════════════════════════════════════════╝');
}

/// Simulate user activity logging
Future<void> simulateUserActivity(Logger logger) async {
  print('\n📱 Simulating user activity...\n');

  final users = ['alice', 'bob', 'charlie', 'diana'];
  final actions = ['login', 'view_dashboard', 'update_profile', 'logout'];
  final random = Random();

  for (int i = 0; i < 5; i++) {
    final user = users[random.nextInt(users.length)];
    final action = actions[random.nextInt(actions.length)];
    final responseTime = random.nextInt(500) + 50;

    // Set MDC context for this operation
    LoggerFactory.setMdcValue('user_id', user);
    LoggerFactory.setMdcValue('response_time', responseTime.toString());

    switch (action) {
      case 'login':
        logger.logInfo('User logged in successfully', tag: 'AUTH');
        break;
      case 'view_dashboard':
        logger.logInfo(
            'Dashboard loaded with ${random.nextInt(10) + 1} widgets',
            tag: 'UI');
        break;
      case 'update_profile':
        logger.logInfo('Profile updated', tag: 'USER');
        break;
      case 'logout':
        logger.logInfo('User logged out', tag: 'AUTH');
        break;
    }

    print('✓ Logged: $user performed $action (${responseTime}ms)');
    await Future.delayed(Duration(milliseconds: 500));
  }

  LoggerFactory.removeMdcValue('user_id');
  LoggerFactory.removeMdcValue('response_time');
}

/// Simulate error scenarios
Future<void> simulateErrorScenarios(Logger logger) async {
  print('\n⚠️ Simulating error scenarios...\n');

  // Validation error
  logger.logWarn('Invalid email format provided: not-an-email',
      tag: 'VALIDATION');
  print('✓ Logged validation warning');

  // Database connection error
  try {
    throw TimeoutException('Database connection timeout after 30 seconds');
  } catch (e, stackTrace) {
    logger.logError('Database connection failed',
        exception: e, stackTrace: stackTrace, tag: 'DATABASE');
    print('✓ Logged database error with stack trace');
  }

  // Critical system error
  logger.logFatal('Out of memory: Available heap space: 12MB', tag: 'SYSTEM');
  print('✓ Logged critical system error');

  // Business logic error
  logger.logError('Payment processing failed: Insufficient funds',
      tag: 'PAYMENT');
  print('✓ Logged business logic error');

  await Future.delayed(Duration(seconds: 1));
}

/// Perform bulk logging
Future<void> performBulkLogging(Logger logger) async {
  print('\n📊 Performing bulk logging...\n');

  final stopwatch = Stopwatch()..start();
  final random = Random();

  for (int i = 1; i <= 100; i++) {
    final level = random.nextInt(4);
    final metric = random.nextInt(100);

    LoggerFactory.setMdcValue(
        'batch_id', 'BULK_${DateTime.now().millisecondsSinceEpoch}');
    LoggerFactory.setMdcValue('metric_value', metric.toString());

    switch (level) {
      case 0:
        logger.logDebug('Processing item $i of 100', tag: 'BATCH');
        break;
      case 1:
        logger.logInfo('Batch progress: $i%', tag: 'BATCH');
        break;
      case 2:
        logger.logWarn('Slow processing detected for item $i',
            tag: 'PERFORMANCE');
        break;
      case 3:
        logger.logTrace('Detailed metrics: value=$metric', tag: 'METRICS');
        break;
    }

    if (i % 20 == 0) {
      print('Progress: $i/100 logs generated');
    }
  }

  stopwatch.stop();
  print('\n✓ Generated 100 log entries in ${stopwatch.elapsedMilliseconds}ms');

  LoggerFactory.removeMdcValue('batch_id');
  LoggerFactory.removeMdcValue('metric_value');
}

/// Simulate business operations
Future<void> simulateBusinessOperations(Logger logger) async {
  print('\n💼 Simulating business operations...\n');

  final businessLogger = LoggerFactory.getLogger('BusinessService');
  final random = Random();

  // Order processing
  final orderId = 'ORD-${random.nextInt(10000)}';
  LoggerFactory.setMdcValue('order_id', orderId);

  businessLogger.logInfo('New order received', tag: 'ORDER');
  print('✓ Order $orderId received');

  await Future.delayed(Duration(milliseconds: 200));
  businessLogger.logDebug('Validating order items', tag: 'ORDER');

  await Future.delayed(Duration(milliseconds: 300));
  businessLogger.logInfo('Payment processed: \$${random.nextInt(500) + 50}',
      tag: 'PAYMENT');
  print('✓ Payment processed');

  await Future.delayed(Duration(milliseconds: 200));
  businessLogger.logInfo('Order confirmed and sent to fulfillment',
      tag: 'ORDER');
  print('✓ Order sent to fulfillment');

  // Inventory update
  businessLogger.logDebug('Updating inventory levels', tag: 'INVENTORY');

  // Email notification
  businessLogger.logInfo('Order confirmation email sent', tag: 'NOTIFICATION');
  print('✓ Confirmation email sent');

  LoggerFactory.removeMdcValue('order_id');
}

/// Query logs from database
Future<void> queryLogs() async {
  print('\n🔍 Querying logs from database...\n');

  // This would normally use your MySqlAppender's queryLogs method
  // For demo purposes, we'll simulate it
  print('Fetching last 10 ERROR logs...');
  print('┌────────────────┬───────┬──────────────────────────┐');
  print('│   Timestamp    │ Level │        Message           │');
  print('├────────────────┼───────┼──────────────────────────┤');
  print('│ 10:23:45.123   │ ERROR │ Database connection fail │');
  print('│ 10:24:12.456   │ ERROR │ Payment processing fail  │');
  print('└────────────────┴───────┴──────────────────────────┘');

  print(
      '\nNote: Implement actual database query using MySqlAppender.queryLogs()');
}

/// Test different log levels
Future<void> testLogLevels(Logger logger) async {
  print('\n🎚️ Testing different log levels...\n');

  logger.logTrace('TRACE: Most detailed diagnostic information', tag: 'TEST');
  print('✓ TRACE level logged');

  logger.logDebug('DEBUG: Diagnostic information for debugging', tag: 'TEST');
  print('✓ DEBUG level logged');

  logger.logInfo('INFO: Informational messages', tag: 'TEST');
  print('✓ INFO level logged');

  logger.logWarn('WARN: Warning messages', tag: 'TEST');
  print('✓ WARN level logged');

  logger.logError('ERROR: Error messages', tag: 'TEST');
  print('✓ ERROR level logged');

  logger.logFatal('FATAL: Critical error messages', tag: 'TEST');
  print('✓ FATAL level logged');
}

/// Show statistics
Future<void> showStatistics() async {
  print('\n📈 Logger Statistics\n');
  print('═══════════════════════════════════════');

  // This would normally get stats from your MySqlAppender
  print('Total logs generated: ~250');
  print('Successful inserts: ~240');
  print('Failed inserts: 0');
  print('Buffer size: 10');
  print('Last insert: ${DateTime.now()}');
  print('Connection status: Active');

  print('\nNote: Implement actual stats using MySqlAppender.getStatistics()');
}

/// Flush logs to database
Future<void> flushLogs() async {
  print('\n💾 Flushing logs to database...');

  // Get all appenders and flush them
  await LoggerFactory.flushAll();

  print('✓ All pending logs flushed to database');
}

/// Cleanup and exit
Future<void> cleanup() async {
  print('\n🧹 Cleaning up...');

  // Clear MDC
  LoggerFactory.clearMdc();

  // Dispose of loggers
  await LoggerFactory.dispose();

  print('✓ Logger disposed');
  print('\nGoodbye! 👋');
}

/// Generate a random session ID
String generateSessionId() {
  final random = Random();
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(12, (index) => chars[random.nextInt(chars.length)])
      .join();
}

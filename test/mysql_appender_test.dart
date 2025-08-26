import 'package:any_logger/any_logger.dart';
import 'package:any_logger_mysql/any_logger_mysql.dart';
import 'package:test/test.dart';

void main() {
  // Ensure the MYSQL appender is registered before all tests
  setUpAll(() {
    AnyLoggerMySqlExtension.register();
  });

  group('MySqlAppender Configuration', () {
    tearDown(() async {
      await LoggerFactory.dispose();
    });

    test('should create appender from config', () async {
      final config = {
        'type': 'MYSQL',
        'host': 'localhost',
        'port': 3306,
        'database': 'test_db',
        'user': 'test_user',
        'password': 'test_pass',
        'table': 'logs',
        'level': 'INFO',
        'batchSize': 100,
        'batchIntervalSeconds': 10,
      };

      final appender = await MySqlAppender.fromConfig(config, test: true);

      expect(appender.getType(), equals('MYSQL'));
      expect(appender.host, equals('localhost'));
      expect(appender.port, equals(3306));
      expect(appender.database, equals('test_db'));
      expect(appender.user, equals('test_user'));
      expect(appender.password, equals('test_pass'));
      expect(appender.table, equals('logs'));
      expect(appender.level, equals(Level.INFO));
      expect(appender.batchSize, equals(100));
      expect(appender.batchInterval, equals(Duration(seconds: 10)));
    });

    test('should use default values for optional fields', () async {
      final config = {
        'type': 'MYSQL',
        'host': 'localhost',
        'database': 'test_db',
      };

      final appender = await MySqlAppender.fromConfig(config, test: true);

      expect(appender.port, equals(3306)); // Default MySQL port
      expect(appender.table, equals('logs')); // Default table name
      expect(appender.batchSize, equals(50)); // Default batch size
      expect(appender.batchInterval,
          equals(Duration(seconds: 10))); // Default interval
      expect(appender.useSSL, equals(false));
      expect(appender.autoCreateTable, equals(true));
      expect(appender.useCompression, equals(false));
      expect(appender.tableEngine, equals('InnoDB'));
      expect(appender.charset, equals('utf8mb4'));
    });

    test('should configure SSL settings', () async {
      final config = {
        'type': 'MYSQL',
        'host': 'secure.db.com',
        'database': 'secure_db',
        'useSSL': true,
        'connectionTimeout': 60,
      };

      final appender = await MySqlAppender.fromConfig(config, test: true);

      expect(appender.useSSL, equals(true));
      expect(appender.connectionTimeout, equals(60));
    });

    test('should configure table settings', () async {
      final config = {
        'type': 'MYSQL',
        'host': 'localhost',
        'database': 'test_db',
        'table': 'custom_logs',
        'autoCreateTable': false,
        'useCompression': true,
        'tableEngine': 'MyISAM',
        'charset': 'latin1',
        'customFields': {
          'user_id': 'VARCHAR(100)',
          'event_type': 'VARCHAR(50)',
        },
      };

      final appender = await MySqlAppender.fromConfig(config, test: true);

      expect(appender.table, equals('custom_logs'));
      expect(appender.autoCreateTable, equals(false));
      expect(appender.useCompression, equals(true));
      expect(appender.tableEngine, equals('MyISAM'));
      expect(appender.charset, equals('latin1'));
      expect(
          appender.customFields,
          equals({
            'user_id': 'VARCHAR(100)',
            'event_type': 'VARCHAR(50)',
          }));
    });

    test('should configure rotation settings', () async {
      final config = {
        'type': 'MYSQL',
        'host': 'localhost',
        'database': 'test_db',
        'enableRotation': true,
        'maxRows': 5000000,
        'rotationCheckInterval': 1800,
        'archiveTablePrefix': 'archive_',
      };

      final appender = await MySqlAppender.fromConfig(config, test: true);

      expect(appender.enableRotation, equals(true));
      expect(appender.maxRows, equals(5000000));
      expect(appender.rotationCheckInterval, equals(1800));
      expect(appender.archiveTablePrefix, equals('archive_'));
    });

    test('should configure index settings', () async {
      final config = {
        'type': 'MYSQL',
        'host': 'localhost',
        'database': 'test_db',
        'createIndices': true,
        'indexColumns': ['timestamp', 'level', 'tag', 'user_id'],
      };

      final appender = await MySqlAppender.fromConfig(config, test: true);

      expect(appender.createIndices, equals(true));
      expect(appender.indexColumns,
          equals(['timestamp', 'level', 'tag', 'user_id']));
    });

    test('should throw on missing required fields', () {
      // Missing host
      expect(
        () async => await MySqlAppender.fromConfig({
          'type': 'MYSQL',
          'database': 'test_db',
        }),
        throwsA(isA<ArgumentError>()),
      );

      // Missing database
      expect(
        () async => await MySqlAppender.fromConfig({
          'type': 'MYSQL',
          'host': 'localhost',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should throw for synchronous factory', () {
      final config = {
        'type': 'MYSQL',
        'host': 'localhost',
        'database': 'test_db',
      };

      expect(
        () => MySqlAppender.fromConfigSync(config),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('MySqlAppender Batching', () {
    late MySqlAppender appender;

    tearDown(() async {
      await appender.dispose();
          await LoggerFactory.dispose();
    });

    test('should batch logs until batch size reached', () async {
      appender = await MySqlAppender.fromConfig({
        'host': 'localhost',
        'database': 'test_db',
        'batchSize': 3,
        'batchIntervalSeconds': 60,
      }, test: true);

      final contextInfo = LoggerStackTrace.from(StackTrace.current);

      // Add logs but don't reach batch size
      appender.append(LogRecord(Level.INFO, 'Message 1', null, contextInfo));
      appender.append(LogRecord(Level.INFO, 'Message 2', null, contextInfo));

      // Buffer should have 2 items
      expect(appender.getStatistics()['bufferSize'], equals(2));

      // Add one more to trigger batch
      appender.append(LogRecord(Level.INFO, 'Message 3', null, contextInfo));

      // In test mode, buffer is cleared after batch
      expect(appender.getStatistics()['bufferSize'], equals(0));
    });

    test('should flush on dispose', () async {
      appender = await MySqlAppender.fromConfig({
        'host': 'localhost',
        'database': 'test_db',
        'batchSize': 100,
      }, test: true);

      final contextInfo = LoggerStackTrace.from(StackTrace.current);

      // Add some logs
      appender.append(LogRecord(Level.INFO, 'Message 1', null, contextInfo));
      appender.append(LogRecord(Level.INFO, 'Message 2', null, contextInfo));

      expect(appender.getStatistics()['bufferSize'], equals(2));

      // Dispose should flush
      await appender.dispose();
      expect(appender.getStatistics()['bufferSize'], equals(0));
    });

    test('should track statistics correctly', () async {
      appender = await MySqlAppender.fromConfig({
        'host': 'localhost',
        'database': 'test_db',
        'batchSize': 100,
      }, test: true);

      final stats = appender.getStatistics();
      expect(stats['successfulInserts'], equals(0));
      expect(stats['failedInserts'], equals(0));
      expect(stats['bufferSize'], equals(0));
      expect(stats['lastInsertTime'], isNull);

      // Add some logs and trigger insert
      final contextInfo = LoggerStackTrace.from(StackTrace.current);
      for (int i = 0; i < 100; i++) {
        appender.append(LogRecord(Level.INFO, 'Message $i', null, contextInfo));
      }

      // After batch is sent (in test mode)
      final statsAfter = appender.getStatistics();
      expect(statsAfter['successfulInserts'], equals(100));
      expect(statsAfter['bufferSize'], equals(0));
      expect(statsAfter['lastInsertTime'], isNotNull);
    });
  });

  group('MySqlAppenderBuilder', () {
    tearDown(() async {
      await LoggerFactory.dispose();
    });

    test('should build with basic configuration', () async {
      final appender = await mySqlAppenderBuilder()
          .withConnection('localhost', 3306, 'test_db')
          .withCredentials('user', 'pass')
          .withTable('logs')
          .withLevel(Level.WARN)
          .withBatchSize(75)
          .build(test: true);

      expect(appender.host, equals('localhost'));
      expect(appender.port, equals(3306));
      expect(appender.database, equals('test_db'));
      expect(appender.user, equals('user'));
      expect(appender.password, equals('pass'));
      expect(appender.table, equals('logs'));
      expect(appender.level, equals(Level.WARN));
      expect(appender.batchSize, equals(75));

      await appender.dispose();
    });

    test('should build with SSL configuration', () async {
      final appender = await mySqlAppenderBuilder()
          .withHost('secure.db.com')
          .withPort(3306)
          .withDatabase('secure_db')
          .withSSL(true)
          .withConnectionTimeout(45)
          .build(test: true);

      expect(appender.useSSL, equals(true));
      expect(appender.connectionTimeout, equals(45));

      await appender.dispose();
    });

    test('should build with custom fields', () async {
      final appender = await mySqlAppenderBuilder()
          .withConnection('localhost', 3306, 'test_db')
          .withTable('events')
          .withCustomField('user_id', 'VARCHAR(100)')
          .withCustomField('event_type', 'VARCHAR(50)')
          .build(test: true);

      expect(appender.customFields['user_id'], equals('VARCHAR(100)'));
      expect(appender.customFields['event_type'], equals('VARCHAR(50)'));

      await appender.dispose();
    });

    test('should apply production preset correctly', () async {
      final appender = await mySqlAppenderBuilder()
          .withConnection('localhost', 3306, 'test_db')
          .withProductionPreset()
          .build(test: true);

      expect(appender.level, equals(Level.INFO));
      expect(appender.batchSize, equals(100));
      expect(appender.usePreparedStatements, equals(true));
      expect(appender.maxReconnectAttempts, equals(5));
      expect(appender.enableRotation, equals(true));
      expect(appender.maxRows, equals(10000000));

      await appender.dispose();
    });

    test('should apply high volume preset correctly', () async {
      final appender = await mySqlAppenderBuilder()
          .withConnection('localhost', 3306, 'test_db')
          .withHighVolumePreset()
          .build(test: true);

      expect(appender.batchSize, equals(200));
      expect(appender.batchInterval, equals(Duration(seconds: 5)));
      expect(appender.useCompression, equals(true));
      expect(appender.createIndices, equals(true));

      await appender.dispose();
    });

    test('should apply audit preset correctly', () async {
      final appender = await mySqlAppenderBuilder()
          .withConnection('localhost', 3306, 'test_db')
          .withAuditPreset()
          .build(test: true);

      expect(appender.tableEngine, equals('InnoDB'));
      expect(appender.enableRotation, equals(false));
      expect(appender.customFields.containsKey('user_id'), equals(true));
      expect(appender.customFields.containsKey('action'), equals(true));

      await appender.dispose();
    });

    test('should throw if required fields are missing', () async {
      // Missing host
      expect(
        () async =>
            await mySqlAppenderBuilder().withDatabase('test_db').build(),
        throwsA(isA<ArgumentError>()),
      );

      // Missing database
      expect(
        () async => await mySqlAppenderBuilder().withHost('localhost').build(),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('MySqlAppender Integration', () {
    tearDown(() async {
      await LoggerFactory.dispose();
    });

    test('should register with AppenderRegistry', () async {
      // The registration happens in setUpAll()
      expect(AppenderRegistry.instance.isRegistered('MYSQL'), isTrue);
    });

    test('should work with LoggerFactory.init', () async {
      final config = {
        'appenders': [
          {
            'type': 'CONSOLE',
            'level': 'INFO',
          },
          {
            'type': 'MYSQL',
            'host': 'localhost',
            'database': 'test_db',
            'level': 'WARN',
            'batchSize': 50,
          },
        ],
      };

      await LoggerFactory.init(config, test: true);
      final logger = LoggerFactory.getRootLogger();

      expect(logger.appenders.length, equals(2));
      expect(logger.appenders[1].getType(), equals('MYSQL'));
    });

    test('should work with LoggerBuilder extension', () async {
      await LoggerFactory.builder()
          .console(level: Level.INFO)
          .mysql(
            host: 'localhost',
            database: 'test_db',
            user: 'test_user',
            password: 'test_pass',
            level: Level.ERROR,
            batchSize: 100,
          )
          .build(test: true);

      final logger = LoggerFactory.getRootLogger();
      expect(logger.appenders.length, equals(2));

      final mysqlAppender = logger.appenders[1] as MySqlAppender;
      expect(mysqlAppender.getType(), equals('MYSQL'));
      expect(mysqlAppender.host, equals('localhost'));
      expect(mysqlAppender.database, equals('test_db'));
      expect(mysqlAppender.batchSize, equals(100));
    });

    test('should work with convenience extension methods', () async {
      await LoggerFactory.builder()
          .console(level: Level.INFO)
          .mysqlProduction(
            host: 'prod.db.com',
            database: 'production',
            user: 'app_user',
            password: 'secure_pass',
            level: Level.INFO,
          )
          .build(test: true);

      final logger = LoggerFactory.getRootLogger();
      final mysqlAppender = logger.appenders[1] as MySqlAppender;
      expect(mysqlAppender.batchSize, equals(100));
      expect(mysqlAppender.usePreparedStatements, equals(true));
      expect(mysqlAppender.enableRotation, equals(true));
    });

    test('should handle deep copy correctly', () async {
      final original = await MySqlAppender.fromConfig({
        'host': 'localhost',
        'database': 'test_db',
        'user': 'test_user',
        'password': 'test_pass',
        'table': 'custom_logs',
        'batchSize': 75,
        'customFields': {'field1': 'VARCHAR(50)'},
      }, test: true);

      final copy = original.createDeepCopy() as MySqlAppender;

      expect(copy.host, equals(original.host));
      expect(copy.database, equals(original.database));
      expect(copy.user, equals(original.user));
      expect(copy.password, equals(original.password));
      expect(copy.table, equals(original.table));
      expect(copy.batchSize, equals(original.batchSize));
      expect(copy.customFields['field1'], equals('VARCHAR(50)'));
      expect(identical(copy, original), isFalse);
      expect(identical(copy.customFields, original.customFields), isFalse);

      await original.dispose();
      await copy.dispose();
    });

    test('should respect enabled state', () async {
      final appender = await MySqlAppender.fromConfig({
        'host': 'localhost',
        'database': 'test_db',
        'enabled': false,
      }, test: true);

      expect(appender.enabled, isFalse);

      final contextInfo = LoggerStackTrace.from(StackTrace.current);
      appender.append(LogRecord(Level.INFO, 'Test', null, contextInfo));

      // Should not add to buffer when disabled
      expect(appender.getStatistics()['bufferSize'], equals(0));

      await appender.dispose();
    });
  });
}

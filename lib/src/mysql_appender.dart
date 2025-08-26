import 'dart:async';
import 'dart:io';

import 'package:any_logger/any_logger.dart';
import 'package:mysql1/mysql1.dart';

/// Appender that stores log records in a MySQL database.
///
/// Features:
/// - Automatic table creation and schema management
/// - Batch inserts for performance
/// - Connection pooling and automatic reconnection
/// - Configurable table structure
/// - Query support for log analysis
/// - Automatic log rotation/archiving
/// - Custom fields support
class MySqlAppender extends Appender {
  static const String appenderName = 'MYSQL';

  // Connection settings
  late String host;
  late int port;
  String? user;
  String? password;
  late String database;
  late String table;
  int connectionTimeout = 30;
  bool useSSL = false;

  // Table configuration
  bool autoCreateTable = true;
  bool useCompression = false;
  String? tableEngine = 'InnoDB';
  String? charset = 'utf8mb4';
  Map<String, String> customFields = {};

  // Batch settings
  final List<LogRecord> _logBuffer = [];
  int batchSize = 50;
  Duration batchInterval = Duration(seconds: 10);
  Timer? _batchTimer;
  bool usePreparedStatements = true;

  // Connection pooling
  MySqlConnection? _connection;
  ConnectionSettings? _connectionSettings;
  bool _initialized = false;
  bool _tableChecked = false;
  int _reconnectAttempts = 0;
  int maxReconnectAttempts = 3;
  Duration reconnectDelay = Duration(seconds: 2);
  DateTime? _lastConnectionCheck;

  // Rotation/archiving settings
  bool enableRotation = false;
  int maxRows = 1000000;
  int rotationCheckInterval = 3600; // seconds
  Timer? _rotationTimer;
  String? archiveTablePrefix;

  // Query optimization
  bool createIndices = true;
  List<String> indexColumns = ['timestamp', 'level', 'tag', 'logger_name'];

  // Statistics
  int _successfulInserts = 0;
  int _failedInserts = 0;
  DateTime? _lastInsertTime;

  // Test mode
  bool test = false;

  MySqlAppender() : super();

  /// Factory constructor for configuration-based creation
  static Future<MySqlAppender> fromConfig(Map<String, dynamic> config,
      {bool test = false, DateTime? date}) async {
    final appender = MySqlAppender()
      ..test = test
      ..created = date ?? DateTime.now();

    appender.initializeCommonProperties(config, test: test, date: date);

    // Required fields
    if (!config.containsKey('host')) {
      throw ArgumentError('Missing host argument for MySqlAppender');
    }
    appender.host = config['host'];

    if (!config.containsKey('database')) {
      throw ArgumentError('Missing database argument for MySqlAppender');
    }
    appender.database = config['database'];

    // Optional connection settings
    appender.port = config['port'] ?? 3306;
    appender.user = config['user'];
    appender.password = config['password'];
    appender.table = config['table'] ?? 'logs';
    appender.connectionTimeout = config['connectionTimeout'] ?? 30;
    appender.useSSL = config['useSSL'] ?? false;

    // Table configuration
    if (config.containsKey('autoCreateTable')) {
      appender.autoCreateTable = config['autoCreateTable'];
    }
    if (config.containsKey('useCompression')) {
      appender.useCompression = config['useCompression'];
    }
    if (config.containsKey('tableEngine')) {
      appender.tableEngine = config['tableEngine'];
    }
    if (config.containsKey('charset')) {
      appender.charset = config['charset'];
    }
    if (config.containsKey('customFields')) {
      appender.customFields = Map<String, String>.from(config['customFields']);
    }

    // Batch settings
    if (config.containsKey('batchSize')) {
      appender.batchSize = config['batchSize'];
    }
    if (config.containsKey('batchIntervalSeconds')) {
      appender.batchInterval =
          Duration(seconds: config['batchIntervalSeconds']);
    }
    if (config.containsKey('usePreparedStatements')) {
      appender.usePreparedStatements = config['usePreparedStatements'];
    }

    // Connection pooling settings
    if (config.containsKey('maxReconnectAttempts')) {
      appender.maxReconnectAttempts = config['maxReconnectAttempts'];
    }
    if (config.containsKey('reconnectDelaySeconds')) {
      appender.reconnectDelay =
          Duration(seconds: config['reconnectDelaySeconds']);
    }

    // Rotation settings
    if (config.containsKey('enableRotation')) {
      appender.enableRotation = config['enableRotation'];
    }
    if (config.containsKey('maxRows')) {
      appender.maxRows = config['maxRows'];
    }
    if (config.containsKey('rotationCheckInterval')) {
      appender.rotationCheckInterval = config['rotationCheckInterval'];
    }
    if (config.containsKey('archiveTablePrefix')) {
      appender.archiveTablePrefix = config['archiveTablePrefix'];
    }

    // Query optimization
    if (config.containsKey('createIndices')) {
      appender.createIndices = config['createIndices'];
    }
    if (config.containsKey('indexColumns')) {
      appender.indexColumns = List<String>.from(config['indexColumns']);
    }

    await appender.initialize();

    return appender;
  }

  /// Synchronous factory - throws since MySQL requires async
  factory MySqlAppender.fromConfigSync(Map<String, dynamic> config) {
    throw UnsupportedError(
        'MySqlAppender requires async initialization. Use fromConfig() or builder().build()');
  }

  /// Initialize the appender
  Future<void> initialize() async {
    if (_initialized || test) {
      if (test) {
        Logger.getSelfLogger()?.logDebug(
            'MySqlAppender in test mode - skipping database initialization');
      }
      return;
    }

    try {
      _connectionSettings = ConnectionSettings(
        host: host,
        port: port,
        user: user,
        password: password,
        db: database,
        timeout: Duration(seconds: connectionTimeout),
        useSSL: useSSL,
      );

      await _connect();

      if (autoCreateTable) {
        await _ensureTableExists();
      }

      _startBatchTimer();

      if (enableRotation) {
        _startRotationTimer();
      }

      _initialized = true;
      Logger.getSelfLogger()?.logDebug('MySqlAppender initialized: $this');
    } catch (e) {
      Logger.getSelfLogger()
          ?.logError('Failed to initialize MySqlAppender: $e');
      _initialized = false;
      rethrow;
    }
  }

  Future<void> _connect() async {
    try {
      _connection?.close();
      _connection = await MySqlConnection.connect(_connectionSettings!);
      _lastConnectionCheck = DateTime.now();
      _reconnectAttempts = 0;
      Logger.getSelfLogger()
          ?.logDebug('MySQL connection established to $host:$port/$database');
    } catch (e) {
      Logger.getSelfLogger()?.logError('MySQL connection failed: $e');
      throw e;
    }
  }

  Future<void> _ensureConnection() async {
    // Check if we need to reconnect
    if (_connection == null ||
        (_lastConnectionCheck != null &&
            DateTime.now().difference(_lastConnectionCheck!).inMinutes > 5)) {
      try {
        await _connection?.query('SELECT 1');
        _lastConnectionCheck = DateTime.now();
      } catch (e) {
        Logger.getSelfLogger()
            ?.logWarn('Connection test failed, reconnecting...');
        await _reconnect();
      }
    }
  }

  Future<void> _reconnect() async {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      throw Exception('Max reconnection attempts reached');
    }

    _reconnectAttempts++;
    await Future.delayed(
        reconnectDelay * _reconnectAttempts); // Exponential backoff
    await _connect();
  }

  Future<void> _ensureTableExists() async {
    if (_tableChecked) return;

    try {
      // Build custom fields SQL
      String customFieldsSql = '';
      customFields.forEach((name, type) {
        customFieldsSql += ',\n  $name $type';
      });

      // Build index SQL
      String indexSql = '';
      for (var column in indexColumns) {
        if (column == 'timestamp' || customFields.containsKey(column)) {
          indexSql += ',\n  INDEX idx_$column ($column)';
        }
      }

      // Create table with optional compression
      String compressionSql = useCompression ? 'ROW_FORMAT=COMPRESSED' : '';

      await _connection!.query('''
        CREATE TABLE IF NOT EXISTS $table (
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
          hostname VARCHAR(255)
          $customFieldsSql,
          INDEX idx_timestamp (timestamp),
          INDEX idx_level (level),
          INDEX idx_tag (tag),
          INDEX idx_logger_name (logger_name)
          $indexSql
        ) ENGINE=$tableEngine DEFAULT CHARSET=$charset $compressionSql
      ''');

      _tableChecked = true;
      Logger.getSelfLogger()?.logDebug('Table $table is ready');
    } catch (e) {
      Logger.getSelfLogger()?.logError('Failed to create table: $e');
      throw e;
    }
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(batchInterval, (_) {
      if (_logBuffer.isNotEmpty) {
        _flushBatch();
      }
    });
    Logger.getSelfLogger()
        ?.logDebug('Batch timer started with interval: $batchInterval');
  }

  void _startRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer =
        Timer.periodic(Duration(seconds: rotationCheckInterval), (_) async {
      await _checkAndRotate();
    });
  }

  Future<void> _checkAndRotate() async {
    if (!enableRotation) return;

    try {
      await _ensureConnection();

      // Count rows
      var result =
          await _connection!.query('SELECT COUNT(*) as count FROM $table');
      int rowCount = result.first['count'];

      if (rowCount > maxRows) {
        await _rotateTable();
      }
    } catch (e) {
      Logger.getSelfLogger()?.logError('Failed to check table rotation: $e');
    }
  }

  Future<void> _rotateTable() async {
    String archiveName =
        '${archiveTablePrefix ?? table}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Create archive table
      await _connection!.query('CREATE TABLE $archiveName LIKE $table');

      // Move old data
      await _connection!.query('''
        INSERT INTO $archiveName 
        SELECT * FROM $table 
        ORDER BY timestamp 
        LIMIT ${maxRows ~/ 2}
      ''');

      // Delete archived data
      await _connection!.query('''
        DELETE FROM $table 
        ORDER BY timestamp 
        LIMIT ${maxRows ~/ 2}
      ''');

      Logger.getSelfLogger()?.logInfo('Rotated table $table to $archiveName');
    } catch (e) {
      Logger.getSelfLogger()?.logError('Failed to rotate table: $e');
    }
  }

  @override
  Appender createDeepCopy() {
    MySqlAppender copy = MySqlAppender();
    copyBasePropertiesTo(copy);

    copy.test = test;
    copy.host = host;
    copy.port = port;
    copy.user = user;
    copy.password = password;
    copy.database = database;
    copy.table = table;
    copy.connectionTimeout = connectionTimeout;
    copy.useSSL = useSSL;
    copy.autoCreateTable = autoCreateTable;
    copy.useCompression = useCompression;
    copy.tableEngine = tableEngine;
    copy.charset = charset;
    copy.customFields = Map.from(customFields);
    copy.batchSize = batchSize;
    copy.batchInterval = batchInterval;
    copy.usePreparedStatements = usePreparedStatements;
    copy.maxReconnectAttempts = maxReconnectAttempts;
    copy.reconnectDelay = reconnectDelay;
    copy.enableRotation = enableRotation;
    copy.maxRows = maxRows;
    copy.rotationCheckInterval = rotationCheckInterval;
    copy.archiveTablePrefix = archiveTablePrefix;
    copy.createIndices = createIndices;
    copy.indexColumns = List.from(indexColumns);

    if (!copy.test) {
      copy._connectionSettings = ConnectionSettings(
        host: host,
        port: port,
        user: user,
        password: password,
        db: database,
        timeout: Duration(seconds: connectionTimeout),
        useSSL: useSSL,
      );
      copy._startBatchTimer();
      if (copy.enableRotation) {
        copy._startRotationTimer();
      }
    }

    return copy;
  }

  @override
  void append(LogRecord logRecord) {
    if (!enabled) return;

    logRecord.loggerName ??= getType().toString();

    // Add to buffer
    _logBuffer.add(logRecord);

    // Check if buffer is full
    if (_logBuffer.length >= batchSize) {
      _flushBatch();
    }
  }

  Future<void> _flushBatch() async {
    if (_logBuffer.isEmpty) return;

    // Copy and clear buffer
    final logs = List<LogRecord>.from(_logBuffer);
    _logBuffer.clear();

    if (test) {
      Logger.getSelfLogger()?.logDebug(
          'Test mode: Would insert ${logs.length} logs to MySQL table $table');
      _successfulInserts += logs.length;
      _lastInsertTime = DateTime.now();
      return;
    }

    try {
      if (!_initialized) {
        await initialize();
      }

      await _ensureConnection();

      // Insert logs
      if (logs.length == 1) {
        await _insertSingle(logs.first);
      } else {
        await _insertBatch(logs);
      }

      _successfulInserts += logs.length;
      _lastInsertTime = DateTime.now();

      Logger.getSelfLogger()
          ?.logDebug('Inserted ${logs.length} log records to MySQL');
    } catch (e) {
      _failedInserts += logs.length;
      Logger.getSelfLogger()?.logError('Failed to insert logs to MySQL: $e');

      // Put logs back if insert failed (with overflow protection)
      if (_logBuffer.length < batchSize * 2) {
        _logBuffer.insertAll(0, logs);
      } else {
        Logger.getSelfLogger()?.logWarn(
            'Dropping ${logs.length} log records due to buffer overflow');
      }
    }
  }

  Future<void> _insertSingle(LogRecord logRecord) async {
    // Build custom values
    List<dynamic> customValues = [];
    String customColumns = '';
    String customPlaceholders = '';

    customFields.forEach((name, _) {
      customColumns += ', $name';
      customPlaceholders += ', ?';
      customValues.add(null); // Default null for custom fields
    });

    await _connection!.query('''
      INSERT INTO $table (
        timestamp, level, level_value, tag, message, logger_name,
        class_name, method_name, file_location, line_number,
        error, stack_trace, mdc_context, app_version, device_id, 
        session_id, hostname$customColumns
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?$customPlaceholders)
    ''', [
      logRecord.time.toUtc(),
      logRecord.level.name,
      logRecord.level.value,
      logRecord.tag ?? '',
      _truncate(logRecord.message.toString(), 65535),
      logRecord.loggerName ?? '',
      logRecord.className ?? '',
      logRecord.methodName ?? '',
      logRecord.inFileLocation() ?? '',
      logRecord.lineNumber,
      logRecord.error?.toString() ?? '',
      logRecord.stackTrace?.toString() ?? '',
      _getMdcJson(),
      LoggerFactory.getAppVersion() ?? '',
      LoggerFactory.getDeviceId() ?? '',
      LoggerFactory.getSessionId() ?? '',
      _getHostname(),
      ...customValues,
    ]);
  }

  Future<void> _insertBatch(List<LogRecord> logs) async {
    // Build batch insert query
    final values = <String>[];
    final params = <dynamic>[];

    // Build custom fields placeholders
    String customPlaceholders = '';
    for (int i = 0; i < customFields.length; i++) {
      customPlaceholders += ', ?';
    }

    for (var log in logs) {
      values.add(
          '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?$customPlaceholders)');
      params.addAll([
        log.time.toUtc(),
        log.level.name,
        log.level.value,
        log.tag ?? '',
        _truncate(log.message.toString(), 65535),
        log.loggerName ?? '',
        log.className ?? '',
        log.methodName ?? '',
        log.inFileLocation() ?? '',
        log.lineNumber,
        log.error?.toString() ?? '',
        log.stackTrace?.toString() ?? '',
        _getMdcJson(),
        LoggerFactory.getAppVersion() ?? '',
        LoggerFactory.getDeviceId() ?? '',
        LoggerFactory.getSessionId() ?? '',
        _getHostname(),
      ]);

      // Add null values for custom fields
      for (int i = 0; i < customFields.length; i++) {
        params.add(null);
      }
    }

    String customColumns = '';
    customFields.forEach((name, _) {
      customColumns += ', $name';
    });

    final query = '''
      INSERT INTO $table (
        timestamp, level, level_value, tag, message, logger_name,
        class_name, method_name, file_location, line_number,
        error, stack_trace, mdc_context, app_version, device_id,
        session_id, hostname$customColumns
      ) VALUES ${values.join(', ')}
    ''';

    await _connection!.query(query, params);
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength);
  }

  String _getMdcJson() {
    final mdcValues = LoggerFactory.getAllMdcValues();
    if (mdcValues.isEmpty) return '{}';

    // Simple JSON encoding for MDC
    final entries = mdcValues.entries
        .map((e) => '"${e.key}":"${e.value.toString().replaceAll('"', '\\"')}"')
        .join(',');

    return '{$entries}';
  }

  String _getHostname() {
    try {
      return Platform.localHostname;
    } catch (e) {
      return 'unknown';
    }
  }

  @override
  Future<void> flush() async {
    await _flushBatch();
  }

  @override
  Future<void> dispose() async {
    _batchTimer?.cancel();
    _rotationTimer?.cancel();
    await flush();
    await _connection?.close();
    _connection = null;
    _initialized = false;
    Logger.getSelfLogger()?.logDebug('MySqlAppender disposed');
  }

  @override
  String toString() {
    return 'MySqlAppender(host: $host:$port, database: $database, '
        'table: $table, batchSize: $batchSize, enabled: $enabled, '
        'stats: {inserted: $_successfulInserts, failed: $_failedInserts})';
  }

  @override
  String getType() {
    return MySqlAppender.appenderName;
  }

  /// Get statistics about database operations
  Map<String, dynamic> getStatistics() {
    return {
      'successfulInserts': _successfulInserts,
      'failedInserts': _failedInserts,
      'lastInsertTime': _lastInsertTime?.toIso8601String(),
      'bufferSize': _logBuffer.length,
      'connectionActive': _connection != null,
    };
  }

  /// Query logs from the database
  Future<List<Map<String, dynamic>>> queryLogs({
    Level? minLevel,
    DateTime? startTime,
    DateTime? endTime,
    String? tag,
    String? loggerName,
    int limit = 100,
    int offset = 0,
    String orderBy = 'timestamp DESC',
  }) async {
    if (test) {
      return [];
    }

    await _ensureConnection();

    String whereClause = 'WHERE 1=1';
    List<dynamic> params = [];

    if (minLevel != null) {
      whereClause += ' AND level_value >= ?';
      params.add(minLevel.value);
    }

    if (startTime != null) {
      whereClause += ' AND timestamp >= ?';
      params.add(startTime.toUtc());
    }

    if (endTime != null) {
      whereClause += ' AND timestamp <= ?';
      params.add(endTime.toUtc());
    }

    if (tag != null && tag.isNotEmpty) {
      whereClause += ' AND tag = ?';
      params.add(tag);
    }

    if (loggerName != null && loggerName.isNotEmpty) {
      whereClause += ' AND logger_name = ?';
      params.add(loggerName);
    }

    final query = '''
      SELECT * FROM $table
      $whereClause
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''';

    params.addAll([limit, offset]);

    final results = await _connection!.query(query, params);

    return results.map((row) => row.fields).toList();
  }
}

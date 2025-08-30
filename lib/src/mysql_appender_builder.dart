import 'package:any_logger/any_logger.dart';

import '../any_logger_mysql.dart';

/// A specialized builder for creating and configuring [MySqlAppender] instances.
///
/// This builder provides a fluent API specifically tailored for MySQL appenders,
/// with all relevant configuration options exposed.
///
/// ### Example Usage:
///
/// ```dart
/// // Simple MySQL appender
/// final appender = await mySqlAppenderBuilder()
///     .withConnection('localhost', 3306, 'mydb')
///     .withCredentials('user', 'password')
///     .withTable('logs')
///     .withLevel(Level.INFO)
///     .build();
///
/// // With batching and rotation
/// final advancedAppender = await mySqlAppenderBuilder()
///     .withConnection('db.example.com', 3306, 'production')
///     .withCredentials('logger', 'secure_pass')
///     .withTable('app_logs')
///     .withBatchSize(100)
///     .withRotation(maxRows: 1000000)
///     .withIndices(['timestamp', 'level', 'tag'])
///     .build();
/// ```

/// Convenience factory function for creating a MySqlAppenderBuilder.
MySqlAppenderBuilder mySqlAppenderBuilder() => MySqlAppenderBuilder();

class MySqlAppenderBuilder {
  final Map<String, dynamic> _config = {
    'type': MySqlAppender.appenderName,
  };

  /// Creates a new MySqlAppenderBuilder.
  MySqlAppenderBuilder();

  // --- Connection Configuration ---

  /// Sets the MySQL connection parameters.
  MySqlAppenderBuilder withConnection(String host, int port, String database) {
    _config['host'] = host;
    _config['port'] = port;
    _config['database'] = database;
    return this;
  }

  /// Sets the MySQL host.
  MySqlAppenderBuilder withHost(String host) {
    _config['host'] = host;
    return this;
  }

  /// Sets the MySQL port.
  MySqlAppenderBuilder withPort(int port) {
    _config['port'] = port;
    return this;
  }

  /// Sets the database name.
  MySqlAppenderBuilder withDatabase(String database) {
    _config['database'] = database;
    return this;
  }

  /// Sets MySQL credentials.
  MySqlAppenderBuilder withCredentials(String? user, String? password) {
    _config['user'] = user;
    _config['password'] = password;
    return this;
  }

  /// Sets the connection timeout in seconds.
  MySqlAppenderBuilder withConnectionTimeout(int seconds) {
    _config['connectionTimeout'] = seconds;
    return this;
  }

  /// Enables SSL for the connection.
  MySqlAppenderBuilder withSSL(bool useSSL) {
    _config['useSSL'] = useSSL;
    return this;
  }

  // --- Table Configuration ---

  /// Sets the table name.
  MySqlAppenderBuilder withTable(String table) {
    _config['table'] = table;
    return this;
  }

  /// Sets whether to automatically create the table if it doesn't exist.
  MySqlAppenderBuilder withAutoCreateTable(bool autoCreate) {
    _config['autoCreateTable'] = autoCreate;
    return this;
  }

  /// Enables table compression.
  MySqlAppenderBuilder withCompression(bool compress) {
    _config['useCompression'] = compress;
    return this;
  }

  /// Sets the table engine (InnoDB, MyISAM, etc.).
  MySqlAppenderBuilder withTableEngine(String engine) {
    _config['tableEngine'] = engine;
    return this;
  }

  /// Sets the character set for the table.
  MySqlAppenderBuilder withCharset(String charset) {
    _config['charset'] = charset;
    return this;
  }

  /// Adds custom fields to the table.
  MySqlAppenderBuilder withCustomFields(Map<String, String> fields) {
    _config['customFields'] = fields;
    return this;
  }

  /// Adds a single custom field to the table.
  MySqlAppenderBuilder withCustomField(String name, String type) {
    final fields = _config['customFields'] as Map<String, String>? ?? {};
    fields[name] = type;
    _config['customFields'] = fields;
    return this;
  }

  // --- Common Appender Properties ---

  /// Sets the logging [Level] for this appender.
  MySqlAppenderBuilder withLevel(Level level) {
    _config['level'] = level.name;
    return this;
  }

  /// Sets the log message format pattern.
  MySqlAppenderBuilder withFormat(String format) {
    _config['format'] = format;
    return this;
  }

  /// Sets the date format pattern for timestamps.
  MySqlAppenderBuilder withDateFormat(String dateFormat) {
    _config['dateFormat'] = dateFormat;
    return this;
  }

  /// Sets whether this appender starts enabled.
  MySqlAppenderBuilder withEnabledState(bool enabled) {
    _config['enabled'] = enabled;
    return this;
  }

  // --- Batching Configuration ---

  /// Sets the batch size (number of logs before inserting).
  MySqlAppenderBuilder withBatchSize(int size) {
    _config['batchSize'] = size;
    return this;
  }

  /// Sets the batch interval.
  MySqlAppenderBuilder withBatchInterval(Duration interval) {
    _config['batchIntervalSeconds'] = interval.inSeconds;
    return this;
  }

  /// Sets the batch interval in seconds.
  MySqlAppenderBuilder withBatchIntervalSeconds(int seconds) {
    _config['batchIntervalSeconds'] = seconds;
    return this;
  }

  /// Sets whether to use prepared statements.
  MySqlAppenderBuilder withPreparedStatements(bool use) {
    _config['usePreparedStatements'] = use;
    return this;
  }

  // --- Connection Pooling ---

  /// Sets the maximum reconnection attempts.
  MySqlAppenderBuilder withMaxReconnectAttempts(int attempts) {
    _config['maxReconnectAttempts'] = attempts;
    return this;
  }

  /// Sets the reconnection delay.
  MySqlAppenderBuilder withReconnectDelay(Duration delay) {
    _config['reconnectDelaySeconds'] = delay.inSeconds;
    return this;
  }

  // --- Rotation Configuration ---

  /// Enables table rotation with specified parameters.
  MySqlAppenderBuilder withRotation({
    required int maxRows,
    int? checkInterval,
    String? archivePrefix,
  }) {
    _config['enableRotation'] = true;
    _config['maxRows'] = maxRows;
    if (checkInterval != null) {
      _config['rotationCheckInterval'] = checkInterval;
    }
    if (archivePrefix != null) {
      _config['archiveTablePrefix'] = archivePrefix;
    }
    return this;
  }

  /// Disables table rotation.
  MySqlAppenderBuilder withoutRotation() {
    _config['enableRotation'] = false;
    return this;
  }

  // --- Query Optimization ---

  /// Sets whether to create indices.
  MySqlAppenderBuilder withIndices(List<String> columns) {
    _config['createIndices'] = true;
    _config['indexColumns'] = columns;
    return this;
  }

  /// Disables index creation.
  MySqlAppenderBuilder withoutIndices() {
    _config['createIndices'] = false;
    return this;
  }

  // --- Preset Configurations ---

  /// Applies settings optimized for high-volume logging.
  MySqlAppenderBuilder withHighVolumePreset() {
    _config['batchSize'] = 200;
    _config['batchIntervalSeconds'] = 5;
    _config['usePreparedStatements'] = true;
    _config['useCompression'] = true;
    _config['tableEngine'] = 'InnoDB';
    _config['createIndices'] = true;
    _config['indexColumns'] = ['timestamp', 'level'];
    return this;
  }

  /// Applies settings optimized for development/debugging.
  MySqlAppenderBuilder withDevelopmentPreset() {
    _config['level'] = Level.DEBUG.name;
    _config['batchSize'] = 1; // Insert immediately
    _config['batchIntervalSeconds'] = 1;
    _config['autoCreateTable'] = true;
    _config['createIndices'] = true;
    _config['indexColumns'] = ['timestamp', 'level', 'tag', 'logger_name'];
    return this;
  }

  /// Applies settings optimized for production logging.
  MySqlAppenderBuilder withProductionPreset() {
    _config['level'] = Level.INFO.name;
    _config['batchSize'] = 100;
    _config['batchIntervalSeconds'] = 10;
    _config['usePreparedStatements'] = true;
    _config['maxReconnectAttempts'] = 5;
    _config['reconnectDelaySeconds'] = 2;
    _config['enableRotation'] = true;
    _config['maxRows'] = 10000000; // 10 million rows
    _config['rotationCheckInterval'] = 3600; // Check hourly
    _config['useCompression'] = false;
    _config['tableEngine'] = 'InnoDB';
    _config['createIndices'] = true;
    return this;
  }

  /// Applies settings optimized for audit logging.
  MySqlAppenderBuilder withAuditPreset() {
    _config['level'] = Level.INFO.name;
    _config['batchSize'] = 50;
    _config['batchIntervalSeconds'] = 5;
    _config['tableEngine'] = 'InnoDB'; // For transactions
    _config['enableRotation'] = false; // Keep all audit logs
    _config['customFields'] = {
      'user_id': 'VARCHAR(100)',
      'action': 'VARCHAR(255)',
      'ip_address': 'VARCHAR(45)',
      'user_agent': 'TEXT',
    };
    _config['createIndices'] = true;
    _config['indexColumns'] = ['timestamp', 'level', 'user_id', 'action'];
    return this;
  }

  /// Applies settings optimized for analytics and reporting.
  MySqlAppenderBuilder withAnalyticsPreset() {
    _config['batchSize'] = 500;
    _config['batchIntervalSeconds'] = 30;
    _config['useCompression'] = true;
    _config['tableEngine'] = 'InnoDB';
    _config['customFields'] = {
      'event_type': 'VARCHAR(100)',
      'event_data': 'JSON',
      'duration_ms': 'INT',
      'user_segment': 'VARCHAR(50)',
    };
    _config['createIndices'] = true;
    _config['indexColumns'] = ['timestamp', 'event_type', 'user_segment'];
    return this;
  }

  // --- Build Methods ---

  /// Builds the MySQL appender asynchronously.
  ///
  /// Returns a fully configured [MySqlAppender] instance.
  Future<MySqlAppender> build({bool test = false, DateTime? date}) async {
    // Validate required fields
    if (!_config.containsKey('host')) {
      throw ArgumentError('MySQL host is required. Use withHost() or withConnection() to set it.');
    }
    if (!_config.containsKey('database')) {
      throw ArgumentError('Database name is required. Use withDatabase() or withConnection() to set it.');
    }

    return await MySqlAppender.fromConfig(_config, test: test, date: date);
  }

  /// Creates a copy of this builder with the same configuration.
  MySqlAppenderBuilder copy() {
    final newBuilder = MySqlAppenderBuilder();
    newBuilder._config.addAll(_config);
    return newBuilder;
  }

  /// Gets the current configuration as a Map.
  Map<String, dynamic> getConfig() {
    return Map.unmodifiable(_config);
  }

  @override
  String toString() {
    return 'MySqlAppenderBuilder(config: $_config)';
  }
}

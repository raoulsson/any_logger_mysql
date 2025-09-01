import 'package:mysql1/mysql1.dart';

/// Runs with MySQL 5.7, not 8.0
void main() async {
  print('Testing MySQL connection...\n');

  try {
    // Test 1: Basic connection
    print('Test 1: Establishing connection...');
    final settings = ConnectionSettings(
      host: 'localhost',
      port: 3306,
      user: 'root',
      password: 'yourpassword',  // Your actual password
      db: 'testdb',
      timeout: Duration(seconds: 10),
    );

    final conn = await MySqlConnection.connect(settings);
    print('✓ Connected successfully!\n');

    // Test 2: Query MySQL version
    print('Test 2: Checking MySQL version...');
    var results = await conn.query('SELECT VERSION() as version');
    for (var row in results) {
      print('✓ MySQL Version: ${row['version']}\n');
    }

    // Test 3: Create the logs table
    print('Test 3: Creating logs table...');
    await conn.query('''
      CREATE TABLE IF NOT EXISTS app_logs (
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
        INDEX idx_timestamp (timestamp),
        INDEX idx_level (level),
        INDEX idx_tag (tag),
        INDEX idx_logger_name (logger_name)
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ''');
    print('✓ Table created/verified\n');

    // Test 4: Insert a test log
    print('Test 4: Inserting test log...');
    await conn.query('''
      INSERT INTO app_logs (
        timestamp, level, level_value, tag, message, logger_name,
        class_name, method_name, file_location, line_number,
        error, stack_trace, mdc_context, app_version, device_id, 
        session_id, hostname
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      DateTime.now().toUtc(),
      'INFO',
      800,
      'TEST',
      'Test log message from Dart',
      'TestLogger',
      'TestClass',
      'testMethod',
      'test.dart',
      42,
      null,
      null,
      '{}',
      '1.0.0',
      'test-device',
      'test-session',
      'test-host',
    ]);
    print('✓ Test log inserted\n');

    // Test 5: Read back the log
    print('Test 5: Reading logs...');
    results = await conn.query(
        'SELECT * FROM app_logs ORDER BY id DESC LIMIT 1'
    );
    for (var row in results) {
      print('✓ Found log: ${row['message']}\n');
    }

    // Test 6: Batch insert
    print('Test 6: Testing batch insert...');
    var batch = await conn.queryMulti(
        'INSERT INTO app_logs (timestamp, level, level_value, tag, message, logger_name, '
            'class_name, method_name, file_location, line_number, error, stack_trace, '
            'mdc_context, app_version, device_id, session_id, hostname) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          [DateTime.now().toUtc(), 'DEBUG', 500, 'BATCH', 'Batch message 1', 'TestLogger',
            null, null, null, null, null, null, '{}', '1.0.0', null, null, 'localhost'],
          [DateTime.now().toUtc(), 'INFO', 800, 'BATCH', 'Batch message 2', 'TestLogger',
            null, null, null, null, null, null, '{}', '1.0.0', null, null, 'localhost'],
          [DateTime.now().toUtc(), 'WARN', 900, 'BATCH', 'Batch message 3', 'TestLogger',
            null, null, null, null, null, null, '{}', '1.0.0', null, null, 'localhost'],
        ]
    );
    print('✓ Batch insert completed\n');

    // Test 7: Count logs
    print('Test 7: Counting logs...');
    results = await conn.query('SELECT COUNT(*) as count FROM app_logs');
    for (var row in results) {
      print('✓ Total logs in database: ${row['count']}\n');
    }

    await conn.close();
    print('═══════════════════════════════════════');
    print('All tests passed! MySQL connection is working correctly.');
    print('Your MySqlAppender should work with these settings.');

  } catch (e, stackTrace) {
    print('❌ Connection failed: $e');
    print('\nStack trace:');
    print(stackTrace);

    print('\nPossible solutions:');
    print('1. Check if MySQL is running: docker ps');
    print('2. Verify password is correct (currently using: yourpassword)');
    print('3. Try restarting MySQL: docker restart mysql-test');
    print('4. Check if port 3306 is not blocked by firewall');
    print('5. Try using IP 127.0.0.1 instead of localhost');
  }
}
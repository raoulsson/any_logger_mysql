library any_logger_mysql;

import 'package:any_logger/any_logger.dart';

// Import the implementation files
import 'src/mysql_appender.dart';

// Export public APIs
export 'src/mysql_appender.dart';
export 'src/mysql_appender_builder.dart';
export 'src/mysql_logger_builder_extension.dart';
export 'src/mysql_presets_extension.dart';

/// Extension initialization for MySQL appender.
///
/// This registers the MYSQL appender type with the AnyLogger registry,
/// allowing it to be used in configuration files and builders.
class AnyLoggerMySqlExtension {
  static bool _registered = false;

  /// Registers the MySQL appender with the AnyLogger registry.
  ///
  /// Clients have to actually call this before initializing the LoggerFactory
  /// as Dart will "optimize away" any code that in other languages executes on
  /// loading through importing the class file.
  ///
  /// Call: AnyLoggerMySqlExtension.register();
  static void register() {
    if (_registered) return;

    AppenderRegistry.instance.register(MySqlAppender.appenderName, (config,
        {test = false, date}) async {
      return await MySqlAppender.fromConfig(config, test: test, date: date);
    });

    _registered = true;

    // Log registration if self-debugging is enabled
    Logger.getSelfLogger()
        ?.logDebug('MYSQL appender registered with AppenderRegistry');
  }

  /// Unregisters the MySQL appender (mainly for testing).
  static void unregister() {
    AppenderRegistry.instance.unregister(MySqlAppender.appenderName);
    _registered = false;
  }

  /// Check if the appender is registered
  static bool get isRegistered => _registered;
}

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final String? client;
  final int? statusCode;

  const LogEntry({
    required this.timestamp,
    required this.message,
    this.level = LogLevel.info,
    this.client,
    this.statusCode,
  });

  factory LogEntry.request({
    required String method,
    required String path,
    required String client,
    required int statusCode,
  }) {
    return LogEntry(
      timestamp: DateTime.now(),
      message: '$method $path',
      level: statusCode >= 400 ? LogLevel.warning : LogLevel.info,
      client: client,
      statusCode: statusCode,
    );
  }

  factory LogEntry.info(String message) => LogEntry(
        timestamp: DateTime.now(),
        message: message,
        level: LogLevel.info,
      );

  factory LogEntry.error(String message) => LogEntry(
        timestamp: DateTime.now(),
        message: message,
        level: LogLevel.error,
      );
}

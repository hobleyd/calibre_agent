import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/log_entry.dart';
import '../server/calibre_server.dart';
import '../services/cert_service.dart';
import '../services/mdns_service.dart';
import 'settings_provider.dart';

enum ServerStatus { stopped, starting, running, error }

class ServerState {
  final ServerStatus status;
  final String? serverUrl;
  final int bookCount;
  final List<LogEntry> logEntries;
  final String? errorMessage;
  final String? certExpiry;

  const ServerState({
    this.status = ServerStatus.stopped,
    this.serverUrl,
    this.bookCount = 0,
    this.logEntries = const [],
    this.errorMessage,
    this.certExpiry,
  });

  bool get isRunning => status == ServerStatus.running;
  bool get isStarting => status == ServerStatus.starting;

  ServerState copyWith({
    ServerStatus? status,
    String? serverUrl,
    int? bookCount,
    List<LogEntry>? logEntries,
    String? errorMessage,
    String? certExpiry,
  }) {
    return ServerState(
      status: status ?? this.status,
      serverUrl: serverUrl ?? this.serverUrl,
      bookCount: bookCount ?? this.bookCount,
      logEntries: logEntries ?? this.logEntries,
      errorMessage: errorMessage ?? this.errorMessage,
      certExpiry: certExpiry ?? this.certExpiry,
    );
  }
}

class ServerNotifier extends Notifier<ServerState> {
  CalibreServer? _server;
  final _mdns = MdnsService();

  @override
  ServerState build() => const ServerState();

  Future<void> start() async {
    final settings = ref.read(settingsProvider);

    if (settings.libraryPath.isEmpty) {
      state = state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Library path not configured',
      );
      return;
    }

    state = state.copyWith(status: ServerStatus.starting, errorMessage: null);

    try {
      _server = CalibreServer(
        libraryPath: settings.libraryPath,
        port: settings.port,
        onLog: _addLog,
      );

      final url = await _server!.start();
      final count = _server!.bookCount();
      final expiry = await CertService.expiryDate();

      await _mdns.start(settings.port);

      state = state.copyWith(
        status: ServerStatus.running,
        serverUrl: url,
        bookCount: count,
        certExpiry: expiry,
        logEntries: [
          LogEntry.info('Server started at $url'),
          LogEntry.info('mDNS: calibre-agent._http._tcp registered'),
          ...state.logEntries,
        ],
      );
    } catch (e) {
      _server = null;
      state = state.copyWith(
        status: ServerStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> stop() async {
    await _server?.stop();
    await _mdns.stop();
    _server = null;

    state = state.copyWith(
      status: ServerStatus.stopped,
      serverUrl: null,
      logEntries: [
        LogEntry.info('Server stopped'),
        ...state.logEntries,
      ],
    );
  }

  Future<void> regenerateCert() async {
    if (state.isRunning) await stop();
    try {
      await CertService.regenerate();
      _addLog(LogEntry.info('SSL certificate regenerated'));
    } catch (e) {
      _addLog(LogEntry.error('Certificate regeneration failed: $e'));
    }
  }

  void clearLog() {
    state = state.copyWith(logEntries: []);
  }

  void _addLog(LogEntry entry) {
    final entries = [entry, ...state.logEntries];
    if (entries.length > 500) entries.removeRange(500, entries.length);
    state = state.copyWith(logEntries: entries);
  }
}

final serverProvider =
    NotifierProvider<ServerNotifier, ServerState>(ServerNotifier.new);

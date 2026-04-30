import 'package:bonsoir/bonsoir.dart';

class MdnsService {
  BonsoirBroadcast? _broadcast;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start(int port) async {
    if (_running) return;

    final service = BonsoirService(
      name: 'calibre-agent',
      type: '_http._tcp',
      port: port,
      attributes: {
        'description': 'Calibre Agent',
        'version': '1.0',
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize();
    _broadcast!.eventStream?.listen(
      (event) {},
      onError: (e) => print('[mDNS] broadcast error: $e'),
    );
    await _broadcast!.start();
    _running = true;
  }

  Future<void> stop() async {
    if (!_running) return;
    await _broadcast?.stop();
    _broadcast = null;
    _running = false;
  }
}

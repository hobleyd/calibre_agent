import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../database/calibre_db.dart';
import '../models/log_entry.dart';
import '../services/cert_service.dart';

typedef LogCallback = void Function(LogEntry entry);

const int _defaultLimit = 100;
const int _maxLimit = 1000;

class CalibreServer {
  final String libraryPath;
  final int port;
  final LogCallback onLog;

  HttpServer? _server;
  CalibreDatabase? _db;

  CalibreServer({
    required this.libraryPath,
    required this.port,
    required this.onLog,
  });

  bool get isRunning => _server != null;

  int bookCount() => _db?.bookCount() ?? 0;

  Future<String> start() async {
    _db = CalibreDatabase(libraryPath);

    final certs = await CertService.ensureCerts();

    final context = SecurityContext()
      ..useCertificateChain(certs.certPath)
      ..usePrivateKey(certs.keyPath);

    final handler = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_loggingMiddleware())
        .addHandler(_buildRouter());

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
      securityContext: context,
    );

    _server!.autoCompress = true;
    return 'https://${await _localIp()}:$port';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _db = null;
  }

  Handler _buildRouter() {
    final router = Router();

    router.get('/', _handleHealth);
    router.get('/health', _handleHealth);
    router.get('/books', _handleBooks);
    router.put('/books', _handleBooksUpdate);
    router.get('/book/<uuid>', _handleBookFile);
    router.get('/count/<lastModified>/<limit>', _handleCount);
    router.get('/library', _handleLibrary);
    router.get('/details/<uuid>', _handleDetails);
    router.get('/tags/<uuid>', _handleTags);

    return router.call;
  }

  Response _handleHealth(Request req) {
    return _json({
      'status': 'running',
      'message': 'Calibre Agent is running',
      'timestamp': DateTime.now().toIso8601String(),
      'endpoints': {
        'GET /books': 'List books (params: last_modified, limit, offset)',
        'PUT /books': 'Update book data in Calibre',
        'GET /book/<uuid>': 'Download EPUB file',
        'GET /count/<last_modified>/<limit>': 'Count modified books',
        'GET /library': 'List all UUIDs',
        'GET /details/<uuid>': 'Book metadata',
        'GET /tags/<uuid>': 'Book tags',
        'GET /health': 'This message',
      },
    });
  }

  Response _handleBooks(Request req) {
    final db = _db;
    if (db == null) return _error(503, 'Server not ready');

    final params = req.url.queryParameters;
    final lastModified = int.tryParse(params['last_modified'] ?? '0') ?? 0;
    var limit =
        int.tryParse(params['limit'] ?? '$_defaultLimit') ?? _defaultLimit;
    var offset = int.tryParse(params['offset'] ?? '0') ?? 0;

    if (limit > _maxLimit) limit = _maxLimit;
    if (limit < 1) limit = _defaultLimit;
    if (offset < 0) offset = 0;

    try {
      final books = db.queryBooks(lastModified, limit, offset);
      return _json(books.map((b) => b.toJson()).toList());
    } catch (e) {
      onLog(LogEntry.error('queryBooks failed: $e'));
      return _error(500, 'Database error: $e');
    }
  }

  Future<Response> _handleBooksUpdate(Request req) async {
    final db = _db;
    if (db == null) return _error(503, 'Server not ready');

    final contentLength =
        int.tryParse(req.headers['content-length'] ?? '0') ?? 0;
    if (contentLength == 0) return _error(400, 'No content provided');

    final body = await req.readAsString();
    dynamic parsed;
    try {
      parsed = jsonDecode(body);
    } catch (e) {
      return _error(400, 'Invalid JSON: $e');
    }

    final books = parsed is List ? parsed : [parsed];
    int updated = 0;

    for (final book in books) {
      if (book is Map<String, dynamic>) {
        try {
          db.updateBook(book);
          updated++;
        } catch (e) {
          onLog(LogEntry.error('updateBook failed for ${book['UUID']}: $e'));
        }
      }
    }

    return _json({'status': 'success', 'message': 'Updated $updated book(s)'});
  }

  Response _handleBookFile(Request req, String uuid) {
    final db = _db;
    if (db == null) return _error(503, 'Server not ready');

    final cleanUuid = Uri.decodeComponent(uuid).trim();
    if (cleanUuid.isEmpty ||
        cleanUuid.contains('..') ||
        cleanUuid.contains('/') ||
        cleanUuid.contains('\\')) {
      return _error(400, 'Invalid UUID');
    }

    final relativePath = db.queryBookFilePath(cleanUuid);
    if (relativePath == null) return _error(404, 'Book not found');

    final file = File('$libraryPath/$relativePath');
    if (!file.existsSync()) return _error(404, 'EPUB file not found');

    return Response.ok(
      file.openRead(),
      headers: {
        'Content-Type': 'application/epub+zip',
        'Content-Length': file.lengthSync().toString(),
        'Content-Disposition': 'attachment; filename="$cleanUuid.epub"',
        'Cache-Control': 'no-cache',
      },
    );
  }

  Response _handleCount(Request req, String lastModified, String limit) {
    final db = _db;
    if (db == null) return _error(503, 'Server not ready');

    final lm = int.tryParse(lastModified) ?? 0;
    final lim = int.tryParse(limit) ?? _defaultLimit;

    try {
      final result = db.queryCountModified(lm, lim);
      return _json(result ?? {'count': 0, 'books': []});
    } catch (e) {
      onLog(LogEntry.error('queryCount failed: $e'));
      return _error(500, 'Database error: $e');
    }
  }

  Response _handleLibrary(Request req) {
    final db = _db;
    if (db == null) return _error(503, 'Server not ready');

    try {
      return _json(db.queryBookUuids());
    } catch (e) {
      onLog(LogEntry.error('queryBookUuids failed: $e'));
      return _error(500, 'Database error: $e');
    }
  }

  Response _handleDetails(Request req, String uuid) {
    final db = _db;
    if (db == null) return _error(503, 'Server not ready');

    final book = db.queryBook(uuid);
    if (book == null) return _error(404, 'Book not found');
    return _json(book.toJson());
  }

  Response _handleTags(Request req, String uuid) {
    final db = _db;
    if (db == null) return _error(503, 'Server not ready');

    try {
      final tags = db.queryBookTags(uuid);
      return _json(tags.map((t) => t.toJson()).toList());
    } catch (e) {
      onLog(LogEntry.error('queryBookTags failed: $e'));
      return _error(500, 'Database error: $e');
    }
  }

  Response _json(dynamic data) => Response.ok(
        jsonEncode(data),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );

  Response _error(int status, String message) => Response(
        status,
        body: jsonEncode({'error': message}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );

  Middleware _corsMiddleware() {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    return (Handler handler) {
      return (Request req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: corsHeaders);
        }
        final resp = await handler(req);
        return resp.change(headers: {...corsHeaders, ...resp.headers});
      };
    };
  }

  Middleware _loggingMiddleware() {
    return (Handler handler) {
      return (Request req) async {
        final resp = await handler(req);
        final client = req.headers['x-forwarded-for'] ?? 'unknown';
        onLog(LogEntry.request(
          method: req.method,
          path: req.requestedUri.path,
          client: client,
          statusCode: resp.statusCode,
        ));
        return resp;
      };
    };
  }

  Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }
}

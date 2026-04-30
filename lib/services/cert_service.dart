import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CertPaths {
  final String certPath;
  final String keyPath;
  const CertPaths({required this.certPath, required this.keyPath});
}

class CertService {
  static Future<Directory> _certDir() async {
    final dir = await getApplicationSupportDirectory();
    final certDir = Directory('${dir.path}/certs');
    if (!certDir.existsSync()) certDir.createSync(recursive: true);
    return certDir;
  }

  static Future<CertPaths> ensureCerts() async {
    final dir = await _certDir();
    final certPath = '${dir.path}/selfsigned.crt';
    final keyPath = '${dir.path}/private.key';

    if (File(certPath).existsSync() && File(keyPath).existsSync()) {
      return CertPaths(certPath: certPath, keyPath: keyPath);
    }

    return _generate(certPath, keyPath);
  }

  static Future<CertPaths> regenerate() async {
    final dir = await _certDir();
    final certPath = '${dir.path}/selfsigned.crt';
    final keyPath = '${dir.path}/private.key';

    for (final path in [certPath, keyPath]) {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    }

    return _generate(certPath, keyPath);
  }

  static Future<String?> expiryDate() async {
    final dir = await _certDir();
    final certPath = '${dir.path}/selfsigned.crt';
    if (!File(certPath).existsSync()) return null;

    final result = await Process.run(
        'openssl', ['x509', '-noout', '-enddate', '-in', certPath]);
    if (result.exitCode != 0) return null;

    final output = (result.stdout as String).trim();
    // output: "notAfter=Apr 27 10:23:45 2035 GMT"
    final match = RegExp(r'notAfter=(.+)').firstMatch(output);
    return match?.group(1);
  }

  static Future<CertPaths> _generate(String certPath, String keyPath) async {
    // Write a temporary config file to include SANs
    final tmpDir = Directory.systemTemp;
    final confPath = '${tmpDir.path}/calibre_agent_openssl.cnf';
    File(confPath).writeAsStringSync(_opensslConf());

    final result = await Process.run('openssl', [
      'req', '-x509', '-newkey', 'rsa:2048',
      '-keyout', keyPath,
      '-out', certPath,
      '-days', '3650',
      '-nodes',
      '-config', confPath,
    ]);

    File(confPath).deleteSync();

    if (result.exitCode != 0) {
      throw Exception(
          'SSL certificate generation failed:\n${result.stderr}');
    }

    return CertPaths(certPath: certPath, keyPath: keyPath);
  }

  static String _opensslConf() => '''
[req]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
CN = calibre-agent
O = Calibre Agent
C = US

[v3_req]
subjectAltName = @alt_names
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment

[alt_names]
DNS.1 = localhost
DNS.2 = calibre-agent.local
IP.1 = 127.0.0.1
''';
}

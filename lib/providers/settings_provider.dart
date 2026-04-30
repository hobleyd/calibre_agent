import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final String libraryPath;
  final int port;

  const AppSettings({
    this.libraryPath = '',
    this.port = 10444,
  });

  AppSettings copyWith({String? libraryPath, int? port}) {
    return AppSettings(
      libraryPath: libraryPath ?? this.libraryPath,
      port: port ?? this.port,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _keyLibraryPath = 'library_path';
  static const _keyPort = 'port';

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      libraryPath: prefs.getString(_keyLibraryPath) ?? '',
      port: prefs.getInt(_keyPort) ?? 10444,
    );
  }

  Future<void> setLibraryPath(String path) async {
    state = state.copyWith(libraryPath: path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLibraryPath, path);
  }

  Future<void> setPort(int port) async {
    state = state.copyWith(port: port);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPort, port);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

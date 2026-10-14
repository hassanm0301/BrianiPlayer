import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'playback_adapter.dart';

typedef PlayerLaunch = Future<void> Function(String executable, List<String> arguments);

class ExternalPlayerProfile {
  const ExternalPlayerProfile({required this.name, required this.executable,
    this.arguments = const ['{url}'], this.macApplication = false});
  final String name, executable;
  final List<String> arguments;
  final bool macApplication;
  List<String> argumentsFor(PlaybackSource source, {String? operatingSystem}) {
    final os = operatingSystem ?? Platform.operatingSystem;
    if (name.trim().isEmpty || name.length > 128 || executable.length > 4096 ||
        executable.isEmpty || RegExp(r'[\x00-\x1f\x7f]').hasMatch(executable) ||
        !(executable.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(executable))) {
      throw const FormatException('Choose an absolute installed player path.');
    }
    if (macApplication) {
      if (os != 'macos' || !executable.endsWith('.app') || arguments.length != 1 || arguments.single != '{url}') {
        throw const FormatException('Choose a macOS media application.');
      }
      return ['-a', executable, '--args', source.uri.toString()];
    }
    if (os == 'windows' && !executable.toLowerCase().endsWith('.exe')) {
      throw const FormatException('Windows player launchers must be executables.');
    }
    if (arguments.length > 32 || arguments.where((a) => a == '{url}').length != 1 ||
        arguments.any((a) => a.length > 2048 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(a)
          || (a.contains('{url}') && a != '{url}'))) {
      throw const FormatException('Use one complete {url} argument and bounded literal arguments.');
    }
    return arguments.map((a) => a == '{url}' ? source.uri.toString() : a).toList(growable: false);
  }
  Map<String, Object> toJson() => {'name': name, 'executable': executable, 'arguments': arguments, 'macApplication': macApplication};
  factory ExternalPlayerProfile.fromJson(Map<String, dynamic> json) => ExternalPlayerProfile(
    name: json['name'] as String, executable: json['executable'] as String,
    arguments: (json['arguments'] as List).cast<String>(), macApplication: json['macApplication'] == true);
}

class ExternalPlayerService {
  ExternalPlayerService(this.preferences, {PlayerLaunch? launch}) : _launch = launch ?? _spawn;
  final SharedPreferences preferences;
  final PlayerLaunch _launch;
  static const _key = 'external_player_v1';
  static Future<void> _spawn(String executable, List<String> args) async {
    await Process.start(executable, args, runInShell: false, mode: ProcessStartMode.detached);
  }
  ExternalPlayerProfile? get preferred {
    final raw = preferences.getString(_key);
    if (raw == null || raw.length > 12000) return null;
    try { return ExternalPlayerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>); }
    catch (_) { return null; }
  }
  Future<void> save(ExternalPlayerProfile profile, PlaybackSource validationSource) async {
    profile.argumentsFor(validationSource);
    await preferences.setString(_key, jsonEncode(profile.toJson()));
  }
  Future<void> reset() async { await preferences.remove(_key); }
  Future<void> launch(ExternalPlayerProfile profile, PlaybackSource source) async {
    final args = profile.argumentsFor(source);
    try { await _launch(profile.macApplication ? '/usr/bin/open' : profile.executable, args); }
    on ProcessException { throw const ExternalPlayerException('The player could not be opened. Check that it is installed, or choose another player.'); }
    on FileSystemException { throw const ExternalPlayerException('The selected player is unavailable. Choose another player.'); }
  }
  List<ExternalPlayerProfile> installed() {
    if (Platform.isMacOS) {
      return [for (final app in ['VLC', 'mpv', 'IINA'])
        if (Directory('/Applications/$app.app').existsSync())
          ExternalPlayerProfile(name: app, executable: '/Applications/$app.app', macApplication: true)];
    }
    final paths = (Platform.environment['PATH'] ?? '').split(Platform.isWindows ? ';' : ':');
    final found = <ExternalPlayerProfile>[];
    for (final player in ['mpv', 'vlc']) {
      for (final path in paths) {
        if (path.isEmpty) continue;
        final file = File('$path${Platform.pathSeparator}$player${Platform.isWindows ? '.exe' : ''}').absolute;
        if (file.existsSync()) {
          found.add(ExternalPlayerProfile(name: player == 'vlc' ? 'VLC' : 'mpv', executable: file.path,
            arguments: player == 'mpv' ? const ['--no-config', '--load-scripts=no', '--', '{url}'] : const ['--', '{url}']));
          break;
        }
      }
    }
    return found;
  }
}

class ExternalPlayerException implements Exception {
  const ExternalPlayerException(this.message);
  final String message;
  @override String toString() => message;
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../preferences/preferences_providers.dart';
import '../playback/playback_adapter.dart';

class DeviceCapabilities {
  const DeviceCapabilities({required this.television, required this.platform, this.sdk});
  final bool television;
  final String platform;
  final int? sdk;
}
class AndroidVideoHandler {
  const AndroidVideoHandler(this.name, this.package);
  final String name, package;
}
class NativePlatformService {
  NativePlatformService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'audioFocus' && call.arguments is String) _events.add(call.arguments as String);
      if (call.method == 'externalReturned') _events.add('externalReturned');
    });
  }
  static const _channel = MethodChannel('org.brianiplayer.app/platform');
  final _events = StreamController<String>.broadcast();
  Stream<String> get events => _events.stream;
  Future<DeviceCapabilities> capabilities() async {
    if (!Platform.isAndroid) return DeviceCapabilities(television: false, platform: Platform.operatingSystem);
    final values = await _channel.invokeMapMethod<String, dynamic>('capabilities');
    return DeviceCapabilities(television: values?['television'] == true, platform: 'android', sdk: values?['sdk'] as int?);
  }
  Future<bool> requestAudioFocus() async => !Platform.isAndroid || await _channel.invokeMethod<bool>('requestAudioFocus') == true;
  Future<void> abandonAudioFocus() async { if (Platform.isAndroid) await _channel.invokeMethod<void>('abandonAudioFocus'); }
  Future<List<AndroidVideoHandler>> handlers(PlaybackSource source, String mime) async {
    final rows = await _channel.invokeListMethod<dynamic>('videoHandlers', {'url': source.uri.toString(), 'mime': mime});
    return (rows ?? []).map((row) => AndroidVideoHandler(row['name'] as String, row['package'] as String)).toList(growable: false);
  }
  Future<void> launchVideo(PlaybackSource source, String mime, {String? package}) => _channel.invokeMethod<void>('launchVideo',
    {'url': source.uri.toString(), 'mime': mime, 'package': ?package});
  void dispose() { _channel.setMethodCallHandler(null); _events.close(); }
}
final nativePlatformProvider = Provider<NativePlatformService>((ref) {
  final service = NativePlatformService(); ref.onDispose(service.dispose); return service;
});
final deviceCapabilitiesProvider = FutureProvider<DeviceCapabilities>((ref) async {
  final native = await ref.watch(nativePlatformProvider).capabilities();
  final override = ref.watch(devicePreferencesProvider).modeOverride;
  return DeviceCapabilities(television: override == DeviceModeOverride.television || (override == DeviceModeOverride.automatic && native.television),
    platform: native.platform, sdk: native.sdk);
});

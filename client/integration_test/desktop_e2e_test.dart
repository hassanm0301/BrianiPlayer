// Real Linux desktop integration test. The runner creates this file mode 0600
// and removes it after Flutter exits. No credentials are accepted on argv.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:media_kit/media_kit.dart' as mk;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:briani_player/app/app.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/playback/playback_adapter.dart';
import 'package:briani_player/features/playback/player_screen.dart';
import 'package:briani_player/features/libraries/folder_screen.dart';
import 'package:window_manager/window_manager.dart';

Future<void> _until(WidgetTester tester, Finder finder, String label,
    {Duration timeout = const Duration(seconds: 35)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  final visibleText = tester.widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
      .where((text) => text.isNotEmpty).take(30).join(' | ');
  throw TestFailure('Timed out waiting for $label; visible text: $visibleText');
}

Future<void> _enter(WidgetTester tester, int index, String label, String value) async {
  final fields = find.byType(TextFormField);
  await _until(tester, fields, '$label field');
  final field = fields.at(index);
  await tester.enterText(field, value);
}

Future<void> _writeMarker(File marker, String contents) async {
  final pending = File('${marker.path}.writing');
  await pending.writeAsString(contents, flush: true);
  await pending.rename(marker.path);
}

Future<void> _mark(Map<String, dynamic> config, String stage) async {
  await _writeMarker(File(config['stageMarker'] as String), stage);
}

Future<void> _waitForMarker(WidgetTester tester, String path, String stage,
    {Duration timeout = const Duration(seconds: 45)}) async {
  final marker = File(path);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (await marker.exists()) return;
  }
  throw TestFailure('Timed out waiting for the isolated fixture to $stage.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('fixture markers never expose unfinished JSON reports', () async {
    final directory = await Directory.systemTemp.createTemp('briani-marker-');
    try {
      final marker = File('${directory.path}/report.json');
      final payload = List.filled(65536, 'x').join();
      await _writeMarker(marker, jsonEncode({'generation': 0, 'payload': payload}));
      var finished = false;
      final writer = () async {
        for (var generation = 1; generation <= 12; generation++) {
          await _writeMarker(marker, jsonEncode({'generation': generation, 'payload': payload}));
        }
        finished = true;
      }();
      var reads = 0;
      while (!finished) {
        final report = jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
        expect(report['payload'], payload);
        expect(report['generation'], inInclusiveRange(0, 12));
        reads++;
      }
      await writer;
      expect(reads, greaterThan(0));
    } finally {
      await directory.delete(recursive: true);
    }
  });
  final handoffPath = Platform.environment['BRIANI_E2E_FILE'];
  testWidgets('Linux desktop connects to the isolated Briani API', (tester) async {
    expect(handoffPath, isNotNull, reason: 'runner must provide protected handoff file');
    final config = jsonDecode(await File(handoffPath!).readAsString()) as Map<String, dynamic>;
    await _mark(config, 'started');
    final adapters = <MediaKitPlaybackAdapter>[];
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1280, 800));
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        playbackAdapterFactoryProvider.overrideWithValue(() {
          final adapter = MediaKitPlaybackAdapter();
          adapters.add(adapter);
          // Headless CI has no physical audio device; keep the normal native
          // video output and disable only audio output for this test process.
          unawaited((adapter.player.platform as mk.NativePlayer).setProperty('ao', 'null'));
          return adapter;
        }),
      ],
      child: const BrianiApp(),
    ));
    await _until(tester, find.text('Servers'), 'server profile screen');
    await _mark(config, 'before-add-server');
    await tester.tap(find.text('Add server'));
    await tester.pump(const Duration(milliseconds: 350));
    await _enter(tester, 0, 'Name', 'M07 isolated server');
    await _enter(tester, 1, 'Server address', config['origin'] as String);
    if ((config['origin'] as String).startsWith('http://')) {
      final trusted = find.text('Allow unencrypted HTTP for a trusted LAN/VPN server');
      await tester.ensureVisible(trusted);
      await tester.tap(trusted);
    }
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 350));
    await _until(tester, find.text('M07 isolated server'), 'saved server profile');
    await tester.tap(find.text('Connect'));
    await _mark(config, 'profile-connected');
    await _until(tester, find.text('Sign in'), 'sign-in screen');
    await _enter(tester, 0, 'Username', config['username'] as String);
    await _enter(tester, 1, 'Password', config['password'] as String);
    expect(tester.widgetList<TextFormField>(find.byType(TextFormField)).map((field) => field.controller!.text).toList(),
        [config['username'], config['password']], reason: 'real login form values');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await _mark(config, 'login-submitted');
    await _until(tester, find.text('Libraries'), 'authenticated libraries screen');
    // These sections are served by the real generated API client and HTTP API.
    await _until(tester, find.text('Your libraries'), 'library response');
    final libraryName = config['libraryName'] as String;
    await tester.tap(find.text(libraryName));
    await _until(tester, find.text('This folder is empty.'), 'empty library folder');
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Discover')));
    await _until(tester, find.text('Discover'), 'discover screen');
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Downloads')));
    final downloadName = config['downloadName'] as String;
    await _until(tester, find.text(downloadName), 'prepared legal torrent request');
    await tester.tap(find.text(downloadName));
    await _mark(config, 'download-opened');
    final mediaName = config['fileName'] as String;
    await _until(tester, find.text(mediaName), 'torrent file metadata in details');
    final checkbox = find.byType(Checkbox).first;
    await tester.ensureVisible(checkbox);
    if (tester.widget<Checkbox>(checkbox).value == true) {
      await tester.tap(checkbox);
      await tester.pump(const Duration(milliseconds: 350));
    }
    if (tester.widget<Checkbox>(checkbox).value != true) {
      await tester.tap(checkbox);
      await tester.pump(const Duration(milliseconds: 350));
    }
    expect(tester.widget<Checkbox>(checkbox).value, isTrue,
        reason: 'real UI must have the legal video selected before consent');
    final saveSelection = find.text('Save selection and start');
    await tester.ensureVisible(saveSelection);
    await tester.tap(saveSelection);
    await _mark(config, 'selection-submitted');
    await _until(tester, find.text('File selection queued.'), 'UI selection request accepted');
    await _until(tester, find.byTooltip('Play'), 'selected file becomes early-play eligible',
        timeout: const Duration(seconds: 165));
    await _mark(config, 'play-eligible');
    await tester.tap(find.byTooltip('Play'));
    await _mark(config, 'player-opened');
    await _until(tester, find.text(mediaName), 'embedded player route');
    await _until(tester, find.byTooltip('Pause'), 'native player controls');
    expect(adapters, hasLength(1), reason: 'production MediaKit adapter must be created');
    final native = adapters.single.player.platform as mk.NativePlayer;
    final frameDeadline = DateTime.now().add(const Duration(seconds: 90));
    var videoCodec = '';
    while (DateTime.now().isBefore(frameDeadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      videoCodec = await native.getProperty('video-codec');
      if (adapters.single.player.state.position > Duration.zero &&
          videoCodec.isNotEmpty) {
        break;
      }
    }
    expect(adapters.single.player.state.position, greaterThan(Duration.zero),
        reason: 'native media_kit playback position must advance');
    expect(videoCodec, isNotEmpty, reason: 'native libmpv must report a decoded video codec');
    final marker = File(config['firstFrameMarker'] as String);
    await _writeMarker(marker, jsonEncode({
      'positionMs': adapters.single.player.state.position.inMilliseconds,
      'videoCodec': videoCodec,
    }));
    await _mark(config, 'first-frame');
    await adapters.single.setSpeed(3);
    await _writeMarker(File(config['bufferRequestMarker'] as String), 'pause-download');
    await _waitForMarker(tester, config['bufferPauseMarker'] as String,
        'pause the selected torrent');
    final bufferDeadline = DateTime.now().add(const Duration(seconds: 60));
    DateTime? stableSince;
    Duration? previousPosition;
    var cachePauseSeen = false;
    var stableAt = Duration.zero;
    while (DateTime.now().isBefore(bufferDeadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      final cachePaused = await native.getProperty('paused-for-cache') == 'yes';
      final position = adapters.single.player.state.position;
      if (cachePaused && previousPosition != null &&
          (position - previousPosition).abs() < const Duration(milliseconds: 100)) {
        stableSince ??= DateTime.now();
        if (DateTime.now().difference(stableSince) >= const Duration(seconds: 1)) {
          cachePauseSeen = true;
          stableAt = position;
          break;
        }
      } else {
        stableSince = null;
      }
      previousPosition = position;
    }
    expect(cachePauseSeen, isTrue,
        reason: 'native libmpv must stall on unavailable torrent bytes');
    final bufferMarker = File(config['bufferMarker'] as String);
    await _writeMarker(bufferMarker, jsonEncode({
      'pausedForCache': true,
      'stablePositionMs': stableAt.inMilliseconds,
    }));
    await _waitForMarker(tester, config['bufferResumeMarker'] as String,
        'resume the same torrent and stream');
    final resumeDeadline = DateTime.now().add(const Duration(seconds: 45));
    var resumedAt = Duration.zero;
    var resumed = false;
    while (DateTime.now().isBefore(resumeDeadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      final cachePaused = await native.getProperty('paused-for-cache') == 'yes';
      final position = adapters.single.player.state.position;
      if (!cachePaused && position > stableAt + const Duration(milliseconds: 500)) {
        resumed = true;
        resumedAt = position;
        break;
      }
    }
    expect(resumed, isTrue,
        reason: 'the same native player URL and session must resume after bytes return');
    await adapters.single.setSpeed(1);
    await _writeMarker(File(config['bufferResumeProof'] as String), jsonEncode({
      'resumed': true,
      'positionAfterResumeMs': resumedAt.inMilliseconds,
    }));
    final screenshot = await Process.run('import',
        ['-window', 'root', config['renderProofPath'] as String],
        runInShell: false).timeout(const Duration(seconds: 8));
    expect(screenshot.exitCode, 0,
        reason: 'Xvfb must capture the real Linux desktop with embedded video');
    expect(await File(config['renderProofPath'] as String).exists(), isTrue,
        reason: 'native desktop render proof must be saved in the run artifacts');
    await tester.tap(find.byTooltip('Play with'));
    await _until(tester, find.text('Play with'), 'external player chooser');
    final externalChoice = find.text('mpv');
    await _until(tester, externalChoice, 'installed mpv choice');
    await tester.tap(externalChoice);
    await _until(tester, find.text('Player opened. Return here to retry or resume internal playback.'),
        'safe external player handoff');
    await _mark(config, 'external-handoff');
    final importReadyPath = config['importReadyMarker'] as String;
    await _waitForMarker(tester, importReadyPath,
        'complete and import the selected media', timeout: const Duration(seconds: 90));
    final back = find.byTooltip('Back');
    await _until(tester, back, 'player back control');
    await tester.tap(back);
    await _until(tester, find.byType(NavigationRail), 'main app navigation after playback');
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Libraries')));
    // Switching tabs retains the previously opened library folder. Refresh it
    // to discover the import completed while playback was on another route.
    await _until(tester, find.byType(FolderScreen), 'retained library folder');
    await tester.tap(find.byTooltip('Refresh folder'));
    final downloadsFolder = find.descendant(
      of: find.byType(FolderScreen), matching: find.text('Downloads'));
    await _until(tester, downloadsFolder, 'completed download folder in library',
        timeout: const Duration(seconds: 45));
    await tester.tap(downloadsFolder);
    final importedFolder = find.textContaining(config['downloadName'] as String);
    await _until(tester, importedFolder, 'imported download folder');
    await tester.tap(importedFolder.last);
    // The torrent metadata includes its root directory as a nested entry under
    // the per-job import directory. Walk that real library folder before
    // asserting the imported media item is browseable.
    final torrentRoot = find.textContaining(config['downloadName'] as String);
    await _until(tester, torrentRoot, 'torrent root directory in imported folder',
        timeout: const Duration(seconds: 45));
    await tester.tap(torrentRoot.last);
    await _until(tester, find.text(mediaName), 'completed imported media in library',
        timeout: const Duration(seconds: 45));
    await _mark(config, 'completed-import-browsed');
    await tester.binding.setSurfaceSize(null);
  });
}

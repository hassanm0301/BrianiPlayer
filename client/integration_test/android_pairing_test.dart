// Connected Android TV device-code pairing against the owned M08 fixture.
// The human code is kept in process memory and sent only to the loopback
// fixture bridge; it is never written to control markers or diagnostic output.
import 'dart:convert';
import 'dart:io';

import 'package:briani_player/app/app.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _configPath = String.fromEnvironment('BRIANI_E2E_FILE');

Future<void> _waitFor(WidgetTester tester, Finder finder, String label,
    {Duration timeout = const Duration(seconds: 35)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 180));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $label.');
}

Element _focusRoot(Element element) {
  if (_isFocusRoot(element.widget)) return element;
  Element? root;
  element.visitAncestorElements((ancestor) {
    if (_isFocusRoot(ancestor.widget)) {
      root = ancestor;
      return false;
    }
    return true;
  });
  return root ?? element;
}

bool _isFocusRoot(Widget widget) => widget is ButtonStyleButton ||
    widget is IconButton || widget is FloatingActionButton ||
    widget is PopupMenuButton || widget is Checkbox || widget is Switch ||
    widget is Radio || widget is InkWell || widget is ListTile ||
    widget is CheckboxListTile || widget is NavigationDestination;

bool _matchesPrimary(BuildContext primary, Element target) {
  final widget = target.widget;
  if (identical(primary, target)) return true;
  bool blocks(Widget candidate) {
    if (candidate is InkWell && widget is ButtonStyleButton) return false;
    if (candidate is ListTile && widget is CheckboxListTile) return false;
    if ((candidate is ButtonStyleButton || candidate is InkWell) &&
        widget is NavigationDestination) {
      return false;
    }
    return candidate is ButtonStyleButton || candidate is IconButton ||
        candidate is FloatingActionButton || candidate is PopupMenuButton ||
        candidate is CheckboxListTile || candidate is ListTile ||
        candidate is NavigationDestination || candidate is Checkbox ||
        candidate is Switch || candidate is Radio;
  }
  if (blocks(primary.widget)) return false;
  var matched = false;
  primary.visitAncestorElements((ancestor) {
    if (identical(ancestor, target)) { matched = true; return false; }
    if (blocks(ancestor.widget)) return false;
    return true;
  });
  return matched;
}

bool _focused(WidgetTester tester, Finder finder) {
  final targets = finder.evaluate().map(_focusRoot).toSet();
  final primary = FocusManager.instance.primaryFocus?.context;
  return primary != null && targets.any((target) => _matchesPrimary(primary, target));
}

Future<void> _focus(WidgetTester tester, Finder finder, String label) async {
  const route = <LogicalKeyboardKey>[
    LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowRight,
  ];
  for (var i = 0; i < 72 && !_focused(tester, finder); i++) {
    await tester.sendKeyEvent(route[i % route.length]);
    await tester.pump(const Duration(milliseconds: 90));
  }
  if (!_focused(tester, finder)) {
    throw TestFailure('D-pad could not focus $label.');
  }
}

Future<void> _select(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.pump(const Duration(milliseconds: 180));
}

Future<void> _mark(String origin, String name) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.postUrl(Uri.parse('$origin/__m08/control/mark/$name'));
    request.headers.contentType = ContentType.json;
    request.write('{}');
    final response = await request.close().timeout(const Duration(seconds: 8));
    await response.drain<void>();
    if (response.statusCode != HttpStatus.noContent) {
      throw StateError('Fixture checkpoint failed.');
    }
  } finally {
    client.close(force: true);
  }
}

Future<String> _sendCode(String origin, String path, String code) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.postUrl(Uri.parse('$origin/__m08/pair/$path'));
    request.headers.contentType = ContentType.json;
    final payload = utf8.encode(jsonEncode({'userCode': code}));
    request.contentLength = payload.length;
    request.add(payload);
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await utf8.decoder.bind(response).join();
    final value = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode != HttpStatus.ok) {
      return 'failed-${value['stage'] ?? 'fixture-http-${response.statusCode}'}';
    }
    if (path == 'approve') {
      return value['approved'] == true && value['previewSafe'] == true
          ? 'approved' : 'invalid-approval-proof';
    }
    return value['consumed'] == true ? 'consumed' : 'not-consumed';
  } finally {
    client.close(force: true);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('TV pairs through real device-code API and receives only granted library access',
      (tester) async {
    expect(_configPath, isNotEmpty);
    final config = jsonDecode(await File(_configPath).readAsString()) as Map<String, dynamic>;
    final origin = config['origin'] as String;
    final runShort = config['runShort'] as String;
    final profile = ServerProfile(id: 'm08-pair-$runShort',
        label: config['profileLabel'] as String, origin: Uri.parse(origin));
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
    ]);
    var success = false;
    try {
      await container.read(serverProfileRepositoryProvider).save(profile);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const BrianiApp()));
      await _waitFor(tester, find.text('Connect'), 'saved server Connect action');
      final connect = find.text('Connect').last;
      await _focus(tester, connect, 'Connect');
      await _select(tester);
      await _waitFor(tester, find.text('Link using another signed-in device'), 'sign-in screen');
      final link = find.text('Link using another signed-in device');
      await _focus(tester, link, 'Link using another signed-in device');
      await _select(tester);
      await _waitFor(tester, find.text('Link this device'), 'device-link screen');
      final requestCode = find.widgetWithText(FilledButton, 'Request device code');
      await _focus(tester, requestCode, 'Request device code');
      await _select(tester);
      final codeFinder = find.byType(SelectableText);
      await _waitFor(tester, codeFinder, 'issued device code');
      final code = tester.widget<SelectableText>(codeFinder.first).data;
      if (code == null || !RegExp(r'^[A-Z2-9]{8}$').hasMatch(code)) {
        throw TestFailure('The fixture did not issue an eight-character pairing code.');
      }
      await _mark(origin, 'pairing-code-visible');
      final approval = await _sendCode(origin, 'approve', code);
      if (approval != 'approved') {
        throw TestFailure('Fixture approval failed at safe stage ${approval.replaceFirst('failed-', '')}.');
      }
      await _mark(origin, 'pairing-approved');

      await _waitFor(tester, find.text('Your libraries'), 'paired member library list',
          timeout: const Duration(seconds: 30));
      final session = container.read(clientSessionProvider);
      if (session == null || session.tokens.user.username != config['pairUsername']) {
        throw TestFailure('The TV did not install the approved fixture member identity.');
      }
      final libraries = (await session.api.getLibrariesApi().listLibraries()).data!.toList();
      final ids = libraries.map((library) => library.id).toSet();
      final visibleId = config['pairVisibleLibraryId'] as String;
      final hiddenId = config['pairHiddenLibraryId'] as String;
      if (!ids.contains(visibleId) || ids.contains(hiddenId) || libraries.length != 1) {
        throw TestFailure('Paired account library permissions did not match the fixture grants.');
      }
      if (find.text(config['pairVisibleLibraryName'] as String).evaluate().isEmpty ||
          find.text(config['pairHiddenLibraryName'] as String).evaluate().isNotEmpty) {
        throw TestFailure('The TV library screen did not reflect the paired account permissions.');
      }
      await _mark(origin, 'pairing-library-access');
      if (await _sendCode(origin, 'consumed', code) != 'consumed') {
        throw TestFailure('The consumed human code remained inspectable after exchange.');
      }
      await _mark(origin, 'pairing-code-consumed');
      success = true;
    } finally {
      try { await tester.pumpWidget(const SizedBox.shrink()); } catch (_) {}
      try {
        if (container.read(clientSessionProvider) != null) {
          await container.read(clientSessionProvider.notifier)
              .disconnect(logout: true).timeout(const Duration(seconds: 8));
        }
      } catch (_) {}
      try { await container.read(serverProfileRepositoryProvider).remove(profile.id); } catch (_) {}
      container.dispose();
      try { await File(_configPath).delete(); } catch (_) {}
    }
    expect(success, isTrue);
  }, timeout: const Timeout(Duration(minutes: 4)));
}

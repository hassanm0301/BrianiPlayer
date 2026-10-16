// Connected M08 Android TV test. The runner installs only the .devtest package,
// places credentials in its private files directory, and bridges localhost via
// an explicitly scoped adb reverse. UI actions use directional HardwareKeyboard
// events; no widget taps or test-only playback adapter are used.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:briani_player/app/app.dart';
import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:briani_player/core/playback/playback_adapter.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/session/client_session.dart';
import 'package:briani_player/features/playback/player_screen.dart'
    show playbackAdapterFactoryProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:shared_preferences/shared_preferences.dart';

const _configPath = String.fromEnvironment('BRIANI_E2E_FILE');
const _backDiagnosticOnly = bool.fromEnvironment('BRIANI_BACK_DIAGNOSTIC');

class _BackDispatchObserver with WidgetsBindingObserver {
  _BackDispatchObserver(this.onPopRoute);

  final Future<void> Function() onPopRoute;

  @override
  Future<bool> didPopRoute() async {
    await onPopRoute();
    return false;
  }
}

Future<void> _until(
  WidgetTester tester,
  Finder finder,
  String label, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((item) => item.data ?? item.textSpan?.toPlainText() ?? '')
      .where((value) => value.isNotEmpty)
      .take(35)
      .join(' | ');
  throw TestFailure('Timed out waiting for $label; visible text: $text');
}

Future<void> _untilGone(
  WidgetTester tester,
  Finder finder,
  String label, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 180));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Timed out waiting for $label to close.');
}

bool _focused(WidgetTester tester, Finder finder) {
  final targets = finder.evaluate().map(_interactiveFocusRoot).toSet();
  for (final element in targets) {
    if (element.widget is EditableText &&
        (element.widget as EditableText).focusNode.hasFocus) {
      return true;
    }
  }
  // Compound controls (CheckboxListTile, buttons with internal InkWell, etc.)
  // put the primary Focus widget below the widget matched by the Finder. Walk
  // up from primaryFocus.context so the predicate recognizes that real focus
  // without requesting focus or interacting with the control.
  final primaryContext = FocusManager.instance.primaryFocus?.context;
  if (primaryContext != null) {
    if (targets.any(
      (target) => _primaryContextMatchesTarget(primaryContext, target),
    )) {
      return true;
    }
  }
  return false;
}

bool _primaryContextMatchesTarget(BuildContext primaryContext, Element target) {
  final targetWidget = target.widget;
  if (identical(primaryContext, target)) return true;
  if (_isBlockingNestedControl(primaryContext.widget, targetWidget)) {
    return false;
  }

  var matched = false;
  primaryContext.visitAncestorElements((ancestor) {
    if (identical(ancestor, target)) {
      matched = true;
      return false;
    }
    if (_isBlockingNestedControl(ancestor.widget, targetWidget)) return false;
    return true;
  });
  return matched;
}

bool _isBlockingNestedControl(Widget candidate, Widget target) {
  // ButtonStyleButton owns an internal InkWell; it is still the target when
  // focus is reported from that implementation detail.
  if (candidate is InkWell && target is ButtonStyleButton) return false;
  // CheckboxListTile is implemented with an internal ListTile. That wrapper
  // does not make it a different target.
  if (candidate is ListTile && target is CheckboxListTile) return false;
  // NavigationDestination similarly hosts its focusable implementation button.
  if ((candidate is ButtonStyleButton || candidate is InkWell) &&
      target is NavigationDestination) {
    return false;
  }

  return candidate is ButtonStyleButton ||
      candidate is IconButton ||
      candidate is FloatingActionButton ||
      candidate is PopupMenuButton ||
      candidate is CheckboxListTile ||
      candidate is ListTile ||
      candidate is NavigationDestination ||
      candidate is Checkbox ||
      candidate is Switch ||
      candidate is Radio;
}

Element _interactiveFocusRoot(Element element) {
  if (_isInteractiveFocusRoot(element.widget)) return element;
  Element? root;
  element.visitAncestorElements((ancestor) {
    if (_isInteractiveFocusRoot(ancestor.widget)) {
      root = ancestor;
      return false;
    }
    return true;
  });
  return root ?? element;
}

bool _isInteractiveFocusRoot(Widget widget) =>
    widget is ButtonStyleButton ||
    widget is IconButton ||
    widget is FloatingActionButton ||
    widget is PopupMenuButton ||
    widget is Checkbox ||
    widget is Switch ||
    widget is Radio ||
    widget is InkWell ||
    widget is ListTile ||
    widget is CheckboxListTile ||
    widget is NavigationDestination;

bool _primaryFocusIsWithin(WidgetTester tester, Finder finder) {
  final targets = finder.evaluate().map(_interactiveFocusRoot).toSet();
  final primaryContext = FocusManager.instance.primaryFocus?.context;
  if (primaryContext == null) return false;
  return targets.any(
    (target) => _primaryContextMatchesTarget(primaryContext, target),
  );
}

String _focusFailureDiagnostic(WidgetTester tester, Finder finder) {
  List<String> ancestors(Element element) {
    final result = <String>[element.widget.runtimeType.toString()];
    element.visitAncestorElements((ancestor) {
      if (result.length >= 8) return false;
      result.add(ancestor.widget.runtimeType.toString());
      return true;
    });
    return result;
  }

  final primary = FocusManager.instance.primaryFocus;
  final primaryContext = primary?.context;
  final targets = finder.evaluate().map(_interactiveFocusRoot).take(4);
  return 'primaryNodeType=${primary?.runtimeType}; '
      'primaryContextTypes=${primaryContext is Element ? ancestors(primaryContext) : const <String>[]}; '
      'targetAncestorTypes=${targets.map(ancestors).toList()}';
}

Future<void> _focusDownByDpad(
  WidgetTester tester,
  Finder finder,
  String label, {
  int maxEvents = 16,
}) async {
  for (var index = 0; index < maxEvents; index++) {
    if (_focused(tester, finder)) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 120));
  }
  throw TestFailure('D-pad Down could not focus $label.');
}

Future<void> _focusByDpad(
  WidgetTester tester,
  Finder finder,
  String label, {
  int maxEvents = 72,
}) async {
  const route = <LogicalKeyboardKey>[
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowRight,
  ];
  for (var index = 0; index < maxEvents; index++) {
    if (_focused(tester, finder)) return;
    await tester.sendKeyEvent(route[index % route.length]);
    await tester.pump(const Duration(milliseconds: 90));
  }
  throw TestFailure(
    'D-pad could not focus $label; ${_focusFailureDiagnostic(tester, finder)}.',
  );
}

Future<void> _activate(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.select);
  await tester.pump(const Duration(milliseconds: 180));
}

Future<void> _focusLibrariesTab(WidgetTester tester) async {
  final libraries = find.text('Libraries').first;
  final tabs = [libraries, find.text('Discover').first, find.text('Downloads').first];
  // Leave the content route upward, then traverse the navigation row left.
  // A repeating walk with two Rights and one Left never visits its left edge.
  for (var i = 0; i < 20 && !tabs.any((tab) => _focused(tester, tab)); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump(const Duration(milliseconds: 120));
  }
  for (var i = 0; i < 8 && !_focused(tester, libraries); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump(const Duration(milliseconds: 120));
  }
  expect(_focused(tester, libraries), isTrue,
    reason: 'D-pad Up to navigation, then Left must reach Libraries.');
}

Future<void> _typeFocused(
  WidgetTester tester,
  Finder finder,
  String value,
  String label,
) async {
  final editable = find.descendant(
    of: finder,
    matching: find.byType(EditableText),
  );
  // Text fields consume Left/Right to move the caret. Keep focus traversal
  // directional and predictable when moving between vertically stacked form
  // fields, rather than sending a generic navigation route through the active
  // editor.
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  var lastDownHandled = false;
  for (
    var event = 0;
    !_focused(tester, editable) &&
        event < 16 &&
        DateTime.now().isBefore(deadline);
    event++
  ) {
    lastDownHandled = await tester.sendKeyDownEvent(
      LogicalKeyboardKey.arrowDown,
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 120));
  }
  if (!_focused(tester, editable)) {
    final primary = FocusManager.instance.primaryFocus;
    throw TestFailure(
      'D-pad Down could not focus $label; handled=$lastDownHandled; '
      'primaryType=${primary?.runtimeType}; primaryLabel=${primary?.debugLabel}; '
      'primaryHasFocus=${primary?.hasFocus};',
    );
  }
  await tester.enterText(finder, value);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _controlPost(
  String origin,
  String name, [
  Map<String, Object?> value = const {},
]) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.postUrl(
      Uri.parse('$origin/__m08/control/mark/$name'),
    );
    request.headers.contentType = ContentType.json;
    final body = jsonEncode(value);
    request.contentLength = utf8.encode(body).length;
    request.write(body);
    final response = await request.close().timeout(const Duration(seconds: 8));
    await response.drain<void>().timeout(const Duration(seconds: 8));
    if (response.statusCode != HttpStatus.noContent) {
      throw StateError(
        'M08 control marker write failed (${response.statusCode}).',
      );
    }
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, Object?>> _controlWait(
  String origin,
  String name, {
  Duration timeout = const Duration(seconds: 180),
  WidgetTester? tester,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final end = DateTime.now().add(timeout);
  try {
    while (DateTime.now().isBefore(end)) {
      final request = await client.getUrl(
        Uri.parse('$origin/__m08/control/response/$name'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == HttpStatus.ok) {
        return (jsonDecode(body) as Map).cast<String, Object?>();
      }
      if (tester != null) {
        await tester.pump(const Duration(milliseconds: 350));
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
    throw TimeoutException(
      'Timed out waiting for isolated E2E controller response: $name.',
    );
  } finally {
    client.close(force: true);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  mk.MediaKit.ensureInitialized();
  testWidgets(
    'TV player controls expose focusable Play and Pause text, not tooltips',
    (tester) async {
      var playing = false;
      var activations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RemoteNavigationScope(
              television: true,
              child: StatefulBuilder(
                builder: (context, setState) => TvPlayerControls(
                  playing: playing,
                  position: Duration.zero,
                  duration: const Duration(seconds: 30),
                  onPlayPause: () => setState(() {
                    playing = !playing;
                    activations++;
                  }),
                  onSeekBack: () {},
                  onSeekForward: () {},
                  onTracks: () {},
                  onOptions: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final play = find.text('Play');
      expect(play, findsOneWidget);
      expect(find.byTooltip('Play'), findsNothing);
      await _focusByDpad(tester, play, 'TV Play control');
      await _activate(tester);
      await tester.pumpAndSettle();

      expect(playing, isTrue);
      expect(activations, 1);
      final pause = find.text('Pause');
      expect(pause, findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
      await _focusByDpad(tester, pause, 'TV Pause control');

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('focus matcher ignores a merely focused route scope', (
    tester,
  ) async {
    final routeScope = FocusScopeNode(debugLabel: 'test route');
    final siblingFocus = FocusNode(debugLabel: 'focused other button');
    final connectFocus = FocusNode(debugLabel: 'Connect button');
    final connectKey = GlobalKey();
    final otherKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: FocusScope(
          node: routeScope,
          child: Scaffold(
            body: Column(
              children: [
                TextButton(
                  key: otherKey,
                  focusNode: siblingFocus,
                  onPressed: () {},
                  child: const Text('Other action'),
                ),
                TextButton(
                  key: connectKey,
                  focusNode: connectFocus,
                  onPressed: () {},
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    siblingFocus.requestFocus();
    await tester.pump();
    expect(siblingFocus.hasPrimaryFocus, isTrue);
    expect(_focused(tester, find.byKey(connectKey)), isFalse);
    expect(_focused(tester, find.text('Connect')), isFalse);
    expect(_primaryFocusIsWithin(tester, find.byKey(connectKey)), isFalse);
    connectFocus.requestFocus();
    await tester.pump();
    expect(connectFocus.hasPrimaryFocus, isTrue);
    expect(_focused(tester, find.byKey(connectKey)), isTrue);
    expect(_focused(tester, find.text('Connect')), isTrue);
    expect(_focused(tester, find.byKey(otherKey)), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    routeScope.dispose();
    siblingFocus.dispose();
    connectFocus.dispose();
  });
  testWidgets(
    'focus matcher rejects a nested popup but accepts a real button',
    (tester) async {
      final rowFocus = FocusNode(debugLabel: 'download row');
      final menuFocus = FocusNode(debugLabel: 'download actions');
      final buttonFocus = FocusNode(debugLabel: 'standalone action');
      var rowActivations = 0;
      var buttonActivations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RemoteNavigationScope(
            television: true,
            child: Scaffold(
              body: Column(
                children: [
                  ListTile(
                    focusNode: rowFocus,
                    title: const Text('Download request'),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Download actions',
                      child: Focus(
                        focusNode: menuFocus,
                        child: const Icon(Icons.more_vert),
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove request'),
                        ),
                      ],
                    ),
                    onTap: () => rowActivations++,
                  ),
                  FilledButton(
                    focusNode: buttonFocus,
                    onPressed: () => buttonActivations++,
                    child: const Text('Standalone action'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      rowFocus.requestFocus();
      await tester.pump();
      expect(_focused(tester, find.text('Download request')), isTrue);

      menuFocus.requestFocus();
      await tester.pump();
      expect(menuFocus.hasPrimaryFocus, isTrue);
      expect(
        _focused(tester, find.text('Download request')),
        isFalse,
        reason:
            'A nested popup control must not count as focus on its ListTile.',
      );
      await _activate(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Remove request'),
        findsOneWidget,
        reason: 'Select on the focused nested control should open its menu.',
      );
      expect(rowActivations, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      buttonFocus.requestFocus();
      await tester.pump();
      expect(buttonFocus.hasPrimaryFocus, isTrue);
      expect(
        _focused(tester, find.text('Standalone action')),
        isTrue,
        reason:
            'A ButtonStyleButton internal InkWell must not mask its own focus.',
      );
      await _activate(tester);
      expect(buttonActivations, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      rowFocus.dispose();
      menuFocus.dispose();
      buttonFocus.dispose();
    },
  );
  testWidgets(
    'Android TV connects, navigates by D-pad, plays, buffers and browses import',
    (tester) async {
      expect(
        Platform.isAndroid,
        isTrue,
        reason: 'This gate must run on emulator-5580.',
      );
      expect(
        _configPath,
        isNotEmpty,
        reason: 'Runner must set the non-secret private config path.',
      );
      final config = jsonDecode(
        await File(_configPath).readAsString(),
      ) as Map<String, dynamic>;
      final origin = config['origin'] as String;
      final adapters = <MediaKitPlaybackAdapter>[];
      final receivedKeys = <String>{};
      bool recordKey(KeyEvent event) {
        if (event is KeyDownEvent &&
            {
              LogicalKeyboardKey.arrowUp,
              LogicalKeyboardKey.arrowDown,
              LogicalKeyboardKey.arrowLeft,
              LogicalKeyboardKey.arrowRight,
              LogicalKeyboardKey.select,
            }.contains(event.logicalKey)) {
          receivedKeys.add(event.logicalKey.keyLabel);
        }
        return false;
      }

      HardwareKeyboard.instance.addHandler(recordKey);
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          playbackAdapterFactoryProvider.overrideWithValue(() {
            final adapter = MediaKitPlaybackAdapter();
            adapters.add(adapter);
            return adapter;
          }),
        ],
      );
      _BackDispatchObserver? backObserver;
      if (_backDiagnosticOnly) {
        backObserver = _BackDispatchObserver(() async {
          final router = container.read(appRouterProvider);
          final path = router.routeInformationProvider.value.uri.path;
          await _controlPost(origin, 'flutter-did-pop-route', {
            'canPop': router.canPop(),
            'routeCategory': path.startsWith('/libraries')
                ? 'libraries'
                : path.startsWith('/play/')
                ? 'play'
                : path.startsWith('/downloads')
                ? 'downloads'
                : path.startsWith('/signin/')
                ? 'signin'
                : path == '/servers'
                ? 'servers'
                : 'other',
          });
        });
        WidgetsBinding.instance.addObserver(backObserver);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BrianiApp(),
        ),
      );
      var success = false;
      try {
        await _until(tester, find.text('Servers'), 'server profile page');
        final addServer = find.text('Add server');
        await _focusByDpad(tester, addServer, 'Add server');
        await _activate(tester);
        await _until(tester, find.text('Server address'), 'add-server form');
        final fields = find.byType(TextFormField);
        await _typeFocused(
          tester,
          fields.at(0),
          'M08 TV ${config['runShort']}',
          'profile name',
        );
        await _typeFocused(tester, fields.at(1), origin, 'server address');
        final trust = find.byType(CheckboxListTile);
        await _focusDownByDpad(tester, trust, 'trusted LAN HTTP opt-in');
        if (tester.widget<CheckboxListTile>(trust).value != true) {
          await _activate(tester);
        }
        expect(tester.widget<CheckboxListTile>(trust).value, isTrue);
        final save = find.widgetWithText(FilledButton, 'Save');
        await _focusByDpad(tester, save, 'save profile');
        await _activate(tester);
        final profileLabel = 'M08 TV ${config['runShort']}';
        await _until(tester, find.text(profileLabel), 'saved TV profile');
        final connect = find.widgetWithText(TextButton, 'Connect').first;
        await _focusByDpad(tester, connect, 'Connect action');
        expect(
          _primaryFocusIsWithin(tester, connect),
          isTrue,
          reason:
              'Connect must contain the actual primary focus before Select.',
        );
        await _activate(tester);
        final routeDeadline = DateTime.now().add(const Duration(seconds: 4));
        var routeCategory = 'servers';
        while (DateTime.now().isBefore(routeDeadline)) {
          final path = container
              .read(appRouterProvider)
              .routeInformationProvider
              .value
              .uri
              .path;
          routeCategory = path.startsWith('/signin/')
              ? 'signin'
              : path == '/servers'
              ? 'servers'
              : 'other';
          if (routeCategory != 'servers') break;
          await tester.pump(const Duration(milliseconds: 120));
        }
        expect(
          routeCategory,
          'signin',
          reason:
              'Select on the focused Connect action must navigate to sign-in.',
        );
        await _until(tester, find.text('Sign in'), 'real API login screen');
        final loginFields = find.byType(TextFormField);
        await _typeFocused(
          tester,
          loginFields.at(0),
          config['username'] as String,
          'username',
        );
        await _typeFocused(
          tester,
          loginFields.at(1),
          config['password'] as String,
          'password',
        );
        final signIn = find.widgetWithText(FilledButton, 'Sign in');
        await _focusByDpad(tester, signIn, 'Sign in');
        await _activate(tester);
        await _until(
          tester,
          find.text('Your libraries'),
          'authenticated library list',
        );
        final libraryName = config['libraryName'] as String;
        await _focusByDpad(tester, find.text(libraryName), 'assigned library');
        await _activate(tester);
        await _until(
          tester,
          find.text('This folder is empty.'),
          'real library root',
        );
        await _controlPost(origin, 'initial-empty-library');
        final router = container.read(appRouterProvider);
        final routePath = router.routeInformationProvider.value.uri.path;
        await _controlPost(origin, 'back-library-before', {
          'canPop': router.canPop(),
          'routeCategory': routePath.startsWith('/libraries')
              ? 'libraries'
              : routePath.startsWith('/play/')
              ? 'play'
              : routePath.startsWith('/downloads')
              ? 'downloads'
              : routePath.startsWith('/signin/')
              ? 'signin'
              : 'other',
        });
        await _controlPost(origin, 'back-library-request');
        final backResult = await _controlWait(origin, 'back-library-request');
        expect(backResult['keyEvent'] == 'KEYCODE_BACK', isTrue);
        await _controlPost(origin, 'back-library-acknowledged');
        await _until(
          tester,
          find.text('Your libraries'),
          'library list after system Back',
        );
        expect(
          _focused(tester, find.text(libraryName)),
          isTrue,
          reason: 'Back from the folder must restore focus to the selected library.',
        );
        await _controlPost(origin, 'back-library-returned');
        var routeAfterBack = container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path;
        await _controlPost(origin, 'library-back-restored', {
          'sessionPresent': container.read(clientSessionProvider) != null,
          'routeCategory': routeAfterBack.startsWith('/libraries')
              ? 'libraries'
              : 'other',
        });

        // From the focused library card, one D-pad up enters the navigation row;
        // rightward events choose Downloads without tapping the navigation bar.
        await _controlPost(origin, 'downloads-navigation-started', {
          'sessionPresent': container.read(clientSessionProvider) != null,
          'routeCategory': routeAfterBack.startsWith('/libraries')
              ? 'libraries'
              : 'other',
        });
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump(const Duration(milliseconds: 120));
        await _controlPost(origin, 'downloads-after-up', {
          'sessionPresent': container.read(clientSessionProvider) != null,
        });
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 120));
        await _controlPost(origin, 'downloads-after-right-1', {
          'sessionPresent': container.read(clientSessionProvider) != null,
        });
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 120));
        await _controlPost(origin, 'downloads-after-right-2', {
          'sessionPresent': container.read(clientSessionProvider) != null,
        });
        final downloadsTab = find.text('Downloads').first;
        await _controlPost(origin, 'downloads-focus-started', {
          'sessionPresent': container.read(clientSessionProvider) != null,
        });
        if (!_focused(tester, downloadsTab)) {
          await _focusByDpad(
            tester,
            downloadsTab,
            'Downloads navigation destination',
          );
        }
        await _controlPost(origin, 'downloads-focused');
        if (_backDiagnosticOnly) {
          success = true;
          return;
        }
        await _controlPost(origin, 'downloads-activate-started');
        await _activate(tester);
        await _controlPost(origin, 'downloads-activated');
        await _until(
          tester,
          find.text(config['downloadName'] as String),
          'pending generated request',
        );
        await _controlPost(origin, 'pending-request-visible');
        final requestTile = find.text(config['downloadName'] as String).first;
        await _focusByDpad(tester, requestTile, 'generated download request');
        await _activate(tester);
        final requestRoute = container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path;
        final primary = FocusManager.instance.primaryFocus;
        final primaryContext = primary?.context;
        final focusAncestors = <String>[];
        if (primaryContext is Element) {
          focusAncestors.add(primaryContext.widget.runtimeType.toString());
          primaryContext.visitAncestorElements((ancestor) {
            if (focusAncestors.length >= 12) return false;
            focusAncestors.add(ancestor.widget.runtimeType.toString());
            return true;
          });
        }
        await _controlPost(origin, 'download-request-activated', {
          'routeCategory': requestRoute.startsWith('/downloads/')
              ? 'download-details'
              : requestRoute == '/downloads'
              ? 'downloads'
              : 'other',
          'primaryNodeType': primary?.runtimeType.toString(),
          'primaryNodeLabel': primary?.debugLabel,
          'primaryAncestors': focusAncestors,
          'requestRowFocused': _focused(tester, requestTile),
          'removeActionVisible': find
              .text('Remove request')
              .evaluate()
              .isNotEmpty,
        });
        final mediaName = config['fileName'] as String;
        await _until(
          tester,
          find.text(mediaName),
          'uploaded torrent file metadata',
        );
        await _controlPost(origin, 'download-details-visible');
        final checkbox = find.byType(Checkbox).first;
        await _focusByDpad(tester, checkbox, 'file selection checkbox');
        if (tester.widget<Checkbox>(checkbox).value == true) {
          await _activate(tester);
          expect(
            tester.widget<Checkbox>(checkbox).value,
            isFalse,
            reason: 'D-pad selection action must toggle the UI file choice.',
          );
        }
        await _activate(tester);
        expect(
          tester.widget<Checkbox>(checkbox).value,
          isTrue,
          reason: 'The UI must confirm selection before download starts.',
        );
        final start = find.widgetWithText(
          FilledButton,
          'Save selection and start',
        );
        await _focusByDpad(tester, start, 'Save selection and start');
        await _activate(tester);
        await _controlPost(origin, 'selection-submitted');
        await _until(
          tester,
          find.text('File selection queued.'),
          'UI selection accepted',
        );
        await _until(
          tester,
          find.byTooltip('Play'),
          'progressive file eligibility',
          timeout: const Duration(seconds: 230),
        );
        final play = find.byTooltip('Play').first;
        await _focusByDpad(tester, play, 'eligible Play action');
        await _activate(tester);
        await _until(tester, find.byType(Scaffold), 'embedded player screen');
        await _until(tester, find.text(mediaName), 'player title');
        await _focusByDpad(
          tester,
          find.text('Pause'),
          'TV native player controls',
        );
        expect(
          adapters,
          hasLength(1),
          reason: 'Player must construct production adapter.',
        );
        final adapter = adapters.single;
        final native = adapter.player.platform as mk.NativePlayer;
        final frameEnd = DateTime.now().add(const Duration(seconds: 65));
        String codec = '';
        String renderer = '';
        while (DateTime.now().isBefore(frameEnd)) {
          await tester.pump(const Duration(milliseconds: 220));
          codec = await native.getProperty('video-codec');
          renderer = await native.getProperty('current-vo');
          if (adapter.state.position > Duration.zero && codec.isNotEmpty) break;
        }
        expect(adapter.state.position, greaterThan(Duration.zero));
        expect(
          codec,
          isNotEmpty,
          reason: 'Native libmpv must report a decoded video codec.',
        );
        expect(
          renderer,
          'gpu',
          reason:
              'Actual Android embedded playback must use the GPU video output.',
        );
        // Codec/position events can precede the video texture's first frame.
        // Flush that frame before the host observes the original surface.
        await adapter.controller!.waitUntilFirstFrameRendered.timeout(
          const Duration(seconds: 10),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        final decodedFrameNumber = await native.getProperty('estimated-frame-number');
        final videoFormat = await native.getProperty('video-params/pixelformat');
        expect(videoFormat, isNotEmpty);
        final beforeBuffer = adapter.state.position;
        await adapter.setSpeed(4);
        await _controlPost(origin, 'first-frame', {
          'positionMs': beforeBuffer.inMilliseconds,
          'videoCodec': codec,
          'renderer': renderer,
          'decodedFrameNumber': decodedFrameNumber,
          'pixelFormat': videoFormat,
        });
        await _controlPost(origin, 'render-request');
        final pixels = await _controlWait(
          origin,
          'render-result',
          timeout: const Duration(seconds: 25),
          tester: tester,
        );
        expect(pixels['captured'], isTrue);
        expect(
          pixels['saturatedPixels'],
          greaterThan(1000),
          reason: 'Emulator screenshot must contain native video color pixels.',
        );
        for (final channel in ['redPixels', 'greenPixels', 'bluePixels']) {
          expect(pixels[channel], greaterThan(100));
        }

        await _controlWait(
          origin,
          'buffer-pause',
          timeout: const Duration(seconds: 45),
        );
        final pauseEnd = DateTime.now().add(const Duration(seconds: 45));
        var stableAt = Duration.zero;
        Duration? previous;
        DateTime? stableSince;
        var pausedForCache = false;
        while (DateTime.now().isBefore(pauseEnd)) {
          await tester.pump(const Duration(milliseconds: 180));
          final cachePause =
              await native.getProperty('paused-for-cache') == 'yes';
          final position = adapter.state.position;
          if (cachePause &&
              previous != null &&
              (position - previous).abs() < const Duration(milliseconds: 100)) {
            stableSince ??= DateTime.now();
            if (DateTime.now().difference(stableSince) >=
                const Duration(seconds: 1)) {
              pausedForCache = true;
              stableAt = position;
              break;
            }
          } else {
            stableSince = null;
          }
          previous = position;
        }
        expect(
          pausedForCache,
          isTrue,
          reason:
              'Native libmpv must buffer at the real missing-byte boundary.',
        );
        await _controlPost(origin, 'buffer-paused', {
          'pausedForCache': true,
          'positionMs': stableAt.inMilliseconds,
        });
        await _controlWait(
          origin,
          'buffer-resume',
          timeout: const Duration(seconds: 35),
        );
        final resumeEnd = DateTime.now().add(const Duration(seconds: 45));
        var resumedAt = Duration.zero;
        var resumed = false;
        while (DateTime.now().isBefore(resumeEnd)) {
          await tester.pump(const Duration(milliseconds: 180));
          if (await native.getProperty('paused-for-cache') != 'yes' &&
              adapter.state.position >
                  stableAt + const Duration(milliseconds: 500)) {
            resumedAt = adapter.state.position;
            resumed = true;
            break;
          }
        }
        expect(
          resumed,
          isTrue,
          reason: 'Same native player stream resumes on newly available bytes.',
        );
        await adapter.setSpeed(1);
        await _controlPost(origin, 'buffer-resumed', {
          'positionMs': resumedAt.inMilliseconds,
        });

        // The track panel and Android system Back are both operated remotely.
        final tracks = find.text('Tracks');
        await _focusByDpad(tester, tracks, 'TV Tracks control');
        await _activate(tester);
        await _until(tester, find.text('Tracks'), 'tracks panel');
        // The panel groups tracks under section headings; the Audio heading
        // appears only once the native player reports audio tracks.
        await _until(
          tester,
          find.descendant(
            of: find.byType(TvFocusPanel),
            matching: find.text('Audio'),
          ),
          'native audio track list',
        );
        expect(
          receivedKeys.contains('Arrow Down') &&
              receivedKeys.contains('Arrow Right') &&
              receivedKeys.contains('Select'),
          isTrue,
          reason: 'The running TV app must receive real HardwareKeyboard directional/Select events.',
        );
        await _controlPost(origin, 'tracks-panel-opened', {
          'hardwareKeys': receivedKeys.toList(),
        });
        await _controlPost(origin, 'back-tracks-before');
        await _controlPost(origin, 'back-tracks-request');
        await _controlWait(origin, 'back-tracks-request');
        await _controlPost(origin, 'back-tracks-acknowledged');
        await _untilGone(
          tester,
          find.byType(TvFocusPanel),
          'tracks panel closed by system Back',
        );
        expect(
          _focused(tester, tracks),
          isTrue,
          reason: 'Closing the tracks panel must restore focus to its opener.',
        );
        await _controlPost(origin, 'back-tracks-returned');
        await _controlPost(origin, 'tracks-back-restored-focus');

        await _controlWait(
          origin,
          'import-ready',
          timeout: const Duration(seconds: 80),
        );
        await _controlPost(origin, 'back-player-before');
        await _controlPost(origin, 'player-back-request');
        await _controlWait(origin, 'player-back-sent');
        await _controlPost(origin, 'back-player-acknowledged');
        await _until(
          tester,
          find.text('Files'),
          'download details after system Back',
        );
        final restoreDeadline = DateTime.now().add(const Duration(seconds: 3));
        while (!_focused(tester, find.byTooltip('Play')) && DateTime.now().isBefore(restoreDeadline)) {
          // The returning route becomes visible before its pop transition
          // restores primary focus. Observe restoration; never request it.
          await tester.pump(const Duration(milliseconds: 120));
        }
        expect(
          _focused(tester, find.byTooltip('Play')),
          isTrue,
          reason: 'Back from the player must restore focus to the eligible file action.',
        );
        await _controlPost(origin, 'back-player-returned');
        await _controlPost(origin, 'player-back-restored-focus');

        // Move from the focused detail action to the TV nav row using D-pad.
        await _focusLibrariesTab(tester);
        await _activate(tester);
        await _until(
          tester,
          find.text('Your libraries'),
          'libraries after completed import',
        );
        await _focusByDpad(
          tester,
          find.text(libraryName),
          'library after completed import',
        );
        await _activate(tester);
        await _until(tester, find.text('Downloads'), 'completed import folder');
        await _focusByDpad(
          tester,
          find.text('Downloads').last,
          'Downloads library folder',
        );
        await _activate(tester);
        // Match folder entries only: the app bar breadcrumb also names the
        // current folder, and it is not a link.
        Finder folderEntry(String name) => find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.textContaining(name),
        );
        await _until(
          tester,
          folderEntry(config['downloadName'] as String),
          'import job folder',
        );
        await _focusByDpad(
          tester,
          folderEntry(config['downloadName'] as String).last,
          'imported torrent directory',
        );
        await _activate(tester);
        await _until(
          tester,
          folderEntry(config['downloadName'] as String),
          'torrent root directory',
        );
        await _focusByDpad(
          tester,
          folderEntry(config['downloadName'] as String).last,
          'nested torrent root directory',
        );
        await _activate(tester);
        await _until(
          tester,
          find.text(mediaName),
          'completed imported media item',
        );
        await _controlPost(origin, 'completed-import-browsed');
        success = true;
      } finally {
        if (backObserver != null) {
          WidgetsBinding.instance.removeObserver(backObserver);
        }
        // Unmount the routed app before disconnecting. This prevents provider
        // refreshes caused by logout from rebuilding visible screens during
        // integration-test teardown and masking the original test failure.
        try {
          await tester.pumpWidget(const SizedBox.shrink());
        } catch (_) {
          // Preserve the test body failure; runner-owned cleanup still proceeds.
        }
        try {
          final session = container.read(clientSessionProvider);
          if (session != null) {
            await container
                .read(clientSessionProvider.notifier)
                .disconnect(logout: true)
                .timeout(const Duration(seconds: 8));
          }
        } catch (_) {
          // The runner still removes the protected handoff and all network data.
        }
        try {
          final profiles = container
              .read(serverProfileRepositoryProvider)
              .load();
          for (final profile in profiles.where(
            (item) => item.label == 'M08 TV ${config['runShort']}',
          )) {
            await container
                .read(serverProfileRepositoryProvider)
                .remove(profile.id);
          }
        } catch (_) {
          // The runner still removes the protected handoff and all network data.
        }
        try {
          HardwareKeyboard.instance.removeHandler(recordKey);
          container.dispose();
        } catch (_) {
          // Do not replace the integration failure with teardown noise.
        }
        try {
          await File(_configPath).delete();
        } catch (_) {}
      }
      expect(success, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

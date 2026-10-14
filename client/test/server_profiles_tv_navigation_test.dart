import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:briani_player/core/server_profiles/credential_vault.dart';
import 'package:briani_player/core/server_profiles/providers.dart';
import 'package:briani_player/core/server_profiles/server_profile.dart';
import 'package:briani_player/features/server_profiles/server_profiles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TV D-pad travels from Add server to the Connect action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final vault = _MemoryVault();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        credentialVaultProvider.overrideWithValue(vault),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(serverProfileRepositoryProvider)
        .save(
          ServerProfile(
            id: 'tv-nav-fixture',
            label: 'TV navigation fixture',
            origin: Uri(scheme: 'https', host: 'server.example'),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1920, 1080),
              navigationMode: NavigationMode.directional,
            ),
            child: const RemoteNavigationScope(
              television: true,
              child: ServerProfilesScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final add = find.widgetWithText(FilledButton, 'Add server');
    final connect = find.widgetWithText(TextButton, 'Connect').first;
    expect(find.text('TV navigation fixture'), findsOneWidget);
    expect(
      _primaryWithin(tester, add),
      isTrue,
      reason: 'The TV header Add server action should receive initial focus.',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 120));
    for (var left = 0; left < 2 && !_primaryWithin(tester, connect); left++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(
      _primaryWithin(tester, connect),
      isTrue,
      reason:
          'From Add server, Down then bounded Left must focus Connect; '
          'focus=${_focusDiagnostic(tester, connect)}; '
          'add=${_focusDiagnostic(tester, add)}',
    );
    expect(
      _primaryWithin(tester, find.text('Connect')),
      isTrue,
      reason: 'The Connect label belongs to the primary-focused action.',
    );
  });
}

bool _primaryWithin(WidgetTester tester, Finder finder) {
  final targets = finder.evaluate().map(_actionRoot).toSet();
  final primary = FocusManager.instance.primaryFocus?.context;
  if (primary == null) return false;
  if (targets.contains(primary)) return true;
  var found = false;
  primary.visitAncestorElements((ancestor) {
    if (targets.contains(ancestor)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

Element _actionRoot(Element element) {
  if (_isAction(element.widget)) return element;
  Element? root;
  element.visitAncestorElements((ancestor) {
    if (_isAction(ancestor.widget)) {
      root = ancestor;
      return false;
    }
    return true;
  });
  return root ?? element;
}

bool _isAction(Widget widget) =>
    widget is ButtonStyleButton ||
    widget is IconButton ||
    widget is FloatingActionButton ||
    widget is InkWell ||
    widget is ListTile ||
    widget is CheckboxListTile;

String _focusDiagnostic(WidgetTester tester, Finder finder) {
  String describe(Element element) {
    final values = <String>[element.widget.runtimeType.toString()];
    element.visitAncestorElements((ancestor) {
      if (values.length == 8) return false;
      values.add(ancestor.widget.runtimeType.toString());
      return true;
    });
    final box = element.renderObject is RenderBox
        ? element.renderObject! as RenderBox
        : null;
    final rect = box == null
        ? 'unavailable'
        : '${box.localToGlobal(Offset.zero)} ${box.size}';
    return '$values@$rect';
  }

  final primary = FocusManager.instance.primaryFocus;
  final context = primary?.context;
  final primaryDescription = context is Element
      ? describe(context)
      : 'unavailable';
  return 'primary=${primary?.runtimeType}, '
      'primaryContext=$primaryDescription, '
      'targets=${finder.evaluate().map(_actionRoot).take(4).map(describe).toList()}';
}

class _MemoryVault implements CredentialVault {
  @override
  Future<void> delete(String profileId) async {}

  @override
  Future<String?> read(String profileId) async => null;

  @override
  Future<void> write(String profileId, String token) async {}
}

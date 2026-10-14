import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:briani_player/core/input/tv_auto_hide_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const timeout = Duration(seconds: 4);

  testWidgets('playing overlay hides after inactivity without disposing controls',
      (tester) async {
    final probeKey = GlobalKey<_ProbeState>();
    await tester.pumpWidget(_app(
      playing: true,
      timeout: timeout,
      child: _Probe(key: probeKey),
    ));
    await tester.pump(timeout - const Duration(milliseconds: 1));
    expect(_overlay(tester).offstage, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    expect(_overlay(tester).offstage, isTrue);
    expect(probeKey.currentState, isNotNull);
    expect(find.text('probe', skipOffstage: false), findsOneWidget);
  });

  testWidgets('paused overlay remains visible beyond its timeout', (tester) async {
    await tester.pumpWidget(_app(
      playing: false,
      timeout: timeout,
      child: const Text('paused controls'),
    ));
    await tester.pump(timeout * 3);
    expect(_overlay(tester).offstage, isFalse);
  });

  testWidgets('first hidden directional key wakes and traverses immediately',
      (tester) async {
    final first = FocusNode(debugLabel: 'first');
    final second = FocusNode(debugLabel: 'second');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(_app(
      playing: true,
      timeout: timeout,
      child: Column(
        children: [
          TextButton(focusNode: first, onPressed: () {}, child: const Text('one')),
          TextButton(focusNode: second, onPressed: () {}, child: const Text('two')),
        ],
      ),
    ));
    first.requestFocus();
    await tester.pump();
    await tester.pump(timeout);
    expect(_overlay(tester).offstage, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_overlay(tester).offstage, isFalse);
    expect(FocusManager.instance.primaryFocus, same(second));
  });

  testWidgets('first hidden Select wakes and activates focused control',
      (tester) async {
    var activated = 0;
    final focus = FocusNode(debugLabel: 'select target');
    addTearDown(focus.dispose);
    await tester.pumpWidget(_app(
      playing: true,
      timeout: timeout,
      child: TextButton(
        focusNode: focus,
        onPressed: () => activated++,
        child: const Text('activate'),
      ),
    ));
    focus.requestFocus();
    await tester.pump();
    await tester.pump(timeout);
    expect(_overlay(tester).offstage, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(_overlay(tester).offstage, isFalse);
    expect(activated, 1);
  });

  testWidgets('Back is left to Flutter and does not wake hidden controls',
      (tester) async {
    await tester.pumpWidget(_app(
      playing: true,
      timeout: timeout,
      child: const Text('controls'),
    ));
    await tester.pump(timeout);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_overlay(tester).offstage, isTrue);
  });

  testWidgets('modal route retains keyboard ownership while overlay is hidden',
      (tester) async {
    await tester.pumpWidget(_app(
      playing: true,
      timeout: timeout,
      child: const Text('controls'),
      launcher: (context) => showDialog<void>(
        context: context,
        builder: (context) => const AlertDialog(title: Text('modal')),
      ),
    ));
    await tester.pump(timeout);
    await tester.tap(find.text('open modal'));
    await tester.pumpAndSettle();
    expect(find.text('modal'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('modal'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_overlay(tester).offstage, isTrue);
  });

  testWidgets('dispose cancels timer and removes keyboard handler',
      (tester) async {
    await tester.pumpWidget(_app(
      playing: true,
      timeout: timeout,
      child: const Text('controls'),
    ));
    await tester.pumpWidget(const MaterialApp(home: Text('replacement')));
    await tester.pump(timeout * 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text('replacement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Offstage _overlay(WidgetTester tester) => tester.widget<Offstage>(
      find.byKey(const ValueKey<String>('tv-auto-hide-controls')),
    );

Widget _app({
  required bool playing,
  required Duration timeout,
  required Widget child,
  Future<void> Function(BuildContext context)? launcher,
}) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: RemoteNavigationScope(
                television: true,
                child: TvAutoHideControls(
                  playing: playing,
                  timeout: timeout,
                  child: child,
                ),
              ),
            ),
            if (launcher != null)
              Builder(
                builder: (context) => TextButton(
                  onPressed: () => launcher(context),
                  child: const Text('open modal'),
                ),
              ),
          ],
        ),
      ),
    );

class _Probe extends StatefulWidget {
  const _Probe({super.key});

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const Text('probe');
}

import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('D-pad focus follows stable row identity across progress updates',
      (tester) async {
    final nodes = {for (final id in ['a', 'b', 'c']) id: FocusNode(debugLabel: id)};
    final changed = ValueNotifier(false);

    Widget buildRows() => MaterialApp(
          home: RemoteNavigationScope(
            television: true,
            child: ValueListenableBuilder<bool>(
              valueListenable: changed,
              builder: (context, isChanged, _) => Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: TvFocusList<String>(
                        items: const ['a', 'b', 'c'],
                        itemKey: (id) => id,
                        itemBuilder: (context, id, index) => TextButton(
                          focusNode: nodes[id],
                          autofocus: id == 'a',
                          onPressed: () {},
                          child: Text('$id ${isChanged ? 'updated' : 'initial'}'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildRows());
    expect(nodes['a']!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(nodes['b']!.hasFocus, isTrue);

    changed.value = true;
    await tester.pump();
    expect(find.text('b updated'), findsOneWidget);
    expect(nodes['b']!.hasFocus, isTrue);
    changed.dispose();
    for (final node in nodes.values) {
      node.dispose();
    }
  });

  testWidgets('D-pad Select, gamepad A, and Enter activate focused buttons',
      (tester) async {
    var activations = 0;
    await tester.pumpWidget(MaterialApp(
      home: RemoteNavigationScope(
        television: true,
        child: Scaffold(
          body: TextButton(
            autofocus: true,
            onPressed: () => activations++,
            child: const Text('Choose'),
          ),
        ),
      ),
    ));

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(activations, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    expect(activations, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activations, 3);
  });

  testWidgets('media Pause does not toggle into Play and Play is explicit',
      (tester) async {
    var toggles = 0;
    var plays = 0;
    var pauses = 0;
    await tester.pumpWidget(MaterialApp(
      home: RemoteNavigationScope(
        television: true,
        onMediaPlayPause: () => toggles++,
        onMediaPlay: () => plays++,
        onMediaPause: () => pauses++,
        child: Scaffold(
          body: TextButton(
            autofocus: true,
            onPressed: () {},
            child: const Text('Player'),
          ),
        ),
      ),
    ));

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPause);
    await tester.pump();
    expect(pauses, 1);
    expect(plays, 0);
    expect(toggles, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlay);
    await tester.pump();
    expect(plays, 1);
    expect(pauses, 1);
    expect(toggles, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();
    expect(toggles, 1);
  });

  testWidgets('system Back key is not intercepted as activation or playback',
      (tester) async {
    var activations = 0;
    var mediaCommands = 0;
    await tester.pumpWidget(MaterialApp(
      home: RemoteNavigationScope(
        television: true,
        onMediaPlayPause: () => mediaCommands++,
        onMediaPlay: () => mediaCommands++,
        onMediaPause: () => mediaCommands++,
        child: Scaffold(
          body: TextButton(
            autofocus: true,
            onPressed: () => activations++,
            child: const Text('Choose'),
          ),
        ),
      ),
    ));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(activations, 0);
    expect(mediaCommands, 0);
    expect(find.text('Choose'), findsOneWidget);
  });

  testWidgets('panel dismisses through Back and restores opener focus',
      (tester) async {
    final opener = FocusNode(debugLabel: 'panel opener');
    await tester.pumpWidget(MaterialApp(
      home: RemoteNavigationScope(
        television: true,
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              focusNode: opener,
              autofocus: true,
              onPressed: () => TvFocusPanel.show<void>(
                context: context,
                title: 'Tracks',
                builder: (context) => const Text('Audio track'),
              ),
              child: const Text('Open tracks'),
            ),
          ),
        ),
      ),
    ));
    expect(opener.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Audio track'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Audio track'), findsNothing);
    expect(opener.hasFocus, isTrue);
  });
}

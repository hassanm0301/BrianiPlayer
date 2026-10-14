import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:briani_player/core/input/remote_navigation.dart';

void main() {
  testWidgets('TV vertical arrows leave single-line fields and reach controls', (tester) async {
    final name = FocusNode(debugLabel: 'Name'); final address = FocusNode(debugLabel: 'Address'); final save = FocusNode(debugLabel: 'Save');
    final text = TextEditingController(text: 'fixture');
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(navigationMode: NavigationMode.directional), child: child!), home: RemoteNavigationScope(television: true,
      child: Scaffold(body: Column(children: [
        TextField(focusNode: name, controller: text),
        TextField(focusNode: address),
        FilledButton(focusNode: save, onPressed: () {}, child: const Text('Save')),
      ])))));
    name.requestFocus(); await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); await tester.pump();
    expect(address.hasFocus, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); await tester.pump();
    expect(save.hasFocus, true);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); await tester.pump();
    expect(address.hasFocus, true, reason: FocusManager.instance.primaryFocus.toString());
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); await tester.pump();
    expect(name.hasFocus, true);
    expect(text.text, 'fixture');
    await tester.pumpWidget(const SizedBox.shrink());
    name.dispose(); address.dispose(); save.dispose(); text.dispose();
  });
}

import 'package:briani_player/core/input/remote_navigation.dart';
import 'package:briani_player/core/input/shell_navigation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('TV content route can traverse Up to the primary navigation', (tester) async {
    final tileFocus = FocusNode();
    addTearDown(tileFocus.dispose);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(navigationMode: NavigationMode.directional),
        child: RemoteNavigationScope(television: true, child: child!)),
      home: TvNavigationScaffold(index: 0, onSelected: (_) {},
        child: Navigator(onDidRemovePage: (_) {}, pages: [TvShellPage(
          child: Scaffold(appBar: AppBar(title: const Text('Your libraries')),
            body: ListTile(focusNode: tileFocus, title: const Text('Fixture library'), onTap: () {})),
        )])),
    ));
    await tester.pumpAndSettle();
    tileFocus.requestFocus();
    await tester.pump();
    expect(tileFocus.hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(tileFocus.hasPrimaryFocus, isFalse);
    final targets = find.byType(FilledButton).evaluate().toSet();
    var withinNavigation = false;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
      if (targets.contains(element)) { withinNavigation = true; return false; }
      return true;
    });
    expect(withinNavigation, isTrue);
  });
}

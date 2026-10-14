import 'package:flutter/material.dart';

/// The primary TV navigation lives outside its nested route Navigator. Allow
/// D-pad traversal to leave the content route at its edge and reach that bar.
/// Modal dialogs retain their own closed traversal scope.
class TvShellPage extends MaterialPage<void> {
  const TvShellPage({required super.child, super.key});

  @override
  Route<void> createRoute(BuildContext context) => MaterialPageRoute<void>(
    settings: this,
    builder: (_) => child,
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
    directionalTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
}

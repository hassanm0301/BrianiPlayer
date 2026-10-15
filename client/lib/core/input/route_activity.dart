import 'package:flutter/material.dart';

/// Carries the root route's visibility into the shell's nested navigators.
class RouteActivity extends InheritedWidget {
  const RouteActivity({super.key, required this.visible, required super.child});
  final bool visible;

  static bool isVisible(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<RouteActivity>()?.visible ??
          true) &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  @override
  bool updateShouldNotify(RouteActivity oldWidget) =>
      visible != oldWidget.visible;
}

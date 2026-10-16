import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Material 3 window size classes, measured on the available width.
enum WindowSize {
  compact,
  medium,
  expanded,
  large;

  static WindowSize ofWidth(double width) => width < 600
      ? compact
      : width < 840
      ? medium
      : width < 1200
      ? expanded
      : large;

  static WindowSize of(BuildContext context) =>
      ofWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;
  bool get atLeastMedium => index >= medium.index;
  bool get atLeastExpanded => index >= expanded.index;
}

/// True on desktop platforms, where a mouse pointer (hover, right-click,
/// double-click) is the expected input.
bool get pointerPlatform => switch (defaultTargetPlatform) {
  TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => true,
  _ => false,
};

/// Whether the app counts as in the foreground for playback and live refresh.
///
/// A desktop window reports `inactive` whenever it merely loses focus while
/// still on screen, so only phones and TVs treat `inactive` as background
/// (a call, the notification shade, a system dialog).
bool isForegroundLifecycle(AppLifecycleState? state) => switch (state) {
  null || AppLifecycleState.resumed => true,
  AppLifecycleState.inactive => pointerPlatform,
  _ => false,
};

/// True when the app is driven by a D-pad (Android TV or the TV override).
bool isTelevision(BuildContext context) =>
    MediaQuery.maybeNavigationModeOf(context) == NavigationMode.directional;

/// Standard page gutters: wider on large windows and on TV overscan-safe
/// layouts, tighter on phones.
EdgeInsets pageGutters(BuildContext context) {
  if (isTelevision(context)) return const EdgeInsets.symmetric(horizontal: 32);
  return switch (WindowSize.of(context)) {
    WindowSize.compact => const EdgeInsets.symmetric(horizontal: 16),
    WindowSize.medium => const EdgeInsets.symmetric(horizontal: 20),
    _ => const EdgeInsets.symmetric(horizontal: 28),
  };
}

/// Describes how the navigation shell is laid out, so pages can adapt their
/// own chrome (for example, compact pages show the account button in their
/// app bar because there is no navigation rail to hold it).
class ShellLayout extends InheritedWidget {
  const ShellLayout({
    super.key,
    required this.accountInPageHeader,
    required this.accountButton,
    required super.child,
  });

  final bool accountInPageHeader;
  final Widget accountButton;

  static ShellLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellLayout>();

  /// The account button to place in a top-level page's app bar, or null when
  /// the shell already shows it.
  static Widget? headerAccountButton(BuildContext context) {
    final layout = maybeOf(context);
    return layout != null && layout.accountInPageHeader
        ? layout.accountButton
        : null;
  }

  @override
  bool updateShouldNotify(ShellLayout oldWidget) =>
      accountInPageHeader != oldWidget.accountInPageHeader ||
      !Widget.canUpdate(accountButton, oldWidget.accountButton);
}

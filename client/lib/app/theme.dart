import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:flutter/material.dart';

/// Seed colors for the user's synced accent preset. Material 3 derives the
/// complete tonal palette from the hue, so these only need distinct hues.
Color accentSeed(UserPreferencesAccentPresetEnum? preset) => switch (preset) {
  UserPreferencesAccentPresetEnum.teal => const Color(0xff008577),
  UserPreferencesAccentPresetEnum.green => const Color(0xff348348),
  UserPreferencesAccentPresetEnum.orange => const Color(0xffb35a00),
  UserPreferencesAccentPresetEnum.purple => const Color(0xff7954b3),
  UserPreferencesAccentPresetEnum.red => const Color(0xffb33232),
  _ => const Color(0xff476f9c),
};

/// Semantic colors that Material's scheme does not name. They are tuned for
/// contrast against the scheme's surfaces in each brightness.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.onSuccessContainer,
    required this.successContainer,
    required this.warning,
    required this.onWarningContainer,
    required this.warningContainer,
  });

  factory StatusColors.of(BuildContext context) =>
      Theme.of(context).extension<StatusColors>() ??
      StatusColors._fallback(Theme.of(context).brightness);

  factory StatusColors._fallback(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static const _light = StatusColors(
    success: Color(0xff2e7d32),
    onSuccessContainer: Color(0xff0f3d13),
    successContainer: Color(0xffc8ecc4),
    warning: Color(0xff8a5a00),
    onWarningContainer: Color(0xff3d2700),
    warningContainer: Color(0xffffe7bf),
  );
  static const _dark = StatusColors(
    success: Color(0xff8fd68a),
    onSuccessContainer: Color(0xffc8ecc4),
    successContainer: Color(0xff1e4d20),
    warning: Color(0xfff5bf5c),
    onWarningContainer: Color(0xffffe1a8),
    warningContainer: Color(0xff47391c),
  );

  final Color success, onSuccessContainer, successContainer;
  final Color warning, onWarningContainer, warningContainer;

  @override
  StatusColors copyWith() => this;

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
    );
  }
}

/// Builds the application theme. Surfaces are tonal rather than shadowed:
/// navigation chrome sits on [ColorScheme.surfaceContainer] and content on a
/// rounded panel of [contentSurface].
ThemeData buildAppTheme({
  required Color seed,
  required Brightness brightness,
  VisualDensity density = VisualDensity.standard,
  bool television = false,
}) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final base = ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    visualDensity: density,
    useMaterial3: true,
  );
  final text = base.textTheme;
  TextStyle? weight(TextStyle? style, FontWeight value) =>
      style?.copyWith(fontWeight: value);
  final textTheme = text.copyWith(
    displaySmall: weight(text.displaySmall, FontWeight.w600),
    headlineLarge: weight(text.headlineLarge, FontWeight.w600),
    headlineMedium: weight(text.headlineMedium, FontWeight.w600),
    headlineSmall: weight(text.headlineSmall, FontWeight.w600),
    titleLarge: weight(text.titleLarge, FontWeight.w600),
    titleMedium: weight(text.titleMedium, FontWeight.w600),
    titleSmall: weight(text.titleSmall, FontWeight.w600),
    labelLarge: weight(text.labelLarge, FontWeight.w600),
  );
  final panel = contentSurfaceOf(scheme);
  final focusRing = scheme.primary;
  const radius12 = BorderRadius.all(Radius.circular(12));
  const radius16 = BorderRadius.all(Radius.circular(16));
  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: panel,
    canvasColor: panel,
    focusColor: television
        ? scheme.primary.withValues(alpha: .22)
        : scheme.onSurface.withValues(alpha: .1),
    extensions: [
      brightness == Brightness.dark ? StatusColors._dark : StatusColors._light,
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      toolbarHeight: television ? 64 : 64,
      // Component themes are built before Theme.of() applies the typography
      // geometry, so sizes here must be explicit.
      titleTextStyle: (text.titleLarge ?? const TextStyle()).copyWith(
        fontSize: television ? 24 : 22,
        height: 1.27,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: radius16),
    ),
    listTileTheme: ListTileThemeData(
      shape: const RoundedRectangleBorder(borderRadius: radius12),
      iconColor: scheme.onSurfaceVariant,
      contentPadding: EdgeInsets.symmetric(horizontal: television ? 20 : 16),
      selectedTileColor: scheme.secondaryContainer,
      selectedColor: scheme.onSecondaryContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: .6),
      border: const OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide(color: focusRing, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius12,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: focusRing, width: 2)
            : BorderSide.none,
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      constraints: const BoxConstraints(minHeight: 48, maxWidth: 720),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      minWidth: 88,
      groupAlignment: -1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium?.copyWith(
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: radius12),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: radius12),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 400),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    // ignore: deprecated_member_use
    progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
    // ignore: deprecated_member_use
    sliderTheme: const SliderThemeData(year2023: false),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: density,
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _focusRingStyle(television, focusRing),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _focusRingStyle(television, focusRing),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _focusRingStyle(television, focusRing),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: _focusRingStyle(television, focusRing),
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
      thumbColor: WidgetStatePropertyAll(
        scheme.onSurfaceVariant.withValues(alpha: .35),
      ),
    ),
  );
}

/// On TV the focused control carries a visible ring, so focus is not shown
/// by color alone. Desktop keeps Material's lighter keyboard-focus overlay
/// plus a thin ring for clarity.
ButtonStyle? _focusRingStyle(bool television, Color ring) => ButtonStyle(
  side: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.focused)
        ? BorderSide(color: ring, width: television ? 3 : 2)
        : null,
  ),
);

/// The color of the main content panel. Light mode uses the brightest
/// surface on tinted chrome; dark mode keeps content on the base surface.
Color contentSurfaceOf(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
    ? scheme.surface
    : scheme.surfaceContainerLowest;

/// The color behind navigation and around the content panel.
Color chromeSurfaceOf(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark
    ? scheme.surfaceContainerLowest
    : scheme.surfaceContainer;

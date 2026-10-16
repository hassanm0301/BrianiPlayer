import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A centered, quiet placeholder for empty, unavailable and error states.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  /// Error presentation with a single Retry action.
  factory EmptyState.error({
    Key? key,
    required String message,
    VoidCallback? onRetry,
    String title = 'Something went wrong',
    String retryLabel = 'Retry',
  }) => EmptyState(
    key: key,
    icon: Icons.cloud_off_outlined,
    title: title,
    message: message,
    action: onRetry == null
        ? null
        : FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryLabel),
          ),
  );

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 56 : 72,
                height: compact ? 56 : 72,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: compact ? 28 : 34,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: compact ? 12 : 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.titleLarge,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

enum NoticeTone { info, warning, error }

/// An inline, rounded notice for partial or degraded states that should not
/// replace the page content (warnings, truncated results, stale data).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.tone = NoticeTone.info,
    this.action,
    this.icon,
    this.margin = EdgeInsets.zero,
  });

  final String message;
  final NoticeTone tone;
  final Widget? action;
  final IconData? icon;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final (background, foreground, defaultIcon) = switch (tone) {
      NoticeTone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.info_outline,
      ),
      NoticeTone.warning => (
        status.warningContainer,
        status.onWarningContainer,
        Icons.warning_amber_rounded,
      ),
      NoticeTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
    };
    return Padding(
      padding: margin,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final iconWidget = Icon(icon ?? defaultIcon, color: foreground, size: 20);
              final text = Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: foreground),
              );
              final actionWidget = action == null
                  ? null
                  : TextButtonTheme(
                      data: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: foreground,
                        ),
                      ),
                      child: action!,
                    );
              // On narrow cards or with large text the action moves below
              // the message instead of squeezing it.
              final stacked =
                  actionWidget != null &&
                  (constraints.maxWidth < 420 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.4);
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          iconWidget,
                          const SizedBox(width: 12),
                          Expanded(child: text),
                        ],
                      ),
                    ),
                    Align(alignment: Alignment.centerRight, child: actionWidget),
                  ],
                );
              }
              return Row(
                children: [
                  iconWidget,
                  const SizedBox(width: 12),
                  Expanded(child: text),
                  ?actionWidget,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A heading for a group of content on a page, with an optional trailing
/// action such as "See all" or a small menu.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final heading = Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
    return Padding(
      padding: padding,
      child: trailing == null
          ? Align(alignment: AlignmentDirectional.centerStart, child: heading)
          : LayoutBuilder(
              builder: (context, constraints) {
                // Very narrow layouts or large text put the action below.
                if (constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.6) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [heading, const SizedBox(height: 4), trailing!],
                  );
                }
                return Row(
                  children: [Expanded(child: heading), trailing!],
                );
              },
            ),
    );
  }
}

/// Small rounded label used for states and metadata (for example
/// "Downloading" or "Stale").
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = PillTone.neutral,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final PillTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = StatusColors.of(context);
    final (background, foreground) = switch (tone) {
      PillTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      PillTone.active => (scheme.primaryContainer, scheme.onPrimaryContainer),
      PillTone.success => (status.successContainer, status.onSuccessContainer),
      PillTone.warning => (status.warningContainer, status.onWarningContainer),
      PillTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: foreground, fontWeight: FontWeight.w600);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 2 : 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum PillTone { neutral, active, success, warning, error }

/// Draws a visible outline around [child] whenever focus is inside it. Used
/// for tiles so D-pad and keyboard focus is shown by shape, not color alone.
class FocusOutline extends StatefulWidget {
  const FocusOutline({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<FocusOutline> createState() => _FocusOutlineState();
}

class _FocusOutlineState extends State<FocusOutline> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keyboard =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final visible = _focused && keyboard;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused != _focused) setState(() => _focused = focused);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        foregroundDecoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: visible ? scheme.primary : Colors.transparent,
            width: isTelevisionMode(context) ? 3 : 2,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: widget.child,
      ),
    );
  }

  static bool isTelevisionMode(BuildContext context) =>
      MediaQuery.maybeNavigationModeOf(context) == NavigationMode.directional;
}

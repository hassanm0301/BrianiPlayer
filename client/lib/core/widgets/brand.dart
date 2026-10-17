import 'package:flutter/material.dart';

/// The Briani app mark: the pot logo without the wordmark, centered in a
/// [size] square. Decorative; callers label it where it carries meaning.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}

/// The full logo (mark over the product name) and a one-line purpose for
/// signed-out screens.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Image.asset(
          'assets/brand/logo.png',
          height: 148,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Briani Player',
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The signed-out page frame: tinted background, an optional back action and
/// a centered card that holds a short form (sign in, device link).
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.child,
    this.onBack,
    this.backTooltip = 'Back to servers',
    this.maxWidth = 460,
  });

  final Widget child;
  final VoidCallback? onBack;
  final String backTooltip;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainer,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: backTooltip,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Card(
                color: dark ? scheme.surface : scheme.surfaceContainerLowest,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact "Server name · address" line used on sign-in and link screens.
class ServerBadge extends StatelessWidget {
  const ServerBadge({super.key, required this.label, required this.origin});
  final String label;
  final String origin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          child: const Icon(Icons.dns_outlined, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                origin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

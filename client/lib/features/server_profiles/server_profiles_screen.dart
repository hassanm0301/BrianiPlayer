import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

import '../../core/server_profiles/providers.dart';
import '../../core/server_profiles/server_profile.dart';
import '../../core/server_profiles/server_connection_service.dart';
import '../../app/theme.dart';
import '../../core/widgets/adaptive.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/states.dart';

class ServerProfilesScreen extends ConsumerWidget {
  const ServerProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(serverProfilesProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tv =
        MediaQuery.of(context).navigationMode == NavigationMode.directional;
    final compact = WindowSize.of(context).isCompact;
    final list = profiles.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => EmptyState.error(
        title: 'Saved servers are unavailable',
        message: 'Could not load saved servers.',
        onRetry: () => ref.invalidate(serverProfilesProvider),
      ),
      data: (items) => items.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: EmptyState(
                compact: true,
                icon: Icons.dns_outlined,
                title: 'No servers yet',
                message: 'No servers saved yet. Add a server address to get started.',
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const Divider(indent: 72, endIndent: 16),
                  _ServerProfileTile(
                    profile: items[index],
                    autofocus: tv && index == 0,
                  ),
                ],
              ],
            ),
    );
    return Scaffold(
      backgroundColor: chromeSurfaceOf(scheme),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 32,
              vertical: tv ? 32 : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: tv ? 860 : 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandHeader(subtitle: 'Connect to your media server'),
                  SizedBox(height: tv ? 28 : 32),
                  Card(
                    color: contentSurfaceOf(scheme),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Semantics(
                                    header: true,
                                    child: Text(
                                      'Servers',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                  ),
                                ),
                                FilledButton.icon(
                                  autofocus:
                                      tv &&
                                      (profiles.asData?.value.isEmpty ?? true),
                                  onPressed: () => _addServer(context, ref),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add server'),
                                ),
                              ],
                            ),
                          ),
                          list,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saved addresses stay on this device. Sign-in credentials are kept in secure system storage when available.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addServer(BuildContext context, WidgetRef ref) async {
    final profile = await showDialog<ServerProfile>(
      context: context,
      builder: (_) => const _AddServerDialog(),
    );
    if (profile == null || !context.mounted) return;
    await ref.read(serverProfileRepositoryProvider).save(profile);
    if (context.mounted) ref.invalidate(serverProfilesProvider);
  }
}

class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog();
  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  final label = TextEditingController();
  final origin = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool allowInsecureHttp = false;
  @override
  void dispose() {
    label.dispose();
    origin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext dialogContext) => AlertDialog(
    icon: const Icon(Icons.dns_outlined),
    title: const Text('Add server'),
    content: Form(
      key: formKey,
      child: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: label,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Home server',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: origin,
                decoration: const InputDecoration(
                  labelText: 'Server address',
                  hintText: 'https://server.example',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: (value) {
                  try {
                    ServerProfile.parseOrigin(
                      value ?? '',
                      allowInsecureHttp: allowInsecureHttp,
                    );
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: allowInsecureHttp,
                onChanged: (value) =>
                    setState(() => allowInsecureHttp = value ?? false),
                title: const Text(
                  'Allow unencrypted HTTP for a trusted LAN/VPN server',
                ),
                subtitle: const Text(
                  'Only enable this when the address is reachable through a network you trust. Login credentials travel without encryption.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialogContext),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          final parsedOrigin = ServerProfile.parseOrigin(
            origin.text,
            allowInsecureHttp: allowInsecureHttp,
          );
          Navigator.pop(
            dialogContext,
            ServerProfile(
              id: const Uuid().v4(),
              label: label.text.trim(),
              origin: parsedOrigin,
              allowInsecureHttp:
                  allowInsecureHttp && parsedOrigin.scheme == 'http',
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _ServerProfileTile extends ConsumerStatefulWidget {
  const _ServerProfileTile({required this.profile, this.autofocus = false});

  final ServerProfile profile;
  final bool autofocus;

  @override
  ConsumerState<_ServerProfileTile> createState() => _ServerProfileTileState();
}

class _ServerProfileTileState extends ConsumerState<_ServerProfileTile> {
  bool _checking = false;

  Future<void> _checkConnection() async {
    setState(() => _checking = true);
    try {
      final api = await ref.read(serverApiProvider(widget.profile).future);
      final server = await ServerConnectionService(api.getServerApi()).check();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to server (API v${server.apiMajor}).'),
        ),
      );
    } on ServerConnectionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not connect. Check the address and server status.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text('Remove ${widget.profile.label}?'),
        content: const Text(
          'The saved address and any sign-in kept for it on this device are removed. The server itself is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(serverProfileRepositoryProvider).remove(widget.profile.id);
    ref.invalidate(serverProfilesProvider);
  }

  void _connect() =>
      context.go('/signin/${Uri.encodeComponent(widget.profile.id)}');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = widget.profile;
    final blocked =
        profile.origin.scheme == 'http' && !profile.allowInsecureHttp;
    final trustedHttp =
        profile.origin.scheme == 'http' && profile.allowInsecureHttp;
    // A row of explicit actions (rather than a tappable ListTile) keeps D-pad
    // focus on real controls; a disabled tap surface can capture focus on TV.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            child: const Icon(Icons.dns_outlined),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.origin.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (blocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Blocked: this remote HTTP address has no trusted-network opt-in.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  )
                else if (trustedHttp)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: StatusPill(
                      dense: true,
                      tone: PillTone.warning,
                      icon: Icons.lock_open,
                      label: 'Unencrypted HTTP',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (WindowSize.of(context).isCompact)
            TextButton(
              autofocus: widget.autofocus,
              onPressed: _connect,
              child: const Text('Connect'),
            )
          else
            TextButton.icon(
              autofocus: widget.autofocus,
              onPressed: _connect,
              icon: const Icon(Icons.login),
              label: const Text('Connect'),
            ),
          PopupMenuButton<String>(
            tooltip: 'Server options',
            onSelected: (action) {
              if (action == 'check') {
                _checkConnection();
              } else if (action == 'remove') {
                _remove();
              }
            },
            icon: _checking
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.more_vert),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'check',
                enabled: !_checking,
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.network_check),
                  title: Text('Check connection'),
                ),
              ),
              PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: Text(
                    'Remove server',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

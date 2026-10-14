import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

import '../../core/server_profiles/providers.dart';
import '../../core/server_profiles/server_profile.dart';
import '../../core/server_profiles/server_connection_service.dart';

class ServerProfilesScreen extends ConsumerWidget {
  const ServerProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(serverProfilesProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final tv =
            MediaQuery.of(context).navigationMode == NavigationMode.directional;
        return Scaffold(
          body: Row(
            children: [
              if (wide && !tv)
                NavigationRail(
                  selectedIndex: 0,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dns_outlined),
                      label: Text('Servers'),
                    ),
                  ],
                ),
              Expanded(
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Padding(
                        padding: EdgeInsets.all(tv ? 36 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text('Servers', style: Theme.of(context).textTheme.headlineMedium)),
                              if (tv) FilledButton.icon(
                                autofocus: profiles.asData?.value.isEmpty ?? true,
                                onPressed: () => _addServer(context, ref),
                                icon: const Icon(Icons.add), label: const Text('Add server')),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                              'Connect to a Briani server or manage saved addresses.',
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: profiles.when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (error, stack) => Center(
                                  child: Text(
                                    'Could not load saved servers: $error',
                                  ),
                                ),
                                data: (items) => items.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No servers saved yet. Add a server address to get started.',
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: items.length,
                                        separatorBuilder: (_, index) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final profile = items[index];
                                          return _ServerProfileTile(
                                            profile: profile, autofocus: tv && index == 0,
                                          );
                                        },
                                      ),
                              ),
                            ),
                            if (!wide && !tv)
                              NavigationBar(
                                selectedIndex: 0,
                                destinations: [
                                  NavigationDestination(
                                    icon: Icon(Icons.dns_outlined),
                                    label: 'Servers',
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: tv ? null : FloatingActionButton.extended(
            onPressed: () => _addServer(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add server'),
          ),
        );
      },
    );
  }

  Future<void> _addServer(BuildContext context, WidgetRef ref) async {
    final profile = await showDialog<ServerProfile>(
      context: context, builder: (_) => const _AddServerDialog());
    if (profile == null || !context.mounted) return;
    await ref.read(serverProfileRepositoryProvider).save(profile);
    if (context.mounted) ref.invalidate(serverProfilesProvider);
  }
}

class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog();
  @override State<_AddServerDialog> createState() => _AddServerDialogState();
}
class _AddServerDialogState extends State<_AddServerDialog> {
  final label = TextEditingController();
  final origin = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool allowInsecureHttp = false;
  @override void dispose() { label.dispose(); origin.dispose(); super.dispose(); }
  @override Widget build(BuildContext dialogContext) => AlertDialog(
          title: const Text('Add server'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: label,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a name.'
                        : null,
                  ),
                  TextFormField(
                    controller: origin,
                    decoration: const InputDecoration(
                      labelText: 'Server address',
                      hintText: 'https://server.example',
                    ),
                    keyboardType: TextInputType.url,
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
                    onChanged: (value) => setState(
                      () => allowInsecureHttp = value ?? false,
                    ),
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
    } on ServerConnectionException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not connect. Check the address and server status.',
          ),
        ),
      );
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
    await ref.read(serverProfileRepositoryProvider).remove(widget.profile.id);
    ref.invalidate(serverProfilesProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).navigationMode == NavigationMode.directional) {
      // A disabled ListTile tap surface can still capture directional focus.
      // The TV row exposes its actions directly, with advanced actions in a menu.
      return Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        const Icon(Icons.dns_outlined), const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.profile.label, style: Theme.of(context).textTheme.titleLarge),
          Text(widget.profile.origin.toString()),
        ])),
        TextButton.icon(autofocus: widget.autofocus,
          onPressed: () => context.go('/signin/${Uri.encodeComponent(widget.profile.id)}'),
          icon: const Icon(Icons.login), label: const Text('Connect')),
        PopupMenuButton<String>(tooltip: 'Server options',
          onSelected: (action) { if (action == 'check') { _checkConnection(); } else if (action == 'remove') { _remove(); } },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'check', enabled: !_checking, child: const Text('Check connection')),
            const PopupMenuItem(value: 'remove', child: Text('Remove server')),
          ]),
      ])));
    }
    return ListTile(
    leading: const Icon(Icons.dns_outlined),
    title: Text(widget.profile.label),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.profile.origin.toString()),
        if (widget.profile.origin.scheme == 'http' &&
            !widget.profile.allowInsecureHttp)
          Text(
            'Blocked: this remote HTTP address has no trusted-network opt-in.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    trailing: Wrap(
      spacing: 4,
      children: [
        TextButton.icon(
          autofocus: widget.autofocus,
          onPressed: () => context.go('/signin/${Uri.encodeComponent(widget.profile.id)}'),
          icon: const Icon(Icons.login), label: const Text('Connect'),
        ),
        TextButton.icon(
          onPressed: _checking ? null : _checkConnection,
          icon: _checking
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link),
          label: const Text('Check connection'),
        ),
        IconButton(tooltip: 'Remove ${widget.profile.label}',
          icon: const Icon(Icons.delete_outline), onPressed: _remove),
      ],
    ),
  );
  }
}

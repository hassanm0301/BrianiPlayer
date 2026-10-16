import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/client_session.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/formatting/locale_formatters.dart';
import '../../core/widgets/adaptive.dart';
import '../../core/widgets/states.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountState();
}

class _AccountState extends ConsumerState<AccountScreen> {
  final _current = TextEditingController(),
      _replacement = TextEditingController(),
      _confirmation = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _cancel = CancelToken();
  Future<List<AuthSession>>? _sessions;
  bool _busy = false;
  String? _error;
  void _reload() {
    final account = ref.read(clientSessionProvider);
    if (account == null || account.tokens.user.mustChangePassword == true) {
      return;
    }
    _sessions = account.api
        .getIdentityApi()
        .listOwnSessions(cancelToken: _cancel)
        .then((r) => r.data!.toList());
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _cancel.cancel();
    _current.dispose();
    _replacement.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_busy) return;
    final account = ref.read(clientSessionProvider);
    if (account == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await account.api.getIdentityApi().changePassword(
        passwordChange: PasswordChange(
          (b) => b
            ..currentPassword = _current.text
            ..newPassword = _replacement.text
            ..confirmNewPassword = _confirmation.text,
        ),
        cancelToken: _cancel,
      );
      if (!mounted) return;
      _current.clear();
      _replacement.clear();
      _confirmation.clear();
      if (identical(ref.read(clientSessionProvider)?.api, account.api)) {
        await ref.read(clientSessionProvider.notifier).disconnect(logout: true);
      }
    } catch (error) {
      if (mounted) setState(() => _error = clientError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(AuthSession session) async {
    final account = ref.read(clientSessionProvider);
    if (account == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke device session?'),
        content: Text(
          'Sign out ${session.deviceName}? Playback tickets from this session will stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke session'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await account.api.getIdentityApi().revokeOwnSession(
        id: session.id,
        cancelToken: _cancel,
      );
      if (!mounted ||
          !identical(ref.read(clientSessionProvider)?.api, account.api)) {
        return;
      }
      if (session.current) {
        await ref.read(clientSessionProvider.notifier).disconnect(logout: true);
      } else {
        setState(_reload);
      }
    } catch (error) {
      if (mounted) setState(() => _error = clientError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(clientSessionProvider);
    final locale = ref.watch(userPreferencesProvider).asData?.value.locale;
    if (account == null) return const SizedBox.shrink();
    final required = account.tokens.user.mustChangePassword == true;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = account.tokens.user;
    final name = user.displayName.trim();
    InputDecoration password(String label) => InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account and devices'),
        actions: [
          TextButton.icon(
            onPressed: () => ref
                .read(clientSessionProvider.notifier)
                .disconnect(logout: true),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: pageGutters(context)
                .add(const EdgeInsets.only(top: 8, bottom: 32)),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: scheme.tertiaryContainer,
                        foregroundColor: scheme.onTertiaryContainer,
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : name.characters.first.toUpperCase(),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${user.username} · ${account.profile.label}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StatusPill(
                              label: account.administrator
                                  ? 'Administrator'
                                  : 'Member',
                              icon: account.administrator
                                  ? Icons.admin_panel_settings_outlined
                                  : Icons.person_outline,
                              tone: account.administrator
                                  ? PillTone.active
                                  : PillTone.neutral,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (required)
                const NoticeBanner(
                  tone: NoticeTone.warning,
                  message:
                      'Your password was reset. Change it before continuing.',
                  margin: EdgeInsets.only(top: 16),
                ),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Change password'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Changing your password signs out every device. Sign in again using the new password.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _current,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.password],
                          decoration: password('Current password'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _replacement,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: password('New password'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmation,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: password('Confirm new password'),
                          onFieldSubmitted: (_) => _change(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          NoticeBanner(
                            tone: NoticeTone.error,
                            message: _error!,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _busy ? null : _change,
                            child: Text(
                              _busy ? 'Changing…' : 'Change password',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!required) ...[
                const SizedBox(height: 24),
                const SectionHeader(title: 'Signed-in devices'),
                Card(
                  child: FutureBuilder<List<AuthSession>>(
                    future: _sessions,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: NoticeBanner(
                            tone: NoticeTone.error,
                            message: clientError(snapshot.error!),
                            action: TextButton(
                              onPressed: () => setState(_reload),
                              child: const Text('Retry devices'),
                            ),
                          ),
                        );
                      }
                      final sessions = snapshot.data ?? [];
                      if (sessions.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No active device sessions.'),
                        );
                      }
                      return Column(
                        children: [
                          for (var i = 0; i < sessions.length; i++) ...[
                            if (i > 0) const Divider(indent: 72, endIndent: 16),
                            _SessionRow(
                              session: sessions[i],
                              lastUsed: formatDateTime(
                                sessions[i].lastSeenAt,
                                locale: locale,
                              ),
                              onRevoke: () => _revoke(sessions[i]),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.lastUsed,
    required this.onRevoke,
  });
  final AuthSession session;
  final String lastUsed;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = session.deviceName.toLowerCase();
    final icon = RegExp(r'\btv\b|television|shield|chromecast').hasMatch(name)
        ? Icons.tv_outlined
        : RegExp(r'phone|pixel|galaxy|android|mobile').hasMatch(name)
        ? Icons.smartphone_outlined
        : RegExp(r'tablet|ipad').hasMatch(name)
        ? Icons.tablet_outlined
        : Icons.computer_outlined;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            child: Icon(icon),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(session.deviceName, style: theme.textTheme.titleSmall),
                    if (session.current)
                      const StatusPill(
                        dense: true,
                        tone: PillTone.success,
                        label: 'This device',
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Last used $lastUsed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: onRevoke,
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }
}

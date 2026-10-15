import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/client_session.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/formatting/locale_formatters.dart';

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
    if (_busy || !_form.currentState!.validate()) return;
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
            ..newPassword = _replacement.text,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account and devices'),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(clientSessionProvider.notifier)
                .disconnect(logout: true),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                account.tokens.user.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(account.profile.label),
              if (required)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Your password was reset. Change it before continuing.',
                  ),
                ),
              const SizedBox(height: 16),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Change password',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Text(
                      'Changing your password signs out every device. Sign in again using the new password.',
                    ),
                    TextFormField(
                      controller: _current,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Enter your current password.'
                          : null,
                    ),
                    TextFormField(
                      controller: _replacement,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                      ),
                      validator: (v) =>
                          v == null || v.length < 12 || v.length > 128
                          ? 'Use 12–128 characters.'
                          : null,
                    ),
                    TextFormField(
                      controller: _confirmation,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Repeat new password',
                      ),
                      validator: (v) => v != _replacement.text
                          ? 'The passwords do not match.'
                          : null,
                    ),
                    if (_error != null) Text(_error!),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _change,
                      child: Text(_busy ? 'Changing…' : 'Change password'),
                    ),
                  ],
                ),
              ),
              if (!required) ...[
                const SizedBox(height: 24),
                Text(
                  'Signed-in devices',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FutureBuilder<List<AuthSession>>(
                  future: _sessions,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          Text(clientError(snapshot.error!)),
                          TextButton(
                            onPressed: () => setState(_reload),
                            child: const Text('Retry devices'),
                          ),
                        ],
                      );
                    }
                    final sessions = snapshot.data ?? [];
                    if (sessions.isEmpty) {
                      return const Text('No active device sessions.');
                    }
                    return Column(
                      children: [
                        for (final session in sessions)
                          ListTile(
                            title: Text(
                              '${session.deviceName}${session.current ? ' (this device)' : ''}',
                            ),
                            subtitle: Text(
                              'Last used ${formatDateTime(session.lastSeenAt, locale: locale)}',
                            ),
                            trailing: TextButton(
                              onPressed: () => _revoke(session),
                              child: const Text('Revoke'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

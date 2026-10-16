import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/server_profiles/server_profile.dart';
import '../../core/session/client_session.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/states.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, required this.profile});
  final ServerProfile profile;
  @override
  ConsumerState<SignInScreen> createState() => _SignInState();
}

class _SignInState extends ConsumerState<SignInScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _code = TextEditingController();
  final _displayName = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _cancel = CancelToken();
  bool _checking = true,
      _busy = false,
      _bootstrap = false,
      _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_check);
  }

  Future<void> _check() async {
    try {
      final controller = ref.read(clientSessionProvider.notifier);
      final server = await controller.inspect(
        widget.profile,
        cancelToken: _cancel,
      );
      if (!mounted) return;
      if (server.apiMajor != 1) throw StateError('Incompatible server.');
      if (!server.bootstrapRequired &&
          await controller.restore(widget.profile, cancelToken: _cancel)) {
        if (mounted) context.go('/libraries');
        return;
      }
      if (mounted) {
        setState(() {
          _bootstrap = server.bootstrapRequired;
          _checking = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = clientError(error);
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(clientSessionProvider.notifier)
          .login(
            widget.profile,
            _username.text.trim(),
            _password.text,
            bootstrapCode: _bootstrap ? _code.text.trim() : null,
            displayName: _displayName.text.trim(),
            confirmPassword: _bootstrap ? _confirmPassword.text : null,
            cancelToken: _cancel,
          );
      if (!mounted) return;
      _password.clear();
      _confirmPassword.clear();
      _code.clear();
      if (mounted) context.go('/libraries');
    } catch (error) {
      if (mounted) setState(() => _error = clientError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _cancel.cancel('Connection screen closed.');
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _code.dispose();
    _displayName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibility = IconButton(
      tooltip: _showPassword ? 'Hide password' : 'Show password',
      onPressed: () => setState(() => _showPassword = !_showPassword),
      icon: Icon(
        _showPassword
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
      ),
    );
    return AuthFrame(
      onBack: () => context.go('/servers'),
      child: _checking
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Contacting server…'),
                  ],
                ),
              ),
            )
          : AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ServerBadge(
                      label: widget.profile.label,
                      origin: widget.profile.origin.toString(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _bootstrap ? 'Create the administrator' : 'Sign in',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bootstrap
                          ? 'Enter the one-time bootstrap code from the server configuration directory.'
                          : 'Use your account on this server.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_bootstrap) ...[
                      TextFormField(
                        controller: _code,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Bootstrap code',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _displayName,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _username,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: _bootstrap
                          ? TextInputAction.next
                          : TextInputAction.done,
                      autofillHints: [
                        _bootstrap
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: visibility,
                      ),
                      onFieldSubmitted: _bootstrap ? null : (_) => _submit(),
                    ),
                    if (_bootstrap) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: !_showPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      NoticeBanner(
                        tone: NoticeTone.error,
                        message: _error!,
                        action: TextButton(
                          onPressed: _busy ? null : _check,
                          child: const Text('Check connection again'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? 'Connecting…'
                            : _bootstrap
                            ? 'Create administrator'
                            : 'Sign in',
                      ),
                    ),
                    if (!_bootstrap) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: _busy
                            ? null
                            : () => context.go('/link/${widget.profile.id}'),
                        icon: const Icon(Icons.devices_other_outlined),
                        label: const Text(
                          'Link using another signed-in device',
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

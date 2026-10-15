import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/server_profiles/server_profile.dart';
import '../../core/session/client_session.dart';

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
  bool _checking = true, _busy = false, _bootstrap = false;
  String? _error;
  @override
  void initState() { super.initState(); Future.microtask(_check); }
  Future<void> _check() async {
    try {
      final controller = ref.read(clientSessionProvider.notifier);
      final server = await controller.inspect(widget.profile, cancelToken: _cancel);
      if (!mounted) return;
      if (server.apiMajor != 1) throw StateError('Incompatible server.');
      if (!server.bootstrapRequired && await controller.restore(widget.profile, cancelToken: _cancel)) {
        if (mounted) context.go('/libraries');
        return;
      }
      if (mounted) setState(() { _bootstrap = server.bootstrapRequired; _checking = false; _error = null; });
    } catch (error) {
      if (mounted) setState(() { _checking = false; _error = clientError(error); });
    }
  }
  Future<void> _submit() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(clientSessionProvider.notifier).login(widget.profile,
        _username.text.trim(), _password.text,
        bootstrapCode: _bootstrap ? _code.text.trim() : null,
        displayName: _displayName.text.trim(),
        confirmPassword: _bootstrap ? _confirmPassword.text : null, cancelToken: _cancel);
      if (!mounted) return;
      _password.clear(); _confirmPassword.clear(); _code.clear();
      if (mounted) context.go('/libraries');
    } catch (error) {
      if (mounted) setState(() => _error = clientError(error));
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() { _cancel.cancel('Connection screen closed.'); _username.dispose(); _password.dispose(); _confirmPassword.dispose(); _code.dispose(); _displayName.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.profile.label), leading: BackButton(onPressed: () => context.go('/servers'))),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
      child: _checking ? const CircularProgressIndicator() : SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: Form(key: _form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_bootstrap ? 'Create the administrator' : 'Sign in', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (!_bootstrap) OutlinedButton(onPressed: _busy ? null : () => context.go('/link/${widget.profile.id}'), child: const Text('Link using another signed-in device')),
          if (_bootstrap) ...[
            const Text('Enter the one-time bootstrap code from the server configuration directory.'),
            TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Bootstrap code')),
            TextFormField(controller: _displayName, decoration: const InputDecoration(labelText: 'Display name')),
          ],
          TextFormField(controller: _username, autofocus: true, autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(labelText: 'Username')),
          TextFormField(controller: _password, obscureText: true, autocorrect: false, enableSuggestions: false,
            autofillHints: [_bootstrap ? AutofillHints.newPassword : AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            onFieldSubmitted: _bootstrap ? null : (_) => _submit()),
          if (_bootstrap)
            TextFormField(controller: _confirmPassword, obscureText: true, autocorrect: false, enableSuggestions: false,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Confirm password'),
              onFieldSubmitted: (_) => _submit()),
          const SizedBox(height: 16),
          if (_error != null) ...[Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: _busy ? null : _check, child: const Text('Check connection again'))],
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Connecting…' : _bootstrap ? 'Create administrator' : 'Sign in')),
        ]))))));
}

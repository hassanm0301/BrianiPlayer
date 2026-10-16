import 'dart:async';

import 'package:briani_api/briani_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/server_profiles/server_profile.dart';
import '../../core/session/client_session.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/code_input.dart';
import '../../core/widgets/states.dart';

class DeviceLinkScreen extends ConsumerStatefulWidget {
  const DeviceLinkScreen({super.key, required this.profile});
  final ServerProfile profile;
  @override
  ConsumerState<DeviceLinkScreen> createState() => _DeviceLinkState();
}

class _DeviceLinkState extends ConsumerState<DeviceLinkScreen> {
  final _name = TextEditingController(text: 'Briani TV');
  PairingCode? _code;
  SessionController? _controller;
  Timer? _timer;
  bool _busy = false, _polling = false;
  String? _error;
  Future<void> _begin() async {
    if (_busy || _name.text.trim().isEmpty || _name.text.trim().length > 128) {
      return;
    }
    _timer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _code = null;
    });
    try {
      _controller = ref.read(clientSessionProvider.notifier);
      final code = await _controller!.beginPairing(
        widget.profile,
        _name.text.trim(),
      );
      if (!mounted) {
        _controller!.cancelPairing();
        return;
      }
      setState(() => _code = code);
      _timer = Timer.periodic(
        Duration(seconds: code.intervalSeconds),
        (_) => _poll(),
      );
    } catch (error) {
      if (mounted) setState(() => _error = clientError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      if (await _controller!.pollPairing()) {
        _timer?.cancel();
        if (mounted) context.go('/libraries');
      } else if (mounted &&
          _code != null &&
          !DateTime.now().isBefore(_code!.expiresAt)) {
        _timer?.cancel();
        setState(() => _error = 'This code expired. Request a new code.');
      }
    } catch (error) {
      _timer?.cancel();
      final expired =
          _code != null && !DateTime.now().isBefore(_code!.expiresAt);
      if (mounted) {
        setState(
          () => _error = expired
              ? 'This code expired. Request a new code.'
              : clientError(error),
        );
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _copyCode() async {
    final code = _code;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code.userCode));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text('Code copied.')));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.cancelPairing();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = _code;
    return AuthFrame(
      maxWidth: 560,
      onBack: () => context.go('/signin/${widget.profile.id}'),
      backTooltip: 'Back to sign in',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServerBadge(
            label: widget.profile.label,
            origin: widget.profile.origin.toString(),
          ),
          const SizedBox(height: 24),
          Text('Link this device', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Sign in without typing a password: approve this device from a phone or computer that is already signed in.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            maxLength: 128,
            enabled: !_busy && code == null,
            decoration: const InputDecoration(
              labelText: 'Device name',
              prefixIcon: Icon(Icons.tv_outlined),
            ),
          ),
          if (code != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Your code',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    code.userCode,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      letterSpacing: 6,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onPrimaryContainer,
                    ),
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy code'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _Step(
              number: 1,
              text: 'On a signed-in phone or computer connected to this server, open the account menu and choose Link a device.',
            ),
            const _Step(
              number: 2,
              text: 'Enter this code and check that the device name matches.',
            ),
            const _Step(
              number: 3,
              text: 'Approve. The code expires in five minutes.',
            ),
            const SizedBox(height: 12),
            if (_error == null)
              Row(
                children: [
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Waiting for approval…',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            NoticeBanner(tone: NoticeTone.error, message: _error!),
          ],
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: _busy ? null : _begin,
            child: Text(
              _busy
                  ? 'Requesting…'
                  : code == null
                  ? 'Request device code'
                  : 'Request new code',
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go('/signin/${widget.profile.id}'),
            child: const Text('Use username and password'),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.secondaryContainer,
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}

class ApproveDeviceDialog extends ConsumerStatefulWidget {
  const ApproveDeviceDialog({super.key});
  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const ApproveDeviceDialog(),
  );
  @override
  ConsumerState<ApproveDeviceDialog> createState() => _ApproveDeviceState();
}

class _ApproveDeviceState extends ConsumerState<ApproveDeviceDialog> {
  final _code = TextEditingController();
  DeviceCodePreview? _preview;
  String? _checkedCode, _error;
  bool _busy = false;
  Future<void> _inspect() async {
    final code = _code.text.trim().toUpperCase();
    if (_busy || !RegExp(r'^[A-Z2-9]{8}$').hasMatch(code)) {
      setState(
        () => _error = 'Enter the eight-character code shown on the device.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview =
          (await requireActiveApi(ref).getIdentityApi().inspectDeviceCode(
            deviceCodeApprove: DeviceCodeApprove((b) => b.userCode = code),
          )).data!;
      if (mounted) {
        setState(() {
          _preview = preview;
          _checkedCode = code;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = clientError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    if (_busy || _preview == null || _checkedCode == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await requireActiveApi(ref).getIdentityApi().approveDeviceCode(
        deviceCodeApprove: DeviceCodeApprove((b) => b.userCode = _checkedCode!),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = clientError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(clientSessionProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = _preview;
    return AlertDialog(
      icon: const Icon(Icons.devices_other_outlined),
      title: const Text('Link a device'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (preview == null) ...[
              Text(
                'Enter the eight-character code shown on the device you want to sign in.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              CodeInput(
                controller: _code,
                label: 'Device code',
                autofocus: true,
                onCompleted: (_) => _inspect(),
                onSubmitted: (_) => _inspect(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      child: const Icon(Icons.tv_outlined),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Allow ${preview.deviceName} to sign in as ${session?.tokens.user.displayName ?? ''}?',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Server: ${session?.profile.label ?? ''}'),
              Text(
                session?.profile.origin.toString() ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              const NoticeBanner(
                tone: NoticeTone.warning,
                message: 'Approve only a device you are linking. It receives your account’s library and download permissions.',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy
              ? null
              : preview == null
              ? _inspect
              : _approve,
          child: Text(
            _busy
                ? 'Checking…'
                : preview == null
                ? 'Check device'
                : 'Approve device',
          ),
        ),
      ],
    );
  }
}

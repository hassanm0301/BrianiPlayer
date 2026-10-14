import 'dart:async';
import 'package:briani_api/briani_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/server_profiles/server_profile.dart';
import '../../core/session/client_session.dart';

class DeviceLinkScreen extends ConsumerStatefulWidget {
  const DeviceLinkScreen({super.key, required this.profile});
  final ServerProfile profile;
  @override ConsumerState<DeviceLinkScreen> createState() => _DeviceLinkState();
}
class _DeviceLinkState extends ConsumerState<DeviceLinkScreen> {
  final _name = TextEditingController(text: 'Briani TV');
  PairingCode? _code;
  SessionController? _controller;
  Timer? _timer;
  bool _busy = false, _polling = false;
  String? _error;
  Future<void> _begin() async {
    if (_busy || _name.text.trim().isEmpty || _name.text.trim().length > 128) return;
    _timer?.cancel();
    setState(() { _busy = true; _error = null; _code = null; });
    try {
      _controller = ref.read(clientSessionProvider.notifier);
      final code = await _controller!.beginPairing(widget.profile, _name.text.trim());
      if (!mounted) { _controller!.cancelPairing(); return; }
      setState(() => _code = code);
      _timer = Timer.periodic(Duration(seconds: code.intervalSeconds), (_) => _poll());
    } catch (error) { if (mounted) setState(() => _error = clientError(error)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _poll() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      if (await _controller!.pollPairing()) {
        _timer?.cancel();
        if (mounted) context.go('/libraries');
      } else if (mounted && _code != null && !DateTime.now().isBefore(_code!.expiresAt)) {
        _timer?.cancel(); setState(() => _error = 'This code expired. Request a new code.');
      }
    } catch (_) {
      _timer?.cancel();
      if (mounted) setState(() => _error = 'Device linking failed or expired. Check the connection and request a new code.');
    } finally { _polling = false; }
  }
  @override void dispose() {
    _timer?.cancel(); _controller?.cancelPairing(); _name.dispose(); super.dispose();
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Link this device')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720),
      child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.profile.label, style: Theme.of(context).textTheme.headlineSmall),
        Text(widget.profile.origin.toString()),
        const SizedBox(height: 24),
        TextField(controller: _name, maxLength: 128, enabled: !_busy && _code == null,
          decoration: const InputDecoration(labelText: 'Device name')),
        if (_code != null) ...[
          SelectableText(_code!.userCode, textAlign: TextAlign.center, style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 16),
          const Text('On a signed-in phone or desktop connected to this server, open Account → Link a device. Enter this code and confirm the device name. The code expires in five minutes.'),
          const SizedBox(height: 16),
          const Text('Waiting for approval…'),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(_error!)),
        FilledButton(onPressed: _busy ? null : _begin, child: Text(_busy ? 'Requesting…' : _code == null ? 'Request device code' : 'Request new code')),
        TextButton(onPressed: () => context.go('/signin/${widget.profile.id}'), child: const Text('Use username and password')),
      ])))));
}

class ApproveDeviceDialog extends ConsumerStatefulWidget {
  const ApproveDeviceDialog({super.key});
  static Future<void> show(BuildContext context) => showDialog<void>(context: context, builder: (_) => const ApproveDeviceDialog());
  @override ConsumerState<ApproveDeviceDialog> createState() => _ApproveDeviceState();
}
class _ApproveDeviceState extends ConsumerState<ApproveDeviceDialog> {
  final _code = TextEditingController();
  DeviceCodePreview? _preview;
  String? _checkedCode, _error;
  bool _busy = false;
  Future<void> _inspect() async {
    final code = _code.text.trim().toUpperCase();
    if (_busy || !RegExp(r'^[A-Z2-9]{8}$').hasMatch(code)) {
      setState(() => _error = 'Enter the eight-character code shown on the device.'); return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final preview = (await requireActiveApi(ref).getIdentityApi().inspectDeviceCode(
        deviceCodeApprove: DeviceCodeApprove((b) => b.userCode = code))).data!;
      if (mounted) setState(() { _preview = preview; _checkedCode = code; });
    } catch (_) { if (mounted) setState(() => _error = 'The code is unavailable or expired. Check the server and code.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _approve() async {
    if (_busy || _preview == null || _checkedCode == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await requireActiveApi(ref).getIdentityApi().approveDeviceCode(
        deviceCodeApprove: DeviceCodeApprove((b) => b.userCode = _checkedCode!));
      if (mounted) Navigator.pop(context);
    } catch (_) { if (mounted) setState(() => _error = 'Approval failed. The code may have expired or already been used.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override void dispose() { _code.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final session = ref.watch(clientSessionProvider);
    return AlertDialog(title: const Text('Link a device'), content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (_preview == null) TextField(controller: _code, maxLength: 8, textCapitalization: TextCapitalization.characters,
        autofocus: true, decoration: const InputDecoration(labelText: 'Device code'), onSubmitted: (_) => _inspect())
      else ...[
        Text('Allow ${_preview!.deviceName} to sign in as ${session?.tokens.user.displayName ?? ''}?'),
        Text('Server: ${session?.profile.label ?? ''}'),
        Text(session?.profile.origin.toString() ?? ''),
        const SizedBox(height: 12),
        const Text('Approve only a device you are linking. It receives your account’s library and download permissions.'),
      ],
      if (_error != null) Text(_error!),
    ])), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _busy ? null : _preview == null ? _inspect : _approve,
        child: Text(_busy ? 'Checking…' : _preview == null ? 'Check device' : 'Approve device')),
    ]);
  }
}

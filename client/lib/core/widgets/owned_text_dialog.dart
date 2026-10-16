import 'package:flutter/material.dart';

/// A text dialog whose editing controller follows the dialog route's widget
/// lifetime, including its reverse transition after the route result is sent.
class OwnedTextDialog extends StatefulWidget {
  const OwnedTextDialog({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
    this.initialText = '',
    this.hintText,
    this.maxLength,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initialText;
  final String? hintText;
  final int? maxLength;

  static Future<String?> show({
    required BuildContext context,
    required String title,
    required String label,
    required String confirmLabel,
    String initialText = '',
    String? hintText,
    int? maxLength,
  }) => showDialog<String>(
    context: context,
    builder: (_) => OwnedTextDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initialText: initialText,
      hintText: hintText,
      maxLength: maxLength,
    ),
  );

  @override
  State<OwnedTextDialog> createState() => _OwnedTextDialogState();
}

class _OwnedTextDialogState extends State<OwnedTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 480,
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          // Long limits (for example magnet links) make a counter noise.
          counterText: (widget.maxLength ?? 0) > 1000 ? '' : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
    ],
  );
}

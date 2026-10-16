import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One-time-code entry drawn as one box per character.
///
/// A single transparent text field sits over the boxes, so paste, on-screen
/// keyboards, screen readers and D-pad focus behave like any other field.
class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.controller,
    required this.label,
    this.length = 8,
    this.autofocus = false,
    this.enabled = true,
    this.onCompleted,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final int length;
  final bool autofocus;
  final bool enabled;

  /// Called once each time the code reaches [length] characters.
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onSubmitted;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  final _focus = FocusNode();
  String? _completed;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_refresh);
  }

  @override
  void didUpdateWidget(CodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _changed() {
    final text = widget.controller.text;
    // The field is invisible, so a tap can drop the caret mid-code. Keep
    // typing at the end; a real range selection (select all) is preserved.
    final selection = widget.controller.selection;
    if (selection.isValid &&
        selection.isCollapsed &&
        selection.baseOffset != text.length) {
      widget.controller.selection = TextSelection.collapsed(
        offset: text.length,
      );
      return;
    }
    setState(() {});
    if (text.length < widget.length) {
      _completed = null;
    } else if (text != _completed) {
      _completed = text;
      widget.onCompleted?.call(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = widget.controller.text;
    final active = _focus.hasFocus
        ? math.min(text.length, widget.length - 1)
        : -1;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final size = math.min(
          52.0,
          (constraints.maxWidth - gap * (widget.length - 1)) / widget.length,
        );
        return SizedBox(
          height: size * 1.2,
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    _box(
                      theme,
                      scheme,
                      size,
                      i < text.length ? text[i] : '',
                      i == active,
                    ),
                  ],
                ],
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  alwaysIncludeSemantics: true,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    showCursor: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      TextInputFormatter.withFunction(
                        (_, value) =>
                            value.copyWith(text: value.text.toUpperCase()),
                      ),
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    decoration: InputDecoration(
                      labelText: widget.label,
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onSubmitted: widget.onSubmitted,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _box(
    ThemeData theme,
    ColorScheme scheme,
    double size,
    String char,
    bool active,
  ) {
    final color = !widget.enabled
        ? scheme.outlineVariant.withValues(alpha: .5)
        : active
        ? scheme.primary
        : char.isEmpty
        ? scheme.outlineVariant
        : scheme.outline;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size * 1.2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: char.isEmpty ? .4 : .8,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: active ? 2 : 1),
      ),
      child: Text(
        char,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

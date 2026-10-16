import 'package:briani_api/briani_api.dart' show ModelLibrary;
import 'package:flutter/material.dart';

import '../../core/widgets/states.dart';

/// The choice made in [AddDownloadDialog].
class AddDownloadChoice {
  const AddDownloadChoice({required this.library, this.magnet});
  final ModelLibrary library;

  /// The trimmed magnet URI when the dialog asked for one.
  final String? magnet;
}

/// Confirms a new download: what is being added, where it goes, and that
/// nothing transfers before files are chosen. The magnet variant also owns
/// the URI field so its controller follows the dialog route's lifetime.
class AddDownloadDialog extends StatefulWidget {
  const AddDownloadDialog({
    super.key,
    required this.title,
    required this.libraries,
    required this.confirmLabel,
    this.subject,
    this.details,
    this.subjectIcon = Icons.download_outlined,
    this.stale = false,
    this.askForMagnet = false,
  });

  final String title;
  final List<ModelLibrary> libraries;
  final String confirmLabel;
  final String? subject;
  final String? details;
  final IconData subjectIcon;
  final bool stale;
  final bool askForMagnet;

  static Future<AddDownloadChoice?> show({
    required BuildContext context,
    required String title,
    required List<ModelLibrary> libraries,
    required String confirmLabel,
    String? subject,
    String? details,
    IconData subjectIcon = Icons.download_outlined,
    bool stale = false,
    bool askForMagnet = false,
  }) => showDialog<AddDownloadChoice>(
    context: context,
    builder: (_) => AddDownloadDialog(
      title: title,
      libraries: libraries,
      confirmLabel: confirmLabel,
      subject: subject,
      details: details,
      subjectIcon: subjectIcon,
      stale: stale,
      askForMagnet: askForMagnet,
    ),
  );

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  late ModelLibrary? _destination = widget.libraries.firstOrNull;
  TextEditingController? _magnet;

  @override
  void initState() {
    super.initState();
    if (widget.askForMagnet) {
      _magnet = TextEditingController()..addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _magnet?.dispose();
    super.dispose();
  }

  bool get _ready =>
      _destination != null &&
      (_magnet == null || _magnet!.text.trim().isNotEmpty);

  void _confirm() {
    if (!_ready) return;
    Navigator.of(context).pop(
      AddDownloadChoice(library: _destination!, magnet: _magnet?.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.subject != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(widget.subjectIcon, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.subject!,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (widget.details != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.details!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_magnet != null) ...[
              TextField(
                controller: _magnet,
                autofocus: true,
                maxLength: 65536,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Magnet URI',
                  hintText: 'magnet:?xt=urn:btih:…',
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<ModelLibrary>(
              initialValue: _destination,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Destination library',
                prefixIcon: Icon(Icons.video_library_outlined),
              ),
              items: widget.libraries
                  .map(
                    (library) => DropdownMenuItem(
                      value: library,
                      child: Text(
                        library.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _destination = value),
            ),
            if (widget.stale) ...[
              const SizedBox(height: 16),
              const NoticeBanner(
                tone: NoticeTone.warning,
                icon: Icons.history,
                message: 'This result is stale. The server will re-resolve it before adding.',
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Briani fetches the file list first. Nothing downloads until you choose files.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _ready ? _confirm : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

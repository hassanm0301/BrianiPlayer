import 'package:briani_api/briani_api.dart' show DownloadSettings;
import 'package:flutter/material.dart';

import 'download_formatters.dart';

/// Entered transfer settings, validated but still as text so the caller
/// keeps ownership of parsing and the request.
class TransferSettingsDraft {
  const TransferSettingsDraft({
    required this.downloadLimit,
    required this.uploadLimit,
    required this.ratio,
    required this.seedTime,
    required this.queue,
    required this.tags,
  });

  final String downloadLimit;
  final String uploadLimit;
  final String ratio;
  final String seedTime;
  final String queue;
  final String tags;
}

/// Per-download rate, seeding, queue and tag settings.
class TransferSettingsDialog extends StatefulWidget {
  const TransferSettingsDialog({
    super.key,
    required this.settings,
    this.locale,
  });

  final DownloadSettings settings;
  final String? locale;

  @override
  State<TransferSettingsDialog> createState() => _TransferSettingsDialogState();
}

class _TransferSettingsDialogState extends State<TransferSettingsDialog> {
  final _errors = <String, String>{};
  late final TextEditingController _downloadLimit;
  late final TextEditingController _uploadLimit;
  late final TextEditingController _ratio;
  late final TextEditingController _seedTime;
  late final TextEditingController _queue;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _downloadLimit = TextEditingController(
      text: settings.downloadLimitBytesPerSecond?.toString() ?? '',
    );
    _uploadLimit = TextEditingController(
      text: settings.uploadLimitBytesPerSecond?.toString() ?? '',
    );
    _ratio = TextEditingController(text: settings.ratioLimit?.toString() ?? '');
    _seedTime = TextEditingController(
      text: settings.seedTimeMinutes?.toString() ?? '',
    );
    _queue = TextEditingController(
      text: settings.queuePosition?.toString() ?? '',
    );
    _tags = TextEditingController(text: settings.tags?.join(', ') ?? '');
    for (final controller in [_downloadLimit, _uploadLimit, _seedTime]) {
      controller.addListener(_refreshHelpers);
    }
  }

  void _refreshHelpers() => setState(() {});

  @override
  void dispose() {
    _downloadLimit.dispose();
    _uploadLimit.dispose();
    _ratio.dispose();
    _seedTime.dispose();
    _queue.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _save() {
    _errors.clear();
    void integer(String field, String text, int max) {
      if (text.trim().isEmpty) return;
      final value = int.tryParse(text.trim());
      if (value == null || value < 0 || value > max) {
        _errors[field] = 'Enter a whole number from 0 to $max, or leave blank.';
      }
    }

    integer('download', _downloadLimit.text, 1073741824);
    integer('upload', _uploadLimit.text, 1073741824);
    integer('time', _seedTime.text, 525600);
    integer('queue', _queue.text, 500);
    if (_ratio.text.trim().isNotEmpty) {
      final ratio = double.tryParse(_ratio.text.trim());
      if (ratio == null || !ratio.isFinite || ratio < 0 || ratio > 10000) {
        _errors['ratio'] = 'Enter a number from 0 to 10000, or leave blank.';
      }
    }
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(
      TransferSettingsDraft(
        downloadLimit: _downloadLimit.text,
        uploadLimit: _uploadLimit.text,
        ratio: _ratio.text,
        seedTime: _seedTime.text,
        queue: _queue.text,
        tags: _tags.text,
      ),
    );
  }

  /// Shows the entered rate in readable units, or what blank means.
  String _rateHelper(String text) {
    final value = int.tryParse(text.trim());
    if (text.trim().isEmpty || value == null || value < 0) {
      return 'Leave blank for no limit';
    }
    return '≈ ${formatRate(value, locale: widget.locale)}';
  }

  String _durationHelper(String text) {
    final value = int.tryParse(text.trim());
    if (text.trim().isEmpty || value == null || value < 0) {
      return 'Leave blank for no time limit';
    }
    return '≈ ${formatEta(value * 60, locale: widget.locale)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget group(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          ...children,
        ],
      ),
    );
    return AlertDialog(
      title: const Text('Transfer settings'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            group('Speed limits', [
              TextField(
                controller: _downloadLimit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  errorText: _errors['download'],
                  labelText: 'Download limit (bytes/sec)',
                  helperText: _rateHelper(_downloadLimit.text),
                  prefixIcon: const Icon(Icons.arrow_downward),
                ),
              ),
              TextField(
                controller: _uploadLimit,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  errorText: _errors['upload'],
                  labelText: 'Upload limit (bytes/sec)',
                  helperText: _rateHelper(_uploadLimit.text),
                  prefixIcon: const Icon(Icons.arrow_upward),
                ),
              ),
            ]),
            group('Seeding', [
              TextField(
                controller: _ratio,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Seeding ratio limit',
                  errorText: _errors['ratio'],
                  helperText: 'Leave blank for no ratio limit',
                  prefixIcon: const Icon(Icons.percent),
                ),
              ),
              TextField(
                controller: _seedTime,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  errorText: _errors['time'],
                  labelText: 'Seed time limit (minutes)',
                  helperText: _durationHelper(_seedTime.text),
                  prefixIcon: const Icon(Icons.timer_outlined),
                ),
              ),
            ]),
            group('Queue and tags', [
              TextField(
                controller: _queue,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Queue position',
                  errorText: _errors['queue'],
                  helperText: 'Position in the transfer queue',
                  prefixIcon: const Icon(Icons.format_list_numbered),
                ),
              ),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  helperText: 'Labels only; they never change file paths',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

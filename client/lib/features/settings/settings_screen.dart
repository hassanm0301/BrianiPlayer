import 'dart:async';

import 'package:briani_api/briani_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/preferences/preferences_providers.dart';
import '../../core/session/client_session.dart';

final permittedPreferenceLibrariesProvider = FutureProvider<List<ModelLibrary>>(
  (ref) async {
    final api = ref.watch(activeApiProvider);
    if (api == null) return const [];
    return (await api.getLibrariesApi().listLibraries()).data!.toList();
  },
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(userPreferencesProvider);
    final device = ref.watch(devicePreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          message: _safeMessage(error),
          retry: () => ref.invalidate(userPreferencesProvider),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(
              title: 'Appearance and accessibility',
              reset: () => _reset(ref, context, PreferenceSection.appearance),
              children: [
                _dropdown<UserPreferencesThemeEnum>(
                  context,
                  label: 'Theme',
                  value: value.theme ?? UserPreferencesThemeEnum.system,
                  options: UserPreferencesThemeEnum.values.toList(),
                  title: _enumLabel,
                  onChanged: (v) => _update(ref, context, (b) => b.theme = v),
                ),
                _dropdown<UserPreferencesAccentPresetEnum>(
                  context,
                  label: 'Accent color',
                  value:
                      value.accentPreset ??
                      UserPreferencesAccentPresetEnum.blue,
                  options: UserPreferencesAccentPresetEnum.values.toList(),
                  title: _enumLabel,
                  onChanged: (v) =>
                      _update(ref, context, (b) => b.accentPreset = v),
                ),
                _dropdown<UserPreferencesDensityEnum>(
                  context,
                  label: 'Density',
                  value:
                      value.density ?? UserPreferencesDensityEnum.comfortable,
                  options: UserPreferencesDensityEnum.values.toList(),
                  title: _enumLabel,
                  onChanged: (v) => _update(ref, context, (b) => b.density = v),
                ),
                _textSetting(
                  context,
                  label: 'Locale for formatting',
                  value: value.locale ?? 'en',
                  maxLength: 30,
                  onSubmitted: (v) =>
                      _update(ref, context, (b) => b.locale = v.trim()),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'The interface text is currently in English. This locale setting controls supported date and number formatting.',
                  ),
                ),
                _dropdown<UserPreferencesKeyboardShortcutPresetEnum>(
                  context,
                  label: 'Keyboard shortcuts',
                  value:
                      value.keyboardShortcutPreset ??
                      UserPreferencesKeyboardShortcutPresetEnum.standard,
                  options: UserPreferencesKeyboardShortcutPresetEnum.values
                      .toList(),
                  title: _enumLabel,
                  onChanged: (v) => _update(
                    ref,
                    context,
                    (b) => b.keyboardShortcutPreset = v,
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Libraries and discovery',
              reset: () => _reset(ref, context, PreferenceSection.library),
              children: [
                _dropdown<UserPreferencesLibraryLayoutEnum>(
                  context,
                  label: 'Library layout',
                  value:
                      value.libraryLayout ??
                      UserPreferencesLibraryLayoutEnum.grid,
                  options: UserPreferencesLibraryLayoutEnum.values.toList(),
                  title: _enumLabel,
                  onChanged: (v) =>
                      _update(ref, context, (b) => b.libraryLayout = v),
                ),
                _dropdown<UserPreferencesDefaultSortEnum>(
                  context,
                  label: 'Default sort',
                  value:
                      value.defaultSort ??
                      UserPreferencesDefaultSortEnum.byName,
                  options: UserPreferencesDefaultSortEnum.values.toList(),
                  title: _enumLabel,
                  onChanged: (v) =>
                      _update(ref, context, (b) => b.defaultSort = v),
                ),
                _dropdown<UserPreferencesDefaultSortOrderEnum>(
                  context,
                  label: 'Sort order',
                  value:
                      value.defaultSortOrder ??
                      UserPreferencesDefaultSortOrderEnum.asc,
                  options: UserPreferencesDefaultSortOrderEnum.values.toList(),
                  title: _enumLabel,
                  onChanged: (v) =>
                      _update(ref, context, (b) => b.defaultSortOrder = v),
                ),
                _switch(
                  'Show filename extensions',
                  value.showFilenameExtensions ?? true,
                  (v) => _update(
                    ref,
                    context,
                    (b) => b.showFilenameExtensions = v,
                  ),
                ),
                _switch(
                  'Show Continue Watching',
                  value.showContinueWatching ?? true,
                  (v) =>
                      _update(ref, context, (b) => b.showContinueWatching = v),
                ),
                _switch(
                  'Remember folder sort',
                  value.rememberFolderSort ?? true,
                  (v) => _update(ref, context, (b) => b.rememberFolderSort = v),
                ),
                _PinnedLibraries(value: value),
                for (final folder
                    in value.folderPreferences?.toList() ??
                        <UserPreferencesFolderPreferencesInner>[])
                  _FolderPreferenceRow(value: value, folder: folder),
                Text(
                  'Visible torrent columns',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final column
                        in UserPreferencesTorrentColumnsEnum.values)
                      FilterChip(
                        label: Text(_enumLabel(column)),
                        selected:
                            (value.torrentColumns?.contains(column) ?? false),
                        onSelected: (selected) {
                          final columns =
                              value.torrentColumns?.toList() ??
                              <UserPreferencesTorrentColumnsEnum>[];
                          if (selected && !columns.contains(column)) {
                            columns.add(column);
                          }
                          if (!selected &&
                              column !=
                                  UserPreferencesTorrentColumnsEnum.title) {
                            columns.remove(column);
                          }
                          _update(
                            ref,
                            context,
                            (b) => b.torrentColumns.replace(columns),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
            _Section(
              title: 'Playback and photos',
              reset: () => _reset(ref, context, PreferenceSection.playback),
              children: [
                _dropdown<UserPreferencesPlaybackModeEnum>(
                  context,
                  label: 'Preferred playback mode',
                  value:
                      value.playbackMode ??
                      UserPreferencesPlaybackModeEnum.internal,
                  options: UserPreferencesPlaybackModeEnum.values.toList(),
                  title: _enumLabel,
                  onChanged: (v) =>
                      _update(ref, context, (b) => b.playbackMode = v),
                ),
                _dropdown<UserPreferencesResumePolicyEnum>(
                  context,
                  label: 'Resume policy',
                  value:
                      value.resumePolicy ?? UserPreferencesResumePolicyEnum.ask,
                  options: UserPreferencesResumePolicyEnum.values.toList(),
                  title: _enumLabel,
                  onChanged: (v) =>
                      _update(ref, context, (b) => b.resumePolicy = v),
                ),
                _numberSetting(
                  context,
                  label: 'Default playback speed',
                  value: value.defaultPlaybackSpeed ?? 1,
                  min: .25,
                  max: 4,
                  step: .25,
                  onChanged: (v) =>
                      _update(ref, context, (b) => b.defaultPlaybackSpeed = v),
                ),
                _numberSetting(
                  context,
                  label: 'Subtitle text scale',
                  value: value.subtitleScale ?? 1,
                  min: .5,
                  max: 3,
                  step: .1,
                  onChanged: (v) =>
                      _update(ref, context, (b) => b.subtitleScale = v),
                ),
                _textSetting(
                  context,
                  label: 'Preferred audio language',
                  value: value.preferredAudioLanguage ?? '',
                  maxLength: 50,
                  onSubmitted: (v) => _update(
                    ref,
                    context,
                    (b) => b.preferredAudioLanguage = v.trim().isEmpty
                        ? null
                        : v.trim(),
                  ),
                ),
                _textSetting(
                  context,
                  label: 'Preferred subtitle language',
                  value: value.preferredSubtitleLanguage ?? '',
                  maxLength: 50,
                  onSubmitted: (v) => _update(
                    ref,
                    context,
                    (b) => b.preferredSubtitleLanguage = v.trim().isEmpty
                        ? null
                        : v.trim(),
                  ),
                ),
                _numberSetting(
                  context,
                  label: 'Slideshow interval (seconds)',
                  value: (value.slideshowSeconds ?? 5).toDouble(),
                  min: 1,
                  max: 3600,
                  step: 1,
                  onChanged: (v) => _update(
                    ref,
                    context,
                    (b) => b.slideshowSeconds = v.round(),
                  ),
                ),
              ],
            ),
            _Section(
              title: 'This device',
              reset: () => ref.read(devicePreferencesProvider.notifier).reset(),
              children: [
                _dropdown<PlayerCachePreset>(
                  context,
                  label: 'Player cache',
                  value: device.cachePreset,
                  options: PlayerCachePreset.values,
                  title: (v) => switch (v) {
                    PlayerCachePreset.small => 'Small · 16 MiB',
                    PlayerCachePreset.medium => 'Balanced · 32 MiB',
                    PlayerCachePreset.large => 'Large · 64 MiB',
                  },
                  onChanged: (v) =>
                      _deviceUpdate(ref, device.copyWith(cachePreset: v)),
                ),
                _dropdown<DecoderPreference>(
                  context,
                  label: 'Hardware decoder',
                  value: device.hardwareDecoder,
                  options: DecoderPreference.values,
                  title: (v) => switch (v) {
                    DecoderPreference.automatic => 'Automatic',
                    DecoderPreference.safe => 'Safe tested choice',
                    DecoderPreference.disabled => 'Disabled',
                  },
                  onChanged: (v) =>
                      _deviceUpdate(ref, device.copyWith(hardwareDecoder: v)),
                ),
                _dropdown<DeviceModeOverride>(
                  context,
                  label: 'Device layout override',
                  value: device.modeOverride,
                  options: DeviceModeOverride.values,
                  title: (v) => switch (v) {
                    DeviceModeOverride.automatic => 'Automatic',
                    DeviceModeOverride.mobile => 'Mobile',
                    DeviceModeOverride.television => 'TV',
                  },
                  onChanged: (v) =>
                      _deviceUpdate(ref, device.copyWith(modeOverride: v)),
                ),
                _numberSetting(
                  context,
                  label: 'Display scale',
                  value: device.displayScale,
                  min: .75,
                  max: 2,
                  step: .05,
                  onChanged: (v) =>
                      _deviceUpdate(ref, device.copyWith(displayScale: v)),
                ),
                _numberSetting(
                  context,
                  label: 'Window width',
                  value: device.windowWidth.toDouble(),
                  min: 640,
                  max: 3840,
                  step: 80,
                  onChanged: (v) => _deviceUpdate(
                    ref,
                    device.copyWith(windowWidth: v.round()),
                  ),
                ),
                _numberSetting(
                  context,
                  label: 'Window height',
                  value: device.windowHeight.toDouble(),
                  min: 360,
                  max: 2160,
                  step: 40,
                  onChanged: (v) => _deviceUpdate(
                    ref,
                    device.copyWith(windowHeight: v.round()),
                  ),
                ),
                _switch(
                  'Start fullscreen',
                  device.fullscreenByDefault,
                  (v) => _deviceUpdate(
                    ref,
                    device.copyWith(fullscreenByDefault: v),
                  ),
                ),
                _textSetting(
                  context,
                  label: 'Preferred installed player',
                  value: device.preferredPlayer ?? '',
                  maxLength: 128,
                  onSubmitted: (v) => _deviceUpdate(
                    ref,
                    device.copyWith(
                      preferredPlayer: v.trim().isEmpty ? null : v.trim(),
                    ),
                  ),
                ),
                _textSetting(
                  context,
                  label: 'Player executable / app path',
                  value: device.executablePath ?? '',
                  maxLength: 4096,
                  onSubmitted: (v) {
                    final input = v.trim();
                    if (input.isNotEmpty && !_absoluteExecutable(input)) {
                      _message(
                        context,
                        'Enter an absolute executable or application path.',
                      );
                      return;
                    }
                    _deviceUpdate(
                      ref,
                      device.copyWith(
                        executablePath: input.isEmpty ? null : input,
                      ),
                    );
                  },
                ),
                _textSetting(
                  context,
                  label: 'Player arguments (one per line; exactly one {url})',
                  value: device.arguments.join('\n'),
                  maxLength: 8192,
                  onSubmitted: (v) {
                    final args = v.split('\n');
                    if (args.length > 32 ||
                        args.where((a) => a == '{url}').length != 1 ||
                        args.any((a) => a.contains('{url}') && a != '{url}')) {
                      _message(
                        context,
                        'Use at most 32 arguments with exactly one complete {url} argument.',
                      );
                      return;
                    }
                    _deviceUpdate(ref, device.copyWith(arguments: args));
                  },
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _reset(ref, context, PreferenceSection.all),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset all synced preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinnedLibraries extends ConsumerWidget {
  const _PinnedLibraries({required this.value});
  final UserPreferences value;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Pinned libraries', style: Theme.of(context).textTheme.titleSmall),
      ref
          .watch(permittedPreferenceLibrariesProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) =>
                const Text('Library pins are unavailable right now.'),
            data: (libraries) {
              final pinned = value.pinnedLibraryIds?.toList() ?? <String>[];
              return Wrap(
                spacing: 8,
                children: [
                  for (final library in libraries)
                    FilterChip(
                      label: Text(library.name),
                      selected: pinned.contains(library.id),
                      onSelected: (selected) {
                        final ids = [...pinned];
                        if (selected && !ids.contains(library.id)) {
                          ids.add(library.id);
                        }
                        if (!selected) {
                          ids.remove(library.id);
                        }
                        _update(
                          ref,
                          context,
                          (b) => b.pinnedLibraryIds.replace(ids),
                        );
                      },
                    ),
                ],
              );
            },
          ),
    ],
  );
}

class _FolderPreferenceRow extends ConsumerWidget {
  const _FolderPreferenceRow({required this.value, required this.folder});
  final UserPreferences value;
  final UserPreferencesFolderPreferencesInner folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders =
        value.folderPreferences?.toList() ??
        <UserPreferencesFolderPreferencesInner>[];
    final index = folders.indexOf(folder);
    return ExpansionTile(
      title: Text('Saved folder view · ${folder.libraryId}'),
      subtitle: Text(
        folder.folderId == null ? 'Library root' : 'Folder ${folder.folderId}',
      ),
      children: [
        _dropdown<UserPreferencesFolderPreferencesInnerLayoutEnum>(
          context,
          label: 'Folder layout',
          value: folder.layout,
          options: UserPreferencesFolderPreferencesInnerLayoutEnum.values
              .toList(),
          title: _enumLabel,
          onChanged: (layout) => _replaceFolderPreference(
            ref,
            context,
            folders,
            index,
            folder.rebuild((b) => b.layout = layout),
          ),
        ),
        _dropdown<UserPreferencesFolderPreferencesInnerSortEnum>(
          context,
          label: 'Folder sort',
          value: folder.sort,
          options: UserPreferencesFolderPreferencesInnerSortEnum.values
              .toList(),
          title: _enumLabel,
          onChanged: (sort) => _replaceFolderPreference(
            ref,
            context,
            folders,
            index,
            folder.rebuild((b) => b.sort = sort),
          ),
        ),
        _dropdown<UserPreferencesFolderPreferencesInnerOrderEnum>(
          context,
          label: 'Folder order',
          value: folder.order,
          options: UserPreferencesFolderPreferencesInnerOrderEnum.values
              .toList(),
          title: _enumLabel,
          onChanged: (order) => _replaceFolderPreference(
            ref,
            context,
            folders,
            index,
            folder.rebuild((b) => b.order = order),
          ),
        ),
      ],
    );
  }
}

void _replaceFolderPreference(
  WidgetRef ref,
  BuildContext context,
  List<UserPreferencesFolderPreferencesInner> folders,
  int index,
  UserPreferencesFolderPreferencesInner updated,
) {
  if (index < 0) return;
  folders[index] = updated;
  _update(ref, context, (b) => b.folderPreferences.replace(folders));
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    required this.reset,
  });
  final String title;
  final List<Widget> children;
  final Future<void> Function() reset;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Reset $title',
                onPressed: () => reset(),
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        FilledButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );
}

Widget _switch(String title, bool value, ValueChanged<bool> onChanged) =>
    SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );

Widget _dropdown<T extends Object>(
  BuildContext context, {
  required String label,
  required T value,
  required Iterable<T> options,
  required String Function(T) title,
  required ValueChanged<T> onChanged,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: DropdownButtonFormField<T>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final option in options)
        DropdownMenuItem(value: option, child: Text(title(option))),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  ),
);

Widget _textSetting(
  BuildContext context, {
  required String label,
  required String value,
  required int maxLength,
  required ValueChanged<String> onSubmitted,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: TextFormField(
    key: ValueKey('$label:$value'),
    initialValue: value,
    maxLength: maxLength,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    onFieldSubmitted: onSubmitted,
  ),
);

Widget _numberSetting(
  BuildContext context, {
  required String label,
  required double value,
  required double min,
  required double max,
  required double step,
  required ValueChanged<double> onChanged,
}) => _NumberSetting(
  label: label,
  value: value,
  min: min,
  max: max,
  step: step,
  onChanged: onChanged,
);

class _NumberSetting extends StatefulWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });
  final String label;
  final double value, min, max, step;
  final ValueChanged<double> onChanged;
  @override
  State<_NumberSetting> createState() => _NumberSettingState();
}

class _NumberSettingState extends State<_NumberSetting> {
  late double _draft = widget.value.clamp(widget.min, widget.max);
  @override
  void didUpdateWidget(covariant _NumberSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _draft = widget.value.clamp(widget.min, widget.max);
    }
  }

  @override
  Widget build(BuildContext context) {
    if ((widget.max - widget.min) / widget.step > 100) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          key: ValueKey('${widget.label}:${widget.value}'),
          initialValue: widget.value.round().toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
          onFieldSubmitted: (raw) {
            final parsed = double.tryParse(raw.trim());
            if (parsed == null ||
                !parsed.isFinite ||
                parsed < widget.min ||
                parsed > widget.max) {
              _message(
                context,
                'Enter a value from ${widget.min.round()} to ${widget.max.round()}.',
              );
              return;
            }
            widget.onChanged(parsed);
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.label}: ${_draft.toStringAsFixed(widget.step < 1 ? 2 : 0)}',
          ),
          Slider(
            value: _draft,
            min: widget.min,
            max: widget.max,
            divisions: ((widget.max - widget.min) / widget.step).round(),
            label: _draft.toStringAsFixed(2),
            onChanged: (next) => setState(() => _draft = next),
            onChangeEnd: (next) {
              _draft = next;
              widget.onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

String _enumLabel(Object value) => value
    .toString()
    .split('.')
    .last
    .replaceAll('_', ' ')
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
bool _absoluteExecutable(String input) =>
    input.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(input);
String _safeMessage(Object error) => error is StateError
    ? error.message
    : 'Could not load preferences. Check the server and retry.';

Future<void> _update(
  WidgetRef ref,
  BuildContext context,
  void Function(UserPreferencesBuilder) change,
) async {
  try {
    await ref.read(userPreferencesProvider.notifier).update(change);
  } catch (error) {
    if (context.mounted) _message(context, _safeMessage(error));
  }
}

Future<void> _reset(
  WidgetRef ref,
  BuildContext context,
  PreferenceSection section,
) async {
  if (section == PreferenceSection.all) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset synced preferences?'),
        content: const Text(
          'This resets all personal settings on this server. Device-only player settings are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }
  try {
    await ref.read(userPreferencesProvider.notifier).reset(section);
  } catch (error) {
    if (context.mounted) _message(context, _safeMessage(error));
  }
}

Future<void> _deviceUpdate(WidgetRef ref, DevicePreferences value) async {
  await ref.read(devicePreferencesProvider.notifier).update(value);
}

void _message(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

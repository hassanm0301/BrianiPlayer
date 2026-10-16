import 'dart:io';

import 'package:briani_api/briani_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/session/client_session.dart';
import '../../core/widgets/adaptive.dart';
import '../../core/widgets/section_jump.dart';
import '../../core/widgets/states.dart';

final permittedPreferenceLibrariesProvider = FutureProvider<List<ModelLibrary>>(
  (ref) async {
    final api = ref.watch(activeApiProvider);
    if (api == null) return const [];
    return (await api.getLibrariesApi().listLibraries()).data!.toList();
  },
);

const _sections = [
  JumpSection('Appearance', Icons.palette_outlined),
  JumpSection('Browsing', Icons.folder_open_outlined),
  JumpSection('Playback', Icons.play_circle_outline),
  JumpSection('Device', Icons.devices_outlined),
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SectionScrollSpy {
  @override
  int get sectionCount => _sections.length;

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(userPreferencesProvider);
    final device = ref.watch(devicePreferencesProvider);
    final television = isTelevision(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState.error(
          title: 'Settings are unavailable',
          message: _safeMessage(error),
          onRetry: () => ref.invalidate(userPreferencesProvider),
        ),
        data: (value) => LayoutBuilder(
          builder: (context, constraints) {
            final sidebar = !television && constraints.maxWidth >= 960;
            final list = ListView(
              controller: scrollController,
              padding:
                  (sidebar
                          ? const EdgeInsets.only(left: 8, right: 28)
                          : pageGutters(context))
                      .add(const EdgeInsets.only(top: 4, bottom: 40)),
              children: [
                Align(
                  alignment: sidebar ? Alignment.topLeft : Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _appearance(context, value, key: sectionKeys[0]),
                        _library(context, value, key: sectionKeys[1]),
                        _playback(context, value, key: sectionKeys[2]),
                        _device(context, device, key: sectionKeys[3]),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _reset(ref, context, PreferenceSection.all),
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset all synced preferences'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
            if (!sidebar) return list;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionJumpList(
                  sections: _sections,
                  current: currentSection,
                  onSelected: jumpToSection,
                ),
                Expanded(child: list),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _appearance(BuildContext context, UserPreferences value, {Key? key}) =>
      _Section(
        key: key,
        title: 'Appearance and accessibility',
        reset: () => _reset(ref, context, PreferenceSection.appearance),
        children: [
          _SettingRow(
            title: 'Theme',
            help: 'Follow the system, or always use light or dark.',
            control: _Segments<UserPreferencesThemeEnum>(
              value: value.theme ?? UserPreferencesThemeEnum.system,
              options: const {
                UserPreferencesThemeEnum.system: (
                  'System',
                  Icons.brightness_auto_outlined,
                ),
                UserPreferencesThemeEnum.light: (
                  'Light',
                  Icons.light_mode_outlined,
                ),
                UserPreferencesThemeEnum.dark: (
                  'Dark',
                  Icons.dark_mode_outlined,
                ),
              },
              onChanged: (v) => _update(ref, context, (b) => b.theme = v),
            ),
          ),
          _SettingRow(
            title: 'Accent color',
            help: 'Used for highlights, selection and progress.',
            control: _AccentPicker(
              value: value.accentPreset ?? UserPreferencesAccentPresetEnum.blue,
              onChanged: (v) =>
                  _update(ref, context, (b) => b.accentPreset = v),
            ),
          ),
          _SettingRow(
            title: 'Density',
            help: 'Compact fits more rows on screen.',
            control: _Segments<UserPreferencesDensityEnum>(
              value: value.density ?? UserPreferencesDensityEnum.comfortable,
              options: const {
                UserPreferencesDensityEnum.comfortable: ('Comfortable', null),
                UserPreferencesDensityEnum.compact: ('Compact', null),
              },
              onChanged: (v) => _update(ref, context, (b) => b.density = v),
            ),
          ),
          _SettingRow(
            title: 'Keyboard shortcuts',
            help: 'Standard enables shortcuts such as Ctrl+1, Ctrl+2 and Ctrl+3 to switch sections.',
            control: _Segments<UserPreferencesKeyboardShortcutPresetEnum>(
              value:
                  value.keyboardShortcutPreset ??
                  UserPreferencesKeyboardShortcutPresetEnum.standard,
              options: const {
                UserPreferencesKeyboardShortcutPresetEnum.standard: (
                  'Standard',
                  null,
                ),
                UserPreferencesKeyboardShortcutPresetEnum.minimal: (
                  'Minimal',
                  null,
                ),
              },
              onChanged: (v) =>
                  _update(ref, context, (b) => b.keyboardShortcutPreset = v),
            ),
          ),
          _TextSetting(
            label: 'Locale for formatting',
            help: 'The interface text is currently in English. This locale setting controls supported date and number formatting.',
            value: value.locale ?? 'en',
            maxLength: 30,
            onSubmitted: (v) =>
                _update(ref, context, (b) => b.locale = v.trim()),
          ),
        ],
      );

  Widget _library(
    BuildContext context,
    UserPreferences value, {
    Key? key,
  }) => _Section(
    key: key,
    title: 'Libraries and discovery',
    reset: () => _reset(ref, context, PreferenceSection.library),
    children: [
      _SettingRow(
        title: 'Library layout',
        help: 'How libraries and folders are shown unless a folder remembers its own view.',
        control: _Segments<UserPreferencesLibraryLayoutEnum>(
          value: value.libraryLayout ?? UserPreferencesLibraryLayoutEnum.grid,
          options: const {
            UserPreferencesLibraryLayoutEnum.grid: (
              'Grid',
              Icons.grid_view_outlined,
            ),
            UserPreferencesLibraryLayoutEnum.list: (
              'List',
              Icons.view_list_outlined,
            ),
          },
          onChanged: (v) => _update(ref, context, (b) => b.libraryLayout = v),
        ),
      ),
      _SettingRow(
        title: 'Default sort',
        help: 'Order used when a folder has no saved view.',
        control: _Segments<UserPreferencesDefaultSortEnum>(
          value: value.defaultSort ?? UserPreferencesDefaultSortEnum.byName,
          options: const {
            UserPreferencesDefaultSortEnum.byName: ('Name', null),
            UserPreferencesDefaultSortEnum.date: ('Date', null),
            UserPreferencesDefaultSortEnum.size: ('Size', null),
          },
          onChanged: (v) => _update(ref, context, (b) => b.defaultSort = v),
        ),
      ),
      _SettingRow(
        title: 'Sort order',
        control: _Segments<UserPreferencesDefaultSortOrderEnum>(
          value:
              value.defaultSortOrder ?? UserPreferencesDefaultSortOrderEnum.asc,
          options: const {
            UserPreferencesDefaultSortOrderEnum.asc: (
              'Ascending',
              Icons.arrow_upward,
            ),
            UserPreferencesDefaultSortOrderEnum.desc: (
              'Descending',
              Icons.arrow_downward,
            ),
          },
          onChanged: (v) =>
              _update(ref, context, (b) => b.defaultSortOrder = v),
        ),
      ),
      _SwitchRow(
        title: 'Show filename extensions',
        help: 'Show endings such as .mkv or .jpg in file names.',
        value: value.showFilenameExtensions ?? true,
        onChanged: (v) =>
            _update(ref, context, (b) => b.showFilenameExtensions = v),
      ),
      _SwitchRow(
        title: 'Show Continue Watching',
        help: 'Show recently played videos on the Libraries page.',
        value: value.showContinueWatching ?? true,
        onChanged: (v) =>
            _update(ref, context, (b) => b.showContinueWatching = v),
      ),
      _SwitchRow(
        title: 'Remember folder sort',
        help: 'Each folder keeps the layout and sort you last chose.',
        value: value.rememberFolderSort ?? true,
        onChanged: (v) =>
            _update(ref, context, (b) => b.rememberFolderSort = v),
      ),
      _PinnedLibraries(value: value),
      if ((value.folderPreferences?.length ?? 0) > 0)
        _SavedFolderViews(value: value),
      _SettingRow(
        title: 'Visible torrent columns',
        help: 'Columns shown in Discover results. Title is always shown.',
        stacked: true,
        control: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final column in UserPreferencesTorrentColumnsEnum.values)
              FilterChip(
                label: Text(_columnLabel(column)),
                selected: (value.torrentColumns?.contains(column) ?? false),
                onSelected: (selected) {
                  final columns =
                      value.torrentColumns?.toList() ??
                      <UserPreferencesTorrentColumnsEnum>[];
                  if (selected && !columns.contains(column)) {
                    columns.add(column);
                  }
                  if (!selected &&
                      column != UserPreferencesTorrentColumnsEnum.title) {
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
      ),
    ],
  );

  Widget _playback(
    BuildContext context,
    UserPreferences value, {
    Key? key,
  }) => _Section(
    key: key,
    title: 'Playback and photos',
    reset: () => _reset(ref, context, PreferenceSection.playback),
    children: [
      _NumberSetting(
        label: 'Default playback speed',
        help: 'Speed new videos start at.',
        value: value.defaultPlaybackSpeed ?? 1,
        min: .25,
        max: 4,
        step: .25,
        format: (v) => '${_trim(v)}×',
        onChanged: (v) =>
            _update(ref, context, (b) => b.defaultPlaybackSpeed = v),
      ),
      _SettingRow(
        title: 'Preferred playback mode',
        help: 'Built-in plays inside Briani. External hands the stream to another installed player.',
        control: _Segments<UserPreferencesPlaybackModeEnum>(
          value: value.playbackMode ?? UserPreferencesPlaybackModeEnum.internal,
          options: const {
            UserPreferencesPlaybackModeEnum.internal: ('Built-in', null),
            UserPreferencesPlaybackModeEnum.ask: ('Ask', null),
            UserPreferencesPlaybackModeEnum.external_: ('External', null),
          },
          onChanged: (v) => _update(ref, context, (b) => b.playbackMode = v),
        ),
      ),
      _SettingRow(
        title: 'Resume policy',
        help: 'What happens when a video has saved progress.',
        control: _Segments<UserPreferencesResumePolicyEnum>(
          value: value.resumePolicy ?? UserPreferencesResumePolicyEnum.ask,
          options: const {
            UserPreferencesResumePolicyEnum.ask: ('Ask', null),
            UserPreferencesResumePolicyEnum.always: ('Always', null),
            UserPreferencesResumePolicyEnum.never: ('Never', null),
          },
          onChanged: (v) => _update(ref, context, (b) => b.resumePolicy = v),
        ),
      ),
      _NumberSetting(
        label: 'Subtitle text scale',
        help: 'Size of subtitles in the built-in player.',
        value: value.subtitleScale ?? 1,
        min: .5,
        max: 3,
        step: .1,
        format: (v) => '${_trim(v)}×',
        onChanged: (v) => _update(ref, context, (b) => b.subtitleScale = v),
      ),
      _TextSetting(
        label: 'Preferred audio language',
        help: 'Language code such as en or fra. Leave empty to use the file’s default.',
        value: value.preferredAudioLanguage ?? '',
        maxLength: 50,
        onSubmitted: (v) => _update(
          ref,
          context,
          (b) => b.preferredAudioLanguage = v.trim().isEmpty ? null : v.trim(),
        ),
      ),
      _TextSetting(
        label: 'Preferred subtitle language',
        help: 'Language code such as en or fra. Leave empty to use the file’s default.',
        value: value.preferredSubtitleLanguage ?? '',
        maxLength: 50,
        onSubmitted: (v) => _update(
          ref,
          context,
          (b) =>
              b.preferredSubtitleLanguage = v.trim().isEmpty ? null : v.trim(),
        ),
      ),
      _NumberSetting(
        label: 'Slideshow interval (seconds)',
        help: 'Time each photo stays on screen during a slideshow.',
        value: (value.slideshowSeconds ?? 5).toDouble(),
        min: 1,
        max: 3600,
        step: 1,
        onChanged: (v) =>
            _update(ref, context, (b) => b.slideshowSeconds = v.round()),
      ),
    ],
  );

  Widget _device(
    BuildContext context,
    DevicePreferences device, {
    Key? key,
  }) => _Section(
    key: key,
    title: 'This device',
    subtitle: 'Stored only on this device.',
    reset: () => ref.read(devicePreferencesProvider.notifier).reset(),
    children: [
      _NumberSetting(
        label: 'Display scale',
        help: 'Scales text on this device only, on top of the system setting.',
        value: device.displayScale,
        min: .75,
        max: 2,
        step: .05,
        format: (v) => '${(v * 100).round()}%',
        onChanged: (v) => _deviceUpdate(ref, device.copyWith(displayScale: v)),
      ),
      _SettingRow(
        title: 'Device layout',
        help:
            'Automatic detects TV and phone layouts; override it for testing.',
        control: _Segments<DeviceModeOverride>(
          value: device.modeOverride,
          options: const {
            DeviceModeOverride.automatic: ('Automatic', null),
            DeviceModeOverride.mobile: ('Mobile', null),
            DeviceModeOverride.television: ('TV', null),
          },
          onChanged: (v) =>
              _deviceUpdate(ref, device.copyWith(modeOverride: v)),
        ),
      ),
      _SettingRow(
        title: 'Player cache',
        help: 'Memory used to buffer streams in the built-in player.',
        control: _Segments<PlayerCachePreset>(
          value: device.cachePreset,
          options: const {
            PlayerCachePreset.small: ('16 MiB', null),
            PlayerCachePreset.medium: ('32 MiB', null),
            PlayerCachePreset.large: ('64 MiB', null),
          },
          onChanged: (v) => _deviceUpdate(ref, device.copyWith(cachePreset: v)),
        ),
      ),
      _SettingRow(
        title: 'Hardware decoder',
        help: 'Use Safe or Disabled if videos show artifacts or fail to start.',
        control: _Segments<DecoderPreference>(
          value: device.hardwareDecoder,
          options: const {
            DecoderPreference.automatic: ('Automatic', null),
            DecoderPreference.safe: ('Safe', null),
            DecoderPreference.disabled: ('Off', null),
          },
          onChanged: (v) =>
              _deviceUpdate(ref, device.copyWith(hardwareDecoder: v)),
        ),
      ),
      _SwitchRow(
        title: 'Start fullscreen',
        help: 'Open the built-in player in fullscreen.',
        value: device.fullscreenByDefault,
        onChanged: (v) =>
            _deviceUpdate(ref, device.copyWith(fullscreenByDefault: v)),
      ),
      if (!Platform.isAndroid) ...[
        _NumberSetting(
          label: 'Window width',
          help: 'Initial window width in logical pixels.',
          value: device.windowWidth.toDouble(),
          min: 640,
          max: 3840,
          step: 80,
          format: (v) => '${v.round()} px',
          onChanged: (v) =>
              _deviceUpdate(ref, device.copyWith(windowWidth: v.round())),
        ),
        _NumberSetting(
          label: 'Window height',
          help: 'Initial window height in logical pixels.',
          value: device.windowHeight.toDouble(),
          min: 360,
          max: 2160,
          step: 40,
          format: (v) => '${v.round()} px',
          onChanged: (v) =>
              _deviceUpdate(ref, device.copyWith(windowHeight: v.round())),
        ),
      ],
      const _GroupLabel('External player'),
      _TextSetting(
        label: 'Preferred installed player',
        help: 'Name or app package of the player offered first in Play with.',
        value: device.preferredPlayer ?? '',
        maxLength: 128,
        onSubmitted: (v) => _deviceUpdate(
          ref,
          device.copyWith(preferredPlayer: v.trim().isEmpty ? null : v.trim()),
        ),
      ),
      _TextSetting(
        label: 'Player executable / app path',
        help: 'Absolute path to the player program on this computer.',
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
            device.copyWith(executablePath: input.isEmpty ? null : input),
          );
        },
      ),
      _TextSetting(
        label: 'Player arguments (one per line; exactly one {url})',
        help: 'Passed to the player without a shell. {url} is replaced by the playback address.',
        value: device.arguments.join('\n'),
        maxLength: 8192,
        multiline: true,
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
  );
}

String _trim(double value) =>
    value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

String _columnLabel(UserPreferencesTorrentColumnsEnum column) =>
    switch (column) {
      UserPreferencesTorrentColumnsEnum.title => 'Title',
      UserPreferencesTorrentColumnsEnum.size => 'Size',
      UserPreferencesTorrentColumnsEnum.seeders => 'Seeders',
      UserPreferencesTorrentColumnsEnum.leechers => 'Leechers',
      UserPreferencesTorrentColumnsEnum.peers => 'Peers',
      UserPreferencesTorrentColumnsEnum.provider => 'Indexer',
      UserPreferencesTorrentColumnsEnum.publishedAt => 'Published',
      _ => _enumLabel(column),
    };

/// A titled group of settings in a single tonal card, with its own Reset.
class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.children,
    required this.reset,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Future<void> Function() reset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: theme.textTheme.titleLarge),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Reset $title',
                  child: TextButton.icon(
                    onPressed: () => reset(),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0 &&
                      children[i] is! _GroupLabel &&
                      children[i - 1] is! _GroupLabel)
                    const Divider(indent: 20, endIndent: 20),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Title and help text with a control: side by side on wide rows, stacked
/// on narrow ones.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.control,
    this.help,
    this.stacked = false,
  });
  final String title;
  final String? help;
  final Widget control;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        if (help != null) ...[
          const SizedBox(height: 2),
          Text(
            help!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (stacked || constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 12), control],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 24),
              control,
            ],
          );
        },
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.help,
  });
  final String title;
  final String? help;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: help == null
        ? null
        : Text(
            help!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
    value: value,
    onChanged: onChanged,
    shape: const RoundedRectangleBorder(),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
  );
}

/// Single-choice segmented control over a small, fixed set of options.
class _Segments<T extends Object> extends StatelessWidget {
  const _Segments({
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final T value;
  final Map<T, (String, IconData?)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<T>(
    showSelectedIcon: false,
    segments: [
      for (final entry in options.entries)
        ButtonSegment<T>(
          value: entry.key,
          label: Text(entry.value.$1),
          icon: entry.value.$2 == null ? null : Icon(entry.value.$2, size: 18),
        ),
    ],
    selected: {value},
    onSelectionChanged: (selection) {
      if (selection.isNotEmpty && selection.first != value) {
        onChanged(selection.first);
      }
    },
  );
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.value, required this.onChanged});
  final UserPreferencesAccentPresetEnum value;
  final ValueChanged<UserPreferencesAccentPresetEnum> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in UserPreferencesAccentPresetEnum.values)
          Builder(
            builder: (context) {
              final scheme = ColorScheme.fromSeed(
                seedColor: accentSeed(preset),
                brightness: brightness,
              );
              final selected = preset == value;
              final name = _enumLabel(preset);
              return Tooltip(
                message: name[0].toUpperCase() + name.substring(1),
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: '$name accent',
                  child: FocusOutline(
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onChanged(preset),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? Icon(
                                Icons.check,
                                color: scheme.onPrimary,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _PinnedLibraries extends ConsumerWidget {
  const _PinnedLibraries({required this.value});
  final UserPreferences value;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _SettingRow(
    title: 'Pinned libraries',
    help: 'Pinned libraries are listed first.',
    stacked: true,
    control: ref
        .watch(permittedPreferenceLibrariesProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) =>
              const Text('Library pins are unavailable right now.'),
          data: (libraries) {
            final pinned = value.pinnedLibraryIds?.toList() ?? <String>[];
            if (libraries.isEmpty) {
              return const Text('No libraries are available to this account.');
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final library in libraries)
                  FilterChip(
                    avatar: pinned.contains(library.id)
                        ? null
                        : const Icon(Icons.push_pin_outlined, size: 16),
                    label: Text(library.name),
                    selected: pinned.contains(library.id),
                    onSelected: (selected) {
                      final ids = [...pinned];
                      if (selected && !ids.contains(library.id)) {
                        ids.add(library.id);
                      }
                      if (!selected) ids.remove(library.id);
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
  );
}

class _SavedFolderViews extends ConsumerWidget {
  const _SavedFolderViews({required this.value});
  final UserPreferences value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders =
        value.folderPreferences?.toList() ??
        <UserPreferencesFolderPreferencesInner>[];
    final names = {
      for (final library
          in ref.watch(permittedPreferenceLibrariesProvider).asData?.value ??
              const <ModelLibrary>[])
        library.id: library.name,
    };
    return ExpansionTile(
      shape: const RoundedRectangleBorder(),
      collapsedShape: const RoundedRectangleBorder(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(
        'Saved folder views',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        '${folders.length} folder${folders.length == 1 ? '' : 's'} remember their own layout and sort.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      children: [
        for (var index = 0; index < folders.length; index++)
          _FolderPreferenceRow(
            folders: folders,
            index: index,
            libraryName: names[folders[index].libraryId] ?? 'Library',
          ),
      ],
    );
  }
}

class _FolderPreferenceRow extends ConsumerWidget {
  const _FolderPreferenceRow({
    required this.folders,
    required this.index,
    required this.libraryName,
  });
  final List<UserPreferencesFolderPreferencesInner> folders;
  final int index;
  final String libraryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = folders[index];
    void replace(UserPreferencesFolderPreferencesInner updated) =>
        _replaceFolderPreference(ref, context, [...folders], index, updated);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$libraryName · ${folder.folderId == null ? 'Library root' : 'Folder ${folder.folderId}'}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _Segments<UserPreferencesFolderPreferencesInnerLayoutEnum>(
                value: folder.layout,
                options: const {
                  UserPreferencesFolderPreferencesInnerLayoutEnum.grid: (
                    'Grid',
                    null,
                  ),
                  UserPreferencesFolderPreferencesInnerLayoutEnum.list: (
                    'List',
                    null,
                  ),
                },
                onChanged: (layout) =>
                    replace(folder.rebuild((b) => b.layout = layout)),
              ),
              _Segments<UserPreferencesFolderPreferencesInnerSortEnum>(
                value: folder.sort,
                options: const {
                  UserPreferencesFolderPreferencesInnerSortEnum.byName: (
                    'Name',
                    null,
                  ),
                  UserPreferencesFolderPreferencesInnerSortEnum.date: (
                    'Date',
                    null,
                  ),
                  UserPreferencesFolderPreferencesInnerSortEnum.size: (
                    'Size',
                    null,
                  ),
                },
                onChanged: (sort) =>
                    replace(folder.rebuild((b) => b.sort = sort)),
              ),
              _Segments<UserPreferencesFolderPreferencesInnerOrderEnum>(
                value: folder.order,
                options: const {
                  UserPreferencesFolderPreferencesInnerOrderEnum.asc: (
                    'Asc',
                    null,
                  ),
                  UserPreferencesFolderPreferencesInnerOrderEnum.desc: (
                    'Desc',
                    null,
                  ),
                },
                onChanged: (order) =>
                    replace(folder.rebuild((b) => b.order = order)),
              ),
            ],
          ),
        ],
      ),
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

/// A text value saved explicitly with Enter or the Save button, so partial
/// input is never written to the server.
class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.label,
    required this.value,
    required this.maxLength,
    required this.onSubmitted,
    this.help,
    this.multiline = false,
  });
  final String label;
  final String? help;
  final String value;
  final int maxLength;
  final bool multiline;
  final ValueChanged<String> onSubmitted;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _TextSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, current, _) {
        final dirty = current.text != widget.value;
        return TextField(
          controller: _controller,
          maxLength: widget.maxLength,
          minLines: widget.multiline ? 2 : 1,
          maxLines: widget.multiline ? 6 : 1,
          keyboardType: widget.multiline
              ? TextInputType.multiline
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.help,
            helperMaxLines: 3,
            counterText: '',
            suffixIcon: dirty
                ? IconButton(
                    tooltip: 'Save ${widget.label}',
                    icon: const Icon(Icons.check),
                    onPressed: () => widget.onSubmitted(_controller.text),
                  )
                : null,
          ),
          onSubmitted: widget.multiline ? null : widget.onSubmitted,
        );
      },
    ),
  );
}

class _NumberSetting extends StatefulWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.help,
    this.format,
  });
  final String label;
  final String? help;
  final double value, min, max, step;
  final ValueChanged<double> onChanged;
  final String Function(double value)? format;
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

  String _label(double value) =>
      widget.format?.call(value) ??
      value.toStringAsFixed(widget.step < 1 ? 2 : 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if ((widget.max - widget.min) / widget.step > 100) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: TextFormField(
          key: ValueKey('${widget.label}:${widget.value}'),
          initialValue: widget.value.round().toString(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.help == null
                ? 'From ${widget.min.round()} to ${widget.max.round()}. Press Enter to save.'
                : '${widget.help} From ${widget.min.round()} to ${widget.max.round()}.',
            helperMaxLines: 2,
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: theme.textTheme.titleSmall),
                    if (widget.help != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.help!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _label(_draft),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: _draft,
            min: widget.min,
            max: widget.max,
            divisions: ((widget.max - widget.min) / widget.step).round(),
            label: _label(_draft),
            semanticFormatterCallback: _label,
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
        icon: const Icon(Icons.restart_alt),
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

import 'dart:async';
import 'dart:math' as math;

// The generated API exposes built collection request builders.
// ignore_for_file: depend_on_referenced_packages

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme.dart';
import '../../core/session/client_session.dart';
import '../../core/input/route_activity.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/widgets/adaptive.dart';
import '../../core/widgets/states.dart';
import 'download_formatters.dart';
import 'download_rules.dart';
import 'transfer_settings_dialog.dart';
import 'transfer_widgets.dart';

class DownloadDetailsScreen extends ConsumerStatefulWidget {
  const DownloadDetailsScreen({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<DownloadDetailsScreen> createState() =>
      _DownloadDetailsScreenState();
}

class _DownloadDetailsScreenState extends ConsumerState<DownloadDetailsScreen>
    with WidgetsBindingObserver {
  Download? _download;
  List<DownloadFile> _files = [];
  DownloadSettings? _settings;
  final Map<String, bool> _selected = {};
  final Map<String, FileChoicePriorityEnum> _priority = {};
  Timer? _poll;
  String? _error;
  bool _loading = true;
  bool _savingSelection = false;
  bool _managing = false;
  bool _canManageLibrary = false;
  bool _canDownloadLibrary = false;
  bool _busy = false;
  bool _visible = true;
  int _loadEpoch = 0;
  CancelToken? _loadCancel;
  DateTime? _metadataLoadedAt;
  bool _selectionInitialized = false;
  int _firstSelectedVideo = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isForegroundLifecycle(state)) {
      _startPolling();
      if (RouteActivity.isVisible(context)) _load(quiet: true);
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (RouteActivity.isVisible(context)) _load(quiet: true);
    });
  }

  @override
  void didUpdateWidget(covariant DownloadDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) {
      _loadCancel?.cancel();
      _loadEpoch++;
      _busy = false;
      _download = null;
      _files = [];
      _settings = null;
      _selected.clear();
      _priority.clear();
      _metadataLoadedAt = null;
      _selectionInitialized = false;
      _managing = false;
      _canManageLibrary = false;
      _canDownloadLibrary = false;
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = RouteActivity.isVisible(context);
    if (visible && !_visible) {
      Future.microtask(() {
        if (mounted) _load(quiet: true);
      });
    }
    _visible = visible;
  }

  @override
  void dispose() {
    _loadEpoch++;
    _loadCancel?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (_busy && quiet) return;
    _loadCancel?.cancel();
    final cancel = _loadCancel = CancelToken();
    final epoch = ++_loadEpoch;
    final id = widget.requestId;
    final api = ref.read(activeApiProvider);
    if (api == null) return;
    bool current() =>
        mounted &&
        epoch == _loadEpoch &&
        id == widget.requestId &&
        !cancel.isCancelled &&
        identical(ref.read(activeApiProvider), api);
    _busy = true;
    if (!quiet && !_loading) setState(() => _loading = true);
    try {
      final response = await Future.wait([
        api.getDownloadsApi().getDownload(id: id, cancelToken: cancel),
        api.getDownloadsApi().listDownloadFiles(id: id, cancelToken: cancel),
      ]);
      if (!current()) return;
      final download = response[0].data as Download?;
      final files =
          (response[1].data as Iterable?)?.cast<DownloadFile>().toList() ??
          <DownloadFile>[];
      final refreshMetadata =
          !quiet ||
          _metadataLoadedAt == null ||
          DateTime.now().difference(_metadataLoadedAt!) >=
              const Duration(minutes: 1);
      var settings = _settings;
      var canManageLibrary = _canManageLibrary;
      var canDownloadLibrary = _canDownloadLibrary;
      final user = ref.read(clientSessionProvider)?.tokens.user;
      if (refreshMetadata) {
        final libraryResponse = await api.getLibrariesApi().listLibraries(
          cancelToken: cancel,
        );
        final library = libraryResponse.data
            ?.where((x) => x.id == download?.libraryId)
            .firstOrNull;
        canManageLibrary =
            library?.capabilities.manage == true ||
            user?.role == UserRoleEnum.administrator;
        canDownloadLibrary =
            library?.capabilities.download == true ||
            user?.id == download?.ownerId;
        try {
          settings = (await api.getDownloadsApi().getDownloadSettings(
            id: id,
            cancelToken: cancel,
          )).data;
        } on DioException catch (error) {
          if (cancel.isCancelled) rethrow;
          settings = null;
          if (![403, 404].contains(error.response?.statusCode)) rethrow;
        }
      }
      if (!current()) return;
      setState(() {
        _download = download;
        _files = files;
        _settings = settings;
        _canManageLibrary = canManageLibrary;
        _canDownloadLibrary = canDownloadLibrary;
        _managing = canManageLibrary || user?.id == download?.ownerId;
        if (refreshMetadata) _metadataLoadedAt = DateTime.now();
        final ids = files.map((x) => x.id).toSet();
        _selected.removeWhere((key, _) => !ids.contains(key));
        _priority.removeWhere((key, _) => !ids.contains(key));
        for (final file in files) {
          _selected.putIfAbsent(file.id, () => file.selected);
          _priority.putIfAbsent(
            file.id,
            () => FileChoicePriorityEnum.valueOf(file.priority.name),
          );
        }
        if (!_selectionInitialized && files.isNotEmpty) {
          if (files.every((f) => !(_selected[f.id] ?? f.selected))) {
            final video = files
                .where((f) => f.kind == DownloadFileKindEnum.video)
                .firstOrNull;
            if (video != null) _selected[video.id] = true;
          }
          _selectionInitialized = true;
        }
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!current()) return;
      setState(() {
        if (error is DioException &&
            [401, 403, 404].contains(error.response?.statusCode)) {
          _download = null;
          _files = [];
          _settings = null;
          _managing = false;
          _canManageLibrary = false;
          _canDownloadLibrary = false;
        }
        _error = clientError(error);
        _loading = false;
      });
    } finally {
      if (epoch == _loadEpoch) _busy = false;
    }
  }

  Future<void> _submitSelection() async {
    final download = _download;
    if (download == null || !_canDownloadLibrary || _savingSelection) return;
    final selectedVideos = _files
        .where(
          (f) =>
              f.kind == DownloadFileKindEnum.video &&
              (_selected[f.id] ?? f.selected),
        )
        .toList();
    if (selectedVideos.length > 1) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Sequential download order'),
          content: const Text(
            'Selected files download sequentially. A later video may wait until earlier selected videos have downloaded. Select one video now and add others later to reduce that wait.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Go back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
    }
    setState(() => _savingSelection = true);
    try {
      final choices = _files
          .map(
            (file) => FileChoice(
              (b) => b
                ..fileId = file.id
                ..selected = _selected[file.id] ?? file.selected
                ..priority =
                    _priority[file.id] ?? FileChoicePriorityEnum.normal,
            ),
          )
          .toList();
      await requireActiveApi(ref).getDownloadsApi().selectDownloadFiles(
        id: download.id,
        downloadSelection: DownloadSelection(
          (b) => b
            ..files = ListBuilder(choices)
            ..autoStart = true
            ..version = download.version,
        ),
        idempotencyKey: const Uuid().v4(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File selection queued.')));
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(clientError(error))));
      }
    } finally {
      if (mounted) setState(() => _savingSelection = false);
    }
  }

  Future<void> _action(
    DownloadActionActionEnum action, {
    bool deleteData = false,
  }) async {
    final download = _download;
    if (download == null) return;
    try {
      await requireActiveApi(ref).getDownloadsApi().actOnDownload(
        id: download.id,
        downloadAction: DownloadAction(
          (b) => b
            ..action = action
            ..version = download.version
            ..deleteData = deleteData
            ..confirmation = deleteData ? 'DELETE DATA' : null,
        ),
        idempotencyKey: const Uuid().v4(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${stateLabel(action.name)} requested.')),
        );
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(clientError(error))));
      }
    }
  }

  Future<void> _deletePayload() async {
    final requestId = widget.requestId;
    final api = ref.read(activeApiProvider);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined),
        title: const Text('Delete torrent payload?'),
        content: const Text(
          'This permanently removes the managed download data. Other users or visible library links may still refer to it. Continue only if you have reviewed those consequences.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete payload'),
          ),
        ],
      ),
    );
    if (accepted == true &&
        mounted &&
        widget.requestId == requestId &&
        identical(ref.read(activeApiProvider), api)) {
      await _action(DownloadActionActionEnum.remove, deleteData: true);
    }
  }

  Future<void> _editSettings() async {
    final download = _download;
    final settings = _settings;
    final api = ref.read(activeApiProvider);
    final requestId = widget.requestId;
    bool current() =>
        mounted &&
        widget.requestId == requestId &&
        identical(ref.read(activeApiProvider), api);
    if (download == null || settings == null || !_managing) return;
    final draft = await showDialog<TransferSettingsDraft>(
      context: context,
      builder: (_) => TransferSettingsDialog(
        settings: settings,
        locale: ref.read(userPreferencesProvider).asData?.value.locale,
      ),
    );
    if (draft == null || !mounted || !current() || api == null) return;
    int? readInt(String value) =>
        value.trim().isEmpty ? null : int.tryParse(value.trim());
    final dl = readInt(draft.downloadLimit),
        ul = readInt(draft.uploadLimit),
        minutes = readInt(draft.seedTime),
        position = readInt(draft.queue);
    final ratioValue = draft.ratio.trim().isEmpty
        ? null
        : double.tryParse(draft.ratio.trim());
    if ((draft.downloadLimit.trim().isNotEmpty && dl == null) ||
        (draft.uploadLimit.trim().isNotEmpty && ul == null) ||
        (draft.seedTime.trim().isNotEmpty && minutes == null) ||
        (draft.queue.trim().isNotEmpty && position == null) ||
        (draft.ratio.trim().isNotEmpty && ratioValue == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid numeric limits.')),
      );
      return;
    }
    try {
      final updated = await api.getDownloadsApi().updateDownloadSettings(
        id: download.id,
        downloadSettings: DownloadSettings(
          (b) => b
            ..version = settings.version
            ..downloadLimitBytesPerSecond = dl
            ..uploadLimitBytesPerSecond = ul
            ..ratioLimit = ratioValue
            ..seedTimeMinutes = minutes
            ..queuePosition = position
            ..tags = ListBuilder(
              draft.tags
                  .split(',')
                  .map((x) => x.trim())
                  .where((x) => x.isNotEmpty),
            ),
        ),
      );
      if (current()) setState(() => _settings = updated.data ?? settings);
    } catch (error) {
      if (mounted && current()) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(clientError(error))));
      }
    }
  }

  bool get _needsSelection =>
      _download?.state == DownloadStateEnum.awaitingSelection ||
      _download?.state == DownloadStateEnum.metadataPending;

  @override
  Widget build(BuildContext context) {
    if (_loading && _download == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Download details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_download == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Download details')),
        body: EmptyState.error(
          title: 'Download unavailable',
          message: _error ?? 'This download could not be found.',
          onRetry: _load,
        ),
      );
    }
    _firstSelectedVideo = _files.indexWhere(
      (f) =>
          f.kind == DownloadFileKindEnum.video &&
          (_selected[f.id] ?? f.selected),
    );
    final download = _download!;
    final locale = ref.watch(userPreferencesProvider).asData?.value.locale;
    final ownsRequest =
        ref.read(clientSessionProvider)?.tokens.user.id == download.ownerId;
    final total = download.selectedBytes;
    final fraction = total == null || total <= 0
        ? null
        : (download.downloadedSelectedBytes / total).clamp(0.0, 1.0).toDouble();
    final canDeletePayload = _canManageLibrary && _managing;
    final selecting =
        _needsSelection && _canDownloadLibrary && _files.isNotEmpty;
    final multipleVideos =
        _files
            .where(
              (f) =>
                  f.kind == DownloadFileKindEnum.video &&
                  (_selected[f.id] ?? f.selected),
            )
            .length >
        1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download details'),
        actions: [
          IconButton(
            tooltip: 'Refresh details',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final side = math.max(
                    pageGutters(context).left,
                    (constraints.maxWidth - _detailsMaxWidth) / 2,
                  );
                  final padding = EdgeInsets.symmetric(horizontal: side);
                  return CustomScrollView(
                    key: PageStorageKey('download-${widget.requestId}'),
                    slivers: [
                      SliverPadding(
                        padding: padding.copyWith(top: 8),
                        sliver: SliverList.list(
                          children: _header(
                            download,
                            fraction,
                            locale,
                            ownsRequest: ownsRequest,
                            canDeletePayload: canDeletePayload,
                            contentWidth: constraints.maxWidth - side * 2,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: padding,
                        sliver: SliverList.builder(
                          itemCount: _files.length,
                          findChildIndexCallback: (key) {
                            if (key is! ValueKey<String>) return null;
                            final index = _files.indexWhere(
                              (file) => file.id == key.value,
                            );
                            return index < 0 ? null : index;
                          },
                          itemBuilder: (context, index) => _fileRow(
                            _files[index],
                            index,
                            locale,
                            last: index == _files.length - 1,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: padding.copyWith(top: 12, bottom: 32),
                        sliver: SliverToBoxAdapter(
                          child:
                              !selecting &&
                                  download.sequential &&
                                  multipleVideos
                              ? const NoticeBanner(
                                  icon: Icons.low_priority,
                                  message: 'Sequential order applies to selected files. A later video may wait for earlier selected videos.',
                                )
                              : null,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (selecting)
            _selectionBar(
              locale,
              sequentialNote: download.sequential && multipleVideos,
            ),
        ],
      ),
    );
  }

  static const _detailsMaxWidth = 960.0;

  List<Widget> _header(
    Download download,
    double? fraction,
    String? locale, {
    required bool ownsRequest,
    required bool canDeletePayload,
    required double contentWidth,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final presentation = downloadStatePresentation(download.state);
    final transfer = stateLabel(download.transferState.name);
    final selectionControls =
        _needsSelection && _canDownloadLibrary && _files.isNotEmpty
        ? Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => _selectAll(true),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: () => _selectAll(false),
                child: const Text('Select none'),
              ),
            ],
          )
        : null;
    // With large text on narrow windows the selection controls move below
    // the section title instead of squeezing it.
    final controlsBesideTitle =
        contentWidth >=
        360 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final actions = _actionRow(
      download,
      ownsRequest: ownsRequest,
      canDeletePayload: canDeletePayload,
    );
    return [
      if (_error != null) ...[
        NoticeBanner(
          tone: NoticeTone.error,
          message: _error!,
          action: TextButton(onPressed: _load, child: const Text('Retry')),
        ),
        const SizedBox(height: 16),
      ],
      Text(
        download.name ?? 'Torrent metadata pending',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusPill(
            label: presentation.label,
            icon: presentation.icon,
            tone: presentation.tone,
          ),
          Text(
            download.sequential
                ? 'Transfer: $transfer · Sequential'
                : 'Transfer: $transfer',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          for (final tag in download.tags) TagPill(tag: tag),
        ],
      ),
      if (download.errorCode != null) ...[
        const SizedBox(height: 16),
        NoticeBanner(
          tone: NoticeTone.error,
          message: download.errorDetail ?? 'The download failed.',
        ),
      ],
      const SizedBox(height: 20),
      if (!_needsSelection) ...[
        _summary(download, fraction, locale),
        const SizedBox(height: 16),
      ],
      ?actions,
      const SizedBox(height: 28),
      SectionHeader(
        title: 'Files',
        trailing: selectionControls != null
            ? (controlsBesideTitle ? selectionControls : null)
            : _files.isEmpty
            ? null
            : Text(
                '${formatCount(_files.length, locale: locale)} ${_files.length == 1 ? 'file' : 'files'}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
      ),
      if (selectionControls != null && !controlsBesideTitle) ...[
        selectionControls,
        const SizedBox(height: 8),
      ],
      if (download.state == DownloadStateEnum.awaitingSelection &&
          _files.isNotEmpty) ...[
        const NoticeBanner(
          tone: NoticeTone.warning,
          icon: Icons.checklist,
          message: 'Choose files before payload transfer. Nothing downloads until you save your selection.',
        ),
        const SizedBox(height: 8),
      ],
      if (download.state == DownloadStateEnum.metadataPending) ...[
        const NoticeBanner(
          icon: Icons.hourglass_empty,
          message: 'Waiting for torrent metadata. Payload transfer will not start until file selection is confirmed.',
        ),
        const SizedBox(height: 8),
      ],
      if (_files.isEmpty && download.state != DownloadStateEnum.metadataPending)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No files are available in the server snapshot. Refresh to check for updates.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
    ];
  }

  void _selectAll(bool selected) => setState(() {
    for (final file in _files) {
      if (file.kind != DownloadFileKindEnum.other) {
        _selected[file.id] = selected;
      }
    }
  });

  Widget _summary(Download download, double? fraction, String? locale) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    final presentation = downloadStatePresentation(download.state);
    final total = download.selectedBytes;
    final complete = fraction != null && fraction >= 1;
    final tiles = [
      StatTile(
        label: 'Download speed',
        icon: Icons.arrow_downward,
        value: formatRate(download.downloadBps, locale: locale),
      ),
      StatTile(
        label: 'Upload speed',
        icon: Icons.arrow_upward,
        value: formatRate(download.uploadBps, locale: locale),
      ),
      StatTile(
        label: 'Connected seeders',
        icon: Icons.cloud_upload_outlined,
        value: formatCount(download.seedersConnected, locale: locale),
      ),
      StatTile(
        label: 'Connected peers',
        icon: Icons.people_outline,
        value: formatCount(download.peersConnected, locale: locale),
      ),
      StatTile(
        label: 'Time left',
        icon: Icons.schedule,
        value: formatEta(download.etaSeconds, locale: locale),
      ),
      StatTile(
        label: 'Import',
        icon: Icons.drive_file_move_outlined,
        value: stateLabel(download.importState.name),
        valueColor: download.importState == DownloadImportStateEnum.complete
            ? status.success
            : download.importState == DownloadImportStateEnum.failed
            ? scheme.error
            : null,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatBytes(
                            download.downloadedSelectedBytes,
                            locale: locale,
                          ),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFeatures: tabularFigures,
                          ),
                        ),
                        if (!complete)
                          TextSpan(
                            text: '  of ${formatBytes(total, locale: locale)}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFeatures: tabularFigures,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  fraction == null
                      ? '—'
                      : formatPercent(fraction, locale: locale),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFeatures: tabularFigures,
                    color: complete ? status.success : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (fraction != null)
              TransferProgressBar(
                value: fraction,
                minHeight: 8,
                color: switch (presentation.tone) {
                  PillTone.error => scheme.error,
                  PillTone.success => status.success,
                  PillTone.neutral => scheme.outline,
                  _ => null,
                },
              ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                // Six tiles in one row, two rows of three, or three of two,
                // whichever keeps every label readable.
                const gap = 16.0;
                final minTile =
                    140 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
                final columns = constraints.maxWidth >= minTile * 6 + gap * 5
                    ? 6
                    : constraints.maxWidth >= minTile * 3 + gap * 2
                    ? 3
                    : constraints.maxWidth >= minTile * 2 + gap
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final tile in tiles)
                      SizedBox(width: width, child: tile),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget? _actionRow(
    Download download, {
    required bool ownsRequest,
    required bool canDeletePayload,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final buttons = [
      if (_managing &&
          (download.transferState == DownloadTransferStateEnum.downloading ||
              download.transferState == DownloadTransferStateEnum.seeding))
        FilledButton.tonalIcon(
          onPressed: () => _action(DownloadActionActionEnum.pause),
          icon: const Icon(Icons.pause),
          label: const Text('Pause'),
        ),
      if (_managing && canResumeDownload(download))
        FilledButton.icon(
          onPressed: () => _action(DownloadActionActionEnum.resume),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Resume'),
        ),
      if (_managing &&
          (download.state == DownloadStateEnum.failed ||
              download.state == DownloadStateEnum.stalled))
        FilledButton.tonalIcon(
          onPressed: () => _action(DownloadActionActionEnum.retry),
          icon: const Icon(Icons.restart_alt),
          label: const Text('Retry'),
        ),
      if (ownsRequest)
        OutlinedButton.icon(
          onPressed: () => _removeRequest(download),
          icon: const Icon(Icons.remove_circle_outline),
          label: const Text('Remove request'),
        ),
    ];
    if (buttons.isEmpty && !_managing) return null;
    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label, {
      Color? color,
    }) => PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: color == null ? null : TextStyle(color: color)),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: buttons)),
        if (_managing) ...[
          IconButton(
            tooltip: 'Transfer settings',
            onPressed: _settings == null ? null : _editSettings,
            icon: const Icon(Icons.tune),
          ),
          PopupMenuButton<String>(
            tooltip: 'Advanced actions',
            onSelected: (value) {
              switch (value) {
                case 'reannounce':
                  _action(DownloadActionActionEnum.reannounce);
                case 'recheck':
                  _action(DownloadActionActionEnum.recheck);
                case 'delete':
                  _deletePayload();
              }
            },
            itemBuilder: (_) => [
              item(
                'reannounce',
                Icons.campaign_outlined,
                'Reannounce to trackers',
              ),
              item('recheck', Icons.fact_check_outlined, 'Recheck data'),
              if (canDeletePayload) ...[
                const PopupMenuDivider(),
                item(
                  'delete',
                  Icons.delete_forever_outlined,
                  'Delete payload…',
                  color: scheme.error,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _selectionBar(String? locale, {required bool sequentialNote}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _files
        .where((file) => _selected[file.id] ?? file.selected)
        .toList();
    final bytes = selected.fold<int>(0, (sum, file) => sum + file.sizeBytes);
    final count = selected.length;
    // A floating rounded bar, inset from the page edges, so it sits cleanly
    // inside the rounded content panel instead of running under its corners.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: pageGutters(context)
                .add(const EdgeInsets.symmetric(vertical: 12)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _detailsMaxWidth),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final summary = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          count == 0
                              ? 'No files selected'
                              : '${formatCount(count, locale: locale)} ${count == 1 ? 'file' : 'files'} selected · ${formatBytes(bytes, locale: locale)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontFeatures: tabularFigures,
                          ),
                        ),
                        if (sequentialNote)
                          Text(
                            'Later videos may wait for earlier ones.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: StatusColors.of(context).warning,
                            ),
                          ),
                      ],
                    );
                    final save = FilledButton.icon(
                      onPressed: _savingSelection ? null : _submitSelection,
                      icon: _savingSelection
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Save selection and start'),
                    );
                    final scale = MediaQuery.textScalerOf(context)
                        .scale(1)
                        .clamp(1.0, 2.0);
                    // Side by side when both fit; stacked for narrow windows
                    // and large text.
                    if (constraints.maxWidth >= 360 * scale) {
                      return Row(
                        children: [
                          Expanded(child: summary),
                          const SizedBox(width: 12),
                          save,
                        ],
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [summary, const SizedBox(height: 8), save],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compact inline priority control shown under a selected file's name.
  Widget _priorityPicker(DownloadFile file) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: 'File priority',
      child: DropdownButton<FileChoicePriorityEnum>(
        value:
            _priority[file.id] ??
            FileChoicePriorityEnum.valueOf(file.priority.name),
        isDense: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
        icon: Icon(Icons.arrow_drop_down, color: scheme.primary),
        style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
        onChanged: (value) {
          if (value != null) setState(() => _priority[file.id] = value);
        },
        items: FileChoicePriorityEnum.values
            .whereType<FileChoicePriorityEnum>()
            .map(
              (value) => DropdownMenuItem<FileChoicePriorityEnum>(
                value: value,
                child: Text('${stateLabel(value.name)} priority'),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _fileRow(
    DownloadFile file,
    int index,
    String? locale, {
    required bool last,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectable = file.kind != DownloadFileKindEnum.other;
    final checked = _selected[file.id] ?? file.selected;
    final selectionMode = _needsSelection && _canDownloadLibrary;
    final canToggle = selectionMode && selectable;
    final progress = file.sizeBytes <= 0
        ? null
        : (file.downloadedBytes / file.sizeBytes).clamp(0.0, 1.0).toDouble();
    final laterVideo =
        file.kind == DownloadFileKindEnum.video &&
        _firstSelectedVideo >= 0 &&
        index > _firstSelectedVideo;
    final playable =
        file.kind == DownloadFileKindEnum.video &&
        file.selected &&
        (file.playbackState == DownloadFilePlaybackStateEnum.eligible ||
            file.playbackState == DownloadFilePlaybackStateEnum.complete);
    final transferring =
        !_needsSelection &&
        file.selected &&
        file.sizeBytes > 0 &&
        file.downloadedBytes < file.sizeBytes;
    final playback = _needsSelection
        ? null
        : filePlaybackPresentation(file.playbackState);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: tabularFigures,
    );
    return Column(
      key: ValueKey(file.id),
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusOutline(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: InkWell(
            // The checkbox is the focus target; the row is a larger pointer
            // target for the same toggle.
            canRequestFocus: false,
            borderRadius: BorderRadius.circular(12),
            onTap: canToggle
                ? () => setState(() => _selected[file.id] = !checked)
                : null,
            child: Padding(
              padding: EdgeInsets.fromLTRB(selectionMode ? 0 : 12, 10, 4, 10),
              child: Row(
                children: [
                  if (selectionMode)
                    SizedBox(
                      width: 48,
                      child: canToggle
                          ? Checkbox(
                              value: checked,
                              onChanged: (value) => setState(
                                () => _selected[file.id] = value ?? false,
                              ),
                            )
                          : null,
                    ),
                  Semantics(
                    label: fileKindLabel(file.kind),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        fileKindIcon(file.kind),
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: selectionMode && !selectable
                                ? scheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              transferring
                                  ? '${formatBytes(file.downloadedBytes, locale: locale)} of ${formatBytes(file.sizeBytes, locale: locale)}'
                                  : formatBytes(file.sizeBytes, locale: locale),
                              style: muted,
                            ),
                            if (canToggle && checked) _priorityPicker(file),
                            if (playback != null)
                              StatusPill(
                                label: playback.label,
                                icon: playback.icon,
                                tone: playback.tone,
                                dense: true,
                              ),
                            if (selectionMode && !selectable)
                              Text('Not downloadable', style: muted),
                            if (laterVideo && checked)
                              IconMetric(
                                label: 'Note',
                                icon: Icons.low_priority,
                                value: 'May wait behind an earlier video',
                                color: StatusColors.of(context).warning,
                              ),
                          ],
                        ),
                        if (transferring) ...[
                          const SizedBox(height: 8),
                          TransferProgressBar(
                            value: progress ?? 0,
                            minHeight: 4,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatBytes(file.contiguousBytes, locale: locale)} contiguous from the start',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontFeatures: tabularFigures,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (playable)
                    Padding(
                      key: const ValueKey('play'),
                      padding: const EdgeInsets.only(left: 8),
                      child: IconButton.filledTonal(
                        tooltip: 'Play',
                        onPressed: () => context.push(
                          '/play/downloadFile/${Uri.encodeComponent(file.id)}',
                        ),
                        icon: const Icon(Icons.play_arrow),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!last)
          Divider(
            height: 1,
            indent: selectionMode ? 48 : 12,
            endIndent: 12,
            color: scheme.outlineVariant.withValues(alpha: .6),
          ),
      ],
    );
  }

  Future<void> _removeRequest(Download download) async {
    if (ref.read(clientSessionProvider)?.tokens.user.id != download.ownerId) {
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this request?'),
        content: const Text(
          'This removes only this request. It does not delete the torrent payload or another user’s request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove request'),
          ),
        ],
      ),
    );
    if (accepted == true) await _action(DownloadActionActionEnum.remove);
  }
}

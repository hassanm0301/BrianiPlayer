import 'dart:async';

// The generated API exposes built collection request builders.
// ignore_for_file: depend_on_referenced_packages

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/session/client_session.dart';
import '../../core/input/route_activity.dart';
import '../../core/preferences/preferences_providers.dart';
import 'download_formatters.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});
  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with WidgetsBindingObserver {
  final _items = <Download>[];
  Timer? _poll;
  String? _cursor;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _busy = false;
  bool _truncated = false;
  int _capacity = 50, _loadEpoch = 0;
  CancelToken? _loadCancel;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(reset: true);
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      if (RouteActivity.isVisible(context)) _load(reset: true, quiet: true);
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (RouteActivity.isVisible(context)) _load(reset: true, quiet: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = RouteActivity.isVisible(context);
    if (visible && !_visible) {
      Future.microtask(() {
        if (mounted) _load(reset: true, quiet: true);
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

  Future<void> _load({required bool reset, bool quiet = false}) async {
    if (_busy && quiet) return;
    if (!reset && (_cursor == null || _loadingMore)) return;
    _loadCancel?.cancel();
    final cancel = _loadCancel = CancelToken();
    final epoch = ++_loadEpoch;
    final api = ref.read(activeApiProvider);
    if (api == null) return;
    bool current() =>
        mounted &&
        epoch == _loadEpoch &&
        !cancel.isCancelled &&
        identical(ref.read(activeApiProvider), api);
    _busy = true;
    final target = (reset ? _capacity : _capacity + 50).clamp(50, 10000);
    setState(() {
      _loading = _items.isEmpty;
      _loadingMore = !reset;
    });
    try {
      // Reconcile the whole loaded window atomically. A first-page response
      // alone cannot establish deletion of an item from a later page.
      final refreshed = <String, Download>{};
      final warnings = <String>{};
      String? cursor;
      var truncated = false;
      var received = 0;
      do {
        final page = (await api.getDownloadsApi().listDownloads(
          cursor: cursor,
          limit: (target - received).clamp(1, 200),
          cancelToken: cancel,
        )).data!;
        if (!current()) return;
        for (final item in page.items) {
          refreshed[item.id] = item;
        }
        received += page.items.length;
        warnings.addAll(page.warnings);
        truncated = truncated || page.truncated;
        final next = page.nextCursor;
        if (next == cursor && next != null) {
          throw StateError('Repeated page cursor');
        }
        cursor = next;
        if (page.items.isEmpty) break;
      } while (cursor != null && received < target);
      if (!current()) return;
      setState(() {
        if (warnings.isEmpty || refreshed.isNotEmpty) {
          _items
            ..clear()
            ..addAll(refreshed.values);
          _cursor = cursor;
          _capacity = target;
        }
        _truncated = truncated;
        _error = warnings.isEmpty ? null : warnings.join('\n');
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!current()) return;
      setState(() {
        _error = clientError(error);
        if (error is DioException &&
            [401, 403, 404].contains(error.response?.statusCode)) {
          _items.clear();
          _cursor = null;
        }
        _loading = false;
        _loadingMore = false;
      });
    } finally {
      if (epoch == _loadEpoch) _busy = false;
    }
  }

  Future<void> _action(
    Download download,
    DownloadActionActionEnum action,
  ) async {
    try {
      await requireActiveApi(ref).getDownloadsApi().actOnDownload(
        id: download.id,
        downloadAction: DownloadAction(
          (b) => b
            ..action = action
            ..version = download.version,
        ),
        idempotencyKey: const Uuid().v4(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${stateLabel(action.name)} requested.')),
        );
        await _load(reset: true, quiet: true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(clientError(error))));
      }
    }
  }

  Future<void> _confirmRemove(Download download) async {
    final removeData = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove download request?'),
        content: const Text(
          'This removes only your request. Downloaded data and other users’ requests remain available.',
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
    if (removeData != true) return;
    await _action(download, DownloadActionActionEnum.remove);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(userPreferencesProvider).asData?.value.locale;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Refresh downloads',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_truncated)
            const MaterialBanner(
              content: Text('Only the current bounded page is shown.'),
              actions: [],
            ),
          if (_error != null && !_loading)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => _load(reset: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Text(
                      _error == null
                          ? 'No downloads yet. Discover a release or add a magnet.'
                          : 'Downloads could not be loaded.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    child: ListView.builder(
                      key: const PageStorageKey('downloads'),
                      findChildIndexCallback: (key) {
                        if (key is! ValueKey<String>) return null;
                        final index = _items.indexWhere(
                          (item) => item.id == key.value,
                        );
                        return index < 0 ? null : index;
                      },
                      itemCount: _items.length,
                      itemBuilder: (context, index) =>
                          _downloadTile(_items[index], locale),
                    ),
                  ),
          ),
          if (_cursor != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _load(reset: false),
                icon: _loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: const Text('Load next page'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _downloadTile(Download download, String? locale) {
    final user = ref.read(clientSessionProvider)?.tokens.user;
    final ownsRequest = user?.id == download.ownerId;
    final canControl = ownsRequest || user?.role == UserRoleEnum.administrator;
    final total = download.selectedBytes;
    final progress = total == null || total <= 0
        ? null
        : (download.downloadedSelectedBytes / total).clamp(0.0, 1.0).toDouble();
    return Card(
      key: ValueKey(download.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ListTile(
        title: Text(
          download.name ?? 'Torrent metadata pending',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              '${stateLabel(download.state.name)} · ${formatBytes(download.downloadedSelectedBytes, locale: locale)} / ${formatBytes(total, locale: locale)}',
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text(
              '↓ ${formatRate(download.downloadBps, locale: locale)}   ↑ ${formatRate(download.uploadBps, locale: locale)}   Connected seeders ${formatCount(download.seedersConnected, locale: locale)} · peers ${formatCount(download.peersConnected, locale: locale)}',
            ),
            if (download.errorCode != null)
              Text(download.errorDetail ?? 'The download failed.'),
            if (download.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: download.tags
                    .map((tag) => Chip(label: Text(tag)))
                    .toList(),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          tooltip: 'Download actions',
          enabled: canControl,
          onSelected: (value) {
            switch (value) {
              case 'pause':
                _action(download, DownloadActionActionEnum.pause);
                break;
              case 'resume':
                _action(download, DownloadActionActionEnum.resume);
                break;
              case 'retry':
                _action(download, DownloadActionActionEnum.retry);
                break;
              case 'remove':
                _confirmRemove(download);
                break;
            }
          },
          itemBuilder: (_) => [
            if (canControl &&
                (download.transferState ==
                        DownloadTransferStateEnum.downloading ||
                    download.transferState ==
                        DownloadTransferStateEnum.seeding))
              const PopupMenuItem(value: 'pause', child: Text('Pause')),
            if (canControl &&
                download.transferState == DownloadTransferStateEnum.paused)
              const PopupMenuItem(value: 'resume', child: Text('Resume')),
            if (canControl &&
                (download.state == DownloadStateEnum.failed ||
                    download.state == DownloadStateEnum.stalled))
              const PopupMenuItem(value: 'retry', child: Text('Retry')),
            if (ownsRequest)
              const PopupMenuItem(
                value: 'remove',
                child: Text('Remove request'),
              ),
          ],
        ),
        onTap: () =>
            context.push('/downloads/${Uri.encodeComponent(download.id)}'),
      ),
    );
  }
}

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
    if (state == AppLifecycleState.resumed) {
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
    final draft = await showDialog<_DownloadSettingsDraft>(
      context: context,
      builder: (_) => _DownloadSettingsDialog(settings: settings),
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
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Download unavailable'),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(download.name ?? 'Download'),
        actions: [
          IconButton(
            tooltip: 'Refresh details',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_managing)
            IconButton(
              tooltip: 'Transfer settings',
              onPressed: _settings == null ? null : _editSettings,
              icon: const Icon(Icons.tune),
            ),
          if (_managing)
            PopupMenuButton<String>(
              tooltip: 'Advanced actions',
              onSelected: (value) {
                switch (value) {
                  case 'reannounce':
                    _action(DownloadActionActionEnum.reannounce);
                    break;
                  case 'recheck':
                    _action(DownloadActionActionEnum.recheck);
                    break;
                  case 'delete':
                    _deletePayload();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'reannounce',
                  child: Text('Reannounce to trackers'),
                ),
                const PopupMenuItem(
                  value: 'recheck',
                  child: Text('Recheck data'),
                ),
                if (canDeletePayload)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete payload…'),
                  ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: PageStorageKey('download-${widget.requestId}'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  if (_error != null)
                    MaterialBanner(
                      content: Text(_error!),
                      actions: [
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  Text(
                    'State: ${stateLabel(download.state.name)} · Transfer: ${stateLabel(download.transferState.name)} · Import: ${stateLabel(download.importState.name)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: fraction),
                  const SizedBox(height: 6),
                  Text(
                    '${formatBytes(download.downloadedSelectedBytes, locale: locale)} / ${formatBytes(total, locale: locale)} selected bytes · sequential ${download.sequential ? 'on' : 'off'}',
                  ),
                  Text(
                    '↓ ${formatRate(download.downloadBps, locale: locale)} · ↑ ${formatRate(download.uploadBps, locale: locale)} · Connected seeders ${formatCount(download.seedersConnected, locale: locale)} · peers ${formatCount(download.peersConnected, locale: locale)} · ETA ${formatEta(download.etaSeconds, locale: locale)}',
                  ),
                  if (download.errorCode != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(download.errorDetail ?? 'The download failed.'),
                      ),
                    ),
                  if (download.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: download.tags
                          .map((tag) => Chip(label: Text(tag)))
                          .toList(),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_managing &&
                          (download.transferState ==
                                  DownloadTransferStateEnum.downloading ||
                              download.transferState ==
                                  DownloadTransferStateEnum.seeding))
                        OutlinedButton.icon(
                          onPressed: () =>
                              _action(DownloadActionActionEnum.pause),
                          icon: const Icon(Icons.pause),
                          label: const Text('Pause'),
                        ),
                      if (_managing &&
                          download.transferState ==
                              DownloadTransferStateEnum.paused)
                        FilledButton.icon(
                          onPressed: () =>
                              _action(DownloadActionActionEnum.resume),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume'),
                        ),
                      if (_managing &&
                          (download.state == DownloadStateEnum.failed ||
                              download.state == DownloadStateEnum.stalled))
                        OutlinedButton.icon(
                          onPressed: () =>
                              _action(DownloadActionActionEnum.retry),
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Retry'),
                        ),
                      if (ownsRequest)
                        OutlinedButton.icon(
                          onPressed: () => _removeRequest(download),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Remove request'),
                        ),
                    ],
                  ),
                  const Divider(height: 28),
                  Text(
                    _needsSelection
                        ? 'Choose files before payload transfer'
                        : 'Files',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_download?.state == DownloadStateEnum.metadataPending)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Waiting for torrent metadata. Payload transfer will not start until file selection is confirmed.',
                      ),
                    ),
                  if (_files.isEmpty &&
                      download.state != DownloadStateEnum.metadataPending)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No files are available in the server snapshot. Refresh to check for updates.',
                      ),
                    ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) =>
                    _fileRow(_files[index], index, locale),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.list(
                children: [
                  if (_needsSelection &&
                      _canDownloadLibrary &&
                      _files.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FilledButton.icon(
                        onPressed: _savingSelection ? null : _submitSelection,
                        icon: _savingSelection
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Save selection and start'),
                      ),
                    ),
                  if (download.sequential &&
                      _files
                              .where(
                                (f) =>
                                    f.kind == DownloadFileKindEnum.video &&
                                    (_selected[f.id] ?? f.selected),
                              )
                              .length >
                          1)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Sequential order applies to selected files. A later video may wait for earlier selected videos.',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileRow(DownloadFile file, int index, String? locale) {
    final selectable = file.kind != DownloadFileKindEnum.other;
    final checked = _selected[file.id] ?? file.selected;
    final canToggle = _needsSelection && _canDownloadLibrary && selectable;
    final progress = file.sizeBytes <= 0
        ? null
        : (file.downloadedBytes / file.sizeBytes).clamp(0.0, 1.0).toDouble();
    final laterVideo =
        file.kind == DownloadFileKindEnum.video &&
        _firstSelectedVideo >= 0 &&
        index > _firstSelectedVideo;
    final leading = canToggle
        ? Checkbox(
            value: checked,
            onChanged: (value) =>
                setState(() => _selected[file.id] = value ?? false),
          )
        : Icon(_kindIcon(file.kind));
    final title = Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis);
    final subtitle = Text(
      '${file.kind.name} · ${formatBytes(file.sizeBytes, locale: locale)} · ${stateLabel(file.playbackState.name)}${laterVideo && checked ? ' · may wait behind earlier video' : ''}',
    );
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canToggle && checked)
          DropdownButton<FileChoicePriorityEnum>(
            value:
                _priority[file.id] ??
                FileChoicePriorityEnum.valueOf(file.priority.name),
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _priority[file.id] = value);
              }
            },
            items: FileChoicePriorityEnum.values
                .whereType<FileChoicePriorityEnum>()
                .map(
                  (value) => DropdownMenuItem<FileChoicePriorityEnum>(
                    value: value,
                    child: Text(value.name),
                  ),
                )
                .toList(),
          ),
        if (file.kind == DownloadFileKindEnum.video &&
            file.selected &&
            (file.playbackState == DownloadFilePlaybackStateEnum.eligible ||
                file.playbackState == DownloadFilePlaybackStateEnum.complete))
          IconButton(
            tooltip: 'Play',
            onPressed: () => context.push(
              '/play/downloadFile/${Uri.encodeComponent(file.id)}',
            ),
            icon: const Icon(Icons.play_arrow),
          ),
      ],
    );
    final television =
        MediaQuery.of(context).navigationMode == NavigationMode.directional;
    return Card(
      key: ValueKey(file.id),
      child: Column(
        children: [
          if (television)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 4), subtitle],
                    ),
                  ),
                  const SizedBox(width: 12),
                  trailing,
                ],
              ),
            )
          else
            ListTile(
              leading: leading,
              title: title,
              subtitle: subtitle,
              trailing: trailing,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 4),
                Text(
                  '${formatBytes(file.downloadedBytes, locale: locale)} received · ${formatBytes(file.contiguousBytes, locale: locale)} contiguous',
                ),
              ],
            ),
          ),
        ],
      ),
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

class _DownloadSettingsDraft {
  const _DownloadSettingsDraft({
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

class _DownloadSettingsDialog extends StatefulWidget {
  const _DownloadSettingsDialog({required this.settings});

  final DownloadSettings settings;

  @override
  State<_DownloadSettingsDialog> createState() =>
      _DownloadSettingsDialogState();
}

class _DownloadSettingsDialogState extends State<_DownloadSettingsDialog> {
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
  }

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
      _DownloadSettingsDraft(
        downloadLimit: _downloadLimit.text,
        uploadLimit: _uploadLimit.text,
        ratio: _ratio.text,
        seedTime: _seedTime.text,
        queue: _queue.text,
        tags: _tags.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Transfer settings'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _downloadLimit,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              errorText: _errors['download'],
              labelText: 'Download limit (bytes/sec)',
            ),
          ),
          TextField(
            controller: _uploadLimit,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              errorText: _errors['upload'],
              labelText: 'Upload limit (bytes/sec)',
            ),
          ),
          TextField(
            controller: _ratio,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Seeding ratio limit',
              errorText: _errors['ratio'],
            ),
          ),
          TextField(
            controller: _seedTime,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              errorText: _errors['time'],
              labelText: 'Seed time limit (minutes)',
            ),
          ),
          TextField(
            controller: _queue,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Queue position',
              errorText: _errors['queue'],
            ),
          ),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Tags (comma-separated)',
            ),
          ),
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

IconData _kindIcon(DownloadFileKindEnum kind) => switch (kind) {
  DownloadFileKindEnum.video => Icons.movie_outlined,
  DownloadFileKindEnum.photo => Icons.image_outlined,
  DownloadFileKindEnum.subtitle => Icons.subtitles_outlined,
  _ => Icons.insert_drive_file_outlined,
};

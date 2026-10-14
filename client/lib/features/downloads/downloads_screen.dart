import 'dart:async';

// The generated API exposes built collection request builders.
// ignore_for_file: depend_on_referenced_packages

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/session/client_session.dart';
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
      _load(reset: true, quiet: true);
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(reset: true, quiet: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool reset, bool quiet = false}) async {
    if (_busy) return;
    _busy = true;
    if (reset) {
      if (!quiet || _items.isEmpty) setState(() => _loading = true);
    } else {
      if (_cursor == null || _loadingMore) {
        _busy = false;
        return;
      }
      setState(() => _loadingMore = true);
    }
    try {
      final response = await requireActiveApi(ref)
          .getDownloadsApi()
          .listDownloads(cursor: reset ? null : _cursor, limit: 50);
      if (!mounted || response.data == null) return;
      final page = response.data!;
      setState(() {
        if (reset) {
          if (quiet && _items.isNotEmpty) {
            final byId = {for (final item in page.items) item.id: item};
            for (var index = 0; index < _items.length; index++) {
              _items[index] = byId.remove(_items[index].id) ?? _items[index];
            }
            _items.insertAll(0, byId.values);
          } else {
            _items
              ..clear()
              ..addAll(page.items);
          }
        } else {
          for (final item in page.items) {
            final index = _items.indexWhere((current) => current.id == item.id);
            if (index == -1) {
              _items.add(item);
            } else {
              _items[index] = item;
            }
          }
        }
        _cursor = page.nextCursor;
        _truncated = page.truncated;
        _error = page.warnings.isEmpty ? null : page.warnings.join('\n');
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = clientError(error);
        _loading = false;
        _loadingMore = false;
      });
    } finally {
      _busy = false;
    }
  }

  Future<void> _action(
    Download download,
    DownloadActionActionEnum action,
  ) async {
    try {
      await requireActiveApi(ref)
          .getDownloadsApi()
          .actOnDownload(
            id: download.id,
            downloadAction: DownloadAction(
              (b) => b
                ..action = action
                ..version = download.version,
            ),
            idempotencyKey: const Uuid().v4(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${action.name} queued.')));
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
              '${download.state.name} · ${formatBytes(download.downloadedSelectedBytes, locale: locale)} / ${formatBytes(total, locale: locale)}',
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text(
              '↓ ${formatRate(download.downloadBps, locale: locale)}   ↑ ${formatRate(download.uploadBps, locale: locale)}   Connected seeders ${formatCount(download.seedersConnected, locale: locale)} · peers ${formatCount(download.peersConnected, locale: locale)}',
            ),
            if (download.errorCode != null)
              Text(
                'Error: ${download.errorCode}${download.errorDetail == null ? '' : ' · ${download.errorDetail}'}',
              ),
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
      _load(quiet: true);
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(quiet: true),
    );
  }

  @override
  void didUpdateWidget(covariant DownloadDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestId != widget.requestId) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (_busy) return;
    _busy = true;
    if (!quiet && !_loading) setState(() => _loading = true);
    try {
      final api = requireActiveApi(ref);
      final downloadResponse = await api.getDownloadsApi().getDownload(
        id: widget.requestId,
      );
      final filesResponse = await api.getDownloadsApi().listDownloadFiles(
        id: widget.requestId,
      );
      DownloadSettings? settings;
      try {
        settings = (await api.getDownloadsApi().getDownloadSettings(
          id: widget.requestId,
        )).data;
      } catch (_) {
        // Read-only detail access remains useful when settings require management rights.
      }
      final libraryResponse = await api.getLibrariesApi().listLibraries();
      if (!mounted) return;
      final download = downloadResponse.data;
      final files = filesResponse.data?.toList() ?? <DownloadFile>[];
      final libraries = libraryResponse.data?.toList() ?? <ModelLibrary>[];
      final library = libraries
          .where((item) => item.id == download?.libraryId)
          .firstOrNull;
      final user = ref.read(clientSessionProvider)?.tokens.user;
      final canManage =
          user?.role == UserRoleEnum.administrator ||
          user?.id == download?.ownerId ||
          library?.capabilities.manage == true;
      final canDownload =
          user?.id == download?.ownerId ||
          library?.capabilities.download == true;
      setState(() {
        _download = download;
        _files = files;
        _settings = settings;
        _canManageLibrary =
            library?.capabilities.manage == true ||
            user?.role == UserRoleEnum.administrator;
        _canDownloadLibrary = canDownload;
        _managing = canManage;
        for (final file in files) {
          _selected.putIfAbsent(file.id, () => file.selected);
          _priority.putIfAbsent(
            file.id,
            () => FileChoicePriorityEnum.valueOf(file.priority.name),
          );
        }
        if (files.isNotEmpty &&
            files.every((f) => !(_selected[f.id] ?? f.selected))) {
          final firstVideo = files.indexWhere(
            (f) => f.kind == DownloadFileKindEnum.video,
          );
          if (firstVideo >= 0) _selected[files[firstVideo].id] = true;
        }
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = clientError(error);
        _loading = false;
      });
    } finally {
      _busy = false;
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
      await requireActiveApi(ref)
          .getDownloadsApi()
          .selectDownloadFiles(
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
      await requireActiveApi(ref)
          .getDownloadsApi()
          .actOnDownload(
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${action.name} queued.')));
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
    if (accepted == true) {
      await _action(DownloadActionActionEnum.remove, deleteData: true);
    }
  }

  Future<void> _editSettings() async {
    final download = _download;
    final settings = _settings;
    if (download == null || settings == null || !_managing) return;
    final draft = await showDialog<_DownloadSettingsDraft>(
      context: context,
      builder: (_) => _DownloadSettingsDialog(settings: settings),
    );
    if (draft == null || !mounted) return;
    int? readInt(String value) =>
        value.trim().isEmpty ? null : int.tryParse(value.trim());
    final dl = readInt(draft.downloadLimit),
        ul = readInt(draft.uploadLimit),
        minutes = readInt(draft.seedTime),
        position = readInt(draft.queue);
    final ratioValue = draft.ratio.trim().isEmpty
        ? null
        : double.tryParse(draft.ratio.trim());
    if ([
              draft.downloadLimit,
              draft.uploadLimit,
              draft.seedTime,
              draft.queue,
            ].any((value) => value.trim().isNotEmpty) &&
            [dl, ul, minutes, position].contains(null) ||
        draft.ratio.trim().isNotEmpty && ratioValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid numeric limits.')),
      );
      return;
    }
    try {
      final updated = await requireActiveApi(ref)
          .getDownloadsApi()
          .updateDownloadSettings(
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
      if (mounted) setState(() => _settings = updated.data ?? settings);
    } catch (error) {
      if (mounted) {
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
              onPressed: _editSettings,
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            Text(
              'State: ${download.state.name} · Transfer: ${download.transferState.name} · Import: ${download.importState.name}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: fraction),
            const SizedBox(height: 6),
            Text(
              '${formatBytes(download.downloadedSelectedBytes, locale: locale)} / ${formatBytes(total, locale: locale)} selected bytes · sequential ${download.sequential ? 'on' : 'off'}',
            ),
            Text(
              '↓ ${formatRate(download.downloadBps, locale: locale)} · ↑ ${formatRate(download.uploadBps, locale: locale)} · Connected seeders ${formatCount(download.seedersConnected, locale: locale)} · peers ${formatCount(download.peersConnected, locale: locale)} · ETA ${download.etaSeconds == null ? '—' : '${formatCount(download.etaSeconds, locale: locale)}s'}',
            ),
            if (download.errorCode != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(download.errorCode!),
                  subtitle: Text(
                    download.errorDetail ?? 'The server reported an error without additional detail.',
                  ),
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
                    onPressed: () => _action(DownloadActionActionEnum.pause),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                if (_managing &&
                    download.transferState == DownloadTransferStateEnum.paused)
                  FilledButton.icon(
                    onPressed: () => _action(DownloadActionActionEnum.resume),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  ),
                if (_managing &&
                    (download.state == DownloadStateEnum.failed ||
                        download.state == DownloadStateEnum.stalled))
                  OutlinedButton.icon(
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
            for (var index = 0; index < _files.length; index++)
              _fileRow(_files[index], index, locale),
            if (_needsSelection && _canDownloadLibrary && _files.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: _savingSelection ? null : _submitSelection,
                  icon: _savingSelection
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
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
        index > 0 &&
        _files
            .take(index)
            .any(
              (x) =>
                  x.kind == DownloadFileKindEnum.video &&
                  (_selected[x.id] ?? x.selected),
            );
    final leading = canToggle
                ? Checkbox(
                    value: checked,
                    onChanged: (value) =>
                        setState(() => _selected[file.id] = value ?? false),
                  )
                : Icon(_kindIcon(file.kind));
    final title = Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
    final subtitle = Text(
              '${file.kind.name} · ${formatBytes(file.sizeBytes, locale: locale)} · ${file.playbackState.name}${laterVideo && checked ? ' · may wait behind earlier video' : ''}',
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
                    (file.playbackState ==
                            DownloadFilePlaybackStateEnum.eligible ||
                        file.playbackState ==
                            DownloadFilePlaybackStateEnum.complete))
                  IconButton(
                    tooltip: 'Play',
                    onPressed: () => context.push(
                      '/play/downloadFile/${Uri.encodeComponent(file.id)}',
                    ),
                    icon: const Icon(Icons.play_arrow),
                  ),
              ],
            );
    final television = MediaQuery.of(context).navigationMode == NavigationMode.directional;
    return Card(
      child: Column(
        children: [
          if (television)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [leading, const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 4), subtitle])),
                const SizedBox(width: 12), trailing]))
          else ListTile(leading: leading, title: title, subtitle: subtitle, trailing: trailing),
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

  void _save() => Navigator.of(context).pop(
    _DownloadSettingsDraft(
      downloadLimit: _downloadLimit.text,
      uploadLimit: _uploadLimit.text,
      ratio: _ratio.text,
      seedTime: _seedTime.text,
      queue: _queue.text,
      tags: _tags.text,
    ),
  );

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
            decoration: const InputDecoration(
              labelText: 'Download limit (bytes/sec)',
            ),
          ),
          TextField(
            controller: _uploadLimit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Upload limit (bytes/sec)',
            ),
          ),
          TextField(
            controller: _ratio,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Seeding ratio limit'),
          ),
          TextField(
            controller: _seedTime,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Seed time limit (minutes)',
            ),
          ),
          TextField(
            controller: _queue,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Queue position'),
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

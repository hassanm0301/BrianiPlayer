import 'dart:async';

import 'package:briani_api/briani_api.dart' hide Provider;
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
import 'transfer_widgets.dart';

export 'download_details_screen.dart';

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
    final gutters = pageGutters(context);
    final showError = _error != null && !_loading && _items.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Refresh downloads',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
          ?ShellLayout.headerAccountButton(context),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showError || _truncated)
            Padding(
              padding: gutters.add(const EdgeInsets.only(top: 4, bottom: 8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  if (showError)
                    NoticeBanner(
                      tone: NoticeTone.error,
                      message: _error!,
                      action: TextButton(
                        onPressed: () => _load(reset: true),
                        child: const Text('Retry'),
                      ),
                    ),
                  if (_truncated)
                    const NoticeBanner(
                      message: 'Only the current bounded page is shown.',
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? _error == null
                      ? EmptyState(
                          icon: Icons.download_outlined,
                          title: 'Start your first download',
                          message: 'No downloads yet. Discover a release or add a magnet.',
                          action: GoRouter.maybeOf(context) == null
                              ? null
                              : FilledButton.tonalIcon(
                                  onPressed: () => context.go('/discover'),
                                  icon: const Icon(Icons.travel_explore),
                                  label: const Text('Go to Discover'),
                                ),
                        )
                      : EmptyState.error(
                          title: 'Downloads could not be loaded',
                          message: _error!,
                          onRetry: () => _load(reset: true),
                        )
                : RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    // No scroll-triggered loading here: every page loaded
                    // widens the window that the 5 s poll refetches, so the
                    // list only grows when the user asks for the next page.
                    child: ListView.builder(
                      key: const PageStorageKey('downloads'),
                      padding: gutters.add(
                        const EdgeInsets.only(top: 4, bottom: 24),
                      ),
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: FilledButton.tonalIcon(
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
              ),
            ),
        ],
      ),
    );
  }

  void _openDetails(Download download) =>
      context.push('/downloads/${Uri.encodeComponent(download.id)}');

  /// The permitted actions for [download], in menu order.
  List<(String, IconData, String)> _permittedActions(Download download) {
    final user = ref.read(clientSessionProvider)?.tokens.user;
    final ownsRequest = user?.id == download.ownerId;
    final canControl = ownsRequest || user?.role == UserRoleEnum.administrator;
    return [
      if (canControl &&
          (download.transferState == DownloadTransferStateEnum.downloading ||
              download.transferState == DownloadTransferStateEnum.seeding))
        ('pause', Icons.pause, 'Pause'),
      if (canControl &&
          download.transferState == DownloadTransferStateEnum.paused)
        ('resume', Icons.play_arrow, 'Resume'),
      if (canControl &&
          (download.state == DownloadStateEnum.failed ||
              download.state == DownloadStateEnum.stalled))
        ('retry', Icons.restart_alt, 'Retry'),
      if (ownsRequest)
        ('remove', Icons.remove_circle_outline, 'Remove request'),
    ];
  }

  void _runAction(Download download, String value) {
    switch (value) {
      case 'pause':
        _action(download, DownloadActionActionEnum.pause);
      case 'resume':
        _action(download, DownloadActionActionEnum.resume);
      case 'retry':
        _action(download, DownloadActionActionEnum.retry);
      case 'remove':
        _confirmRemove(download);
    }
  }

  List<PopupMenuEntry<String>> _menuEntries(
    List<(String, IconData, String)> actions,
  ) => [
    for (final (value, icon, label) in actions)
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
  ];

  Future<void> _showContextMenu(Download download, Offset position) async {
    final actions = _permittedActions(download);
    if (actions.isEmpty) return;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: _menuEntries(actions),
    );
    if (value != null && mounted) _runAction(download, value);
  }

  Widget _downloadTile(Download download, String? locale) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    final total = download.selectedBytes;
    final progress = total == null || total <= 0
        ? null
        : (download.downloadedSelectedBytes / total).clamp(0.0, 1.0).toDouble();
    final presentation = downloadStatePresentation(download.state);
    final downloading =
        download.transferState == DownloadTransferStateEnum.downloading;
    final seeding = download.transferState == DownloadTransferStateEnum.seeding;
    final awaitingSelection =
        download.state == DownloadStateEnum.awaitingSelection;
    final fetchingMetadata =
        download.state == DownloadStateEnum.metadataPending ||
        download.state == DownloadStateEnum.resolving;
    final actions = _permittedActions(download);
    // The first applicable transfer action is shown inline; the rest stay in
    // the overflow menu so each card has one obvious control.
    final primary = actions
        .where((action) => action.$1 != 'remove')
        .firstOrNull;
    final overflow = actions.where((action) => action != primary).toList();
    final barColor = switch (presentation.tone) {
      PillTone.error => scheme.error,
      PillTone.success => status.success,
      PillTone.neutral => scheme.outline,
      _ => null,
    };
    final eta = download.etaSeconds;
    final metrics = <Widget>[
      StatusPill(
        label: presentation.label,
        icon: presentation.icon,
        tone: presentation.tone,
        dense: true,
      ),
      if (!awaitingSelection && !fetchingMetadata)
        IconMetric(
          label: 'Downloaded',
          value: formatProgressBytes(
            download.downloadedSelectedBytes,
            total,
            locale: locale,
          ),
          color: scheme.onSurface,
        ),
      if (!awaitingSelection && progress != null && progress < 1)
        IconMetric(
          label: 'Progress',
          value: formatPercent(progress, locale: locale),
        ),
      if (downloading)
        IconMetric(
          label: 'Download speed',
          icon: Icons.arrow_downward,
          value: formatRate(download.downloadBps, locale: locale),
        ),
      if (seeding || download.uploadBps > 0)
        IconMetric(
          label: 'Upload speed',
          icon: Icons.arrow_upward,
          value: formatRate(download.uploadBps, locale: locale),
        ),
      if ((downloading || seeding) &&
          (download.seedersConnected != null ||
              download.peersConnected != null))
        IconMetric(
          label: 'Connected',
          icon: Icons.people_outline,
          value:
              '${formatCount(download.seedersConnected, locale: locale)} seeders · ${formatCount(download.peersConnected, locale: locale)} peers',
        ),
      if (downloading && eta != null && eta > 0)
        IconMetric(
          label: 'Time left',
          icon: Icons.schedule,
          value: '${formatEta(eta, locale: locale)} left',
        ),
    ];
    return Padding(
      key: ValueKey(download.id),
      padding: const EdgeInsets.only(bottom: 8),
      child: FocusOutline(
        child: Card(
          child: InkWell(
            onTap: () => _openDetails(download),
            onSecondaryTapUp: actions.isEmpty
                ? null
                : (details) =>
                      _showContextMenu(download, details.globalPosition),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            download.name ?? 'Torrent metadata pending',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ),
                      if (primary != null)
                        IconButton(
                          tooltip: primary.$3,
                          onPressed: () => _runAction(download, primary.$1),
                          icon: Icon(primary.$2),
                        ),
                      if (overflow.isNotEmpty)
                        PopupMenuButton<String>(
                          tooltip: 'Download actions',
                          onSelected: (value) => _runAction(download, value),
                          itemBuilder: (_) => _menuEntries(overflow),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (awaitingSelection) ...[
                          // Nothing has transferred yet, so the state and the
                          // call to action replace the progress bar.
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: metrics,
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            // The whole card opens file selection; the inline
                            // button is added only where it fits beside the
                            // message.
                            builder: (context, constraints) => NoticeBanner(
                              tone: NoticeTone.warning,
                              icon: Icons.checklist,
                              message: 'Choose which files to download. Nothing transfers until you do.',
                              action:
                                  constraints.maxWidth >=
                                      480 *
                                          MediaQuery.textScalerOf(context)
                                              .scale(1)
                                              .clamp(1.0, 2.0)
                                  ? TextButton(
                                      onPressed: () => _openDetails(download),
                                      child: const Text('Choose files'),
                                    )
                                  : null,
                            ),
                          ),
                        ] else ...[
                          // An unknown total shows no bar rather than a
                          // misleading 0% (and no constant animation).
                          if (!fetchingMetadata && progress != null) ...[
                            const SizedBox(height: 8),
                            TransferProgressBar(
                              value: progress,
                              color: barColor,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: metrics,
                          ),
                        ],
                        if (download.errorCode != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: scheme.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  download.errorDetail ??
                                      'The download failed.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (download.tags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in download.tags)
                                TagPill(tag: tag),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

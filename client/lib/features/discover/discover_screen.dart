import 'dart:async';

// These types are owned by the generated client package and are used only to
// construct its request collections and tagged-union sources.
// ignore_for_file: depend_on_referenced_packages

import 'package:briani_api/briani_api.dart';
import 'package:built_collection/built_collection.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:go_router/go_router.dart';
import 'package:one_of/one_of.dart';
import 'package:uuid/uuid.dart';

import '../../core/session/client_session.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/formatting/locale_formatters.dart';
import '../../core/widgets/adaptive.dart';
import '../../core/widgets/states.dart';
import 'add_download_dialog.dart';
import 'discover_filters.dart';
import 'discover_results.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  static const _pageSize = 50;
  final _searchController = TextEditingController();
  final _categoryController = TextEditingController();
  final _minSizeController = TextEditingController();
  final _maxSizeController = TextEditingController();
  final _minSeedersController = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'Discovery search');
  final _uuid = const Uuid();
  final List<DiscoveryResult> _items = [];
  List<Provider> _providers = [];
  List<ModelLibrary> _libraries = [];
  final Set<String> _providerIds = {};
  String _mode = 'latest';
  String _sort = 'publishedAt';
  String _order = 'desc';
  DiscoverySnapshot? _snapshot;
  CancelToken? _queryCancel;
  String? _error;
  String? _providerError;
  // A 403 here means discovery itself is unavailable to this account, not just the indexer list.
  bool _discoveryForbidden = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _submitting = false;
  bool _truncated = false;
  bool _preferencesApplied = false;
  bool _initialQueryStarted = false;
  bool _viewEdited = false;
  bool _failedPage = false;
  int _queryGeneration = 0;
  String? _searchedQuery;

  @override
  void initState() {
    super.initState();
    ref.listenManual(userPreferencesProvider, (previous, next) {
      final preferences = next.asData?.value;
      if (preferences == null || _preferencesApplied || !mounted) return;
      _preferencesApplied = true;
      if (_viewEdited) return;
      setState(() => _applySavedView(_mode, preferences));
      if (_initialQueryStarted) unawaited(_runQuery());
    }, fireImmediately: true);
    ref.listenManual(activeApiProvider, (previous, next) {
      if (!mounted || identical(previous, next)) return;
      _cancelQuery();
      setState(() {
        _items.clear();
        _snapshot = null;
        _providers = [];
        _libraries = [];
        _error = null;
        _providerError = null;
        _discoveryForbidden = false;
        _loading = next != null;
        _viewEdited = false;
        _preferencesApplied = false;
        _initialQueryStarted = false;
      });
      if (next != null) unawaited(_loadInitial());
    });
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _queryCancel?.cancel('Discover screen closed');
    _searchController.dispose();
    _categoryController.dispose();
    _minSizeController.dispose();
    _maxSizeController.dispose();
    _minSeedersController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final api = ref.read(activeApiProvider);
    await Future.wait([_loadProviders(), _loadLibraries()]);
    if (!mounted ||
        _initialQueryStarted ||
        api == null ||
        !identical(ref.read(activeApiProvider), api)) {
      return;
    }
    await _runQuery();
  }

  void _changeMode(String mode, {bool runQuery = false}) {
    _viewEdited = true;
    _initialQueryStarted = true;
    _cancelQuery();
    final preferences = ref.read(userPreferencesProvider).asData?.value;
    setState(() {
      _error = null;
      if (!runQuery) {
        _loading = false;
        _snapshot = null;
        _items.clear();
        _truncated = false;
      }
      if (preferences != null) {
        _applySavedView(mode, preferences);
      } else {
        _mode = mode;
        _sort = switch (mode) {
          'mostSeeded' => 'seeders',
          'search' => 'title',
          _ => 'publishedAt',
        };
        _order = mode == 'search' ? 'asc' : 'desc';
        _providerIds.clear();
        _categoryController.clear();
        _minSizeController.clear();
        _maxSizeController.clear();
        _minSeedersController.clear();
      }
    });
    if (runQuery) unawaited(_runQuery());
  }

  Future<void> _loadLibraries() async {
    final api = ref.read(activeApiProvider);
    if (api == null) return;
    try {
      final response = await api.getLibrariesApi().listLibraries();
      if (!mounted || !identical(ref.read(activeApiProvider), api)) return;
      setState(
        () => _libraries =
            response.data?.whereType<ModelLibrary>().toList() ??
            <ModelLibrary>[],
      );
    } catch (error) {
      if (!mounted || !identical(ref.read(activeApiProvider), api)) return;
      setState(
        () => _error = 'Libraries could not be loaded: ${clientError(error)}',
      );
    }
  }

  Future<void> _loadProviders() async {
    final api = ref.read(activeApiProvider);
    if (api == null) return;
    try {
      final response = await api.getDiscoveryApi().listProviders();
      if (!mounted || !identical(ref.read(activeApiProvider), api)) return;
      setState(() {
        _providers =
            response.data?.whereType<Provider>().toList() ?? <Provider>[];
        _providerError = null;
        _discoveryForbidden = false;
      });
    } catch (error) {
      if (!mounted || !identical(ref.read(activeApiProvider), api)) return;
      setState(() {
        _providerError = clientError(error);
        _discoveryForbidden =
            error is DioException && error.response?.statusCode == 403;
      });
    }
  }

  Future<void> _retryDiscoveryAccess() async {
    await _loadProviders();
    if (mounted && !_discoveryForbidden) await _runQuery();
  }

  void _cancelQuery() {
    _queryCancel?.cancel('Discovery view changed');
    _queryCancel = null;
    ++_queryGeneration;
    _loadingMore = false;
  }

  Future<void> _runQuery() async {
    _initialQueryStarted = true;
    _cancelQuery();
    final categories = parseCategoryIds(_categoryController.text);
    final minSize = parseGib(_minSizeController.text);
    final maxSize = parseGib(_maxSizeController.text);
    final minSeeders = int.tryParse(_minSeedersController.text.trim());
    if ((_categoryController.text.trim().isNotEmpty && categories == null) ||
        (_minSizeController.text.trim().isNotEmpty && minSize == null) ||
        (_maxSizeController.text.trim().isNotEmpty && maxSize == null) ||
        (_minSeedersController.text.trim().isNotEmpty && minSeeders == null) ||
        (minSize != null && maxSize != null && minSize > maxSize) ||
        (minSeeders != null && minSeeders < 0)) {
      setState(() {
        _error = 'Check the category, size, and minimum seeder filters.';
        _loading = false;
      });
      return;
    }
    unawaited(
      _saveCurrentView(
        categories: categories,
        minSize: minSize,
        maxSize: maxSize,
        minSeeders: minSeeders,
      ),
    );
    if (_mode == 'search' && _searchController.text.trim().isEmpty) {
      setState(() {
        _items.clear();
        _snapshot = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    final generation = _queryGeneration;
    final api = ref.read(activeApiProvider);
    if (api == null) {
      setState(() => _loading = false);
      return;
    }
    final cancel = CancelToken();
    bool current() =>
        mounted &&
        !cancel.isCancelled &&
        generation == _queryGeneration &&
        identical(ref.read(activeApiProvider), api);
    _queryCancel = cancel;
    setState(() {
      _searchedQuery = _searchController.text.trim();
      _loading = true;
      _loadingMore = false;
      _error = null;
      _failedPage = false;
      _snapshot = null;
      _truncated = false;
    });
    try {
      final query = DiscoveryQuery(
        (b) => b
          ..mode = _mode == 'latest'
              ? DiscoveryQueryModeEnum.latest
              : _mode == 'mostSeeded'
              ? DiscoveryQueryModeEnum.mostSeeded
              : DiscoveryQueryModeEnum.search
          ..query = _mode == 'search' ? _searchController.text.trim() : null
          ..providerIds = _providerIds.isEmpty
              ? null
              : ListBuilder(_providerIds)
          ..categories = categories == null ? null : ListBuilder(categories)
          ..sort = DiscoveryQuerySortEnum.valueOf(_sort)
          ..order = DiscoveryQueryOrderEnum.valueOf(_order)
          ..minSizeBytes = minSize
          ..maxSizeBytes = maxSize
          ..minSeeders = minSeeders,
      );
      final first = await api.getDiscoveryApi().createDiscoveryQuery(
        discoveryQuery: query,
        idempotencyKey: _uuid.v4(),
        cancelToken: cancel,
      );
      var snapshot =
          first.data ??
          (throw StateError('The discovery query returned no snapshot.'));
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while ((snapshot.state == DiscoverySnapshotStateEnum.queued ||
              snapshot.state == DiscoverySnapshotStateEnum.running) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!current()) return;
        final response = await api.getDiscoveryApi().getDiscoverySnapshot(
          id: snapshot.id,
          limit: _pageSize,
          cancelToken: cancel,
        );
        snapshot = response.data ?? snapshot;
      }
      if (!current()) return;
      setState(() {
        _snapshot = snapshot;
        if (snapshot.state != DiscoverySnapshotStateEnum.failed ||
            snapshot.items.isNotEmpty) {
          _items
            ..clear()
            ..addAll(snapshot.items);
        }
        _truncated = snapshot.truncated;
        _loading = false;
        if (snapshot.state == DiscoverySnapshotStateEnum.failed) {
          _error = snapshot.warnings.isEmpty
              ? 'The search could not complete. Retry or check discovery service health.'
              : snapshot.warnings.join('\n');
        } else if (snapshot.state == DiscoverySnapshotStateEnum.queued ||
            snapshot.state == DiscoverySnapshotStateEnum.running) {
          _error = 'This search is still running. Refresh to check its status.';
        }
      });
    } catch (error) {
      if (!current()) return;
      setState(() {
        _loading = false;
        _error = clientError(error);
      });
    }
  }

  void _applySavedView(String mode, UserPreferences preferences) {
    final saved = preferences.discoveryViews
        ?.where((view) => view.mode.name == mode)
        .firstOrNull;
    _mode = mode;
    _sort =
        saved?.sort.name ??
        switch (mode) {
          'mostSeeded' => 'seeders',
          'search' => 'title',
          _ => 'publishedAt',
        };
    _order = saved?.order.name ?? (mode == 'search' ? 'asc' : 'desc');
    _providerIds
      ..clear()
      ..addAll(saved?.providerIds ?? const []);
    _categoryController.text = saved?.categories.join(', ') ?? '';
    _minSizeController.text = _sizeInput(saved?.minSizeBytes);
    _maxSizeController.text = _sizeInput(saved?.maxSizeBytes);
    _minSeedersController.text = saved?.minSeeders?.toString() ?? '';
  }

  String _sizeInput(int? bytes) => bytes == null
      ? ''
      : (bytes / (1024 * 1024 * 1024))
            .toStringAsPrecision(8)
            .replaceAll(RegExp(r'\.?0+$'), '');

  Future<void> _saveCurrentView({
    required List<int>? categories,
    required int? minSize,
    required int? maxSize,
    required int? minSeeders,
  }) async {
    final current = ref.read(userPreferencesProvider).asData?.value;
    if (current == null) return;
    final views =
        current.discoveryViews
            ?.where((view) => view.mode.name != _mode)
            .toList() ??
        <UserPreferencesDiscoveryViewsInner>[];
    views.add(
      UserPreferencesDiscoveryViewsInner(
        (b) => b
          ..mode = UserPreferencesDiscoveryViewsInnerModeEnum.valueOf(_mode)
          ..sort = UserPreferencesDiscoveryViewsInnerSortEnum.valueOf(_sort)
          ..order = UserPreferencesDiscoveryViewsInnerOrderEnum.valueOf(_order)
          ..providerIds.replace(_providerIds)
          ..categories.replace(categories ?? const <int>[])
          ..minSizeBytes = minSize
          ..maxSizeBytes = maxSize
          ..minSeeders = minSeeders,
      ),
    );
    try {
      await ref
          .read(userPreferencesProvider.notifier)
          .update((b) => b.discoveryViews.replace(views));
    } catch (_) {
      // Search still works when synced preference persistence is unavailable.
    }
  }

  Future<void> _loadMore() async {
    final snapshot = _snapshot;
    if (snapshot == null ||
        snapshot.nextCursor == null ||
        _loadingMore ||
        _loading) {
      return;
    }
    final generation = _queryGeneration;
    final api = requireActiveApi(ref);
    final cancel = _queryCancel ??= CancelToken();
    bool current() =>
        mounted &&
        !cancel.isCancelled &&
        generation == _queryGeneration &&
        _snapshot?.id == snapshot.id &&
        identical(ref.read(activeApiProvider), api);
    setState(() {
      _loadingMore = true;
      _error = null;
      _failedPage = false;
    });
    try {
      final response = await api.getDiscoveryApi().getDiscoverySnapshot(
        id: snapshot.id,
        cursor: snapshot.nextCursor,
        limit: _pageSize,
        cancelToken: cancel,
      );
      if (!current()) return;
      final page =
          response.data ??
          (throw StateError('The discovery page returned no snapshot.'));
      if (page.id != snapshot.id) {
        throw StateError('The discovery snapshot changed. Retry the query.');
      }
      setState(() {
        _snapshot = page;
        final existing = _items.map((result) => result.id).toSet();
        _items.addAll(page.items.where((result) => existing.add(result.id)));
        _truncated = page.truncated;
        _loadingMore = false;
      });
    } catch (error) {
      if (!current()) return;
      setState(() {
        _loadingMore = false;
        _failedPage = true;
        _error = clientError(error);
      });
    }
  }

  Future<void> _startDownload(DiscoveryResult result) async {
    if (!result.downloadable || _submitting) return;
    final libraries = _libraries
        .where((x) => x.enabled && x.capabilities.download)
        .toList();
    if (libraries.isEmpty) {
      _showMessage('No download-capable library is available to this account.');
      return;
    }
    final locale = _currentLocale;
    final choice = await AddDownloadDialog.show(
      context: context,
      title: 'Add download',
      libraries: libraries,
      confirmLabel: 'Continue',
      subject: result.title,
      details: [
        formatBytes(result.sizeBytes, locale: locale),
        '${formatCount(result.seeders, locale: locale)} seeders',
        result.providerName,
      ].join(' · '),
      stale: result.stale,
    );
    final destination = choice?.library;
    if (destination == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      final source = DownloadSource(
        (b) => b.oneOf =
            OneOf.fromValue3<
              DownloadSourceOneOf,
              DownloadSourceOneOf1,
              DownloadSourceOneOf2
            >(
              value: DownloadSourceOneOf(
                (s) => s
                  ..kind = DownloadSourceOneOfKindEnum.discoveryResult
                  ..value = result.id,
              ),
            ),
      );
      final response = await requireActiveApi(ref)
          .getDownloadsApi()
          .createDownload(
            downloadCreate: DownloadCreate(
              (b) => b
                ..libraryId = destination.id
                ..source_ = source.toBuilder(),
            ),
            idempotencyKey: _uuid.v4(),
          );
      if (!mounted || response.data == null) return;
      _showMessage(
        'Metadata is being prepared. No torrent payload starts before file selection.',
      );
      if (mounted) {
        context.push('/downloads/${Uri.encodeComponent(response.data!.id)}');
      }
    } catch (error) {
      if (mounted) _showMessage(clientError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _uploadTorrent() async {
    if (_submitting) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['torrent'],
    );
    if (picked.isEmpty || !mounted) return;
    final file = picked.single;
    final size = await file.length();
    if (!mounted) return;
    if (size == null || size <= 0 || size > 16 * 1024 * 1024) {
      _showMessage('Choose a .torrent file between 1 byte and 16 MiB.');
      return;
    }
    final path = file.path;
    if (file.extension?.toLowerCase() != 'torrent') {
      _showMessage('Choose a file with the .torrent extension.');
      return;
    }
    final libraries = _libraries
        .where((x) => x.enabled && x.capabilities.download)
        .toList();
    if (libraries.isEmpty) {
      _showMessage('No download-capable library is available to this account.');
      return;
    }
    final choice = await AddDownloadDialog.show(
      context: context,
      title: 'Add torrent file',
      libraries: libraries,
      confirmLabel: 'Upload',
      subject: file.name,
      details: formatBytes(size, locale: _currentLocale),
      subjectIcon: Icons.description_outlined,
    );
    final destination = choice?.library;
    if (destination == null || !mounted) return;
    setState(() => _submitting = true);
    try {
      final multipart = path != null
          ? await MultipartFile.fromFile(path, filename: file.name)
          : MultipartFile.fromStream(
              () => file.readAsByteStream(),
              size,
              filename: file.name,
            );
      final upload = await requireActiveApi(ref)
          .getDownloadsApi()
          .uploadTorrent(file: multipart, idempotencyKey: _uuid.v4());
      final uploadId = upload.data?.id;
      if (uploadId == null) {
        throw StateError('The upload did not return a temporary upload ID.');
      }
      final sourceValue = DownloadSourceOneOf2(
        (b) => b
          ..kind = DownloadSourceOneOf2KindEnum.torrentUpload
          ..value = uploadId,
      );
      final source = DownloadSource(
        (b) => b.oneOf =
            OneOf.fromValue3<
              DownloadSourceOneOf,
              DownloadSourceOneOf1,
              DownloadSourceOneOf2
            >(value: sourceValue),
      );
      final created = await requireActiveApi(ref)
          .getDownloadsApi()
          .createDownload(
            downloadCreate: DownloadCreate(
              (b) => b
                ..libraryId = destination.id
                ..source_ = source.toBuilder(),
            ),
            idempotencyKey: _uuid.v4(),
          );
      if (mounted && created.data != null) {
        context.push('/downloads/${Uri.encodeComponent(created.data!.id)}');
      }
    } catch (error) {
      if (mounted) _showMessage(clientError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (ref.watch(activeApiProvider) == null) return const SizedBox.shrink();
    final preferences = ref.watch(userPreferencesProvider).asData?.value;
    final locale = preferences?.locale;
    final configuredColumns =
        preferences?.torrentColumns?.map((column) => column.name).toSet() ??
        {
          'title',
          'size',
          'seeders',
          'leechers',
          'peers',
          'provider',
          'publishedAt',
        };
    final latestAvailable = _providers.any(
      (p) => p.enabled && p.supportsRecent,
    );
    final gutters = pageGutters(context);
    final television = isTelevision(context);
    final notices = _notices();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          Builder(
            builder: (buttonContext) => FilledButton.tonalIcon(
              onPressed: () => _showAddMenu(buttonContext),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Refresh discovery',
            onPressed: _loading ? null : _runQuery,
            icon: const Icon(Icons.refresh),
          ),
          ?ShellLayout.headerAccountButton(context),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_discoveryForbidden)
            Padding(
              padding: gutters.add(const EdgeInsets.only(top: 4, bottom: 8)),
              child: _toolbar(latestAvailable, television),
            ),
          SizedBox(
            height: 4,
            child: _loading && _items.isNotEmpty
                ? const LinearProgressIndicator(minHeight: 2)
                : null,
          ),
          if (notices.isNotEmpty)
            Padding(
              padding: gutters.add(const EdgeInsets.only(top: 4, bottom: 4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: notices,
              ),
            ),
          Expanded(
            child: _content(configuredColumns, locale, gutters, television),
          ),
        ],
      ),
    );
  }

  /// Opens the Add menu below its button. A route-based menu keeps system
  /// Back and D-pad behavior consistent with the other overflow menus.
  Future<void> _showAddMenu(BuildContext buttonContext) async {
    final button = buttonContext.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(buttonContext).overlay!.context.findRenderObject()!
            as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
          Offset(0, button.size.height + 4),
          ancestor: overlay,
        ),
        button.localToGlobal(
          button.size.bottomRight(const Offset(0, 4)),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label, {
      bool enabled = true,
    }) => PopupMenuItem(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
    final choice = await showMenu<String>(
      context: buttonContext,
      position: position,
      items: [
        item('magnet', Icons.link, 'Magnet link…'),
        item(
          'torrent',
          Icons.upload_file,
          'Torrent file…',
          enabled: !_submitting,
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'magnet':
        await _showMagnetEntry();
      case 'torrent':
        await _uploadTorrent();
    }
  }

  void _selectMode(String mode, bool latestAvailable) {
    switch (mode) {
      case 'latest':
        if (!latestAvailable) {
          _showMessage(
            'No enabled provider supports recent releases. Use Search instead.',
          );
          return;
        }
        _changeMode('latest', runQuery: true);
      case 'mostSeeded':
        _changeMode('mostSeeded', runQuery: true);
      case 'search':
        _changeMode('search');
        _searchFocus.requestFocus();
    }
  }

  void _submitSearch() {
    _viewEdited = true;
    if (_mode == 'search') {
      unawaited(_runQuery());
    } else if (_searchController.text.trim().isNotEmpty) {
      _changeMode('search', runQuery: true);
    }
  }

  int get _activeFilterCount => [
    _providerIds.isNotEmpty,
    _categoryController.text.trim().isNotEmpty,
    _minSizeController.text.trim().isNotEmpty ||
        _maxSizeController.text.trim().isNotEmpty,
    _minSeedersController.text.trim().isNotEmpty,
  ].where((active) => active).length;

  Future<void> _openFilters() async {
    final values = await DiscoveryFiltersPanel.show(
      context: context,
      initial: DiscoveryFilterValues(
        providerIds: {..._providerIds},
        categories: _categoryController.text,
        minSize: _minSizeController.text,
        maxSize: _maxSizeController.text,
        minSeeders: _minSeedersController.text,
        sort: _sort,
        order: _order,
      ),
      defaultSort: switch (_mode) {
        'mostSeeded' => 'seeders',
        'search' => 'title',
        _ => 'publishedAt',
      },
      defaultOrder: _mode == 'search' ? 'asc' : 'desc',
      providers: _providers.where((p) => p.enabled).toList(),
    );
    if (values == null || !mounted) return;
    setState(() {
      _viewEdited = true;
      _providerIds
        ..clear()
        ..addAll(values.providerIds);
      _categoryController.text = values.categories;
      _minSizeController.text = values.minSize;
      _maxSizeController.text = values.maxSize;
      _minSeedersController.text = values.minSeeders;
      _sort = values.sort;
      _order = values.order;
    });
    await _runQuery();
  }

  void _sortBy(String sort) {
    setState(() {
      _viewEdited = true;
      if (_sort == sort) {
        _order = _order == 'asc' ? 'desc' : 'asc';
      } else {
        _sort = sort;
        _order = sort == 'title' ? 'asc' : 'desc';
      }
    });
    unawaited(_runQuery());
  }

  Widget _toolbar(bool latestAvailable, bool television) {
    final compact = WindowSize.of(context).isCompact;
    final filterCount = _activeFilterCount;
    Widget modeLabel(String text) =>
        Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    final modes = SegmentedButton<String>(
      showSelectedIcon: false,
      expandedInsets: compact ? EdgeInsets.zero : null,
      // Matches the 48dp search field and filter button beside it.
      style: const ButtonStyle(
        visualDensity: VisualDensity(horizontal: 0, vertical: 2),
      ),
      segments: [
        ButtonSegment(
          value: 'latest',
          label: modeLabel('Latest'),
          icon: compact ? null : const Icon(Icons.schedule),
        ),
        ButtonSegment(
          value: 'mostSeeded',
          label: modeLabel('Most seeded'),
          icon: compact ? null : const Icon(Icons.trending_up),
        ),
        ButtonSegment(
          value: 'search',
          label: modeLabel('Search'),
          icon: compact ? null : const Icon(Icons.search),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (selection) =>
          _selectMode(selection.single, latestAvailable),
    );
    // On TV a text field in the vertical path would open the on-screen
    // keyboard during ordinary D-pad movement, so it appears only in Search.
    final showSearch = !television || _mode == 'search';
    final search = SearchBar(
      controller: _searchController,
      focusNode: _searchFocus,
      hintText: 'Search torrent names',
      textInputAction: TextInputAction.search,
      constraints: const BoxConstraints(minHeight: 48, maxWidth: 720),
      leading: const Icon(Icons.search),
      trailing: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _viewEdited = true;
                    _searchController.clear();
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
      ],
      // Typing only edits the Search view; in Latest/Most seeded the query
      // takes effect on submit (which switches to Search), so a late
      // preference load can still apply the saved view for the current mode.
      onChanged: (_) {
        if (_mode == 'search') _viewEdited = true;
      },
      onSubmitted: (_) => _submitSearch(),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (showSearch) Expanded(child: search) else const Spacer(),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: filterCount == 0
                    ? 'Filters'
                    : 'Filters, $filterCount active',
                onPressed: _openFilters,
                icon: Badge.count(
                  count: filterCount,
                  isLabelVisible: filterCount > 0,
                  child: const Icon(Icons.tune),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          modes,
        ],
      );
    }
    final filters = FilledButton.tonalIcon(
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(0, 48)),
      ),
      onPressed: _openFilters,
      icon: const Icon(Icons.tune),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Filters'),
          if (filterCount > 0) ...[
            const SizedBox(width: 8),
            Badge.count(count: filterCount),
          ],
        ],
      ),
    );
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 880 * scale) {
          return Row(
            children: [
              modes,
              const SizedBox(width: 12),
              if (showSearch) Expanded(child: search) else const Spacer(),
              const SizedBox(width: 12),
              filters,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: modes),
                ),
                const SizedBox(width: 12),
                filters,
              ],
            ),
            if (showSearch) ...[const SizedBox(height: 12), search],
          ],
        );
      },
    );
  }

  List<Widget> _notices() {
    final snapshot = _snapshot;
    return [
      if (_providerError != null && !_discoveryForbidden)
        NoticeBanner(
          tone: NoticeTone.warning,
          message: 'Provider details are unavailable: $_providerError',
          action: TextButton(
            onPressed: _loadProviders,
            child: const Text('Retry providers'),
          ),
        ),
      if (snapshot != null &&
          snapshot.state != DiscoverySnapshotStateEnum.failed &&
          (snapshot.state == DiscoverySnapshotStateEnum.partial ||
              snapshot.warnings.isNotEmpty))
        NoticeBanner(
          tone: NoticeTone.warning,
          message: snapshot.warnings.isEmpty
              ? 'Some sources did not respond.'
              : snapshot.warnings.join('\n'),
          action: TextButton(
            onPressed: _loading ? null : _runQuery,
            child: const Text('Retry sources'),
          ),
        ),
      if (_error != null &&
          !_loading &&
          _items.isNotEmpty &&
          !(_discoveryForbidden && _error == _providerError))
        NoticeBanner(
          tone: NoticeTone.error,
          message: _error!,
          action: TextButton(
            onPressed: _failedPage ? _loadMore : _runQuery,
            child: Text(_failedPage ? 'Retry page' : 'Retry'),
          ),
        ),
      if (_truncated)
        const NoticeBanner(
          message: 'Showing a bounded result snapshot. Refine your search for more matches.',
        ),
    ];
  }

  Widget _content(
    Set<String> configuredColumns,
    String? locale,
    EdgeInsets gutters,
    bool television,
  ) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_discoveryForbidden) {
      return EmptyState(
        icon: Icons.travel_explore,
        title: 'Discover is unavailable',
        message: _providerError,
        action: FilledButton.tonalIcon(
          onPressed: _retryDiscoveryAccess,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.error(
        title: _mode == 'search' ? 'Search failed' : 'Results are unavailable',
        message: _error!,
        retryLabel: _failedPage ? 'Retry page' : 'Retry',
        onRetry: _failedPage ? _loadMore : _runQuery,
      );
    }
    if (_items.isEmpty) {
      if (_mode != 'search') {
        return const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing to show',
          message: 'No results are available for this view.',
        );
      }
      // Typing does not rebuild the screen, so this prompt follows the field.
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, _) {
          final query = value.text.trim();
          if (query.isEmpty) {
            return const EmptyState(
              icon: Icons.search,
              title: 'Search your indexers',
              message: 'Enter a torrent name to search.',
            );
          }
          if (_snapshot == null || query != _searchedQuery) {
            return EmptyState(
              icon: Icons.search,
              title: 'Ready to search',
              message: 'Press Enter to search for “$query”.',
              action: FilledButton.icon(
                onPressed: _submitSearch,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            );
          }
          return const EmptyState(
            icon: Icons.search_off,
            title: 'No matches',
            message: 'No results in this fetched snapshot.',
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
        final columns = visibleDiscoveryColumns(configuredColumns);
        final table =
            constraints.maxWidth >= 720 &&
            constraints.maxWidth -
                    gutters.horizontal -
                    discoveryFixedWidth(columns, scale) >=
                discoveryMinimumTitleWidth;
        final snapshot = _snapshot;
        return NotificationListener<ScrollNotification>(
          onNotification: _autoLoad,
          child: CustomScrollView(
            key: PageStorageKey('discovery-$_mode'),
            slivers: [
              if (snapshot != null)
                SliverPadding(
                  padding: gutters.add(const EdgeInsets.fromLTRB(12, 4, 12, 8)),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _countLine(snapshot, locale),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              if (table)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: DiscoveryTableHeader(
                    columns: columns,
                    scale: scale,
                    padding: gutters,
                    sort: _sort,
                    order: _order,
                    onSort: _loading ? null : _sortBy,
                    background: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              SliverPadding(
                padding: gutters,
                sliver: SliverList.builder(
                  findChildIndexCallback: (key) {
                    final index = _items.indexWhere(
                      (result) => ValueKey('result-${result.id}') == key,
                    );
                    return index < 0 ? null : index;
                  },
                  itemCount: _items.length,
                  itemBuilder: (context, index) => _resultRow(
                    _items[index],
                    columns,
                    locale,
                    table: table,
                    scale: scale,
                    television: television,
                    last: index == _items.length - 1,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _snapshot?.nextCursor == null
                    ? const SizedBox(height: 24)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Center(
                          child: FilledButton.tonalIcon(
                            onPressed: _loadingMore || _loading
                                ? null
                                : _loadMore,
                            icon: _loadingMore
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
      },
    );
  }

  /// Loads the next snapshot page when the user scrolls near the end. A
  /// failed page waits for an explicit retry instead of looping.
  bool _autoLoad(ScrollNotification notification) {
    if (notification.depth == 0 &&
        notification is ScrollUpdateNotification &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < 600 &&
        _snapshot?.nextCursor != null &&
        !_loadingMore &&
        !_loading &&
        !_failedPage) {
      unawaited(_loadMore());
    }
    return false;
  }

  String _countLine(DiscoverySnapshot snapshot, String? locale) {
    final total = snapshot.totalKnown;
    final count = formatCount(_items.length, locale: locale);
    final results = total == null || total == _items.length
        ? '$count ${_items.length == 1 ? 'result' : 'results'}'
        : '$count of ${formatCount(total, locale: locale)} results';
    return _mode == 'mostSeeded'
        ? 'Most seeded among fetched results · $results'
        : results;
  }

  Widget _resultRow(
    DiscoveryResult result,
    List<DiscoveryColumn> columns,
    String? locale, {
    required bool table,
    required double scale,
    required bool television,
    required bool last,
  }) {
    final key = ValueKey('result-${result.id}');
    final onAdd = _submitting ? null : () => _startDownload(result);
    final onTap = result.downloadable
        ? onAdd
        : () => _showMessage(
            'This source does not offer a downloadable torrent for this result.',
          );
    return table
        ? DiscoveryTableRow(
            key: key,
            result: result,
            columns: columns,
            scale: scale,
            locale: locale,
            onTap: onTap,
            onAdd: onAdd,
            television: television,
            divider: !last,
          )
        : DiscoveryResultTile(
            key: key,
            result: result,
            columns: columns,
            locale: locale,
            onTap: onTap,
            onAdd: onAdd,
            television: television,
            divider: !last,
          );
  }

  String? get _currentLocale =>
      ref.read(userPreferencesProvider).asData?.value.locale;

  Future<void> _showMagnetEntry() async {
    final libraries = _libraries
        .where((x) => x.enabled && x.capabilities.download)
        .toList();
    if (libraries.isEmpty) {
      _showMessage('No download-capable library is available to this account.');
      return;
    }
    final choice = await AddDownloadDialog.show(
      context: context,
      title: 'Add magnet link',
      libraries: libraries,
      confirmLabel: 'Add',
      askForMagnet: true,
    );
    final magnet = choice?.magnet;
    final destination = choice?.library;
    if (magnet == null || magnet.isEmpty || destination == null || !mounted) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final typedSource = DownloadSourceOneOf1(
        (b) => b
          ..kind = DownloadSourceOneOf1KindEnum.magnet
          ..value = magnet,
      );
      final source = DownloadSource(
        (b) => b.oneOf =
            OneOf.fromValue3<
              DownloadSourceOneOf,
              DownloadSourceOneOf1,
              DownloadSourceOneOf2
            >(value: typedSource),
      );
      final response = await requireActiveApi(ref)
          .getDownloadsApi()
          .createDownload(
            downloadCreate: DownloadCreate(
              (b) => b
                ..libraryId = destination.id
                ..source_ = source.toBuilder(),
            ),
            idempotencyKey: _uuid.v4(),
          );
      if (mounted && response.data != null) {
        context.push('/downloads/${Uri.encodeComponent(response.data!.id)}');
      }
    } catch (error) {
      if (mounted) _showMessage(clientError(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

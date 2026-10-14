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
import '../../core/widgets/owned_text_dialog.dart';

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
  bool _loading = true;
  bool _loadingMore = false;
  bool _submitting = false;
  bool _truncated = false;
  bool _preferencesApplied = false;
  bool _initialQueryStarted = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(userPreferencesProvider, (previous, next) {
      final preferences = next.asData?.value;
      if (preferences == null || _preferencesApplied || !mounted) return;
      _preferencesApplied = true;
      setState(() => _applySavedView('latest', preferences));
      if (_initialQueryStarted) unawaited(_runQuery());
    }, fireImmediately: true);
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
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await Future.wait([_loadProviders(), _loadLibraries()]);
    if (!mounted) return;
    _initialQueryStarted = true;
    await _runQuery();
  }

  void _changeMode(String mode, {bool runQuery = false}) {
    final preferences = ref.read(userPreferencesProvider).asData?.value;
    setState(() {
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
    try {
      final response = await requireActiveApi(ref)
          .getLibrariesApi()
          .listLibraries();
      if (!mounted) return;
      setState(
        () => _libraries =
            response.data?.whereType<ModelLibrary>().toList() ??
            <ModelLibrary>[],
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = 'Libraries could not be loaded: ${clientError(error)}',
      );
    }
  }

  Future<void> _loadProviders() async {
    try {
      final response = await requireActiveApi(ref)
          .getDiscoveryApi()
          .listProviders();
      if (!mounted) return;
      setState(() {
        _providers =
            response.data?.whereType<Provider>().toList() ?? <Provider>[];
        _providerError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _providerError = clientError(error));
    }
  }

  Future<void> _runQuery() async {
    final categories = _parseCategories(_categoryController.text);
    final minSize = _parseGib(_minSizeController.text);
    final maxSize = _parseGib(_maxSizeController.text);
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

    _queryCancel?.cancel('A newer discovery query started');
    final cancel = CancelToken();
    _queryCancel = cancel;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _snapshot = null;
      _items.clear();
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
      final first = await requireActiveApi(ref)
          .getDiscoveryApi()
          .createDiscoveryQuery(
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
        if (cancel.isCancelled) return;
        final response = await requireActiveApi(ref)
            .getDiscoveryApi()
            .getDiscoverySnapshot(
              id: snapshot.id,
              limit: _pageSize,
              cancelToken: cancel,
            );
        snapshot = response.data ?? snapshot;
      }
      if (!mounted || cancel.isCancelled) return;
      setState(() {
        _snapshot = snapshot;
        _items.addAll(snapshot.items);
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
      if (!mounted || cancel.isCancelled) return;
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
    if (snapshot == null || snapshot.nextCursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final response = await requireActiveApi(ref)
          .getDiscoveryApi()
          .getDiscoverySnapshot(
            id: snapshot.id,
            cursor: snapshot.nextCursor,
            limit: _pageSize,
          );
      if (!mounted || response.data == null) return;
      setState(() {
        _snapshot = response.data;
        _items.addAll(response.data!.items);
        _truncated = response.data!.truncated;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
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
    ModelLibrary? destination = libraries.first;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add download'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.title),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModelLibrary>(
                initialValue: destination,
                decoration: const InputDecoration(
                  labelText: 'Destination library',
                ),
                items: libraries
                    .map(
                      (library) => DropdownMenuItem(
                        value: library,
                        child: Text(library.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => destination = value),
              ),
              if (result.stale) ...[
                const SizedBox(height: 12),
                const Text(
                  'This result is stale. The server will re-resolve it before adding.',
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, destination != null),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || destination == null || !mounted) return;
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
                ..libraryId = destination!.id
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
    ModelLibrary? destination = libraries.first;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add torrent file'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(file.name),
              Text(formatBytes(size, locale: _currentLocale)),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModelLibrary>(
                initialValue: destination,
                decoration: const InputDecoration(
                  labelText: 'Destination library',
                ),
                items: libraries
                    .map(
                      (library) => DropdownMenuItem(
                        value: library,
                        child: Text(library.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() => destination = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, destination != null),
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || destination == null || !mounted) return;
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
                ..libraryId = destination!.id
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            tooltip: 'Upload .torrent file',
            onPressed: _submitting ? null : _uploadTorrent,
            icon: const Icon(Icons.upload_file),
          ),
        ],
      ),
      body: Column(
        children: [
          _modeControls(latestAvailable),
          _filters(),
          if (_providerError != null)
            MaterialBanner(
              content: Text(
                'Provider details are unavailable: $_providerError',
              ),
              actions: [
                TextButton(
                  onPressed: _loadProviders,
                  child: const Text('Retry providers'),
                ),
              ],
            ),
          if (_snapshot?.state == DiscoverySnapshotStateEnum.partial)
            MaterialBanner(
              content: Text(
                _snapshot!.warnings.isEmpty
                    ? 'Some sources did not respond.'
                    : _snapshot!.warnings.join('\n'),
              ),
              actions: const [],
            ),
          if (_error != null && !_loading)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(onPressed: _runQuery, child: const Text('Retry')),
              ],
            ),
          if (_truncated)
            const MaterialBanner(
              content: Text(
                'Showing a bounded result snapshot. Refine your search for more matches.',
              ),
              actions: [],
            ),
          if (_snapshot != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _mode == 'mostSeeded'
                      ? 'Most seeded among fetched results · ${formatCount(_items.length, locale: locale)}${_snapshot!.totalKnown == null ? '' : ' of ${formatCount(_snapshot!.totalKnown, locale: locale)}'}'
                      : '${formatCount(_items.length, locale: locale)}${_snapshot!.totalKnown == null ? '' : ' of ${formatCount(_snapshot!.totalKnown, locale: locale)}'} results · ${_snapshot!.state.name}',
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _items.isEmpty
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : _items.isEmpty
                ? Center(
                    child: Text(
                      _mode == 'search'
                          ? 'No results in this fetched snapshot.'
                          : 'No results are available for this view.',
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) =>
                        _resultTile(_items[index], configuredColumns, locale),
                  ),
          ),
          if (_snapshot?.nextCursor != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : _loadMore,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMagnetEntry,
        icon: const Icon(Icons.add_link),
        label: const Text('Add magnet'),
      ),
    );
  }

  Widget _modeControls(bool latestAvailable) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: const Text('Latest'),
          selected: _mode == 'latest',
          onSelected: (_) {
            if (!latestAvailable) {
              _showMessage(
                'No enabled provider supports recent releases. Use Search instead.',
              );
              return;
            }
            _changeMode('latest', runQuery: true);
          },
        ),
        ChoiceChip(
          label: const Text('Most seeded'),
          selected: _mode == 'mostSeeded',
          onSelected: (_) {
            _changeMode('mostSeeded', runQuery: true);
          },
        ),
        ChoiceChip(
          label: const Text('Search'),
          selected: _mode == 'search',
          onSelected: (_) => _changeMode('search'),
        ),
      ],
    ),
  );

  Widget _filters() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: Column(
      children: [
        if (_mode == 'search')
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Search torrent names',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _runQuery(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loading ? null : _runQuery,
                child: const Text('Search'),
              ),
            ],
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Filters and sort'),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category IDs',
                      hintText: 'Comma-separated',
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _minSizeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minimum GiB'),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _maxSizeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Maximum GiB'),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _minSeedersController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum seeders',
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _sort,
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'publishedAt',
                      child: Text('Publication date'),
                    ),
                    DropdownMenuItem(value: 'seeders', child: Text('Seeders')),
                    DropdownMenuItem(
                      value: 'leechers',
                      child: Text('Leechers'),
                    ),
                    DropdownMenuItem(
                      value: 'peers',
                      child: Text('Total peers'),
                    ),
                    DropdownMenuItem(value: 'sizeBytes', child: Text('Size')),
                    DropdownMenuItem(value: 'title', child: Text('Title')),
                  ],
                ),
                DropdownButton<String>(
                  value: _order,
                  onChanged: (value) {
                    if (value != null) setState(() => _order = value);
                  },
                  items: const [
                    DropdownMenuItem(value: 'desc', child: Text('Descending')),
                    DropdownMenuItem(value: 'asc', child: Text('Ascending')),
                  ],
                ),
              ],
            ),
            if (_providers.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 4,
                  children: _providers
                      .where((p) => p.enabled)
                      .map(
                        (provider) => FilterChip(
                          label: Text(provider.name),
                          selected: _providerIds.contains(provider.id),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _providerIds.add(provider.id)
                                : _providerIds.remove(provider.id);
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _runQuery,
                icon: const Icon(Icons.filter_alt),
                label: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _resultTile(
    DiscoveryResult result,
    Set<String> visibleColumns,
    String? locale,
  ) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: ListTile(
      title: Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            if (visibleColumns.contains('size'))
              Text(formatBytes(result.sizeBytes, locale: locale)),
            if (visibleColumns.contains('seeders'))
              Text('Seeders ${formatCount(result.seeders, locale: locale)}'),
            if (visibleColumns.contains('leechers'))
              Text('Leechers ${formatCount(result.leechers, locale: locale)}'),
            if (visibleColumns.contains('peers'))
              Text('Peers ${formatCount(result.peers, locale: locale)}'),
            if (visibleColumns.contains('provider')) Text(result.providerName),
            if (visibleColumns.contains('publishedAt'))
              Text(_publishedLabel(result.publishedAt, locale)),
            if (result.stale) const Chip(label: Text('Stale')),
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: 'Add to downloads',
        onPressed: result.downloadable && !_submitting
            ? () => _startDownload(result)
            : null,
        icon: const Icon(Icons.download_outlined),
      ),
    ),
  );

  String _publishedLabel(DateTime? value, String? locale) => value == null
      ? 'Date unknown'
      : 'Published ${formatDate(value, locale: locale)}';

  String? get _currentLocale =>
      ref.read(userPreferencesProvider).asData?.value.locale;

  Future<void> _showMagnetEntry() async {
    final magnet = await OwnedTextDialog.show(
      context: context,
      title: 'Add magnet link',
      label: 'Magnet URI',
      hintText: 'magnet:?xt=urn:btih:…',
      confirmLabel: 'Continue',
      maxLength: 65536,
    );
    if (magnet == null || magnet.isEmpty || !mounted) return;
    final libraries = _libraries
        .where((x) => x.enabled && x.capabilities.download)
        .toList();
    if (libraries.isEmpty) {
      _showMessage('No download-capable library is available to this account.');
      return;
    }
    ModelLibrary? destination = libraries.first;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose destination'),
          content: DropdownButtonFormField<ModelLibrary>(
            initialValue: destination,
            items: libraries
                .map((x) => DropdownMenuItem(value: x, child: Text(x.name)))
                .toList(),
            onChanged: (x) => setDialogState(() => destination = x),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, destination != null),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || destination == null) return;
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
                ..libraryId = destination!.id
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

List<int>? _parseCategories(String value) {
  if (value.trim().isEmpty) return null;
  final values = value.split(',').map((x) => int.tryParse(x.trim())).toList();
  if (values.any((x) => x == null || x < 0)) return null;
  return values.cast<int>();
}

int? _parseGib(String value) {
  if (value.trim().isEmpty) return null;
  final number = double.tryParse(value.trim());
  if (number == null || number < 0 || number > 100000) return null;
  return (number * 1024 * 1024 * 1024).round();
}

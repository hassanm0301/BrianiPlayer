import 'dart:typed_data';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/client_session.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/formatting/locale_formatters.dart';
import '../../core/widgets/owned_text_dialog.dart';

@immutable
class FolderBreadcrumb {
  const FolderBreadcrumb({required this.id, required this.name});
  final String id;
  final String name;
}

class FolderScreen extends ConsumerStatefulWidget {
  const FolderScreen({
    super.key,
    required this.libraryId,
    this.folderId = 'root',
    this.folderName,
    this.breadcrumbs = const [],
  });
  final String libraryId;
  final String folderId;
  final String? folderName;
  final List<FolderBreadcrumb> breadcrumbs;
  @override
  ConsumerState<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends ConsumerState<FolderScreen> {
  ModelLibrary? _library;
  List<Entry> _items = [];
  String? _cursor;
  String? _error;
  String _query = '';
  String _sort = 'name';
  String _order = 'asc';
  bool _grid = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _truncated = false;
  bool _preferencesApplied = false;
  String? _preferenceScope;
  final _search = TextEditingController();
  CancelToken? _operationToken;

  List<FolderBreadcrumb> get _breadcrumbPath {
    if (widget.breadcrumbs.isNotEmpty) return widget.breadcrumbs;
    final root = FolderBreadcrumb(
      id: 'root',
      name: _library?.name ?? 'Library',
    );
    if (widget.folderId == 'root') return [root];
    return [
      root,
      FolderBreadcrumb(
        id: widget.folderId,
        name: widget.folderName ?? 'Folder',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(userPreferencesProvider, (previous, next) {
      final preferences = next.asData?.value;
      if (preferences == null || !mounted) return;
      final scope = ref.read(userPreferencesScopeProvider);
      if (!_preferencesApplied || scope != _preferenceScope) {
        _preferenceScope = scope;
        _applyPreferences(preferences);
        _preferencesApplied = true;
        _load(reset: true);
      }
    }, fireImmediately: true);
    if (!_preferencesApplied) {
      _applyPreferences(defaultUserPreferences());
      _load(reset: true);
    }
  }

  void _applyPreferences(UserPreferences preferences) {
    final saved = preferences.rememberFolderSort == true
        ? preferences.folderPreferences
              ?.where(
                (entry) =>
                    entry.libraryId == widget.libraryId &&
                    entry.folderId ==
                        (widget.folderId == 'root' ? null : widget.folderId),
              )
              .firstOrNull
        : null;
    final sort = saved?.sort.name ?? preferences.defaultSort?.name ?? 'byName';
    _sort = switch (sort) {
      'date' => 'modifiedAt',
      'size' => 'sizeBytes',
      _ => 'name',
    };
    _order = saved?.order.name ?? preferences.defaultSortOrder?.name ?? 'asc';
    _grid =
        (saved?.layout.name ?? preferences.libraryLayout?.name ?? 'grid') ==
        'grid';
  }

  Future<void> _persistFolderPreferences() async {
    final current = ref.read(userPreferencesProvider).asData?.value;
    if (current == null || current.rememberFolderSort != true) return;
    final folderId = widget.folderId == 'root' ? null : widget.folderId;
    final updated =
        current.folderPreferences
            ?.where(
              (entry) =>
                  !(entry.libraryId == widget.libraryId &&
                      entry.folderId == folderId),
            )
            .toList() ??
        [];
    updated.add(
      UserPreferencesFolderPreferencesInner(
        (b) => b
          ..libraryId = widget.libraryId
          ..folderId = folderId
          ..layout = _grid
              ? UserPreferencesFolderPreferencesInnerLayoutEnum.grid
              : UserPreferencesFolderPreferencesInnerLayoutEnum.list
          ..sort = switch (_sort) {
            'modifiedAt' => UserPreferencesFolderPreferencesInnerSortEnum.date,
            'sizeBytes' => UserPreferencesFolderPreferencesInnerSortEnum.size,
            _ => UserPreferencesFolderPreferencesInnerSortEnum.byName,
          }
          ..order = UserPreferencesFolderPreferencesInnerOrderEnum.valueOf(
            _order,
          ),
      ),
    );
    try {
      await ref
          .read(userPreferencesProvider.notifier)
          .update((b) => b.folderPreferences.replace(updated));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Folder preference could not be saved.'),
          ),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant FolderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final folderChanged =
        oldWidget.libraryId != widget.libraryId ||
        oldWidget.folderId != widget.folderId;
    if (folderChanged) {
      final preferences = ref.read(userPreferencesProvider).asData?.value;
      if (preferences != null) _applyPreferences(preferences);
    }
    if (folderChanged ||
        oldWidget.folderName != widget.folderName ||
        !_sameBreadcrumbs(oldWidget.breadcrumbs, widget.breadcrumbs)) {
      _load(reset: true);
    }
  }

  bool _sameBreadcrumbs(List<FolderBreadcrumb> a, List<FolderBreadcrumb> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].name != b[i].name) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _operationToken?.cancel('Folder screen disposed');
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _cursor = null;
        _items = [];
      });
    } else {
      if (_cursor == null || _loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final api = requireActiveApi(ref);
      final libs = _library == null
          ? await api.getLibrariesApi().listLibraries()
          : null;
      final lib =
          _library ?? libs!.data!.firstWhere((x) => x.id == widget.libraryId);
      final page = await api.getLibrariesApi().listEntries(
        id: widget.libraryId,
        folderId: widget.folderId == 'root' ? null : widget.folderId,
        query: _query.trim().isEmpty ? null : _query.trim(),
        sort: _sort,
        order: _order,
        cursor: reset ? null : _cursor,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _library = lib;
        if (reset) {
          _items = page.data!.items.toList();
        } else {
          _items.addAll(page.data!.items);
        }
        _cursor = page.data!.nextCursor;
        _truncated = page.data!.truncated;
        _error = null;
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
    }
  }

  bool get _canManage =>
      (_library?.capabilities.manage ?? false) && !(_library?.readOnly ?? true);

  void _navigateToBreadcrumb(int index) {
    final path = _breadcrumbPath.take(index + 1).toList(growable: false);
    final breadcrumb = path.last;
    if (breadcrumb.id == 'root') {
      context.go('/libraries/${Uri.encodeComponent(widget.libraryId)}');
      return;
    }
    context.go(
      '/libraries/${Uri.encodeComponent(widget.libraryId)}/folders/${Uri.encodeComponent(breadcrumb.id)}',
      extra: path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(userPreferencesProvider).asData?.value.locale;
    return Scaffold(
      appBar: AppBar(
        title: Text(_library?.name ?? 'Library'),
        actions: [
          IconButton(
            tooltip: _grid ? 'List view' : 'Grid view',
            icon: Icon(_grid ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() => _grid = !_grid);
              _persistFolderPreferences();
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Sort',
            initialValue: '$_sort:$_order',
            onSelected: (value) {
              final parts = value.split(':');
              setState(() {
                _sort = parts[0];
                _order = parts[1];
              });
              _persistFolderPreferences();
              _load(reset: true);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'name:asc', child: Text('Name (A–Z)')),
              PopupMenuItem(value: 'name:desc', child: Text('Name (Z–A)')),
              PopupMenuItem(
                value: 'modifiedAt:desc',
                child: Text('Recently changed'),
              ),
              PopupMenuItem(
                value: 'sizeBytes:desc',
                child: Text('Largest first'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < _breadcrumbPath.length; i++) ...[
                            if (i > 0) const Icon(Icons.chevron_right),
                            if (i == _breadcrumbPath.length - 1)
                              Text(
                                _breadcrumbPath[i].name,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              TextButton(
                                onPressed: () => _navigateToBreadcrumb(i),
                                child: Text(_breadcrumbPath[i].name),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search this folder',
                suffixIcon: IconButton(
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                    _load(reset: true);
                  },
                  icon: const Icon(Icons.clear),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                setState(() => _query = value);
                _load(reset: true);
              },
            ),
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
          if (_truncated)
            const MaterialBanner(
              content: Text(
                'Some entries could not be listed. Refresh to retry the scan.',
              ),
              actions: [],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'This folder is empty.'
                          : 'No matching files.',
                    ),
                  )
                : _grid
                ? _gridView(locale)
                : _listView(locale),
          ),
          if (_cursor != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _load(reset: false),
                icon: _loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listView(String? locale) => ListView.builder(
    itemCount: _items.length,
    itemBuilder: (context, index) => _entryTile(_items[index], locale: locale),
  );
  Widget _gridView(String? locale) => GridView.builder(
    padding: const EdgeInsets.all(12),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 220,
      childAspectRatio: .9,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemCount: _items.length,
    itemBuilder: (context, index) =>
        _entryTile(_items[index], grid: true, locale: locale),
  );

  Widget _entryTile(Entry entry, {bool grid = false, String? locale}) {
    final folder = entry.kind == EntryKindEnum.folder;
    final photo = entry.kind == EntryKindEnum.photo;
    final video = entry.kind == EntryKindEnum.video;
    final icon = folder
        ? Icons.folder_outlined
        : photo
        ? Icons.image_outlined
        : video
        ? Icons.movie_outlined
        : Icons.subtitles_outlined;
    final thumbId = entry.mediaId;
    final shownName = _displayName(entry.name, folder: folder);
    final leading = entry.thumbnailAvailable && thumbId != null
        ? _AuthorizedThumbnail(mediaId: thumbId)
        : Icon(icon, size: grid ? 50 : 32);
    final canEdit = _canManage && !folder && (video || photo);
    return Card(
      key: ValueKey('entry-${entry.id}'),
      child: InkWell(
        onTap: () {
          if (folder) {
            context.push(
              '/libraries/${Uri.encodeComponent(widget.libraryId)}/folders/${Uri.encodeComponent(entry.id)}',
              extra: [
                ..._breadcrumbPath,
                FolderBreadcrumb(id: entry.id, name: entry.name),
              ],
            );
          } else if (photo && thumbId != null) {
            context.push(
              '/photos/${Uri.encodeComponent(thumbId)}',
              extra: _items
                  .where(
                    (e) => e.kind == EntryKindEnum.photo && e.mediaId != null,
                  )
                  .map((e) => e.mediaId!)
                  .toList(),
            );
          } else if (video && thumbId != null) {
            context.push('/play/media/${Uri.encodeComponent(thumbId)}');
          } else {
            _showDetails(entry, locale);
          }
        },
        child: grid
            ? Column(
                children: [
                  Expanded(child: Center(child: leading)),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 4,
                      bottom: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            shownName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!folder)
                          IconButton(
                            tooltip: 'Details',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => _showDetails(entry, locale),
                          ),
                        if (canEdit)
                          PopupMenuButton<String>(
                            tooltip: 'File actions',
                            onSelected: (action) => _action(entry, action),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(value: 'move', child: Text('Move')),
                              PopupMenuItem(
                                value: 'trash',
                                child: Text('Move to trash'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              )
            : ListTile(
                leading: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(child: leading),
                ),
                title: Text(
                  shownName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    if (entry.sizeBytes != null)
                      formatBytes(entry.sizeBytes, locale: locale),
                    if (entry.modifiedAt != null)
                      formatDate(entry.modifiedAt!, locale: locale),
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!folder)
                      IconButton(
                        tooltip: 'Details',
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showDetails(entry, locale),
                      ),
                    if (canEdit)
                      PopupMenuButton<String>(
                        tooltip: 'File actions',
                        onSelected: (action) => _action(entry, action),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'move', child: Text('Move')),
                          PopupMenuItem(
                            value: 'trash',
                            child: Text('Move to trash'),
                          ),
                        ],
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
      ),
    );
  }

  String _displayName(String name, {required bool folder}) {
    if (folder ||
        ref
                .read(userPreferencesProvider)
                .asData
                ?.value
                .showFilenameExtensions !=
            false) {
      return name;
    }
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<void> _showDetails(
    Entry entry,
    String? locale,
  ) async => showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<Media?>(
          future: entry.mediaId == null
              ? Future.value(null)
              : requireActiveApi(ref)
                    .getMediaApi()
                    .getMedia(id: entry.mediaId!)
                    .then((r) => r.data),
          builder: (context, snapshot) {
            final media = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text('Type: ${entry.kind.name}'),
                if (entry.sizeBytes != null)
                  Text('Size: ${formatBytes(entry.sizeBytes, locale: locale)}'),
                if (entry.modifiedAt != null)
                  Text(
                    'Modified: ${formatDateTime(entry.modifiedAt!, locale: locale)}',
                  ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (snapshot.hasError) Text(clientError(snapshot.error!)),
                if (media != null) ...[
                  Text('Format: ${media.mimeType}'),
                  if (media.durationMs != null)
                    Text('Duration: ${_duration(media.durationMs!)}'),
                  if (media.width != null && media.height != null)
                    Text('Dimensions: ${media.width} × ${media.height}'),
                  if (media.probeState == MediaProbeStateEnum.unsupported)
                    const Text(
                      'This file format is not supported for playback.',
                    ),
                  if (media.probeState == MediaProbeStateEnum.pending)
                    const Text('Media details are still being checked.'),
                  if (media.probeState == MediaProbeStateEnum.failed)
                    const Text('Media details could not be read.'),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );

  Future<void> _action(Entry entry, String action) async {
    final api = requireActiveApi(ref).getMediaApi();
    try {
      if (action == 'rename') {
        final name = await OwnedTextDialog.show(
          context: context,
          title: 'Rename file',
          label: 'Name',
          confirmLabel: 'Rename',
          initialText: entry.name,
        );
        if (name == null || name.isEmpty || name == entry.name) return;
        final response = await api.renameMedia(
          id: entry.mediaId!,
          renameRequest: RenameRequest(
            (b) => b
              ..name = name
              ..version = entry.version,
          ),
        );
        if (!await _waitForOperation(response.data)) return;
      } else if (action == 'move') {
        final target = await showDialog<_MoveTarget>(
          context: context,
          builder: (context) => _FolderMovePicker(
            libraryId: widget.libraryId,
            currentFolderId: entry.parentId,
          ),
        );
        if (!mounted || target == null) return;
        final response = await api.moveMedia(
          id: entry.mediaId!,
          moveRequest: MoveRequest(
            (b) => b
              ..targetFolderId = target.folderId
              ..version = entry.version,
          ),
        );
        if (!await _waitForOperation(response.data)) return;
      } else if (action == 'trash') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Move to trash?'),
            content: Text('“${entry.name}” will be moved to the server trash.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Move to trash'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        final response = await api.deleteMedia(
          id: entry.mediaId!,
          version: entry.version,
          mode: 'trash',
          force: false,
        );
        if (!await _waitForOperation(response.data)) return;
      }
      await _load(reset: true);
    } catch (error) {
      if (mounted) {
        final message = error is _MutationFailure
            ? error.message
            : error is DioException && error.response?.statusCode == 409
            ? 'This file is in use or changed. Close active playback or refresh before retrying.'
            : clientError(error);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<bool> _waitForOperation(Operation? accepted) async {
    if (accepted == null) {
      throw const _MutationFailure(
        'The server did not return an operation status.',
      );
    }
    var operation = accepted;
    final token = CancelToken();
    _operationToken?.cancel('Superseded by another action');
    _operationToken = token;
    try {
      for (var attempt = 0; attempt < 40; attempt++) {
        if (operation.state == OperationStateEnum.completed) return true;
        if (operation.state == OperationStateEnum.failed) {
          throw _MutationFailure(_operationProblem(operation.error));
        }
        if (!mounted || token.isCancelled) return false;
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted || token.isCancelled) return false;
        operation =
            (await requireActiveApi(ref)
                    .getOperationsApi()
                    .getOperation(id: operation.id, cancelToken: token))
                .data!;
      }
      throw const _MutationFailure(
        'The server is still processing this change. Refresh shortly to check its result.',
      );
    } finally {
      if (identical(_operationToken, token)) _operationToken = null;
    }
  }

  String _operationProblem(Problem? problem) {
    if (problem == null) return 'The server could not complete this change.';
    final code = problem.code.toLowerCase();
    if (code.contains('inuse') || code.contains('in_use')) {
      return 'This file is in use. Close active playback and retry.';
    }
    if (problem.status == 409 || code.contains('conflict')) {
      return 'This file changed or is in use. Refresh and try again.';
    }
    final trace = problem.traceId;
    return trace == null || trace.isEmpty
        ? problem.title
        : '${problem.title} (reference $trace)';
  }
}

class _MutationFailure implements Exception {
  const _MutationFailure(this.message);
  final String message;
}

@immutable
class _MoveTarget {
  const _MoveTarget(this.folderId);
  final String? folderId;
}

class _FolderMovePicker extends ConsumerStatefulWidget {
  const _FolderMovePicker({
    required this.libraryId,
    required this.currentFolderId,
  });
  final String libraryId;
  final String? currentFolderId;

  @override
  ConsumerState<_FolderMovePicker> createState() => _FolderMovePickerState();
}

class _FolderMovePickerState extends ConsumerState<_FolderMovePicker> {
  final List<Entry> _stack = [];
  final List<Entry> _folders = [];
  String? _cursor;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_requestGeneration : _requestGeneration;
    if (reset) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _cursor = null;
        _folders.clear();
      });
    } else {
      if (_cursor == null || _loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final page = await requireActiveApi(ref)
          .getLibrariesApi()
          .listEntries(
            id: widget.libraryId,
            folderId: _stack.isEmpty ? null : _stack.last.id,
            kind: 'folder',
            limit: 50,
            cursor: reset ? null : _cursor,
            sort: 'name',
            order: 'asc',
          );
      if (!mounted) return;
      if (generation != _requestGeneration) return;
      setState(() {
        _folders.addAll(page.data!.items);
        _cursor = page.data!.nextCursor;
        _error = null;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (generation != _requestGeneration) return;
      setState(() {
        _error = clientError(error);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _open(Entry folder) {
    _requestGeneration++;
    setState(() => _stack.add(folder));
    _load(reset: true);
  }

  void _goUp() {
    if (_stack.isEmpty) return;
    _requestGeneration++;
    setState(() => _stack.removeLast());
    _load(reset: true);
  }

  void _chooseRoot() => Navigator.pop(context, const _MoveTarget(null));

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 520,
      height: 480,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: _stack.isEmpty ? 'Cancel' : 'Parent folder',
                  onPressed: _stack.isEmpty
                      ? () => Navigator.pop(context)
                      : _goUp,
                  icon: Icon(_stack.isEmpty ? Icons.close : Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Move to folder',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _chooseRoot,
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Select library root'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ['Library', ..._stack.map((e) => e.name)].join('  ›  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: () => _load(reset: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _folders.isEmpty
                ? const Center(child: Text('No subfolders here.'))
                : ListView.builder(
                    itemCount: _folders.length,
                    itemBuilder: (context, index) {
                      final folder = _folders[index];
                      final current = folder.id == widget.currentFolderId;
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(folder.name),
                        subtitle: current ? const Text('Current folder') : null,
                        onTap: () => _open(folder),
                        trailing: TextButton(
                          onPressed: current
                              ? null
                              : () => Navigator.pop(
                                  context,
                                  _MoveTarget(folder.id),
                                ),
                          child: const Text('Select'),
                        ),
                      );
                    },
                  ),
          ),
          if (_cursor != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton.icon(
                onPressed: _loadingMore ? null : () => _load(reset: false),
                icon: _loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: const Text('Load more folders'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _AuthorizedThumbnail extends ConsumerStatefulWidget {
  const _AuthorizedThumbnail({required this.mediaId});
  final String mediaId;
  @override
  ConsumerState<_AuthorizedThumbnail> createState() =>
      _AuthorizedThumbnailState();
}

class _AuthorizedThumbnailState extends ConsumerState<_AuthorizedThumbnail> {
  Future<Uint8List>? _future;
  @override
  void initState() {
    super.initState();
    _future = requireActiveApi(ref)
        .getMediaApi()
        .getThumbnail(id: widget.mediaId)
        .then((r) => r.data!);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _future,
    builder: (context, snapshot) => snapshot.hasData
        ? ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              width: 48,
              height: 48,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          )
        : const Icon(Icons.image_outlined, size: 30),
  );
}

String _duration(int ms) {
  final seconds = ms ~/ 1000;
  return '${seconds ~/ 3600}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

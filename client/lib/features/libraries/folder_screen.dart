import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatting/locale_formatters.dart';
import '../../core/input/remote_navigation.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/session/client_session.dart';
import '../../core/widgets/adaptive.dart';
import '../../core/widgets/media_tile.dart';
import '../../core/widgets/owned_text_dialog.dart';
import '../../core/widgets/states.dart';

part 'folder_entry_views.dart';
part 'folder_dialogs.dart';

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

const _sortOptions = [
  ('name:asc', 'Name (A–Z)'),
  ('name:desc', 'Name (Z–A)'),
  ('date:desc', 'Recently changed'),
  ('size:desc', 'Largest first'),
];

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
  final _searchFocus = FocusNode(debugLabel: 'folder search');
  bool _searchOpen = false;
  Offset? _menuAnchor;
  CancelToken? _operationToken;
  CancelToken? _loadToken;
  bool _viewEdited = false;
  bool _failedPage = false;
  List<String> _warnings = [];
  int _requestGeneration = 0;

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
    ref.listenManual(activeApiProvider, (previous, next) {
      if (!mounted || identical(previous, next)) return;
      _loadToken?.cancel('The signed-in session changed');
      _operationToken?.cancel('The signed-in session changed');
      ++_requestGeneration;
      setState(() {
        _library = null;
        _items = [];
        _cursor = null;
        _warnings = [];
        _truncated = false;
        _error = null;
        _loading = next != null;
        _loadingMore = false;
        _viewEdited = false;
        _preferencesApplied = false;
      });
      if (next != null) _load(reset: true);
    });
    ref.listenManual(userPreferencesProvider, (previous, next) {
      final preferences = next.asData?.value;
      if (preferences == null || !mounted) return;
      final scope = ref.read(userPreferencesScopeProvider);
      if (!_preferencesApplied || scope != _preferenceScope) {
        _preferenceScope = scope;
        _preferencesApplied = true;
        if (!_viewEdited) {
          _applyPreferences(preferences);
          _load(reset: true);
        }
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
      'date' => 'date',
      'size' => 'size',
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
            'date' => UserPreferencesFolderPreferencesInnerSortEnum.date,
            'size' => UserPreferencesFolderPreferencesInnerSortEnum.size,
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(clientError(error))));
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
      _library = null;
      _items = [];
      _warnings = [];
      _truncated = false;
      _query = '';
      _search.clear();
      _searchOpen = false;
      _viewEdited = false;
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
    _loadToken?.cancel('Folder screen disposed');
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_cursor == null || _loadingMore || _loading)) return;
    _loadToken?.cancel('A newer folder request started');
    final token = _loadToken = CancelToken();
    final generation = ++_requestGeneration;
    final libraryId = widget.libraryId;
    final folderId = widget.folderId == 'root' ? null : widget.folderId;
    final query = _query.trim().isEmpty ? null : _query.trim();
    final sort = _sort;
    final order = _order;
    final cursor = reset ? null : _cursor;
    setState(() {
      _loading = reset;
      _loadingMore = !reset;
      if (reset) _cursor = null;
      _error = null;
      _failedPage = false;
    });
    BrianiApi? api;
    bool current() =>
        mounted &&
        !token.isCancelled &&
        generation == _requestGeneration &&
        identical(ref.read(activeApiProvider), api);
    try {
      api = requireActiveApi(ref);
      final libs = _library == null
          ? await api.getLibrariesApi().listLibraries(cancelToken: token)
          : null;
      if (!current()) return;
      final lib = _library ?? libs!.data!.firstWhere((x) => x.id == libraryId);
      final page = await api.getLibrariesApi().listEntries(
        id: libraryId,
        folderId: folderId,
        query: query,
        sort: sort,
        order: order,
        cursor: cursor,
        limit: 50,
        cancelToken: token,
      );
      if (!current()) return;
      final result = page.data!;
      setState(() {
        _library = lib;
        if (reset) {
          _items = result.items.toList();
        } else {
          final existing = _items.map((entry) => entry.id).toSet();
          _items.addAll(result.items.where((entry) => existing.add(entry.id)));
        }
        _cursor = result.nextCursor;
        _truncated = reset ? result.truncated : _truncated || result.truncated;
        _warnings = reset
            ? result.warnings.toList()
            : {..._warnings, ...result.warnings}.toList();
        _error = null;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!current()) return;
      setState(() {
        _error = clientError(error);
        _failedPage = !reset;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  bool get _canManage =>
      (_library?.capabilities.manage ?? false) && !(_library?.readOnly ?? true);

  bool _canEdit(Entry entry) =>
      _canManage &&
      (entry.kind == EntryKindEnum.video || entry.kind == EntryKindEnum.photo);

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

  void _applySort(String value) {
    final parts = value.split(':');
    setState(() {
      _viewEdited = true;
      _sort = parts[0];
      _order = parts[1];
    });
    _persistFolderPreferences();
    _load(reset: true);
  }

  void _toggleLayout() {
    setState(() {
      _viewEdited = true;
      _grid = !_grid;
    });
    _persistFolderPreferences();
  }

  void _submitSearch(String value) {
    setState(() => _query = value);
    _load(reset: true);
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
    _load(reset: true);
  }

  void _closeSearch() {
    final hadQuery = _query.isNotEmpty;
    _search.clear();
    setState(() {
      _searchOpen = false;
      _query = '';
    });
    if (hadQuery) _load(reset: true);
  }

  bool _onScroll(ScrollNotification notification) {
    // Fetch the next page shortly before the end; the visible Load more
    // button remains for keyboard/TV users and after a failed page.
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < 600 &&
        _cursor != null &&
        !_loading &&
        !_loadingMore &&
        !_failedPage) {
      _load(reset: false);
    }
    return false;
  }

  void _open(Entry entry, String? locale) {
    final mediaId = entry.mediaId;
    switch (entry.kind) {
      case EntryKindEnum.folder:
        context.push(
          '/libraries/${Uri.encodeComponent(widget.libraryId)}/folders/${Uri.encodeComponent(entry.id)}',
          extra: [
            ..._breadcrumbPath,
            FolderBreadcrumb(id: entry.id, name: entry.name),
          ],
        );
      case EntryKindEnum.photo when mediaId != null:
        context.push(
          '/photos/${Uri.encodeComponent(mediaId)}',
          extra: _items
              .where((e) => e.kind == EntryKindEnum.photo && e.mediaId != null)
              .map((e) => e.mediaId!)
              .toList(),
        );
      case EntryKindEnum.video when mediaId != null:
        context.push('/play/media/${Uri.encodeComponent(mediaId)}');
      default:
        _showDetails(entry, locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(activeApiProvider) == null) return const SizedBox.shrink();
    final locale = ref.watch(userPreferencesProvider).asData?.value.locale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 600;
        final path = _breadcrumbPath;
        final atRoot = path.length <= 1;
        final searching = compact && (_searchOpen || _query.isNotEmpty);
        final gutters = pageGutters(context);
        // On phones Back first leaves search mode, like other Android apps.
        return PopScope(
          canPop: !searching,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && searching) _closeSearch();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: searching
                  ? IconButton(
                      tooltip: 'Close search',
                      onPressed: _closeSearch,
                      icon: const Icon(Icons.arrow_back),
                    )
                  // Reached through a breadcrumb or link, there is no page
                  // to pop; offer the way up instead of no back button.
                  : !Navigator.of(context).canPop()
                  ? IconButton(
                      tooltip: atRoot ? 'All libraries' : 'Up to parent folder',
                      onPressed: () => atRoot
                          ? context.go('/libraries')
                          : _navigateToBreadcrumb(path.length - 2),
                      icon: const Icon(Icons.arrow_back),
                    )
                  : null,
              titleSpacing: searching ? 0 : null,
              title: searching
                  ? _searchField(autofocus: _searchOpen && _query.isEmpty)
                  : compact || atRoot
                  ? Text(
                      path.last.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : _BreadcrumbTrail(
                      path: path,
                      prominent: true,
                      onSelected: _navigateToBreadcrumb,
                    ),
              actions: [
                if (!compact)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: width >= 1100 ? 320 : 240,
                        child: _searchField(),
                      ),
                    ),
                  ),
                if (compact && !searching)
                  IconButton(
                    tooltip: 'Search this folder',
                    onPressed: () => setState(() => _searchOpen = true),
                    icon: const Icon(Icons.search),
                  ),
                if (!searching) ...[_sortButton(), _layoutButton()],
                // Touch phones refresh by pulling the list; keep the app bar
                // uncluttered there so the folder name stays readable.
                if (!compact || pointerPlatform)
                  IconButton(
                    tooltip: 'Refresh folder',
                    onPressed: _loading ? null : () => _load(reset: true),
                    icon: const Icon(Icons.refresh),
                  ),
                const SizedBox(width: 8),
              ],
              bottom: compact && !atRoot && !searching
                  ? _BreadcrumbBar(
                      path: path,
                      padding: gutters,
                      onSelected: _navigateToBreadcrumb,
                      textScale: _textScale,
                    )
                  : null,
            ),
            body: Stack(
              children: [
                Positioned.fill(
                  child: _body(locale, width: width, gutters: gutters),
                ),
                if (_loading && _items.isNotEmpty)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _searchField({bool autofocus = false}) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _search,
        builder: (context, value, _) => TextField(
          controller: _search,
          focusNode: _searchFocus,
          autofocus: autofocus,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search this folder',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: value.text.isEmpty && _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close, size: 20),
                  ),
          ),
          onSubmitted: _submitSearch,
        ),
      );

  Widget _sortButton() => PopupMenuButton<String>(
    tooltip: 'Sort',
    icon: const Icon(Icons.sort),
    position: PopupMenuPosition.under,
    onSelected: _applySort,
    itemBuilder: (_) => [
      for (final (value, label) in _sortOptions)
        CheckedPopupMenuItem<String>(
          value: value,
          checked: value == '$_sort:$_order',
          child: Text(label),
        ),
    ],
  );

  Widget _layoutButton() => IconButton(
    tooltip: _grid ? 'List view' : 'Grid view',
    onPressed: _toggleLayout,
    icon: Icon(_grid ? Icons.view_list_outlined : Icons.grid_view_outlined),
  );

  Widget _body(
    String? locale, {
    required double width,
    required EdgeInsets gutters,
  }) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState.error(
        title: 'Files could not be loaded',
        message: _error!,
        onRetry: () => _load(reset: !_failedPage),
      );
    }
    final folders = [
      for (final entry in _items)
        if (entry.kind == EntryKindEnum.folder) entry,
    ];
    final files = [
      for (final entry in _items)
        if (entry.kind != EntryKindEnum.folder) entry,
    ];
    final notices = <Widget>[
      if (_error != null && !_loading)
        NoticeBanner(
          tone: NoticeTone.error,
          message: _error!,
          action: TextButton(
            onPressed: () => _load(reset: !_failedPage),
            child: Text(_failedPage ? 'Retry page' : 'Retry'),
          ),
        ),
      if (_truncated || _warnings.isNotEmpty)
        NoticeBanner(
          tone: NoticeTone.warning,
          message: _warnings.isEmpty
              ? 'Some entries could not be listed. Retry the scan.'
              : _warnings.join('\n'),
          action: TextButton(
            onPressed: _loading ? null : () => _load(reset: true),
            child: const Text('Retry scan'),
          ),
        ),
    ];
    final content = gutters.copyWith(top: 12, bottom: 0);
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          key: PageStorageKey(
            'folder-${_grid ? 'grid' : 'list'}-${widget.libraryId}-${widget.folderId}',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            for (final notice in notices)
              SliverPadding(
                padding: gutters.copyWith(top: 12),
                sliver: SliverToBoxAdapter(child: notice),
              ),
            if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _query.isEmpty
                    ? EmptyState(
                        icon: Icons.folder_open_outlined,
                        title: 'This folder is empty.',
                        action: TextButton.icon(
                          onPressed: () => _load(reset: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      )
                    : EmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'No matching files.',
                        message:
                            'Nothing in this folder matches “${_query.trim()}”.',
                        action: TextButton(
                          onPressed: _searchOpen ? _closeSearch : _clearSearch,
                          child: const Text('Clear search'),
                        ),
                      ),
              )
            else if (_grid) ...[
              if (folders.isNotEmpty)
                SliverPadding(
                  padding: content,
                  sliver: _folderGrid(folders, width),
                ),
              if (files.isNotEmpty)
                SliverPadding(
                  padding: content.copyWith(
                    left: content.left - 4,
                    right: content.right - 4,
                    top: folders.isEmpty ? 8 : 20,
                  ),
                  sliver: _fileGrid(
                    files,
                    locale,
                    width - gutters.horizontal + 8,
                  ),
                ),
            ] else ...[
              if (width >= 720)
                SliverPadding(
                  padding: content.copyWith(
                    left: content.left - 8,
                    right: content.right - 8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ListHeader(
                      sort: _sort,
                      order: _order,
                      onSort: _applySort,
                    ),
                  ),
                ),
              SliverPadding(
                padding: content.copyWith(
                  left: content.left - 8,
                  right: content.right - 8,
                  top: width >= 720 ? 4 : 8,
                ),
                sliver: _entryList(
                  [...folders, ...files],
                  locale,
                  wide: width >= 720,
                ),
              ),
            ],
            if (_cursor != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: _loadingMore || _loading
                          ? null
                          : () => _load(reset: false),
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
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  double get _textScale =>
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

  Widget _folderGrid(List<Entry> folders, double width) => SliverGrid(
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: width < 600 ? 240 : 300,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      mainAxisExtent: 56 * _textScale,
    ),
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        final entry = folders[index];
        return KeyedSubtree(
          key: ValueKey('entry-${entry.id}'),
          child: _FolderCard(name: entry.name, onTap: () => _open(entry, null)),
        );
      },
      childCount: folders.length,
      findChildIndexCallback: (key) => _indexIn(folders, key),
    ),
  );

  Widget _fileGrid(List<Entry> files, String? locale, double available) {
    final photos = files.every((entry) => entry.kind == EntryKindEnum.photo);
    final aspect = photos ? 1.0 : 16 / 9;
    const spacing = 8.0;
    final compact = available < 560;
    final maxExtent = photos ? 220.0 : 300.0;
    final columns = compact
        ? 2
        : ((available + spacing) / (maxExtent + spacing)).ceil().clamp(2, 12);
    final tileWidth = (available - spacing * (columns - 1)) / columns;
    // MediaTile: 4dp padding around artwork, then up to two title lines and
    // a metadata line, all scaled with the user's text size.
    final extent = 8 + (tileWidth - 8) / aspect + 70 * _textScale;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 4,
        crossAxisSpacing: spacing,
        mainAxisExtent: extent,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = files[index];
          return KeyedSubtree(
            key: ValueKey('entry-${entry.id}'),
            child: _anchored(
              MediaTile(
                artwork: _EntryArtwork(entry: entry, cacheWidth: 480),
                aspectRatio: aspect,
                title: _displayName(entry.name, folder: false),
                subtitle: _metaLine(entry, locale),
                showPlayOnHover: entry.kind == EntryKindEnum.video,
                onTap: () => _open(entry, locale),
                onSecondaryTap: () => _showEntryMenu(entry, locale),
                menu: _entryMenuButton(entry, locale),
              ),
            ),
          );
        },
        childCount: files.length,
        findChildIndexCallback: (key) => _indexIn(files, key),
      ),
    );
  }

  Widget _entryList(
    List<Entry> entries,
    String? locale, {
    required bool wide,
  }) => SliverList(
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        final entry = entries[index];
        final folder = entry.kind == EntryKindEnum.folder;
        return KeyedSubtree(
          key: ValueKey('entry-${entry.id}'),
          child: _anchored(
            _EntryRow(
              entry: entry,
              name: _displayName(entry.name, folder: folder),
              wide: wide,
              size: folder
                  ? ''
                  : entry.sizeBytes == null
                  ? '—'
                  : formatBytes(entry.sizeBytes, locale: locale),
              modified: entry.modifiedAt == null
                  ? (folder ? '' : '—')
                  : formatDate(entry.modifiedAt!, locale: locale),
              meta: _metaLine(entry, locale),
              onTap: () => _open(entry, locale),
              onSecondaryTap: folder
                  ? null
                  : () => _showEntryMenu(entry, locale),
              menu: folder ? null : _entryMenuButton(entry, locale),
            ),
          ),
        );
      },
      childCount: entries.length,
      findChildIndexCallback: (key) => _indexIn(entries, key),
    ),
  );

  /// Records where a secondary click or long press started, so the context
  /// menu opens at the pointer rather than at the overflow button.
  Widget _anchored(Widget child) => Listener(
    onPointerDown: (event) {
      if (event.kind == PointerDeviceKind.touch ||
          event.buttons == kSecondaryMouseButton) {
        _menuAnchor = event.position;
      }
    },
    child: child,
  );

  int? _indexIn(List<Entry> entries, Key key) {
    final index = entries.indexWhere(
      (entry) => ValueKey('entry-${entry.id}') == key,
    );
    return index < 0 ? null : index;
  }

  String? _metaLine(Entry entry, String? locale) {
    if (entry.kind == EntryKindEnum.folder) return null;
    final parts = [
      if (entry.sizeBytes != null) formatBytes(entry.sizeBytes, locale: locale),
      if (entry.modifiedAt != null)
        formatDate(entry.modifiedAt!, locale: locale),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  List<PopupMenuEntry<String>> _menuItems(Entry entry) {
    final scheme = Theme.of(context).colorScheme;
    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label, {
      bool destructive = false,
    }) {
      final color = destructive ? scheme.error : null;
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      );
    }

    return [
      item('details', Icons.info_outline, 'Details'),
      if (_canEdit(entry)) ...[
        const PopupMenuDivider(),
        item('rename', Icons.drive_file_rename_outline, 'Rename'),
        item('move', Icons.drive_file_move_outline, 'Move'),
        const PopupMenuDivider(),
        item('trash', Icons.delete_outline, 'Move to trash', destructive: true),
      ],
    ];
  }

  void _menuSelected(Entry entry, String action, String? locale) =>
      action == 'details'
      ? _showDetails(entry, locale)
      : _action(entry, action);

  Widget _entryMenuButton(Entry entry, String? locale) =>
      PopupMenuButton<String>(
        tooltip: 'File actions',
        icon: const Icon(Icons.more_vert),
        onSelected: (action) => _menuSelected(entry, action, locale),
        itemBuilder: (_) => _menuItems(entry),
      );

  Future<void> _showEntryMenu(Entry entry, String? locale) async {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final anchor = overlay.globalToLocal(
      _menuAnchor ?? overlay.size.center(Offset.zero),
    );
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        anchor & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: _menuItems(entry),
    );
    if (action != null && mounted) _menuSelected(entry, action, locale);
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

  Future<void> _showDetails(Entry entry, String? locale) async {
    final api = requireActiveApi(ref);
    final openable =
        entry.mediaId != null &&
        (entry.kind == EntryKindEnum.video ||
            entry.kind == EntryKindEnum.photo);
    Widget details(BuildContext sheetContext) =>
        _EntryDetails(entry: entry, api: api, locale: locale);
    void open(BuildContext sheetContext) {
      Navigator.of(sheetContext).pop();
      _open(entry, locale);
    }

    Widget actions(BuildContext sheetContext, {bool closeButton = true}) => Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (closeButton)
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Close'),
          ),
        if (openable) ...[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => open(sheetContext),
            icon: Icon(
              entry.kind == EntryKindEnum.video
                  ? Icons.play_arrow_rounded
                  : Icons.photo_outlined,
            ),
            label: Text(entry.kind == EntryKindEnum.video ? 'Play' : 'Open'),
          ),
        ],
      ],
    );

    if (isTelevision(context)) {
      return TvFocusPanel.show<void>(
        context: context,
        title: 'Details',
        builder: (sheetContext) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details(sheetContext),
              const SizedBox(height: 16),
              actions(sheetContext, closeButton: false),
            ],
          ),
        ),
      );
    }
    if (WindowSize.of(context).isCompact) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              details(sheetContext),
              const SizedBox(height: 16),
              actions(sheetContext),
            ],
          ),
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details(dialogContext),
                const SizedBox(height: 20),
                actions(dialogContext),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
            libraryName: _library?.name ?? 'Library',
            currentFolderId: entry.parentId,
            fileName: entry.name,
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
          builder: (context) => _TrashConfirmDialog(name: entry.name),
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
            (await requireActiveApi(ref).getOperationsApi().getOperation(
              id: operation.id,
              cancelToken: token,
            )).data!;
      }
      throw const _MutationFailure(
        'The server is still processing this change. Refresh shortly to check its result.',
      );
    } finally {
      if (identical(_operationToken, token)) _operationToken = null;
    }
  }

  String _operationProblem(Problem? problem) =>
      serverMessage(problem) ??
      'The server did not explain why this change failed.';
}

class _MutationFailure implements Exception {
  const _MutationFailure(this.message);
  final String message;
}

String _duration(int ms) {
  final seconds = ms ~/ 1000;
  return '${seconds ~/ 3600}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

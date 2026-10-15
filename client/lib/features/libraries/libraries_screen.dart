import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/client_session.dart';
import '../../core/input/route_activity.dart';
import '../../core/preferences/preferences_providers.dart';

class LibrariesScreen extends ConsumerStatefulWidget {
  const LibrariesScreen({super.key});

  @override
  ConsumerState<LibrariesScreen> createState() => _LibrariesScreenState();
}

class _LibrariesScreenState extends ConsumerState<LibrariesScreen> {
  Object? _apiIdentity;
  Future<List<ModelLibrary>>? _librariesFuture;
  List<ModelLibrary>? _lastLibraries;
  int _refreshGeneration = 0;
  bool? _wasVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = RouteActivity.isVisible(context);
    if (_wasVisible == false && visible) ++_refreshGeneration;
    _wasVisible = visible;
  }

  Future<void> _refresh(BrianiApi api) async {
    final future = api.getLibrariesApi().listLibraries().then(
      (r) => r.data?.toList() ?? const <ModelLibrary>[],
    );
    setState(() {
      _librariesFuture = future;
      ++_refreshGeneration;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the failure with the last loaded contents.
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(activeApiProvider);
    if (api == null) {
      _apiIdentity = null;
      _librariesFuture = null;
      _lastLibraries = null;
      return const SizedBox.shrink();
    }
    if (!identical(_apiIdentity, api)) {
      _apiIdentity = api;
      _lastLibraries = null;
      _librariesFuture = api.getLibrariesApi().listLibraries().then(
        (r) => r.data?.toList() ?? const [],
      );
    }
    final preferences = ref.watch(userPreferencesProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libraries'),
        actions: [
          IconButton(
            tooltip: 'Refresh libraries',
            onPressed: () => _refresh(api),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<ModelLibrary>>(
        key: ValueKey(api),
        future: _librariesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _lastLibraries == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError && _lastLibraries == null) {
            return _LoadError(
              message: clientError(snapshot.error!),
              onRetry: () => _refresh(api),
            );
          }
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.hasData) {
            _lastLibraries = snapshot.data;
          }
          final libraries = _lastLibraries ?? const <ModelLibrary>[];
          final pinnedIds =
              preferences?.pinnedLibraryIds?.toSet() ?? <String>{};
          final orderedLibraries = [...libraries]
            ..sort((a, b) {
              final aPinned = pinnedIds.contains(a.id);
              final bPinned = pinnedIds.contains(b.id);
              return aPinned == bPinned
                  ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
                  : aPinned
                  ? -1
                  : 1;
            });
          final grid = preferences?.libraryLayout?.name == 'grid';
          return RefreshIndicator(
            onRefresh: () => _refresh(api),
            child: CustomScrollView(
              key: const PageStorageKey('libraries'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(child: LinearProgressIndicator()),
                if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: MaterialBanner(
                      content: Text(clientError(snapshot.error!)),
                      actions: [
                        TextButton(
                          onPressed: () => _refresh(api),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (preferences?.showContinueWatching != false)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: _ContinueWatching(
                        key: ValueKey(api),
                        refreshGeneration: _refreshGeneration,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Your libraries',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                if (libraries.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No libraries are available to this account.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: grid
                        ? SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final columns =
                                  (constraints.crossAxisExtent / 280)
                                      .floor()
                                      .clamp(1, 6);
                              return SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      mainAxisExtent:
                                          140 *
                                          MediaQuery.textScalerOf(context)
                                              .scale(1)
                                              .clamp(1, 2),
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _libraryTile(
                                    orderedLibraries[index],
                                    grid: true,
                                  ),
                                  childCount: orderedLibraries.length,
                                  findChildIndexCallback: (key) =>
                                      _libraryIndex(orderedLibraries, key),
                                ),
                              );
                            },
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _libraryTile(orderedLibraries[index]),
                              childCount: orderedLibraries.length,
                              findChildIndexCallback: (key) =>
                                  _libraryIndex(orderedLibraries, key),
                            ),
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  int? _libraryIndex(List<ModelLibrary> libraries, Key key) {
    final index = libraries.indexWhere(
      (library) => ValueKey('library-${library.id}') == key,
    );
    return index < 0 ? null : index;
  }

  Widget _libraryTile(ModelLibrary library, {bool grid = false}) => Card(
    key: ValueKey('library-${library.id}'),
    child: InkWell(
      onTap: () =>
          context.push('/libraries/${Uri.encodeComponent(library.id)}'),
      child: grid
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.video_library_outlined),
                  const SizedBox(height: 8),
                  Text(
                    library.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      library.description.isEmpty
                          ? 'Browse media'
                          : library.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          : ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(library.name),
              subtitle: Text(
                library.description.isEmpty
                    ? 'Browse media'
                    : library.description,
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
    ),
  );
}

class _ContinueWatching extends ConsumerStatefulWidget {
  const _ContinueWatching({super.key, required this.refreshGeneration});
  final int refreshGeneration;
  @override
  ConsumerState<_ContinueWatching> createState() => _ContinueWatchingState();
}

class _ContinueWatchingState extends ConsumerState<_ContinueWatching> {
  late Future<ContinueWatchingPage?> _future;
  ContinueWatchingPage? _lastPage;
  void _load() =>
      _future = requireActiveApi(ref)
          .getMediaApi()
          .listContinueWatching(limit: 20)
          .then((r) => r.data);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ContinueWatching oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshGeneration != oldWidget.refreshGeneration) _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ContinueWatchingPage?>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting &&
          _lastPage == null) {
        return const LinearProgressIndicator();
      }
      final errorCard = snapshot.hasError
          ? Card(
              child: ListTile(
                title: const Text('Continue watching'),
                subtitle: Text(clientError(snapshot.error!)),
                trailing: IconButton(
                  tooltip: 'Retry Continue watching',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(_load),
                ),
              ),
            )
          : null;
      if (snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData) {
        _lastPage = snapshot.data;
      }
      final items = _lastPage?.items.toList() ?? <ContinueWatching>[];
      if (items.isEmpty) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        return errorCard ?? const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          ?errorCard,
          Text(
            'Continue watching',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
            child: ListView.separated(
              key: const PageStorageKey('continue-watching'),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final media = item.media;
                final progress = item.progress;
                final duration = progress.durationMs;
                final fraction = duration == null || duration <= 0
                    ? 0.0
                    : (progress.positionMs / duration)
                          .clamp(0.0, 1.0)
                          .toDouble();
                return SizedBox(
                  key: ValueKey('continue-${media.id}'),
                  width: 260,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      await context.push(
                                        '/play/media/${Uri.encodeComponent(media.id)}',
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.play_circle_outline,
                                          size: 36,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            media.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Progress options',
                                  onSelected: (action) =>
                                      _updateProgress(media, progress, action),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'watched',
                                      child: Text('Mark watched'),
                                    ),
                                    PopupMenuItem(
                                      value: 'clear',
                                      child: Text('Clear progress'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          LinearProgressIndicator(value: fraction),
                          const SizedBox(height: 6),
                          Text(
                            duration == null
                                ? 'Resume'
                                : '${_time(progress.positionMs)} of ${_time(duration)}',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );

  Future<void> _updateProgress(
    Media media,
    PlaybackProgress progress,
    String action,
  ) async {
    try {
      await requireActiveApi(ref).getMediaApi().setPlaybackProgress(
        id: media.id,
        progressUpdate: ProgressUpdate(
          (b) => b
            ..positionMs = action == 'clear'
                ? 0
                : (progress.durationMs ?? progress.positionMs)
            ..durationMs = progress.durationMs
            ..watched = action == 'watched' ? true : false
            ..version = progress.version,
        ),
      );
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(clientError(error))));
      }
    }
  }
}

String _time(int ms) {
  final seconds = ms ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

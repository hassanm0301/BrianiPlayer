import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/client_session.dart';
import '../../core/preferences/preferences_providers.dart';

class LibrariesScreen extends ConsumerStatefulWidget {
  const LibrariesScreen({super.key});

  @override
  ConsumerState<LibrariesScreen> createState() => _LibrariesScreenState();
}

class _LibrariesScreenState extends ConsumerState<LibrariesScreen> {
  Object? _apiIdentity;
  Future<List<ModelLibrary>>? _librariesFuture;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(activeApiProvider);
    if (api == null) {
      _apiIdentity = null;
      _librariesFuture = null;
      return const SizedBox.shrink();
    }
    if (!identical(_apiIdentity, api)) {
      _apiIdentity = api;
      _librariesFuture = api.getLibrariesApi().listLibraries().then(
        (r) => r.data?.toList() ?? const [],
      );
    }
    final preferences = ref.watch(userPreferencesProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Libraries')),
      body: FutureBuilder<List<ModelLibrary>>(
        future: _librariesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(
              message: clientError(snapshot.error!),
              onRetry: () => setState(
                () => _librariesFuture = api
                    .getLibrariesApi()
                    .listLibraries()
                    .then((r) => r.data?.toList() ?? const []),
              ),
            );
          }
          final libraries = snapshot.data ?? const [];
          if (libraries.isEmpty) {
            return const Center(
              child: Text('No libraries are available to this account.'),
            );
          }
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
            onRefresh: () async => setState(
              () => _librariesFuture = api
                  .getLibrariesApi()
                  .listLibraries()
                  .then((r) => r.data?.toList() ?? const []),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (preferences?.showContinueWatching != false) ...[
                  const _ContinueWatching(),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Your libraries',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (grid)
                  SizedBox(
                    height: ((orderedLibraries.length + 1) ~/ 2) * 150,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.8,
                          ),
                      itemCount: orderedLibraries.length,
                      itemBuilder: (context, index) {
                        final library = orderedLibraries[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.video_library_outlined),
                            title: Text(library.name),
                            subtitle: Text(
                              library.description.isEmpty
                                  ? 'Browse media'
                                  : library.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => context.push(
                              '/libraries/${Uri.encodeComponent(library.id)}',
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  for (final library in orderedLibraries)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.video_library_outlined),
                        title: Text(library.name),
                        subtitle: Text(
                          library.description.isEmpty
                              ? 'Browse media'
                              : library.description,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/libraries/${Uri.encodeComponent(library.id)}',
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
}

class _ContinueWatching extends ConsumerStatefulWidget {
  const _ContinueWatching();
  @override
  ConsumerState<_ContinueWatching> createState() => _ContinueWatchingState();
}

class _ContinueWatchingState extends ConsumerState<_ContinueWatching> {
  late Future<ContinueWatchingPage?> _future;
  void _load() => _future = requireActiveApi(ref)
      .getMediaApi()
      .listContinueWatching(limit: 20)
      .then((r) => r.data);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ContinueWatchingPage?>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return Card(
          child: ListTile(
            title: const Text('Continue watching'),
            subtitle: Text(clientError(snapshot.error!)),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(_load),
            ),
          ),
        );
      }
      final items = snapshot.data?.items.toList() ?? <ContinueWatching>[];
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue watching',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView.separated(
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
                                    onTap: () => context.push(
                                      '/play/media/${Uri.encodeComponent(media.id)}',
                                    ),
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
      await requireActiveApi(ref)
          .getMediaApi()
          .setPlaybackProgress(
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

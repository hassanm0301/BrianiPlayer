part of 'folder_screen.dart';

@immutable
class _MoveTarget {
  const _MoveTarget(this.folderId);
  final String? folderId;
}

class _TrashConfirmDialog extends StatelessWidget {
  const _TrashConfirmDialog({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Move to trash?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Text('“$name” will be moved to the server trash.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Move to trash'),
        ),
      ],
    );
  }
}

/// Browses the library's folders to choose a move destination. Rows open a
/// folder; Select picks that row, and Move here picks the folder on screen.
class _FolderMovePicker extends ConsumerStatefulWidget {
  const _FolderMovePicker({
    required this.libraryId,
    required this.libraryName,
    required this.currentFolderId,
    required this.fileName,
  });
  final String libraryId;
  final String libraryName;
  final String? currentFolderId;
  final String fileName;

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
      final page = await requireActiveApi(ref).getLibrariesApi().listEntries(
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

  void _moveHere() => Navigator.pop(
    context,
    _MoveTarget(_stack.isEmpty ? null : _stack.last.id),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final here = _stack.isEmpty ? widget.libraryName : _stack.last.name;
    return Dialog(
      child: SizedBox(
        width: 520,
        height: (size.height * .85).clamp(320.0, 520.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _stack.isEmpty ? 'Cancel' : 'Parent folder',
                    onPressed: _stack.isEmpty
                        ? () => Navigator.pop(context)
                        : _goUp,
                    icon: Icon(_stack.isEmpty ? Icons.close : Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Move to folder',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Icon(
                    _stack.isEmpty
                        ? Icons.home_outlined
                        : Icons.folder_open_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        widget.libraryName,
                        ..._stack.map((e) => e.name),
                      ].join('  ›  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
                  ? EmptyState.error(
                      message: _error!,
                      onRetry: () => _load(reset: true),
                    )
                  : _folders.isEmpty
                  ? const EmptyState(
                      compact: true,
                      icon: Icons.folder_off_outlined,
                      title: 'No subfolders here.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _folders.length,
                      itemBuilder: (context, index) {
                        final folder = _folders[index];
                        final current = folder.id == widget.currentFolderId;
                        return ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 24,
                            right: 12,
                          ),
                          leading: Icon(
                            Icons.folder_rounded,
                            color: scheme.primary,
                          ),
                          title: Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: current
                              ? const Text('Current folder')
                              : null,
                          onTap: () => _open(folder),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: current
                                    ? null
                                    : () => Navigator.pop(
                                        context,
                                        _MoveTarget(folder.id),
                                      ),
                                child: const Text('Select'),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: scheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (_cursor != null && !_loading)
              Center(
                child: TextButton.icon(
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
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Destination: $here',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    // The file's own folder is not a move target.
                    onPressed: _stack.lastOrNull?.id == widget.currentFolderId
                        ? null
                        : _moveHere,
                    child: const Text('Move here'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

part of 'administration_screen.dart';

/// Prowlarr torrent indexers: list, enable/disable, test, remove and add from a
/// definition. Every action goes through Briani's administrator endpoints; the
/// server never returns setting values, so nothing secret is shown here.
class _IndexerManagement extends ConsumerWidget {
  const _IndexerManagement(this.snapshot, {required this.retry});
  final _AdminSnapshot snapshot;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unavailable = snapshot.failures.contains('indexers');
    return _AdminSection(
      title: 'Indexers',
      subtitle: 'Torrent indexers in Prowlarr that discovery searches. Passwords, cookies and keys go to Prowlarr and are never shown here again.',
      trailing: FilledButton.icon(
        onPressed: unavailable ? null : () => _addIndexer(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add indexer'),
      ),
      children: [
        if (unavailable)
          _retryNotice(
            snapshot.errors['indexers'] ?? 'Indexers are unavailable.',
            retry,
          ),
        for (final indexer in snapshot.indexers)
          _IndexerRow(key: ValueKey('indexer-${indexer.id}'), indexer: indexer),
        if (!unavailable && snapshot.indexers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No torrent indexers are set up in Prowlarr yet.'),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            "Indexers that need a CAPTCHA, FlareSolverr or a site address you type yourself are set up in Prowlarr's own page.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _IndexerRow extends ConsumerStatefulWidget {
  const _IndexerRow({super.key, required this.indexer});
  final AdminIndexer indexer;

  @override
  ConsumerState<_IndexerRow> createState() => _IndexerRowState();
}

class _IndexerRowState extends ConsumerState<_IndexerRow> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(ClientSession session) action) async {
    final session = _captureAdminSession(ref);
    if (session == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action(session);
    } catch (error) {
      if (mounted && _sameAdminSession(ref, session)) {
        _toast(context, clientError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _sameAdminSession(ref, session)) {
      ref.invalidate(_adminSnapshotProvider);
    }
  }

  Future<void> _toggle(bool enabled) => _run((session) async {
    await session.api.getAdministrationApi().updateAdminIndexer(
      id: widget.indexer.id,
      indexerPatch: IndexerPatch((b) => b..enabled = enabled),
    );
    if (mounted) {
      _toast(
        context,
        '${widget.indexer.name} ${enabled ? 'enabled' : 'disabled'}.',
      );
    }
  });

  Future<void> _test() => _run((session) async {
    final result = (await session.api.getAdministrationApi().testAdminIndexer(
      id: widget.indexer.id,
    )).data!;
    if (mounted) _toast(context, '${widget.indexer.name}: ${result.detail}');
  });

  Future<void> _remove() async {
    final name = widget.indexer.name;
    if (!await _confirm(
          context,
          'Remove $name?',
          'Prowlarr deletes this indexer and its saved settings, including any password, cookie or key. Discovery stops using it. To use it again, add it again.',
        ) ||
        !mounted) {
      return;
    }
    await _run((session) async {
      await session.api.getAdministrationApi().deleteAdminIndexer(
        id: widget.indexer.id,
      );
      if (mounted) _toast(context, '$name removed.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final indexer = widget.indexer;
    final tone = switch (indexer.state) {
      AdminIndexerStateEnum.healthy => PillTone.success,
      AdminIndexerStateEnum.degraded => PillTone.warning,
      AdminIndexerStateEnum.unavailable => PillTone.error,
      _ => PillTone.neutral,
    };
    final privacy = switch (indexer.privacy) {
      AdminIndexerPrivacyEnum.public => 'Public',
      AdminIndexerPrivacyEnum.semiPrivate => 'Semi-private',
      AdminIndexerPrivacyEnum.private => 'Private',
      _ => 'Unknown access',
    };
    final features = [
      if (indexer.supportsSearch) 'search',
      if (indexer.supportsRecent) 'latest',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          Icon(
            indexer.privacy == AdminIndexerPrivacyEnum.public
                ? Icons.public
                : Icons.lock_outline,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(indexer.name, style: theme.textTheme.titleSmall),
                    if (indexer.enabled)
                      StatusPill(
                        dense: true,
                        tone: tone,
                        label: _humanize(indexer.state.name),
                      ),
                  ],
                ),
                Text(
                  [
                    privacy,
                    indexer.definition,
                    if (features.isNotEmpty)
                      'Supports ${features.join(' and ')}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (indexer.stateDetail != null && indexer.enabled)
                  Text(
                    indexer.stateDetail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: indexer.state == AdminIndexerStateEnum.healthy
                          ? scheme.onSurfaceVariant
                          : scheme.error,
                    ),
                  ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Semantics(
            label: '${indexer.enabled ? 'Disable' : 'Enable'} ${indexer.name}',
            child: Switch(
              value: indexer.enabled,
              onChanged: _busy ? null : _toggle,
            ),
          ),
          IconButton(
            tooltip: 'Test ${indexer.name}',
            icon: const Icon(Icons.health_and_safety_outlined),
            onPressed: _busy ? null : _test,
          ),
          IconButton(
            tooltip: 'Remove ${indexer.name}',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _remove,
          ),
        ],
      ),
    );
  }
}

Future<void> _addIndexer(BuildContext context, WidgetRef ref) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  final added = await showDialog<String>(
    context: context,
    builder: (_) => _AddIndexerDialog(session: session),
  );
  if (added == null || !context.mounted || !_sameAdminSession(ref, session)) {
    return;
  }
  ref.invalidate(_adminSnapshotProvider);
  _toast(context, '$added added.');
}

class _AddIndexerDialog extends ConsumerStatefulWidget {
  const _AddIndexerDialog({required this.session});
  final ClientSession session;

  @override
  ConsumerState<_AddIndexerDialog> createState() => _AddIndexerDialogState();
}

class _AddIndexerDialogState extends ConsumerState<_AddIndexerDialog> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _values = <String, String?>{};
  final _controllers = <String, TextEditingController>{};
  List<IndexerDefinitionSummary>? _definitions;
  IndexerDefinitionDetail? _detail;
  bool _enable = true;
  bool _advanced = false;
  bool _busy = false;
  String? _error;

  AdministrationApi get _api => widget.session.api.getAdministrationApi();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadDefinitions();
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _current => mounted && _sameAdminSession(ref, widget.session);

  Future<void> _loadDefinitions() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final definitions = (await _api.listIndexerDefinitions()).data!.toList();
      if (_current) setState(() => _definitions = definitions);
    } catch (error) {
      if (_current) setState(() => _error = clientError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _choose(IndexerDefinitionSummary definition) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final detail = (await _api.getIndexerDefinition(key: definition.key))
          .data!;
      if (!_current) return;
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _values.clear();
      for (final field in detail.fields) {
        if (field.kind == IndexerSettingFieldKindEnum.checkbox ||
            field.kind == IndexerSettingFieldKindEnum.select) {
          _values[field.name] = field.value;
        } else if (field.kind != IndexerSettingFieldKindEnum.info) {
          _controllers[field.name] = TextEditingController(
            text: field.value ?? '',
          );
        }
      }
      setState(() {
        _detail = detail;
        _name.text = detail.name;
        _enable = true;
        _advanced = false;
      });
    } catch (error) {
      if (_current) setState(() => _error = clientError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final detail = _detail;
    if (detail == null || _busy) return;
    if (!_current) {
      setState(
        () => _error = 'Your administrator session changed. Close this dialog and try again.',
      );
      return;
    }
    // Only filled-in values are sent; anything left blank keeps Prowlarr's default.
    final settings = <String, String>{
      for (final entry in _controllers.entries)
        if (entry.value.text.isNotEmpty) entry.key: entry.value.text,
      for (final entry in _values.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = (await _api.createAdminIndexer(
        indexerCreate: IndexerCreate(
          (b) => b
            ..definition = detail.key
            ..name = _name.text.trim().isEmpty ? null : _name.text.trim()
            ..enabled = _enable
            ..settings.replace(settings),
        ),
      )).data!;
      if (mounted) Navigator.pop(context, created.name);
    } catch (error) {
      if (mounted) setState(() => _error = clientError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return AlertDialog(
      title: Text(detail == null ? 'Add indexer' : 'Add ${detail.name}'),
      content: SizedBox(
        width: 560,
        child: detail == null
            ? _definitionList(context)
            : _form(context, detail),
      ),
      actions: [
        if (detail != null)
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _detail = null;
                    _error = null;
                  }),
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (detail != null)
          FilledButton(
            onPressed: _busy ? null : _add,
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add'),
          ),
      ],
    );
  }

  Widget _errorText(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      _error!,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  Widget _definitionList(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text.trim().toLowerCase();
    final shown = (_definitions ?? const <IndexerDefinitionSummary>[]).where(
      (d) =>
          query.isEmpty ||
          d.name.toLowerCase().contains(query) ||
          d.key.toLowerCase().contains(query) ||
          d.description.toLowerCase().contains(query),
    );
    // Definitions Briani can add come first, keeping the server's name order;
    // the rest explain where they are set up.
    final matches = [
      ...shown.where((d) => d.addable),
      ...shown.where((d) => !d.addable),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          autofocus: !isTelevision(context),
          decoration: const InputDecoration(
            labelText: 'Search indexers',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) _errorText(context),
        if (_definitions != null && matches.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No indexer definitions match.'),
          ),
        if (matches.isNotEmpty)
          // Takes up to 380 pixels of whatever height the dialog has, so short
          // phone screens scroll the list instead of overflowing.
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final definition = matches[index];
                  final access = switch (definition.privacy) {
                    IndexerDefinitionSummaryPrivacyEnum.public => 'Public',
                    IndexerDefinitionSummaryPrivacyEnum.semiPrivate =>
                      'Semi-private',
                    IndexerDefinitionSummaryPrivacyEnum.private => 'Private',
                    _ => 'Unknown access',
                  };
                  final itemKey = ValueKey('definition-${definition.key}');
                  ListTile tile({Key? key, Color? tileColor}) => ListTile(
                    key: key,
                    enabled: definition.addable && !_busy,
                    tileColor: tileColor,
                    leading: Icon(
                      definition.privacy ==
                              IndexerDefinitionSummaryPrivacyEnum.public
                          ? Icons.public
                          : Icons.lock_outline,
                    ),
                    title: Text(definition.name),
                    subtitle: Text(
                      definition.addable
                          ? [
                              access,
                              if (definition.language.isNotEmpty)
                                definition.language,
                              if (definition.description.isNotEmpty)
                                definition.description,
                            ].join(' · ')
                          : definition.setupNote ?? access,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: definition.addable
                          ? null
                          : theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                    ),
                    onTap: () => _choose(definition),
                  );
                  if (definition.addable) return tile(key: itemKey);
                  // A disabled tile only takes focus in directional mode, so a
                  // keyboard would stop at the last addable definition and never
                  // scroll to these notes. This stop is for reading: the tile
                  // stays disabled, so Select does nothing.
                  return Focus(
                    key: itemKey,
                    child: Builder(
                      builder: (context) => ExcludeFocus(
                        child: tile(
                          tileColor: Focus.of(context).hasFocus
                              ? theme.focusColor
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _form(BuildContext context, IndexerDefinitionDetail detail) {
    final theme = Theme.of(context);
    final basic = detail.fields.where((f) => !f.advanced).toList();
    final advanced = detail.fields.where((f) => f.advanced).toList();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detail.description.isNotEmpty)
            Text(
              detail.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          TextField(
            controller: _name,
            enabled: !_busy,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Name',
              counterText: '',
            ),
          ),
          for (final field in basic) _field(context, field),
          if (advanced.isNotEmpty)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show advanced settings'),
              value: _advanced,
              onChanged: _busy ? null : (v) => setState(() => _advanced = v),
            ),
          if (_advanced)
            for (final field in advanced) _field(context, field),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable now'),
            subtitle: const Text(
              'Prowlarr tests the indexer first and adds nothing if the test fails. Turn this off to add it disabled without a test.',
            ),
            value: _enable,
            onChanged: _busy ? null : (v) => setState(() => _enable = v),
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _enable
                    ? 'Prowlarr is testing the indexer…'
                    : 'Adding the indexer…',
              ),
            ),
          if (_error != null) _errorText(context),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, IndexerSettingField field) {
    final theme = Theme.of(context);
    switch (field.kind) {
      case IndexerSettingFieldKindEnum.info:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.label, style: theme.textTheme.labelLarge),
              Text(
                field.value ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      case IndexerSettingFieldKindEnum.checkbox:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: field.helpText == null ? null : Text(field.helpText!),
          value: _values[field.name] == 'true',
          onChanged: _busy
              ? null
              : (v) =>
                    setState(() => _values[field.name] = v ? 'true' : 'false'),
        );
      case IndexerSettingFieldKindEnum.select:
        final options =
            field.options?.toList() ?? const <IndexerSettingOption>[];
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _values[field.name],
            isExpanded: true,
            decoration: InputDecoration(
              labelText: field.label,
              helperText: field.helpText,
              helperMaxLines: 3,
            ),
            items: [
              for (final option in options)
                DropdownMenuItem(
                  value: option.value,
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() => _values[field.name] = v),
          ),
        );
      default:
        final secret = field.kind == IndexerSettingFieldKindEnum.secret;
        final number =
            field.kind == IndexerSettingFieldKindEnum.integer ||
            field.kind == IndexerSettingFieldKindEnum.decimal;
        final help = [
          if (field.helpText != null) field.helpText!,
          if (secret) 'Sent to Prowlarr only; Briani never shows it again.',
        ].join(' ');
        return TextField(
          controller: _controllers[field.name],
          enabled: !_busy,
          obscureText: secret,
          enableSuggestions: !secret,
          autocorrect: false,
          keyboardType: number
              ? TextInputType.numberWithOptions(
                  decimal: field.kind == IndexerSettingFieldKindEnum.decimal,
                  signed: true,
                )
              : null,
          decoration: InputDecoration(
            labelText: field.label,
            suffixText: field.unit,
            helperText: help.isEmpty ? null : help,
            helperMaxLines: 3,
          ),
        );
    }
  }
}

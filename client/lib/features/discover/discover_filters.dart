import 'package:briani_api/briani_api.dart' show Provider;
import 'package:flutter/material.dart';

import '../../core/input/remote_navigation.dart';
import '../../core/widgets/adaptive.dart';

/// Parses a comma-separated list of non-negative category IDs. Returns null
/// for blank input and for any invalid entry.
List<int>? parseCategoryIds(String value) {
  if (value.trim().isEmpty) return null;
  final values = value.split(',').map((x) => int.tryParse(x.trim())).toList();
  if (values.any((x) => x == null || x < 0)) return null;
  return values.cast<int>();
}

/// Parses a size in GiB (0 to 100000) into bytes. Returns null for blank or
/// invalid input.
int? parseGib(String value) {
  if (value.trim().isEmpty) return null;
  final number = double.tryParse(value.trim());
  if (number == null || number < 0 || number > 100000) return null;
  return (number * 1024 * 1024 * 1024).round();
}

/// Sort options offered by the discovery API, with their labels.
const discoverySortLabels = {
  'publishedAt': 'Publication date',
  'seeders': 'Seeders',
  'leechers': 'Leechers',
  'peers': 'Total peers',
  'sizeBytes': 'Size',
  'title': 'Title',
};

/// The editable discovery filter values, kept as entered text so validation
/// stays with the query that uses them.
@immutable
class DiscoveryFilterValues {
  const DiscoveryFilterValues({
    required this.providerIds,
    required this.categories,
    required this.minSize,
    required this.maxSize,
    required this.minSeeders,
    required this.sort,
    required this.order,
  });

  final Set<String> providerIds;
  final String categories;
  final String minSize;
  final String maxSize;
  final String minSeeders;
  final String sort;
  final String order;
}

/// Newznab top-level category families, used only as a hint beside the ID.
const _categoryFamilies = {
  1000: 'Console',
  2000: 'Movies',
  3000: 'Audio',
  4000: 'PC',
  5000: 'TV',
  6000: 'XXX',
  7000: 'Books',
  8000: 'Other',
};

String _categoryLabel(int id) {
  final family = _categoryFamilies[id ~/ 1000 * 1000];
  return family == null ? '$id' : '$id · $family';
}

/// Indexer, category, size, seeder and sort filters. Edits stay in a draft
/// until Apply; dismissing discards them.
class DiscoveryFiltersPanel extends StatefulWidget {
  const DiscoveryFiltersPanel({
    super.key,
    required this.initial,
    required this.defaultSort,
    required this.defaultOrder,
    required this.providers,
    this.showTitle = true,
  });

  final DiscoveryFilterValues initial;
  final String defaultSort;
  final String defaultOrder;
  final List<Provider> providers;
  final bool showTitle;

  /// Opens the panel as a dialog (desktop), bottom sheet (phone) or focus
  /// panel (TV) and returns the applied values, or null when dismissed.
  static Future<DiscoveryFilterValues?> show({
    required BuildContext context,
    required DiscoveryFilterValues initial,
    required String defaultSort,
    required String defaultOrder,
    required List<Provider> providers,
  }) {
    Widget panel({bool showTitle = true}) => DiscoveryFiltersPanel(
      initial: initial,
      defaultSort: defaultSort,
      defaultOrder: defaultOrder,
      providers: providers,
      showTitle: showTitle,
    );
    if (isTelevision(context)) {
      return TvFocusPanel.show<DiscoveryFilterValues>(
        context: context,
        title: 'Filters',
        builder: (_) => panel(showTitle: false),
      );
    }
    if (WindowSize.of(context).isCompact) {
      return showModalBottomSheet<DiscoveryFilterValues>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: panel(),
        ),
      );
    }
    return showDialog<DiscoveryFilterValues>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: panel(),
        ),
      ),
    );
  }

  @override
  State<DiscoveryFiltersPanel> createState() => _DiscoveryFiltersPanelState();
}

class _DiscoveryFiltersPanelState extends State<DiscoveryFiltersPanel> {
  late final Set<String> _providerIds = {...widget.initial.providerIds};
  late final _categories = TextEditingController(
    text: widget.initial.categories,
  );
  late final _minSize = TextEditingController(text: widget.initial.minSize);
  late final _maxSize = TextEditingController(text: widget.initial.maxSize);
  late final _minSeeders = TextEditingController(
    text: widget.initial.minSeeders,
  );
  late String _sort = widget.initial.sort;
  late String _order = widget.initial.order;
  final _errors = <String, String>{};

  @override
  void initState() {
    super.initState();
    _categories.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _categories.dispose();
    _minSize.dispose();
    _maxSize.dispose();
    _minSeeders.dispose();
    super.dispose();
  }

  List<String> get _categoryTokens => _categories.text
      .split(',')
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList();

  void _toggleCategory(int id, bool selected) {
    final tokens = _categoryTokens..removeWhere((token) => token == '$id');
    if (selected) tokens.add('$id');
    _categories.text = tokens.join(', ');
  }

  void _reset() => setState(() {
    _providerIds.clear();
    _categories.clear();
    _minSize.clear();
    _maxSize.clear();
    _minSeeders.clear();
    _sort = widget.defaultSort;
    _order = widget.defaultOrder;
    _errors.clear();
  });

  void _apply() {
    _errors.clear();
    if (_categories.text.trim().isNotEmpty &&
        parseCategoryIds(_categories.text) == null) {
      _errors['categories'] = 'Use whole numbers separated by commas.';
    }
    final minSize = parseGib(_minSize.text);
    final maxSize = parseGib(_maxSize.text);
    if (_minSize.text.trim().isNotEmpty && minSize == null) {
      _errors['minSize'] = 'Enter 0 to 100000.';
    }
    if (_maxSize.text.trim().isNotEmpty && maxSize == null) {
      _errors['maxSize'] = 'Enter 0 to 100000.';
    }
    if (minSize != null && maxSize != null && minSize > maxSize) {
      _errors['maxSize'] = 'Must not be below the minimum.';
    }
    final seeders = int.tryParse(_minSeeders.text.trim());
    if (_minSeeders.text.trim().isNotEmpty &&
        (seeders == null || seeders < 0)) {
      _errors['minSeeders'] = 'Enter a whole number, 0 or more.';
    }
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }
    Navigator.of(context).pop(
      DiscoveryFilterValues(
        providerIds: {..._providerIds},
        categories: _categories.text,
        minSize: _minSize.text,
        maxSize: _maxSize.text,
        minSeeders: _minSeeders.text,
        sort: _sort,
        order: _order,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final providerCategories =
        widget.providers
            .expand((provider) => provider.categories)
            .toSet()
            .toList()
          ..sort();
    final selectedCategories = _categoryTokens.toSet();
    Widget section(String title, Widget child, {String? help}) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (help != null) ...[
            const SizedBox(height: 2),
            Text(
              help,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          'Indexers',
          help: 'None selected searches every enabled indexer.',
          widget.providers.isEmpty
              ? Text(
                  'No indexer details are available.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final provider in widget.providers)
                      FilterChip(
                        label: Text(provider.name),
                        tooltip: provider.warning,
                        selected: _providerIds.contains(provider.id),
                        onSelected: (selected) => setState(
                          () => selected
                              ? _providerIds.add(provider.id)
                              : _providerIds.remove(provider.id),
                        ),
                      ),
                  ],
                ),
        ),
        section(
          'Categories',
          help: 'Newznab category IDs. None selected includes every category.',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (providerCategories.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in providerCategories)
                      FilterChip(
                        label: Text(_categoryLabel(id)),
                        selected: selectedCategories.contains('$id'),
                        onSelected: (selected) => _toggleCategory(id, selected),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _categories,
                decoration: InputDecoration(
                  labelText: 'Category IDs',
                  hintText: 'Comma-separated, for example 2000, 5000',
                  errorText: _errors['categories'],
                ),
              ),
            ],
          ),
        ),
        section(
          'Size',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _minSize,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Minimum',
                    suffixText: 'GiB',
                    errorText: _errors['minSize'],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxSize,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Maximum',
                    suffixText: 'GiB',
                    errorText: _errors['maxSize'],
                  ),
                ),
              ),
            ],
          ),
        ),
        section(
          'Seeders',
          TextField(
            controller: _minSeeders,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Minimum seeders',
              errorText: _errors['minSeeders'],
            ),
          ),
        ),
        section(
          'Sort',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _sort,
                decoration: const InputDecoration(labelText: 'Sort by'),
                items: [
                  for (final entry in discoverySortLabels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _sort = value);
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'desc',
                    icon: Icon(Icons.arrow_downward),
                    label: Text('Descending'),
                  ),
                  ButtonSegment(
                    value: 'asc',
                    icon: Icon(Icons.arrow_upward),
                    label: Text('Ascending'),
                  ),
                ],
                selected: {_order},
                onSelectionChanged: (selection) =>
                    setState(() => _order = selection.single),
              ),
            ],
          ),
        ),
      ],
    );
    final actions = Row(
      children: [
        TextButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset'),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _apply, child: const Text('Apply')),
      ],
    );
    final tv = !widget.showTitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Text('Filters', style: theme.textTheme.headlineSmall),
          ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              tv ? 0 : 24,
              tv ? 16 : 0,
              tv ? 0 : 24,
              0,
            ),
            child: form,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            tv ? 0 : 16,
            8,
            tv ? 0 : 24,
            tv ? 0 : 16,
          ),
          child: actions,
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:briani_api/briani_api.dart';
import 'package:briani_api/briani_api.dart' as api_models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/client_session.dart';
import '../../core/preferences/preferences_providers.dart';
import '../../core/formatting/locale_formatters.dart';

final _adminSnapshotProvider = FutureProvider<_AdminSnapshot>((ref) async {
  final session = ref.watch(clientSessionProvider);
  if (session == null || !session.administrator) {
    throw StateError('Administrator access is required.');
  }
  final api = session.api;
  final admin = api.getAdministrationApi();
  final libraries = api.getLibrariesApi();
  final results = await Future.wait<dynamic>([
    _adminRead<AdminSettings>(
      'settings',
      () async => (await admin.getAdminSettings()).data!,
    ),
    _adminRead<List<User>>(
      'users',
      () async => (await admin.listUsers()).data!.toList().cast<User>(),
    ),
    _adminRead<List<ServiceHealth>>(
      'health',
      () async =>
          (await admin.getAdminHealth()).data!.toList().cast<ServiceHealth>(),
    ),
    _adminRead<List<StorageRoot>>(
      'roots',
      () async =>
          (await admin.listStorageRoots()).data!.toList().cast<StorageRoot>(),
    ),
    _adminRead<List<Integration>>(
      'integrations',
      () async =>
          (await admin.listIntegrations()).data!.toList().cast<Integration>(),
    ),
    _adminRead<AuditPage>(
      'audit',
      () async => (await admin.listAudit(limit: 30)).data!,
    ),
    _adminRead<List<ModelLibrary>>(
      'libraries',
      () async =>
          (await libraries.listLibraries()).data!.toList().cast<ModelLibrary>(),
    ),
    _adminRead<List<api_models.Provider>>(
      'providers',
      () async => (await api.getDiscoveryApi().listProviders()).data!
          .toList()
          .cast<api_models.Provider>(),
    ),
  ]);
  final settings = results[0] as _AdminRead<AdminSettings>;
  final users = results[1] as _AdminRead<List<User>>;
  final health = results[2] as _AdminRead<List<ServiceHealth>>;
  final roots = results[3] as _AdminRead<List<StorageRoot>>;
  final integrations = results[4] as _AdminRead<List<Integration>>;
  final audit = results[5] as _AdminRead<AuditPage>;
  final libraryRows = results[6] as _AdminRead<List<ModelLibrary>>;
  final providers = results[7] as _AdminRead<List<api_models.Provider>>;
  return _AdminSnapshot(
    settings: settings.value,
    users: users.value ?? const [],
    health: health.value ?? const [],
    roots: roots.value ?? const [],
    integrations: integrations.value ?? const [],
    audit: audit.value,
    libraries: libraryRows.value ?? const [],
    providers: providers.value ?? const [],
    failures: {
      for (final row in results.cast<_AdminRead<dynamic>>())
        if (row.value == null) row.key,
    },
  );
});

Future<_AdminRead<T>> _adminRead<T>(
  String key,
  Future<T> Function() load,
) async {
  try {
    return _AdminRead<T>(key, await load());
  } catch (_) {
    return _AdminRead<T>(key, null);
  }
}

class _AdminRead<T> {
  const _AdminRead(this.key, this.value);
  final String key;
  final T? value;
}

class _AdminSnapshot {
  const _AdminSnapshot({
    required this.settings,
    required this.users,
    required this.health,
    required this.roots,
    required this.integrations,
    required this.audit,
    required this.libraries,
    required this.providers,
    required this.failures,
  });
  final AdminSettings? settings;
  final List<User> users;
  final List<ServiceHealth> health;
  final List<StorageRoot> roots;
  final List<Integration> integrations;
  final AuditPage? audit;
  final List<ModelLibrary> libraries;
  final List<api_models.Provider> providers;
  final Set<String> failures;
}

class AdministrationScreen extends ConsumerWidget {
  const AdministrationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(clientSessionProvider);
    if (session?.administrator != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: const Center(child: Text('Administrator access is required.')),
      );
    }
    final data = ref.watch(_adminSnapshotProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Administration data is unavailable.'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(_adminSnapshotProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (snapshot) => _AdminContent(
          snapshot: snapshot,
          retry: () => ref.invalidate(_adminSnapshotProvider),
        ),
      ),
    );
  }
}

class _AdminContent extends ConsumerWidget {
  const _AdminContent({required this.snapshot, required this.retry});
  final _AdminSnapshot snapshot;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(userPreferencesProvider).asData?.value.locale;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (snapshot.settings == null)
          _UnavailableSection(
            title: 'Server and transfer settings',
            retry: retry,
          )
        else
          _ServerSettings(snapshot.settings!),
        if (snapshot.settings == null)
          _UnavailableSection(title: 'Discovery scope', retry: retry)
        else
          _DiscoveryScope(
            snapshot.settings!,
            snapshot.providers,
            unavailable: snapshot.failures.contains('providers'),
          ),
        if (snapshot.failures.contains('users'))
          _UnavailableSection(title: 'Users and access', retry: retry)
        else
          _UserManagement(snapshot.users),
        _LibraryManagement(snapshot, locale: locale, retry: retry),
        _HealthAndIntegrations(snapshot, retry: retry),
        _Operations(snapshot, locale: locale, retry: retry),
      ],
    );
  }
}

class _ServerSettings extends StatelessWidget {
  const _ServerSettings(this.settings);
  final AdminSettings settings;

  @override
  Widget build(BuildContext context) => _AdminSection(
    title: 'Server and transfer settings',
    children: [
      _saveText(
        context,
        'Server name',
        settings.serverName ?? '',
        (value) => _putSettings(
          context,
          settings.rebuild((b) => b.serverName = value.trim()),
        ),
      ),
      _saveText(
        context,
        'Public base URL (optional)',
        settings.publicBaseUrl ?? '',
        (value) {
          final text = value.trim();
          _putSettings(
            context,
            settings.rebuild(
              (b) => b.publicBaseUrl = text.isEmpty ? null : text,
            ),
          );
        },
      ),
      _saveInt(
        context,
        'Concurrent downloads',
        settings.activeDownloads ?? 2,
        1,
        20,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.activeDownloads = v),
        ),
      ),
      _saveInt(
        context,
        'Downloads per user',
        settings.activeDownloadsPerUser ?? 1,
        1,
        20,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.activeDownloadsPerUser = v),
        ),
      ),
      _saveInt(
        context,
        'Active seed jobs',
        settings.activeSeeds ?? 2,
        0,
        50,
        (v) =>
            _putSettings(context, settings.rebuild((b) => b.activeSeeds = v)),
      ),
      _saveInt(
        context,
        'Global connections',
        settings.globalConnections ?? 100,
        1,
        5000,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.globalConnections = v),
        ),
      ),
      _saveInt(
        context,
        'Connections per torrent',
        settings.connectionsPerTorrent ?? 40,
        1,
        1000,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.connectionsPerTorrent = v),
        ),
      ),
      _saveOptionalUnit(
        context,
        'Download limit (MiB/s; blank = unlimited)',
        settings.downloadLimitBytesPerSecond,
        1048576,
        1073741824,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.downloadLimitBytesPerSecond = v),
        ),
      ),
      _saveOptionalUnit(
        context,
        'Upload limit (MiB/s; blank = unlimited)',
        settings.uploadLimitBytesPerSecond,
        1048576,
        1073741824,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.uploadLimitBytesPerSecond = v),
        ),
      ),
      _saveNullableDouble(
        context,
        'Default seed ratio (blank = unlimited)',
        settings.defaultRatioLimit,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.defaultRatioLimit = v),
        ),
      ),
      _saveNullableInt(
        context,
        'Default seed minutes (blank = unlimited)',
        settings.defaultSeedTimeMinutes,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.defaultSeedTimeMinutes = v),
        ),
      ),
      _saveOptionalUnit(
        context,
        'Default user quota (GiB; blank = unlimited)',
        settings.defaultUserQuotaBytes,
        1073741824,
        9007199254740991,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.defaultUserQuotaBytes = v),
        ),
      ),
      _saveUnit(
        context,
        'Low disk floor (GiB)',
        settings.lowDiskFloorBytes ?? 5368709120,
        1073741824,
        9007199254740991,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.lowDiskFloorBytes = v),
        ),
      ),
      _saveDouble(
        context,
        'Low disk floor fraction',
        settings.lowDiskFloorFraction ?? .05,
        0,
        .5,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.lowDiskFloorFraction = v),
        ),
      ),
      _saveUnit(
        context,
        'Thumbnail cache limit (MiB)',
        settings.thumbnailCacheMaxBytes ?? 536870912,
        1048576,
        8589934592,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.thumbnailCacheMaxBytes = v),
        ),
      ),
      _saveInt(
        context,
        'Audit retention (days)',
        settings.auditRetentionDays ?? 30,
        1,
        3650,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.auditRetentionDays = v),
        ),
      ),
      _saveInt(
        context,
        'Library scan interval (seconds)',
        settings.libraryScanIntervalSeconds ?? 3600,
        60,
        31536000,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.libraryScanIntervalSeconds = v),
        ),
      ),
      _saveInt(
        context,
        'Discovery cache (seconds)',
        settings.discoveryCacheSeconds ?? 300,
        30,
        86400,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.discoveryCacheSeconds = v),
        ),
      ),
      _saveInt(
        context,
        'Recent refresh (seconds)',
        settings.discoveryRecentRefreshSeconds ?? 900,
        60,
        86400,
        (v) => _putSettings(
          context,
          settings.rebuild((b) => b.discoveryRecentRefreshSeconds = v),
        ),
      ),
    ],
  );
}

class _DiscoveryScope extends ConsumerStatefulWidget {
  const _DiscoveryScope(
    this.settings,
    this.providers, {
    this.unavailable = false,
  });
  final AdminSettings settings;
  final List<api_models.Provider> providers;
  final bool unavailable;

  @override
  ConsumerState<_DiscoveryScope> createState() => _DiscoveryScopeState();
}

class _DiscoveryScopeState extends ConsumerState<_DiscoveryScope> {
  late final TextEditingController _providers;
  late final TextEditingController _categories;
  late String _providerMode;
  late String _categoryMode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _providers = TextEditingController(
      text: widget.settings.enabledProviderIds?.join('\n') ?? '',
    );
    _categories = TextEditingController(
      text: widget.settings.enabledCategoryIds?.join('\n') ?? '',
    );
    _providerMode = widget.settings.enabledProviderIds == null
        ? 'all'
        : 'selected';
    _categoryMode = widget.settings.enabledCategoryIds == null
        ? 'all'
        : 'selected';
  }

  @override
  void dispose() {
    _providers.dispose();
    _categories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AdminSection(
    title: 'Discovery scope',
    children: [
      const Text(
        'Choose which configured providers and category IDs can appear in discovery. The server enforces this scope for every user.',
      ),
      if (widget.unavailable)
        const Text(
          'Configured provider names are unavailable; provider IDs can still be entered manually.',
        ),
      const SizedBox(height: 8),
      _scopeMode(
        'Providers',
        _providerMode,
        (value) => setState(() => _providerMode = value),
      ),
      if (_providerMode == 'selected')
        TextField(
          controller: _providers,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Provider IDs',
            helperText: 'One ID per line. Maximum 100 IDs; each ID is at most 128 characters.',
            border: const OutlineInputBorder(),
            suffixIcon: PopupMenuButton<String>(
              tooltip: 'Choose configured provider IDs',
              icon: const Icon(Icons.list_alt),
              itemBuilder: (_) => widget.providers
                  .map(
                    (provider) => PopupMenuItem(
                      value: provider.id,
                      child: Text('${provider.name} · ${provider.id}'),
                    ),
                  )
                  .toList(),
              onSelected: (id) {
                final ids = _parseTokens(_providers.text);
                if (!ids.contains(id)) ids.add(id);
                _providers.text = ids.join('\n');
              },
            ),
          ),
        ),
      const SizedBox(height: 8),
      _scopeMode(
        'Categories',
        _categoryMode,
        (value) => setState(() => _categoryMode = value),
      ),
      if (_categoryMode == 'selected')
        TextField(
          controller: _categories,
          minLines: 1,
          maxLines: 4,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Category IDs',
            helperText: 'Enter non-negative numeric IDs separated by commas or lines. Maximum 100 IDs.',
            border: const OutlineInputBorder(),
            suffixIcon: PopupMenuButton<int>(
              tooltip: 'Choose configured category IDs',
              icon: const Icon(Icons.list_alt),
              itemBuilder: (_) {
                final ids =
                    widget.providers
                        .expand((provider) => provider.categories)
                        .toSet()
                        .toList()
                      ..sort();
                return ids
                    .map((id) => PopupMenuItem(value: id, child: Text('$id')))
                    .toList();
              },
              onSelected: (id) {
                final ids = _parseTokens(_categories.text);
                if (!ids.contains('$id')) ids.add('$id');
                _categories.text = ids.join('\n');
              },
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save discovery scope'),
        ),
      ),
    ],
  );

  Widget _scopeMode(
    String label,
    String value,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: '$label scope'),
    items: const [
      DropdownMenuItem(value: 'all', child: Text('All (no restriction)')),
      DropdownMenuItem(value: 'selected', child: Text('Selected IDs')),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );

  Future<void> _save() async {
    final providerIds = _providerMode == 'all'
        ? null
        : _parseTokens(_providers.text);
    final categoryStrings = _categoryMode == 'all'
        ? null
        : _parseTokens(_categories.text);
    final categoryIds = <int>[];
    if (categoryStrings != null) {
      for (final token in categoryStrings) {
        final id = int.tryParse(token);
        if (id == null) {
          _toast(context, '"$token" is not a whole number.');
          return;
        }
        categoryIds.add(id);
      }
    }
    final updated = widget.settings.rebuild((b) {
      if (providerIds == null) {
        b.enabledProviderIds = null;
      } else {
        b.enabledProviderIds.replace(providerIds);
      }
      if (categoryStrings == null) {
        b.enabledCategoryIds = null;
      } else {
        b.enabledCategoryIds.replace(categoryIds);
      }
    });
    setState(() => _saving = true);
    await _putSettings(context, updated);
    if (mounted) setState(() => _saving = false);
  }

  List<String> _parseTokens(String text) => text
      .split(RegExp(r'[,\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
}

class _UserManagement extends ConsumerWidget {
  const _UserManagement(this.users);
  final List<User> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _AdminSection(
    title: 'Users and access',
    trailing: FilledButton.icon(
      onPressed: () => _createUser(context, ref),
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Create user'),
    ),
    children: [
      for (final user in users)
        ListTile(
          title: Text(user.displayName),
          subtitle: Text('${user.username} · ${user.role.name}'),
          leading: Icon(
            user.role == UserRoleEnum.administrator
                ? Icons.admin_panel_settings
                : Icons.person_outline,
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              Semantics(
                label: 'Enable ${user.displayName}',
                child: Switch(
                  value: user.enabled,
                  onChanged: (enabled) =>
                      _editUser(context, ref, user, enabled: enabled),
                ),
              ),
              IconButton(
                tooltip: 'Reset ${user.displayName} password',
                icon: const Icon(Icons.password),
                onPressed: () => _resetPassword(context, ref, user),
              ),
            ],
          ),
        ),
      if (users.isEmpty) const ListTile(title: Text('No users returned.')),
    ],
  );
}

class _LibraryManagement extends ConsumerStatefulWidget {
  const _LibraryManagement(this.snapshot, {this.locale, required this.retry});
  final _AdminSnapshot snapshot;
  final String? locale;
  final VoidCallback retry;
  @override
  ConsumerState<_LibraryManagement> createState() => _LibraryManagementState();
}

class _LibraryManagementState extends ConsumerState<_LibraryManagement> {
  String? _selectedLibrary;
  GetLibraryGrants200Response? _grants;
  bool _loadingGrants = false;

  Future<void> _loadGrants(String id) async {
    setState(() {
      _selectedLibrary = id;
      _loadingGrants = true;
    });
    final session = _captureAdminSession(ref);
    if (session == null) {
      setState(() {
        _grants = null;
        _loadingGrants = false;
      });
      return;
    }
    try {
      final grants = (await session.api.getLibrariesApi().getLibraryGrants(
        id: id,
      )).data!;
      if (mounted &&
          _selectedLibrary == id &&
          _sameAdminSession(ref, session)) {
        setState(() {
          _grants = grants;
          _loadingGrants = false;
        });
      }
    } catch (_) {
      if (mounted && _sameAdminSession(ref, session)) {
        setState(() {
          _grants = null;
          _loadingGrants = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final selected = snapshot.libraries
        .where((l) => l.id == _selectedLibrary)
        .firstOrNull;
    return _AdminSection(
      title: 'Libraries, grants and storage',
      trailing: FilledButton.icon(
        onPressed: snapshot.roots.isEmpty || snapshot.failures.contains('roots')
            ? null
            : () => _createLibrary(context, ref, snapshot.roots),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Add library'),
      ),
      children: [
        if (snapshot.failures.contains('roots'))
          _retryNotice('Storage roots are unavailable.', widget.retry),
        if (snapshot.failures.contains('libraries'))
          _retryNotice('Libraries are unavailable.', widget.retry),
        if (snapshot.failures.contains('users'))
          _retryNotice(
            'User list is unavailable; access changes are disabled.',
            widget.retry,
          ),
        for (final root in snapshot.roots)
          ListTile(
            leading: Icon(
              root.available && root.writable
                  ? Icons.storage
                  : Icons.storage_outlined,
            ),
            title: Text(root.label),
            subtitle: Text(
              '${root.available ? 'Available' : 'Unavailable'} · ${root.writable ? 'Writable' : 'Read-only'}'
              '${root.freeBytes == null ? '' : ' · ${_bytes(root.freeBytes!, locale: widget.locale)} free'}',
            ),
          ),
        for (final library in snapshot.libraries)
          ListTile(
            title: Text(library.name),
            subtitle: Text(
              '${library.enabled ? 'Enabled' : 'Disabled'} · ${library.readOnly ? 'Read-only' : 'Writable'}',
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Manage ${library.name} access',
                  icon: const Icon(Icons.group_outlined),
                  onPressed: snapshot.failures.contains('users')
                      ? null
                      : () => _loadGrants(library.id),
                ),
                IconButton(
                  tooltip: 'Scan ${library.name}',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _scanLibrary(context, ref, library),
                ),
              ],
            ),
          ),
        if (snapshot.libraries.isEmpty)
          const ListTile(title: Text('No libraries are configured.')),
        if (_selectedLibrary != null) ...[
          const Divider(),
          Text(
            'Access for ${selected?.name ?? 'library'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_loadingGrants) const LinearProgressIndicator(),
          if (_grants != null)
            for (final user in snapshot.users.where(
              (u) => u.role != UserRoleEnum.administrator,
            ))
              _grantRow(context, ref, user, _grants!),
          if (_grants != null)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () =>
                    _saveGrants(context, ref, _selectedLibrary!, _grants!),
                child: const Text('Save access'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _grantRow(
    BuildContext context,
    WidgetRef ref,
    User user,
    GetLibraryGrants200Response response,
  ) {
    final grant = response.grants.where((g) => g.userId == user.id).firstOrNull;
    return StatefulBuilder(
      builder: (context, setLocal) {
        var read = grant?.read ?? false;
        var download = grant?.download ?? false;
        var manage = grant?.manage ?? false;
        final quota = grant?.quotaBytes;
        void store() {
          final grants = response.grants
              .where((g) => g.userId != user.id)
              .toList();
          if (read || download || manage) {
            grants.add(
              LibraryGrant(
                (b) => b
                  ..userId = user.id
                  ..read = read
                  ..download = download
                  ..manage = manage
                  ..quotaBytes = quota,
              ),
            );
          }
          setState(
            () => _grants = response.rebuild((b) => b.grants.replace(grants)),
          );
        }

        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 140, child: Text(user.displayName)),
            SizedBox(
              width: 150,
              child: CheckboxListTile(
                dense: true,
                title: const Text('Read'),
                value: read,
                onChanged: (v) => setLocal(() {
                  read = v == true;
                  store();
                }),
              ),
            ),
            SizedBox(
              width: 170,
              child: CheckboxListTile(
                dense: true,
                title: const Text('Download'),
                value: download,
                onChanged: (v) => setLocal(() {
                  download = v == true;
                  store();
                }),
              ),
            ),
            SizedBox(
              width: 150,
              child: CheckboxListTile(
                dense: true,
                title: const Text('Manage'),
                value: manage,
                onChanged: (v) => setLocal(() {
                  manage = v == true;
                  store();
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HealthAndIntegrations extends ConsumerWidget {
  const _HealthAndIntegrations(this.snapshot, {required this.retry});
  final _AdminSnapshot snapshot;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _AdminSection(
    title: 'Service health and integrations',
    children: [
      if (snapshot.failures.contains('health'))
        _retryNotice('Service health is unavailable.', retry),
      if (snapshot.failures.contains('integrations'))
        _retryNotice('Integrations are unavailable.', retry),
      for (final health in snapshot.health)
        ListTile(
          leading: Icon(
            health.state == ServiceHealthStateEnum.healthy
                ? Icons.check_circle_outline
                : Icons.warning_amber,
          ),
          title: Text(health.service),
          subtitle: Text(
            '${health.state.name}${health.detail == null ? '' : ' · ${health.detail}'}',
          ),
        ),
      for (final item in snapshot.integrations)
        ListTile(
          title: Text(item.kind.name),
          subtitle: Text(
            '${item.health.state.name} · ${item.credentialConfigured ? 'Credential configured' : 'No credential configured'}',
          ),
          trailing: Wrap(
            children: [
              IconButton(
                tooltip: 'Test ${item.kind.name}',
                icon: const Icon(Icons.health_and_safety_outlined),
                onPressed: () => _testIntegration(context, ref, item.kind.name),
              ),
              IconButton(
                tooltip: 'Configure ${item.kind.name}',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editIntegration(context, ref, item),
              ),
            ],
          ),
        ),
      if (snapshot.integrations.isEmpty)
        const ListTile(title: Text('No integration status is available.')),
    ],
  );
}

class _Operations extends ConsumerWidget {
  const _Operations(this.snapshot, {this.locale, required this.retry});
  final _AdminSnapshot snapshot;
  final String? locale;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context, WidgetRef ref) => _AdminSection(
    title: 'Maintenance and audit',
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Rescan libraries'),
            onPressed: () => _maintenance(
              context,
              ref,
              MaintenanceRequestActionEnum.rescanLibraries,
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Clean thumbnail cache'),
            onPressed: () => _maintenance(
              context,
              ref,
              MaintenanceRequestActionEnum.pruneThumbnailCache,
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('Database snapshot'),
            onPressed: () => _maintenance(
              context,
              ref,
              MaintenanceRequestActionEnum.databaseSnapshot,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Recent audit activity (server-redacted)'),
      if (snapshot.failures.contains('audit'))
        _retryNotice('Audit activity is unavailable.', retry),
      if (snapshot.audit != null)
        for (final item in snapshot.audit!.items)
          ListTile(
            dense: true,
            title: Text(item.action),
            subtitle: Text(
              '${formatDateTime(item.occurredAt, locale: locale)} · ${item.actorId ?? 'System'}',
            ),
          ),
      if (snapshot.audit?.truncated == true)
        const Text('More audit records are available.'),
    ],
  );
}

Widget _retryNotice(String text, VoidCallback retry) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      Expanded(child: Text(text)),
      TextButton(onPressed: retry, child: const Text('Retry')),
    ],
  ),
);

class _UnavailableSection extends StatelessWidget {
  const _UnavailableSection({required this.title, required this.retry});
  final String title;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => _AdminSection(
    title: title,
    children: [
      const Text(
        "This information could not be loaded. Other administration sections remain available.",
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: retry, child: const Text("Retry")),
      ),
    ],
  );
}

class _AdminSection extends StatelessWidget {
  const _AdminSection({
    required this.title,
    required this.children,
    this.trailing,
  });
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

Widget _saveText(
  BuildContext context,
  String label,
  String value,
  ValueChanged<String> save,
) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: TextFormField(
    key: ValueKey('$label:$value'),
    initialValue: value,
    maxLength: 200,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    onFieldSubmitted: save,
  ),
);

Widget _saveOptionalUnit(
  BuildContext context,
  String label,
  int? value,
  int multiplier,
  int max,
  ValueChanged<int?> save,
) => _saveText(
  context,
  label,
  value == null ? '' : (value / multiplier).toStringAsFixed(9),
  (raw) {
    final text = raw.trim();
    final parsed = text.isEmpty ? null : double.tryParse(text);
    if (text.isNotEmpty && (parsed == null || !parsed.isFinite)) {
      _toast(context, '$label must be a number, or blank for unlimited.');
      return;
    }
    save(parsed == null ? null : (parsed * multiplier).round());
  },
);

Widget _saveUnit(
  BuildContext context,
  String label,
  int value,
  int multiplier,
  int max,
  ValueChanged<int> save,
) => _saveText(context, label, (value / multiplier).toStringAsFixed(9), (raw) {
  final parsed = double.tryParse(raw.trim());
  if (parsed == null || !parsed.isFinite) {
    _toast(context, '$label must be a number.');
    return;
  }
  save((parsed * multiplier).round());
});

Widget _saveInt(
  BuildContext context,
  String label,
  int value,
  int min,
  int max,
  ValueChanged<int> save,
) => _saveText(context, label, '$value', (raw) {
  final parsed = int.tryParse(raw.trim());
  if (parsed == null) {
    _toast(context, '$label must be a whole number.');
    return;
  }
  save(parsed);
});

Widget _saveDouble(
  BuildContext context,
  String label,
  double value,
  double min,
  double max,
  ValueChanged<double> save,
) => _saveText(context, label, '$value', (raw) {
  final parsed = double.tryParse(raw.trim());
  if (parsed == null || !parsed.isFinite) {
    _toast(context, '$label must be a number.');
    return;
  }
  save(parsed);
});

Widget _saveNullableInt(
  BuildContext context,
  String label,
  int? value,
  ValueChanged<int?> save,
) => _saveText(context, label, value?.toString() ?? '', (raw) {
  final text = raw.trim();
  final parsed = text.isEmpty ? null : int.tryParse(text);
  if (text.isNotEmpty && parsed == null) {
    _toast(context, '$label must be a whole number, or blank.');
    return;
  }
  save(parsed);
});

Widget _saveNullableDouble(
  BuildContext context,
  String label,
  double? value,
  ValueChanged<double?> save,
) => _saveText(context, label, value?.toString() ?? '', (raw) {
  final text = raw.trim();
  final parsed = text.isEmpty ? null : double.tryParse(text);
  if (text.isNotEmpty && (parsed == null || !parsed.isFinite)) {
    _toast(context, '$label must be a number, or blank.');
    return;
  }
  save(parsed);
});

Future<void> _putSettings(BuildContext context, AdminSettings settings) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final session = container.read(clientSessionProvider);
  if (session == null || !session.administrator) {
    if (context.mounted) _toast(context, 'Administrator access is required.');
    return;
  }
  try {
    await session.api.getAdministrationApi().setAdminSettings(
      adminSettings: settings,
    );
    if (context.mounted &&
        identical(container.read(clientSessionProvider), session)) {
      container.invalidate(_adminSnapshotProvider);
    }
  } catch (error) {
    if (context.mounted &&
        identical(container.read(clientSessionProvider), session)) {
      _toast(context, clientError(error));
    }
  }
}

Future<void> _createUser(BuildContext context, WidgetRef ref) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _CreateUserDialog(session: session),
  );
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog({required this.session});
  final ClientSession session;
  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _name = TextEditingController(),
      _password = TextEditingController(),
      _confirmPassword = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_busy) return;
    if (!_sameAdminSession(ref, widget.session)) {
      setState(
        () => _error = 'Your administrator session changed. Close this dialog and try again.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.getAdministrationApi().createUser(
        createUser: CreateUser(
          (b) => b
            ..username = _username.text.trim()
            ..displayName = _name.text.trim()
            ..password = _password.text
            ..confirmPassword = _confirmPassword.text
            ..role = CreateUserRoleEnum.member,
        ),
        idempotencyKey: 'create-user-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      ref.invalidate(_adminSnapshotProvider);
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              clientError(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create member account'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _username,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              TextFormField(
                controller: _name,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Initial password',
                ),
              ),
              TextFormField(
                controller: _confirmPassword,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm initial password',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _create,
        child: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create'),
      ),
    ],
  );
}

Future<void> _editUser(
  BuildContext context,
  WidgetRef ref,
  User user, {
  required bool enabled,
}) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  try {
    await session.api.getAdministrationApi().updateUser(
      id: user.id,
      patchUser: PatchUser(
        (b) => b
          ..enabled = enabled
          ..version = user.version,
      ),
    );
    if (_sameAdminSession(ref, session)) ref.invalidate(_adminSnapshotProvider);
  } catch (error) {
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, clientError(error));
    }
  }
}

Future<void> _resetPassword(
  BuildContext context,
  WidgetRef ref,
  User user,
) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  var password = '';
  var confirmation = '';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reset ${user.displayName} password?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
            onChanged: (v) => password = v,
          ),
          TextFormField(
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
            ),
            onChanged: (v) => confirmation = v,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Reset and revoke sessions'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (!_sameAdminSession(ref, session)) return;
  if (confirmed != true) return;
  try {
    await session.api.getAdministrationApi().resetUserPassword(
      id: user.id,
      passwordReset: PasswordReset(
        (b) => b
          ..newPassword = password
          ..confirmNewPassword = confirmation
          ..version = user.version,
      ),
    );
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(
        context,
        'Password changed; the user’s other sessions were revoked.',
      );
    }
  } catch (error) {
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, clientError(error));
    }
  }
}

Future<void> _createLibrary(
  BuildContext context,
  WidgetRef ref,
  List<StorageRoot> roots,
) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  final availableRoots = roots.where((r) => r.available && r.writable).toList();
  if (availableRoots.isEmpty) {
    _toast(context, 'No writable mounted storage roots are available.');
    return;
  }
  final api = session.api.getAdministrationApi();
  final directories = <String, List<StorageDirectory>>{};
  try {
    final responses = await Future.wait(
      availableRoots.map((root) => api.listStorageDirectories(id: root.id)),
    );
    for (var i = 0; i < availableRoots.length; i++) {
      directories[availableRoots[i].id] = responses[i].data!.toList();
    }
  } catch (error) {
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, clientError(error));
    }
    return;
  }
  if (!context.mounted || !_sameAdminSession(ref, session)) return;
  final rootsWithDirs = availableRoots
      .where((r) => directories[r.id]!.isNotEmpty)
      .toList();
  if (rootsWithDirs.isEmpty) {
    _toast(
      context,
      'No eligible directories are available under mounted storage.',
    );
    return;
  }
  var name = '';
  var description = '';
  var selectedRoot = rootsWithDirs.first;
  var relative = directories[selectedRoot.id]!.first.relativePath;
  var readOnly = false;
  final result = await showDialog<(String, String, String, String, bool)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) => AlertDialog(
        title: const Text('Add library'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedRoot.id,
              decoration: const InputDecoration(labelText: 'Mounted storage'),
              items: [
                for (final root in rootsWithDirs)
                  DropdownMenuItem(value: root.id, child: Text(root.label)),
              ],
              onChanged: (id) {
                if (id != null) {
                  setDialog(() {
                    selectedRoot = rootsWithDirs.firstWhere(
                      (root) => root.id == id,
                    );
                    relative = directories[id]!.first.relativePath;
                  });
                }
              },
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Library name'),
              onChanged: (v) => name = v,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (v) => description = v,
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('${selectedRoot.id}:$relative'),
              initialValue: relative,
              decoration: const InputDecoration(labelText: 'Directory'),
              items: [
                for (final d in directories[selectedRoot.id]!)
                  DropdownMenuItem(value: d.relativePath, child: Text(d.name)),
              ],
              onChanged: (v) {
                if (v != null) setDialog(() => relative = v);
              },
            ),
            SwitchListTile(
              title: const Text('Read-only library'),
              value: readOnly,
              onChanged: (v) => setDialog(() => readOnly = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              name,
              description,
              selectedRoot.id,
              relative,
              readOnly,
            )),
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (!_sameAdminSession(ref, session)) return;
  if (result == null) return;
  try {
    await session.api.getLibrariesApi().createLibrary(
      libraryCreate: LibraryCreate(
        (b) => b
          ..name = result.$1.trim()
          ..description = result.$2.trim()
          ..storageRootId = result.$3
          ..relativePath = result.$4
          ..readOnly = result.$5,
      ),
      idempotencyKey: 'create-library-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (_sameAdminSession(ref, session)) ref.invalidate(_adminSnapshotProvider);
  } catch (error) {
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, clientError(error));
    }
  }
}

Future<void> _scanLibrary(
  BuildContext context,
  WidgetRef ref,
  ModelLibrary library,
) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  final approved = await _confirm(
    context,
    'Scan ${library.name}?',
    'The server will scan its registered directory for library changes.',
  );
  if (!approved || !context.mounted) return;
  if (!_sameAdminSession(ref, session)) return;
  try {
    await session.api.getLibrariesApi().scanLibrary(
      id: library.id,
      idempotencyKey:
          'scan-${library.id}-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, 'Library scan queued.');
    }
  } catch (error) {
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, clientError(error));
    }
  }
}

Future<void> _saveGrants(
  BuildContext context,
  WidgetRef ref,
  String id,
  GetLibraryGrants200Response grants,
) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  try {
    await session.api.getLibrariesApi().setLibraryGrants(
      id: id,
      grantUpdate: GrantUpdate(
        (b) => b
          ..version = grants.version
          ..grants.replace(grants.grants),
      ),
    );
    if (_sameAdminSession(ref, session)) ref.invalidate(_adminSnapshotProvider);
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, 'Library access saved.');
    }
  } catch (error) {
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(
        context,
        clientError(error),
      );
    }
  }
}

Future<void> _testIntegration(
  BuildContext context,
  WidgetRef ref,
  String kind,
) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  try {
    final response = await session.api.getAdministrationApi().testIntegration(
      kind: kind,
    );
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(
        context,
        '${response.data!.service}: ${response.data!.state.name}',
      );
    }
    if (_sameAdminSession(ref, session)) ref.invalidate(_adminSnapshotProvider);
  } catch (error) {
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(
        context,
        clientError(error),
      );
    }
  }
}

Future<void> _editIntegration(
  BuildContext context,
  WidgetRef ref,
  Integration integration,
) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  var baseUrl = integration.baseUrl;
  var username = '';
  var secret = '';
  final result = await showDialog<(String, String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Configure ${integration.kind.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            initialValue: baseUrl,
            decoration: const InputDecoration(labelText: 'Service URL'),
            onChanged: (v) => baseUrl = v,
          ),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Username (if required)',
            ),
            onChanged: (v) => username = v,
          ),
          TextFormField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'New secret',
              helperText: integration.credentialConfigured
                  ? 'Leave blank to keep the saved credential.'
                  : 'Secret is stored only by the server.',
            ),
            onChanged: (v) => secret = v,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (baseUrl, username, secret)),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (!_sameAdminSession(ref, session)) return;
  if (result == null) return;
  try {
    await session.api.getAdministrationApi().setIntegration(
      kind: integration.kind.name,
      integrationUpdate: IntegrationUpdate(
        (b) => b
          ..baseUrl = result.$1.trim()
          ..username = result.$2.trim().isEmpty ? null : result.$2.trim()
          ..secret = result.$3.isEmpty ? null : result.$3
          ..version = integration.version,
      ),
    );
    if (_sameAdminSession(ref, session)) ref.invalidate(_adminSnapshotProvider);
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, 'Integration settings saved.');
    }
  } catch (error) {
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, clientError(error));
    }
  }
}

Future<void> _maintenance(
  BuildContext context,
  WidgetRef ref,
  MaintenanceRequestActionEnum action,
) async {
  final session = _captureAdminSession(ref);
  if (session == null) return;
  final label = switch (action) {
    MaintenanceRequestActionEnum.rescanLibraries => 'Rescan libraries',
    MaintenanceRequestActionEnum.pruneThumbnailCache => 'Clean thumbnail cache',
    MaintenanceRequestActionEnum.databaseSnapshot => 'Create database snapshot',
    _ => 'Run maintenance job',
  };
  final detail = action == MaintenanceRequestActionEnum.databaseSnapshot
      ? 'This creates an application database snapshot only. It is not a full-stack backup of Docker services or media files.'
      : 'This queues a bounded maintenance job on the server.';
  if (!await _confirm(context, '$label?', detail) || !context.mounted) return;
  if (!_sameAdminSession(ref, session)) return;
  try {
    final job = (await session.api.getAdministrationApi().runMaintenance(
      maintenanceRequest: MaintenanceRequest((b) => b..action = action),
      idempotencyKey:
          'maintenance-${action.name}-${DateTime.now().microsecondsSinceEpoch}',
    )).data!;
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, '${job.kind}: ${job.state.name}');
    }
  } catch (error) {
    if (context.mounted && _sameAdminSession(ref, session)) {
      _toast(context, clientError(error));
    }
  }
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String detail,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ==
    true;

ClientSession? _captureAdminSession(WidgetRef ref) {
  final session = ref.read(clientSessionProvider);
  return session?.administrator == true ? session : null;
}

bool _sameAdminSession(WidgetRef ref, ClientSession session) =>
    session.administrator &&
    identical(ref.read(clientSessionProvider), session);

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

String _bytes(int value, {String? locale}) =>
    formatBytes(value, locale: locale);

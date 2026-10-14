// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_settings.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AdminSettings extends AdminSettings {
  @override
  final int version;
  @override
  final String? serverName;
  @override
  final String? publicBaseUrl;
  @override
  final int? activeDownloads;
  @override
  final int? activeDownloadsPerUser;
  @override
  final int? activeSeeds;
  @override
  final int? globalConnections;
  @override
  final int? connectionsPerTorrent;
  @override
  final int? downloadLimitBytesPerSecond;
  @override
  final int? uploadLimitBytesPerSecond;
  @override
  final double? defaultRatioLimit;
  @override
  final int? defaultSeedTimeMinutes;
  @override
  final int? defaultUserQuotaBytes;
  @override
  final int? lowDiskFloorBytes;
  @override
  final double? lowDiskFloorFraction;
  @override
  final int? thumbnailCacheMaxBytes;
  @override
  final int? auditRetentionDays;
  @override
  final BuiltList<String>? enabledProviderIds;
  @override
  final BuiltList<int>? enabledCategoryIds;
  @override
  final int? libraryScanIntervalSeconds;
  @override
  final int? discoveryCacheSeconds;
  @override
  final int? discoveryRecentRefreshSeconds;

  factory _$AdminSettings([void Function(AdminSettingsBuilder)? updates]) =>
      (AdminSettingsBuilder()..update(updates))._build();

  _$AdminSettings._(
      {required this.version,
      this.serverName,
      this.publicBaseUrl,
      this.activeDownloads,
      this.activeDownloadsPerUser,
      this.activeSeeds,
      this.globalConnections,
      this.connectionsPerTorrent,
      this.downloadLimitBytesPerSecond,
      this.uploadLimitBytesPerSecond,
      this.defaultRatioLimit,
      this.defaultSeedTimeMinutes,
      this.defaultUserQuotaBytes,
      this.lowDiskFloorBytes,
      this.lowDiskFloorFraction,
      this.thumbnailCacheMaxBytes,
      this.auditRetentionDays,
      this.enabledProviderIds,
      this.enabledCategoryIds,
      this.libraryScanIntervalSeconds,
      this.discoveryCacheSeconds,
      this.discoveryRecentRefreshSeconds})
      : super._();
  @override
  AdminSettings rebuild(void Function(AdminSettingsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AdminSettingsBuilder toBuilder() => AdminSettingsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AdminSettings &&
        version == other.version &&
        serverName == other.serverName &&
        publicBaseUrl == other.publicBaseUrl &&
        activeDownloads == other.activeDownloads &&
        activeDownloadsPerUser == other.activeDownloadsPerUser &&
        activeSeeds == other.activeSeeds &&
        globalConnections == other.globalConnections &&
        connectionsPerTorrent == other.connectionsPerTorrent &&
        downloadLimitBytesPerSecond == other.downloadLimitBytesPerSecond &&
        uploadLimitBytesPerSecond == other.uploadLimitBytesPerSecond &&
        defaultRatioLimit == other.defaultRatioLimit &&
        defaultSeedTimeMinutes == other.defaultSeedTimeMinutes &&
        defaultUserQuotaBytes == other.defaultUserQuotaBytes &&
        lowDiskFloorBytes == other.lowDiskFloorBytes &&
        lowDiskFloorFraction == other.lowDiskFloorFraction &&
        thumbnailCacheMaxBytes == other.thumbnailCacheMaxBytes &&
        auditRetentionDays == other.auditRetentionDays &&
        enabledProviderIds == other.enabledProviderIds &&
        enabledCategoryIds == other.enabledCategoryIds &&
        libraryScanIntervalSeconds == other.libraryScanIntervalSeconds &&
        discoveryCacheSeconds == other.discoveryCacheSeconds &&
        discoveryRecentRefreshSeconds == other.discoveryRecentRefreshSeconds;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, serverName.hashCode);
    _$hash = $jc(_$hash, publicBaseUrl.hashCode);
    _$hash = $jc(_$hash, activeDownloads.hashCode);
    _$hash = $jc(_$hash, activeDownloadsPerUser.hashCode);
    _$hash = $jc(_$hash, activeSeeds.hashCode);
    _$hash = $jc(_$hash, globalConnections.hashCode);
    _$hash = $jc(_$hash, connectionsPerTorrent.hashCode);
    _$hash = $jc(_$hash, downloadLimitBytesPerSecond.hashCode);
    _$hash = $jc(_$hash, uploadLimitBytesPerSecond.hashCode);
    _$hash = $jc(_$hash, defaultRatioLimit.hashCode);
    _$hash = $jc(_$hash, defaultSeedTimeMinutes.hashCode);
    _$hash = $jc(_$hash, defaultUserQuotaBytes.hashCode);
    _$hash = $jc(_$hash, lowDiskFloorBytes.hashCode);
    _$hash = $jc(_$hash, lowDiskFloorFraction.hashCode);
    _$hash = $jc(_$hash, thumbnailCacheMaxBytes.hashCode);
    _$hash = $jc(_$hash, auditRetentionDays.hashCode);
    _$hash = $jc(_$hash, enabledProviderIds.hashCode);
    _$hash = $jc(_$hash, enabledCategoryIds.hashCode);
    _$hash = $jc(_$hash, libraryScanIntervalSeconds.hashCode);
    _$hash = $jc(_$hash, discoveryCacheSeconds.hashCode);
    _$hash = $jc(_$hash, discoveryRecentRefreshSeconds.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AdminSettings')
          ..add('version', version)
          ..add('serverName', serverName)
          ..add('publicBaseUrl', publicBaseUrl)
          ..add('activeDownloads', activeDownloads)
          ..add('activeDownloadsPerUser', activeDownloadsPerUser)
          ..add('activeSeeds', activeSeeds)
          ..add('globalConnections', globalConnections)
          ..add('connectionsPerTorrent', connectionsPerTorrent)
          ..add('downloadLimitBytesPerSecond', downloadLimitBytesPerSecond)
          ..add('uploadLimitBytesPerSecond', uploadLimitBytesPerSecond)
          ..add('defaultRatioLimit', defaultRatioLimit)
          ..add('defaultSeedTimeMinutes', defaultSeedTimeMinutes)
          ..add('defaultUserQuotaBytes', defaultUserQuotaBytes)
          ..add('lowDiskFloorBytes', lowDiskFloorBytes)
          ..add('lowDiskFloorFraction', lowDiskFloorFraction)
          ..add('thumbnailCacheMaxBytes', thumbnailCacheMaxBytes)
          ..add('auditRetentionDays', auditRetentionDays)
          ..add('enabledProviderIds', enabledProviderIds)
          ..add('enabledCategoryIds', enabledCategoryIds)
          ..add('libraryScanIntervalSeconds', libraryScanIntervalSeconds)
          ..add('discoveryCacheSeconds', discoveryCacheSeconds)
          ..add('discoveryRecentRefreshSeconds', discoveryRecentRefreshSeconds))
        .toString();
  }
}

class AdminSettingsBuilder
    implements Builder<AdminSettings, AdminSettingsBuilder> {
  _$AdminSettings? _$v;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  String? _serverName;
  String? get serverName => _$this._serverName;
  set serverName(String? serverName) => _$this._serverName = serverName;

  String? _publicBaseUrl;
  String? get publicBaseUrl => _$this._publicBaseUrl;
  set publicBaseUrl(String? publicBaseUrl) =>
      _$this._publicBaseUrl = publicBaseUrl;

  int? _activeDownloads;
  int? get activeDownloads => _$this._activeDownloads;
  set activeDownloads(int? activeDownloads) =>
      _$this._activeDownloads = activeDownloads;

  int? _activeDownloadsPerUser;
  int? get activeDownloadsPerUser => _$this._activeDownloadsPerUser;
  set activeDownloadsPerUser(int? activeDownloadsPerUser) =>
      _$this._activeDownloadsPerUser = activeDownloadsPerUser;

  int? _activeSeeds;
  int? get activeSeeds => _$this._activeSeeds;
  set activeSeeds(int? activeSeeds) => _$this._activeSeeds = activeSeeds;

  int? _globalConnections;
  int? get globalConnections => _$this._globalConnections;
  set globalConnections(int? globalConnections) =>
      _$this._globalConnections = globalConnections;

  int? _connectionsPerTorrent;
  int? get connectionsPerTorrent => _$this._connectionsPerTorrent;
  set connectionsPerTorrent(int? connectionsPerTorrent) =>
      _$this._connectionsPerTorrent = connectionsPerTorrent;

  int? _downloadLimitBytesPerSecond;
  int? get downloadLimitBytesPerSecond => _$this._downloadLimitBytesPerSecond;
  set downloadLimitBytesPerSecond(int? downloadLimitBytesPerSecond) =>
      _$this._downloadLimitBytesPerSecond = downloadLimitBytesPerSecond;

  int? _uploadLimitBytesPerSecond;
  int? get uploadLimitBytesPerSecond => _$this._uploadLimitBytesPerSecond;
  set uploadLimitBytesPerSecond(int? uploadLimitBytesPerSecond) =>
      _$this._uploadLimitBytesPerSecond = uploadLimitBytesPerSecond;

  double? _defaultRatioLimit;
  double? get defaultRatioLimit => _$this._defaultRatioLimit;
  set defaultRatioLimit(double? defaultRatioLimit) =>
      _$this._defaultRatioLimit = defaultRatioLimit;

  int? _defaultSeedTimeMinutes;
  int? get defaultSeedTimeMinutes => _$this._defaultSeedTimeMinutes;
  set defaultSeedTimeMinutes(int? defaultSeedTimeMinutes) =>
      _$this._defaultSeedTimeMinutes = defaultSeedTimeMinutes;

  int? _defaultUserQuotaBytes;
  int? get defaultUserQuotaBytes => _$this._defaultUserQuotaBytes;
  set defaultUserQuotaBytes(int? defaultUserQuotaBytes) =>
      _$this._defaultUserQuotaBytes = defaultUserQuotaBytes;

  int? _lowDiskFloorBytes;
  int? get lowDiskFloorBytes => _$this._lowDiskFloorBytes;
  set lowDiskFloorBytes(int? lowDiskFloorBytes) =>
      _$this._lowDiskFloorBytes = lowDiskFloorBytes;

  double? _lowDiskFloorFraction;
  double? get lowDiskFloorFraction => _$this._lowDiskFloorFraction;
  set lowDiskFloorFraction(double? lowDiskFloorFraction) =>
      _$this._lowDiskFloorFraction = lowDiskFloorFraction;

  int? _thumbnailCacheMaxBytes;
  int? get thumbnailCacheMaxBytes => _$this._thumbnailCacheMaxBytes;
  set thumbnailCacheMaxBytes(int? thumbnailCacheMaxBytes) =>
      _$this._thumbnailCacheMaxBytes = thumbnailCacheMaxBytes;

  int? _auditRetentionDays;
  int? get auditRetentionDays => _$this._auditRetentionDays;
  set auditRetentionDays(int? auditRetentionDays) =>
      _$this._auditRetentionDays = auditRetentionDays;

  ListBuilder<String>? _enabledProviderIds;
  ListBuilder<String> get enabledProviderIds =>
      _$this._enabledProviderIds ??= ListBuilder<String>();
  set enabledProviderIds(ListBuilder<String>? enabledProviderIds) =>
      _$this._enabledProviderIds = enabledProviderIds;

  ListBuilder<int>? _enabledCategoryIds;
  ListBuilder<int> get enabledCategoryIds =>
      _$this._enabledCategoryIds ??= ListBuilder<int>();
  set enabledCategoryIds(ListBuilder<int>? enabledCategoryIds) =>
      _$this._enabledCategoryIds = enabledCategoryIds;

  int? _libraryScanIntervalSeconds;
  int? get libraryScanIntervalSeconds => _$this._libraryScanIntervalSeconds;
  set libraryScanIntervalSeconds(int? libraryScanIntervalSeconds) =>
      _$this._libraryScanIntervalSeconds = libraryScanIntervalSeconds;

  int? _discoveryCacheSeconds;
  int? get discoveryCacheSeconds => _$this._discoveryCacheSeconds;
  set discoveryCacheSeconds(int? discoveryCacheSeconds) =>
      _$this._discoveryCacheSeconds = discoveryCacheSeconds;

  int? _discoveryRecentRefreshSeconds;
  int? get discoveryRecentRefreshSeconds =>
      _$this._discoveryRecentRefreshSeconds;
  set discoveryRecentRefreshSeconds(int? discoveryRecentRefreshSeconds) =>
      _$this._discoveryRecentRefreshSeconds = discoveryRecentRefreshSeconds;

  AdminSettingsBuilder() {
    AdminSettings._defaults(this);
  }

  AdminSettingsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _version = $v.version;
      _serverName = $v.serverName;
      _publicBaseUrl = $v.publicBaseUrl;
      _activeDownloads = $v.activeDownloads;
      _activeDownloadsPerUser = $v.activeDownloadsPerUser;
      _activeSeeds = $v.activeSeeds;
      _globalConnections = $v.globalConnections;
      _connectionsPerTorrent = $v.connectionsPerTorrent;
      _downloadLimitBytesPerSecond = $v.downloadLimitBytesPerSecond;
      _uploadLimitBytesPerSecond = $v.uploadLimitBytesPerSecond;
      _defaultRatioLimit = $v.defaultRatioLimit;
      _defaultSeedTimeMinutes = $v.defaultSeedTimeMinutes;
      _defaultUserQuotaBytes = $v.defaultUserQuotaBytes;
      _lowDiskFloorBytes = $v.lowDiskFloorBytes;
      _lowDiskFloorFraction = $v.lowDiskFloorFraction;
      _thumbnailCacheMaxBytes = $v.thumbnailCacheMaxBytes;
      _auditRetentionDays = $v.auditRetentionDays;
      _enabledProviderIds = $v.enabledProviderIds?.toBuilder();
      _enabledCategoryIds = $v.enabledCategoryIds?.toBuilder();
      _libraryScanIntervalSeconds = $v.libraryScanIntervalSeconds;
      _discoveryCacheSeconds = $v.discoveryCacheSeconds;
      _discoveryRecentRefreshSeconds = $v.discoveryRecentRefreshSeconds;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AdminSettings other) {
    _$v = other as _$AdminSettings;
  }

  @override
  void update(void Function(AdminSettingsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AdminSettings build() => _build();

  _$AdminSettings _build() {
    _$AdminSettings _$result;
    try {
      _$result = _$v ??
          _$AdminSettings._(
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'AdminSettings', 'version'),
            serverName: serverName,
            publicBaseUrl: publicBaseUrl,
            activeDownloads: activeDownloads,
            activeDownloadsPerUser: activeDownloadsPerUser,
            activeSeeds: activeSeeds,
            globalConnections: globalConnections,
            connectionsPerTorrent: connectionsPerTorrent,
            downloadLimitBytesPerSecond: downloadLimitBytesPerSecond,
            uploadLimitBytesPerSecond: uploadLimitBytesPerSecond,
            defaultRatioLimit: defaultRatioLimit,
            defaultSeedTimeMinutes: defaultSeedTimeMinutes,
            defaultUserQuotaBytes: defaultUserQuotaBytes,
            lowDiskFloorBytes: lowDiskFloorBytes,
            lowDiskFloorFraction: lowDiskFloorFraction,
            thumbnailCacheMaxBytes: thumbnailCacheMaxBytes,
            auditRetentionDays: auditRetentionDays,
            enabledProviderIds: _enabledProviderIds?.build(),
            enabledCategoryIds: _enabledCategoryIds?.build(),
            libraryScanIntervalSeconds: libraryScanIntervalSeconds,
            discoveryCacheSeconds: discoveryCacheSeconds,
            discoveryRecentRefreshSeconds: discoveryRecentRefreshSeconds,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'enabledProviderIds';
        _enabledProviderIds?.build();
        _$failedField = 'enabledCategoryIds';
        _enabledCategoryIds?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'AdminSettings', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

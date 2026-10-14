// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_info.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ServerInfo extends ServerInfo {
  @override
  final String name;
  @override
  final String version;
  @override
  final int apiMajor;
  @override
  final bool bootstrapRequired;
  @override
  final BuiltList<String> capabilities;
  @override
  final String? minimumClientVersion;
  @override
  final String? publicBaseUrl;

  factory _$ServerInfo([void Function(ServerInfoBuilder)? updates]) =>
      (ServerInfoBuilder()..update(updates))._build();

  _$ServerInfo._(
      {required this.name,
      required this.version,
      required this.apiMajor,
      required this.bootstrapRequired,
      required this.capabilities,
      this.minimumClientVersion,
      this.publicBaseUrl})
      : super._();
  @override
  ServerInfo rebuild(void Function(ServerInfoBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ServerInfoBuilder toBuilder() => ServerInfoBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ServerInfo &&
        name == other.name &&
        version == other.version &&
        apiMajor == other.apiMajor &&
        bootstrapRequired == other.bootstrapRequired &&
        capabilities == other.capabilities &&
        minimumClientVersion == other.minimumClientVersion &&
        publicBaseUrl == other.publicBaseUrl;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, apiMajor.hashCode);
    _$hash = $jc(_$hash, bootstrapRequired.hashCode);
    _$hash = $jc(_$hash, capabilities.hashCode);
    _$hash = $jc(_$hash, minimumClientVersion.hashCode);
    _$hash = $jc(_$hash, publicBaseUrl.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ServerInfo')
          ..add('name', name)
          ..add('version', version)
          ..add('apiMajor', apiMajor)
          ..add('bootstrapRequired', bootstrapRequired)
          ..add('capabilities', capabilities)
          ..add('minimumClientVersion', minimumClientVersion)
          ..add('publicBaseUrl', publicBaseUrl))
        .toString();
  }
}

class ServerInfoBuilder implements Builder<ServerInfo, ServerInfoBuilder> {
  _$ServerInfo? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _version;
  String? get version => _$this._version;
  set version(String? version) => _$this._version = version;

  int? _apiMajor;
  int? get apiMajor => _$this._apiMajor;
  set apiMajor(int? apiMajor) => _$this._apiMajor = apiMajor;

  bool? _bootstrapRequired;
  bool? get bootstrapRequired => _$this._bootstrapRequired;
  set bootstrapRequired(bool? bootstrapRequired) =>
      _$this._bootstrapRequired = bootstrapRequired;

  ListBuilder<String>? _capabilities;
  ListBuilder<String> get capabilities =>
      _$this._capabilities ??= ListBuilder<String>();
  set capabilities(ListBuilder<String>? capabilities) =>
      _$this._capabilities = capabilities;

  String? _minimumClientVersion;
  String? get minimumClientVersion => _$this._minimumClientVersion;
  set minimumClientVersion(String? minimumClientVersion) =>
      _$this._minimumClientVersion = minimumClientVersion;

  String? _publicBaseUrl;
  String? get publicBaseUrl => _$this._publicBaseUrl;
  set publicBaseUrl(String? publicBaseUrl) =>
      _$this._publicBaseUrl = publicBaseUrl;

  ServerInfoBuilder() {
    ServerInfo._defaults(this);
  }

  ServerInfoBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _version = $v.version;
      _apiMajor = $v.apiMajor;
      _bootstrapRequired = $v.bootstrapRequired;
      _capabilities = $v.capabilities.toBuilder();
      _minimumClientVersion = $v.minimumClientVersion;
      _publicBaseUrl = $v.publicBaseUrl;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ServerInfo other) {
    _$v = other as _$ServerInfo;
  }

  @override
  void update(void Function(ServerInfoBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ServerInfo build() => _build();

  _$ServerInfo _build() {
    _$ServerInfo _$result;
    try {
      _$result = _$v ??
          _$ServerInfo._(
            name: BuiltValueNullFieldError.checkNotNull(
                name, r'ServerInfo', 'name'),
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'ServerInfo', 'version'),
            apiMajor: BuiltValueNullFieldError.checkNotNull(
                apiMajor, r'ServerInfo', 'apiMajor'),
            bootstrapRequired: BuiltValueNullFieldError.checkNotNull(
                bootstrapRequired, r'ServerInfo', 'bootstrapRequired'),
            capabilities: capabilities.build(),
            minimumClientVersion: minimumClientVersion,
            publicBaseUrl: publicBaseUrl,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'capabilities';
        capabilities.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ServerInfo', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

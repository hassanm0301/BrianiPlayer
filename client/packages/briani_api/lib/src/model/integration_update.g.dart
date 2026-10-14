// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'integration_update.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$IntegrationUpdate extends IntegrationUpdate {
  @override
  final String baseUrl;
  @override
  final String? username;
  @override
  final String? secret;
  @override
  final int version;

  factory _$IntegrationUpdate(
          [void Function(IntegrationUpdateBuilder)? updates]) =>
      (IntegrationUpdateBuilder()..update(updates))._build();

  _$IntegrationUpdate._(
      {required this.baseUrl,
      this.username,
      this.secret,
      required this.version})
      : super._();
  @override
  IntegrationUpdate rebuild(void Function(IntegrationUpdateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IntegrationUpdateBuilder toBuilder() =>
      IntegrationUpdateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IntegrationUpdate &&
        baseUrl == other.baseUrl &&
        username == other.username &&
        secret == other.secret &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, baseUrl.hashCode);
    _$hash = $jc(_$hash, username.hashCode);
    _$hash = $jc(_$hash, secret.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IntegrationUpdate')
          ..add('baseUrl', baseUrl)
          ..add('username', username)
          ..add('secret', secret)
          ..add('version', version))
        .toString();
  }
}

class IntegrationUpdateBuilder
    implements Builder<IntegrationUpdate, IntegrationUpdateBuilder> {
  _$IntegrationUpdate? _$v;

  String? _baseUrl;
  String? get baseUrl => _$this._baseUrl;
  set baseUrl(String? baseUrl) => _$this._baseUrl = baseUrl;

  String? _username;
  String? get username => _$this._username;
  set username(String? username) => _$this._username = username;

  String? _secret;
  String? get secret => _$this._secret;
  set secret(String? secret) => _$this._secret = secret;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  IntegrationUpdateBuilder() {
    IntegrationUpdate._defaults(this);
  }

  IntegrationUpdateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _baseUrl = $v.baseUrl;
      _username = $v.username;
      _secret = $v.secret;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IntegrationUpdate other) {
    _$v = other as _$IntegrationUpdate;
  }

  @override
  void update(void Function(IntegrationUpdateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IntegrationUpdate build() => _build();

  _$IntegrationUpdate _build() {
    final _$result = _$v ??
        _$IntegrationUpdate._(
          baseUrl: BuiltValueNullFieldError.checkNotNull(
              baseUrl, r'IntegrationUpdate', 'baseUrl'),
          username: username,
          secret: secret,
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'IntegrationUpdate', 'version'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

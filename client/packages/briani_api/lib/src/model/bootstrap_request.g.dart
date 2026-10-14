// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$BootstrapRequest extends BootstrapRequest {
  @override
  final String code;
  @override
  final String username;
  @override
  final String displayName;
  @override
  final String password;

  factory _$BootstrapRequest(
          [void Function(BootstrapRequestBuilder)? updates]) =>
      (BootstrapRequestBuilder()..update(updates))._build();

  _$BootstrapRequest._(
      {required this.code,
      required this.username,
      required this.displayName,
      required this.password})
      : super._();
  @override
  BootstrapRequest rebuild(void Function(BootstrapRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  BootstrapRequestBuilder toBuilder() =>
      BootstrapRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is BootstrapRequest &&
        code == other.code &&
        username == other.username &&
        displayName == other.displayName &&
        password == other.password;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jc(_$hash, username.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, password.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'BootstrapRequest')
          ..add('code', code)
          ..add('username', username)
          ..add('displayName', displayName)
          ..add('password', password))
        .toString();
  }
}

class BootstrapRequestBuilder
    implements Builder<BootstrapRequest, BootstrapRequestBuilder> {
  _$BootstrapRequest? _$v;

  String? _code;
  String? get code => _$this._code;
  set code(String? code) => _$this._code = code;

  String? _username;
  String? get username => _$this._username;
  set username(String? username) => _$this._username = username;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  String? _password;
  String? get password => _$this._password;
  set password(String? password) => _$this._password = password;

  BootstrapRequestBuilder() {
    BootstrapRequest._defaults(this);
  }

  BootstrapRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _code = $v.code;
      _username = $v.username;
      _displayName = $v.displayName;
      _password = $v.password;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(BootstrapRequest other) {
    _$v = other as _$BootstrapRequest;
  }

  @override
  void update(void Function(BootstrapRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  BootstrapRequest build() => _build();

  _$BootstrapRequest _build() {
    final _$result = _$v ??
        _$BootstrapRequest._(
          code: BuiltValueNullFieldError.checkNotNull(
              code, r'BootstrapRequest', 'code'),
          username: BuiltValueNullFieldError.checkNotNull(
              username, r'BootstrapRequest', 'username'),
          displayName: BuiltValueNullFieldError.checkNotNull(
              displayName, r'BootstrapRequest', 'displayName'),
          password: BuiltValueNullFieldError.checkNotNull(
              password, r'BootstrapRequest', 'password'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

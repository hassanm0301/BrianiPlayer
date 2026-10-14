// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_tokens.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AuthTokens extends AuthTokens {
  @override
  final String accessToken;
  @override
  final DateTime accessExpiresAt;
  @override
  final String refreshToken;
  @override
  final DateTime refreshExpiresAt;
  @override
  final String sessionId;
  @override
  final User user;

  factory _$AuthTokens([void Function(AuthTokensBuilder)? updates]) =>
      (AuthTokensBuilder()..update(updates))._build();

  _$AuthTokens._(
      {required this.accessToken,
      required this.accessExpiresAt,
      required this.refreshToken,
      required this.refreshExpiresAt,
      required this.sessionId,
      required this.user})
      : super._();
  @override
  AuthTokens rebuild(void Function(AuthTokensBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AuthTokensBuilder toBuilder() => AuthTokensBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AuthTokens &&
        accessToken == other.accessToken &&
        accessExpiresAt == other.accessExpiresAt &&
        refreshToken == other.refreshToken &&
        refreshExpiresAt == other.refreshExpiresAt &&
        sessionId == other.sessionId &&
        user == other.user;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, accessToken.hashCode);
    _$hash = $jc(_$hash, accessExpiresAt.hashCode);
    _$hash = $jc(_$hash, refreshToken.hashCode);
    _$hash = $jc(_$hash, refreshExpiresAt.hashCode);
    _$hash = $jc(_$hash, sessionId.hashCode);
    _$hash = $jc(_$hash, user.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AuthTokens')
          ..add('accessToken', accessToken)
          ..add('accessExpiresAt', accessExpiresAt)
          ..add('refreshToken', refreshToken)
          ..add('refreshExpiresAt', refreshExpiresAt)
          ..add('sessionId', sessionId)
          ..add('user', user))
        .toString();
  }
}

class AuthTokensBuilder implements Builder<AuthTokens, AuthTokensBuilder> {
  _$AuthTokens? _$v;

  String? _accessToken;
  String? get accessToken => _$this._accessToken;
  set accessToken(String? accessToken) => _$this._accessToken = accessToken;

  DateTime? _accessExpiresAt;
  DateTime? get accessExpiresAt => _$this._accessExpiresAt;
  set accessExpiresAt(DateTime? accessExpiresAt) =>
      _$this._accessExpiresAt = accessExpiresAt;

  String? _refreshToken;
  String? get refreshToken => _$this._refreshToken;
  set refreshToken(String? refreshToken) => _$this._refreshToken = refreshToken;

  DateTime? _refreshExpiresAt;
  DateTime? get refreshExpiresAt => _$this._refreshExpiresAt;
  set refreshExpiresAt(DateTime? refreshExpiresAt) =>
      _$this._refreshExpiresAt = refreshExpiresAt;

  String? _sessionId;
  String? get sessionId => _$this._sessionId;
  set sessionId(String? sessionId) => _$this._sessionId = sessionId;

  UserBuilder? _user;
  UserBuilder get user => _$this._user ??= UserBuilder();
  set user(UserBuilder? user) => _$this._user = user;

  AuthTokensBuilder() {
    AuthTokens._defaults(this);
  }

  AuthTokensBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _accessToken = $v.accessToken;
      _accessExpiresAt = $v.accessExpiresAt;
      _refreshToken = $v.refreshToken;
      _refreshExpiresAt = $v.refreshExpiresAt;
      _sessionId = $v.sessionId;
      _user = $v.user.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AuthTokens other) {
    _$v = other as _$AuthTokens;
  }

  @override
  void update(void Function(AuthTokensBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AuthTokens build() => _build();

  _$AuthTokens _build() {
    _$AuthTokens _$result;
    try {
      _$result = _$v ??
          _$AuthTokens._(
            accessToken: BuiltValueNullFieldError.checkNotNull(
                accessToken, r'AuthTokens', 'accessToken'),
            accessExpiresAt: BuiltValueNullFieldError.checkNotNull(
                accessExpiresAt, r'AuthTokens', 'accessExpiresAt'),
            refreshToken: BuiltValueNullFieldError.checkNotNull(
                refreshToken, r'AuthTokens', 'refreshToken'),
            refreshExpiresAt: BuiltValueNullFieldError.checkNotNull(
                refreshExpiresAt, r'AuthTokens', 'refreshExpiresAt'),
            sessionId: BuiltValueNullFieldError.checkNotNull(
                sessionId, r'AuthTokens', 'sessionId'),
            user: user.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'user';
        user.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'AuthTokens', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

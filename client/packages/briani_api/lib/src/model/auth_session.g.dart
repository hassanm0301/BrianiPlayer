// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_session.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AuthSession extends AuthSession {
  @override
  final String id;
  @override
  final String deviceName;
  @override
  final DateTime createdAt;
  @override
  final DateTime lastSeenAt;
  @override
  final DateTime expiresAt;
  @override
  final bool current;

  factory _$AuthSession([void Function(AuthSessionBuilder)? updates]) =>
      (AuthSessionBuilder()..update(updates))._build();

  _$AuthSession._(
      {required this.id,
      required this.deviceName,
      required this.createdAt,
      required this.lastSeenAt,
      required this.expiresAt,
      required this.current})
      : super._();
  @override
  AuthSession rebuild(void Function(AuthSessionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AuthSessionBuilder toBuilder() => AuthSessionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AuthSession &&
        id == other.id &&
        deviceName == other.deviceName &&
        createdAt == other.createdAt &&
        lastSeenAt == other.lastSeenAt &&
        expiresAt == other.expiresAt &&
        current == other.current;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, deviceName.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, lastSeenAt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, current.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AuthSession')
          ..add('id', id)
          ..add('deviceName', deviceName)
          ..add('createdAt', createdAt)
          ..add('lastSeenAt', lastSeenAt)
          ..add('expiresAt', expiresAt)
          ..add('current', current))
        .toString();
  }
}

class AuthSessionBuilder implements Builder<AuthSession, AuthSessionBuilder> {
  _$AuthSession? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _deviceName;
  String? get deviceName => _$this._deviceName;
  set deviceName(String? deviceName) => _$this._deviceName = deviceName;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _lastSeenAt;
  DateTime? get lastSeenAt => _$this._lastSeenAt;
  set lastSeenAt(DateTime? lastSeenAt) => _$this._lastSeenAt = lastSeenAt;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  bool? _current;
  bool? get current => _$this._current;
  set current(bool? current) => _$this._current = current;

  AuthSessionBuilder() {
    AuthSession._defaults(this);
  }

  AuthSessionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _deviceName = $v.deviceName;
      _createdAt = $v.createdAt;
      _lastSeenAt = $v.lastSeenAt;
      _expiresAt = $v.expiresAt;
      _current = $v.current;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AuthSession other) {
    _$v = other as _$AuthSession;
  }

  @override
  void update(void Function(AuthSessionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AuthSession build() => _build();

  _$AuthSession _build() {
    final _$result = _$v ??
        _$AuthSession._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'AuthSession', 'id'),
          deviceName: BuiltValueNullFieldError.checkNotNull(
              deviceName, r'AuthSession', 'deviceName'),
          createdAt: BuiltValueNullFieldError.checkNotNull(
              createdAt, r'AuthSession', 'createdAt'),
          lastSeenAt: BuiltValueNullFieldError.checkNotNull(
              lastSeenAt, r'AuthSession', 'lastSeenAt'),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt, r'AuthSession', 'expiresAt'),
          current: BuiltValueNullFieldError.checkNotNull(
              current, r'AuthSession', 'current'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

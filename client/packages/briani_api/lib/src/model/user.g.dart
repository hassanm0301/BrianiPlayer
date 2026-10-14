// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const UserRoleEnum _$userRoleEnum_administrator =
    const UserRoleEnum._('administrator');
const UserRoleEnum _$userRoleEnum_member = const UserRoleEnum._('member');

UserRoleEnum _$userRoleEnumValueOf(String name) {
  switch (name) {
    case 'administrator':
      return _$userRoleEnum_administrator;
    case 'member':
      return _$userRoleEnum_member;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<UserRoleEnum> _$userRoleEnumValues =
    BuiltSet<UserRoleEnum>(const <UserRoleEnum>[
  _$userRoleEnum_administrator,
  _$userRoleEnum_member,
]);

Serializer<UserRoleEnum> _$userRoleEnumSerializer = _$UserRoleEnumSerializer();

class _$UserRoleEnumSerializer implements PrimitiveSerializer<UserRoleEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'administrator': 'administrator',
    'member': 'member',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'administrator': 'administrator',
    'member': 'member',
  };

  @override
  final Iterable<Type> types = const <Type>[UserRoleEnum];
  @override
  final String wireName = 'UserRoleEnum';

  @override
  Object serialize(Serializers serializers, UserRoleEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  UserRoleEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      UserRoleEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$User extends User {
  @override
  final String id;
  @override
  final String username;
  @override
  final String displayName;
  @override
  final UserRoleEnum role;
  @override
  final bool enabled;
  @override
  final int version;
  @override
  final bool? mustChangePassword;

  factory _$User([void Function(UserBuilder)? updates]) =>
      (UserBuilder()..update(updates))._build();

  _$User._(
      {required this.id,
      required this.username,
      required this.displayName,
      required this.role,
      required this.enabled,
      required this.version,
      this.mustChangePassword})
      : super._();
  @override
  User rebuild(void Function(UserBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  UserBuilder toBuilder() => UserBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is User &&
        id == other.id &&
        username == other.username &&
        displayName == other.displayName &&
        role == other.role &&
        enabled == other.enabled &&
        version == other.version &&
        mustChangePassword == other.mustChangePassword;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, username.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, mustChangePassword.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'User')
          ..add('id', id)
          ..add('username', username)
          ..add('displayName', displayName)
          ..add('role', role)
          ..add('enabled', enabled)
          ..add('version', version)
          ..add('mustChangePassword', mustChangePassword))
        .toString();
  }
}

class UserBuilder implements Builder<User, UserBuilder> {
  _$User? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _username;
  String? get username => _$this._username;
  set username(String? username) => _$this._username = username;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  UserRoleEnum? _role;
  UserRoleEnum? get role => _$this._role;
  set role(UserRoleEnum? role) => _$this._role = role;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  bool? _mustChangePassword;
  bool? get mustChangePassword => _$this._mustChangePassword;
  set mustChangePassword(bool? mustChangePassword) =>
      _$this._mustChangePassword = mustChangePassword;

  UserBuilder() {
    User._defaults(this);
  }

  UserBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _username = $v.username;
      _displayName = $v.displayName;
      _role = $v.role;
      _enabled = $v.enabled;
      _version = $v.version;
      _mustChangePassword = $v.mustChangePassword;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(User other) {
    _$v = other as _$User;
  }

  @override
  void update(void Function(UserBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  User build() => _build();

  _$User _build() {
    final _$result = _$v ??
        _$User._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'User', 'id'),
          username: BuiltValueNullFieldError.checkNotNull(
              username, r'User', 'username'),
          displayName: BuiltValueNullFieldError.checkNotNull(
              displayName, r'User', 'displayName'),
          role: BuiltValueNullFieldError.checkNotNull(role, r'User', 'role'),
          enabled: BuiltValueNullFieldError.checkNotNull(
              enabled, r'User', 'enabled'),
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'User', 'version'),
          mustChangePassword: mustChangePassword,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

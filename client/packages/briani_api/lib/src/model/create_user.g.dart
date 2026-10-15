// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_user.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const CreateUserRoleEnum _$createUserRoleEnum_administrator =
    const CreateUserRoleEnum._('administrator');
const CreateUserRoleEnum _$createUserRoleEnum_member =
    const CreateUserRoleEnum._('member');

CreateUserRoleEnum _$createUserRoleEnumValueOf(String name) {
  switch (name) {
    case 'administrator':
      return _$createUserRoleEnum_administrator;
    case 'member':
      return _$createUserRoleEnum_member;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<CreateUserRoleEnum> _$createUserRoleEnumValues =
    BuiltSet<CreateUserRoleEnum>(const <CreateUserRoleEnum>[
  _$createUserRoleEnum_administrator,
  _$createUserRoleEnum_member,
]);

Serializer<CreateUserRoleEnum> _$createUserRoleEnumSerializer =
    _$CreateUserRoleEnumSerializer();

class _$CreateUserRoleEnumSerializer
    implements PrimitiveSerializer<CreateUserRoleEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'administrator': 'administrator',
    'member': 'member',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'administrator': 'administrator',
    'member': 'member',
  };

  @override
  final Iterable<Type> types = const <Type>[CreateUserRoleEnum];
  @override
  final String wireName = 'CreateUserRoleEnum';

  @override
  Object serialize(Serializers serializers, CreateUserRoleEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  CreateUserRoleEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      CreateUserRoleEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$CreateUser extends CreateUser {
  @override
  final String username;
  @override
  final String displayName;
  @override
  final String password;
  @override
  final String confirmPassword;
  @override
  final CreateUserRoleEnum role;

  factory _$CreateUser([void Function(CreateUserBuilder)? updates]) =>
      (CreateUserBuilder()..update(updates))._build();

  _$CreateUser._(
      {required this.username,
      required this.displayName,
      required this.password,
      required this.confirmPassword,
      required this.role})
      : super._();
  @override
  CreateUser rebuild(void Function(CreateUserBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  CreateUserBuilder toBuilder() => CreateUserBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CreateUser &&
        username == other.username &&
        displayName == other.displayName &&
        password == other.password &&
        confirmPassword == other.confirmPassword &&
        role == other.role;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, username.hashCode);
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, password.hashCode);
    _$hash = $jc(_$hash, confirmPassword.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CreateUser')
          ..add('username', username)
          ..add('displayName', displayName)
          ..add('password', password)
          ..add('confirmPassword', confirmPassword)
          ..add('role', role))
        .toString();
  }
}

class CreateUserBuilder implements Builder<CreateUser, CreateUserBuilder> {
  _$CreateUser? _$v;

  String? _username;
  String? get username => _$this._username;
  set username(String? username) => _$this._username = username;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  String? _password;
  String? get password => _$this._password;
  set password(String? password) => _$this._password = password;

  String? _confirmPassword;
  String? get confirmPassword => _$this._confirmPassword;
  set confirmPassword(String? confirmPassword) =>
      _$this._confirmPassword = confirmPassword;

  CreateUserRoleEnum? _role;
  CreateUserRoleEnum? get role => _$this._role;
  set role(CreateUserRoleEnum? role) => _$this._role = role;

  CreateUserBuilder() {
    CreateUser._defaults(this);
  }

  CreateUserBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _username = $v.username;
      _displayName = $v.displayName;
      _password = $v.password;
      _confirmPassword = $v.confirmPassword;
      _role = $v.role;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CreateUser other) {
    _$v = other as _$CreateUser;
  }

  @override
  void update(void Function(CreateUserBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CreateUser build() => _build();

  _$CreateUser _build() {
    final _$result = _$v ??
        _$CreateUser._(
          username: BuiltValueNullFieldError.checkNotNull(
              username, r'CreateUser', 'username'),
          displayName: BuiltValueNullFieldError.checkNotNull(
              displayName, r'CreateUser', 'displayName'),
          password: BuiltValueNullFieldError.checkNotNull(
              password, r'CreateUser', 'password'),
          confirmPassword: BuiltValueNullFieldError.checkNotNull(
              confirmPassword, r'CreateUser', 'confirmPassword'),
          role: BuiltValueNullFieldError.checkNotNull(
              role, r'CreateUser', 'role'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

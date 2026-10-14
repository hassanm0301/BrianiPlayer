// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patch_user.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const PatchUserRoleEnum _$patchUserRoleEnum_administrator =
    const PatchUserRoleEnum._('administrator');
const PatchUserRoleEnum _$patchUserRoleEnum_member =
    const PatchUserRoleEnum._('member');

PatchUserRoleEnum _$patchUserRoleEnumValueOf(String name) {
  switch (name) {
    case 'administrator':
      return _$patchUserRoleEnum_administrator;
    case 'member':
      return _$patchUserRoleEnum_member;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<PatchUserRoleEnum> _$patchUserRoleEnumValues =
    BuiltSet<PatchUserRoleEnum>(const <PatchUserRoleEnum>[
  _$patchUserRoleEnum_administrator,
  _$patchUserRoleEnum_member,
]);

Serializer<PatchUserRoleEnum> _$patchUserRoleEnumSerializer =
    _$PatchUserRoleEnumSerializer();

class _$PatchUserRoleEnumSerializer
    implements PrimitiveSerializer<PatchUserRoleEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'administrator': 'administrator',
    'member': 'member',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'administrator': 'administrator',
    'member': 'member',
  };

  @override
  final Iterable<Type> types = const <Type>[PatchUserRoleEnum];
  @override
  final String wireName = 'PatchUserRoleEnum';

  @override
  Object serialize(Serializers serializers, PatchUserRoleEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  PatchUserRoleEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      PatchUserRoleEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$PatchUser extends PatchUser {
  @override
  final String? displayName;
  @override
  final PatchUserRoleEnum? role;
  @override
  final bool? enabled;
  @override
  final int version;

  factory _$PatchUser([void Function(PatchUserBuilder)? updates]) =>
      (PatchUserBuilder()..update(updates))._build();

  _$PatchUser._(
      {this.displayName, this.role, this.enabled, required this.version})
      : super._();
  @override
  PatchUser rebuild(void Function(PatchUserBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PatchUserBuilder toBuilder() => PatchUserBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PatchUser &&
        displayName == other.displayName &&
        role == other.role &&
        enabled == other.enabled &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, displayName.hashCode);
    _$hash = $jc(_$hash, role.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PatchUser')
          ..add('displayName', displayName)
          ..add('role', role)
          ..add('enabled', enabled)
          ..add('version', version))
        .toString();
  }
}

class PatchUserBuilder implements Builder<PatchUser, PatchUserBuilder> {
  _$PatchUser? _$v;

  String? _displayName;
  String? get displayName => _$this._displayName;
  set displayName(String? displayName) => _$this._displayName = displayName;

  PatchUserRoleEnum? _role;
  PatchUserRoleEnum? get role => _$this._role;
  set role(PatchUserRoleEnum? role) => _$this._role = role;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  PatchUserBuilder() {
    PatchUser._defaults(this);
  }

  PatchUserBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _displayName = $v.displayName;
      _role = $v.role;
      _enabled = $v.enabled;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PatchUser other) {
    _$v = other as _$PatchUser;
  }

  @override
  void update(void Function(PatchUserBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PatchUser build() => _build();

  _$PatchUser _build() {
    final _$result = _$v ??
        _$PatchUser._(
          displayName: displayName,
          role: role,
          enabled: enabled,
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'PatchUser', 'version'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

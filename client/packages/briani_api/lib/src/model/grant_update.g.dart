// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grant_update.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GrantUpdate extends GrantUpdate {
  @override
  final int version;
  @override
  final BuiltList<LibraryGrant> grants;

  factory _$GrantUpdate([void Function(GrantUpdateBuilder)? updates]) =>
      (GrantUpdateBuilder()..update(updates))._build();

  _$GrantUpdate._({required this.version, required this.grants}) : super._();
  @override
  GrantUpdate rebuild(void Function(GrantUpdateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GrantUpdateBuilder toBuilder() => GrantUpdateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GrantUpdate &&
        version == other.version &&
        grants == other.grants;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, grants.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'GrantUpdate')
          ..add('version', version)
          ..add('grants', grants))
        .toString();
  }
}

class GrantUpdateBuilder implements Builder<GrantUpdate, GrantUpdateBuilder> {
  _$GrantUpdate? _$v;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  ListBuilder<LibraryGrant>? _grants;
  ListBuilder<LibraryGrant> get grants =>
      _$this._grants ??= ListBuilder<LibraryGrant>();
  set grants(ListBuilder<LibraryGrant>? grants) => _$this._grants = grants;

  GrantUpdateBuilder() {
    GrantUpdate._defaults(this);
  }

  GrantUpdateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _version = $v.version;
      _grants = $v.grants.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GrantUpdate other) {
    _$v = other as _$GrantUpdate;
  }

  @override
  void update(void Function(GrantUpdateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GrantUpdate build() => _build();

  _$GrantUpdate _build() {
    _$GrantUpdate _$result;
    try {
      _$result = _$v ??
          _$GrantUpdate._(
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'GrantUpdate', 'version'),
            grants: grants.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'grants';
        grants.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'GrantUpdate', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

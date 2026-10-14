// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rename_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$RenameRequest extends RenameRequest {
  @override
  final String name;
  @override
  final int version;

  factory _$RenameRequest([void Function(RenameRequestBuilder)? updates]) =>
      (RenameRequestBuilder()..update(updates))._build();

  _$RenameRequest._({required this.name, required this.version}) : super._();
  @override
  RenameRequest rebuild(void Function(RenameRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  RenameRequestBuilder toBuilder() => RenameRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is RenameRequest &&
        name == other.name &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'RenameRequest')
          ..add('name', name)
          ..add('version', version))
        .toString();
  }
}

class RenameRequestBuilder
    implements Builder<RenameRequest, RenameRequestBuilder> {
  _$RenameRequest? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  RenameRequestBuilder() {
    RenameRequest._defaults(this);
  }

  RenameRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(RenameRequest other) {
    _$v = other as _$RenameRequest;
  }

  @override
  void update(void Function(RenameRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  RenameRequest build() => _build();

  _$RenameRequest _build() {
    final _$result = _$v ??
        _$RenameRequest._(
          name: BuiltValueNullFieldError.checkNotNull(
              name, r'RenameRequest', 'name'),
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'RenameRequest', 'version'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

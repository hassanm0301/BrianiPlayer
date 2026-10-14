// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_library_grants200_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$GetLibraryGrants200Response extends GetLibraryGrants200Response {
  @override
  final int version;
  @override
  final BuiltList<LibraryGrant> grants;

  factory _$GetLibraryGrants200Response(
          [void Function(GetLibraryGrants200ResponseBuilder)? updates]) =>
      (GetLibraryGrants200ResponseBuilder()..update(updates))._build();

  _$GetLibraryGrants200Response._({required this.version, required this.grants})
      : super._();
  @override
  GetLibraryGrants200Response rebuild(
          void Function(GetLibraryGrants200ResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  GetLibraryGrants200ResponseBuilder toBuilder() =>
      GetLibraryGrants200ResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is GetLibraryGrants200Response &&
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
    return (newBuiltValueToStringHelper(r'GetLibraryGrants200Response')
          ..add('version', version)
          ..add('grants', grants))
        .toString();
  }
}

class GetLibraryGrants200ResponseBuilder
    implements
        Builder<GetLibraryGrants200Response,
            GetLibraryGrants200ResponseBuilder> {
  _$GetLibraryGrants200Response? _$v;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  ListBuilder<LibraryGrant>? _grants;
  ListBuilder<LibraryGrant> get grants =>
      _$this._grants ??= ListBuilder<LibraryGrant>();
  set grants(ListBuilder<LibraryGrant>? grants) => _$this._grants = grants;

  GetLibraryGrants200ResponseBuilder() {
    GetLibraryGrants200Response._defaults(this);
  }

  GetLibraryGrants200ResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _version = $v.version;
      _grants = $v.grants.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(GetLibraryGrants200Response other) {
    _$v = other as _$GetLibraryGrants200Response;
  }

  @override
  void update(void Function(GetLibraryGrants200ResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  GetLibraryGrants200Response build() => _build();

  _$GetLibraryGrants200Response _build() {
    _$GetLibraryGrants200Response _$result;
    try {
      _$result = _$v ??
          _$GetLibraryGrants200Response._(
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'GetLibraryGrants200Response', 'version'),
            grants: grants.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'grants';
        grants.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'GetLibraryGrants200Response', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

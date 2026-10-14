// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'move_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$MoveRequest extends MoveRequest {
  @override
  final String? targetFolderId;
  @override
  final int version;

  factory _$MoveRequest([void Function(MoveRequestBuilder)? updates]) =>
      (MoveRequestBuilder()..update(updates))._build();

  _$MoveRequest._({this.targetFolderId, required this.version}) : super._();
  @override
  MoveRequest rebuild(void Function(MoveRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MoveRequestBuilder toBuilder() => MoveRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MoveRequest &&
        targetFolderId == other.targetFolderId &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, targetFolderId.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MoveRequest')
          ..add('targetFolderId', targetFolderId)
          ..add('version', version))
        .toString();
  }
}

class MoveRequestBuilder implements Builder<MoveRequest, MoveRequestBuilder> {
  _$MoveRequest? _$v;

  String? _targetFolderId;
  String? get targetFolderId => _$this._targetFolderId;
  set targetFolderId(String? targetFolderId) =>
      _$this._targetFolderId = targetFolderId;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  MoveRequestBuilder() {
    MoveRequest._defaults(this);
  }

  MoveRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _targetFolderId = $v.targetFolderId;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MoveRequest other) {
    _$v = other as _$MoveRequest;
  }

  @override
  void update(void Function(MoveRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MoveRequest build() => _build();

  _$MoveRequest _build() {
    final _$result = _$v ??
        _$MoveRequest._(
          targetFolderId: targetFolderId,
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'MoveRequest', 'version'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_patch.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$IndexerPatch extends IndexerPatch {
  @override
  final bool enabled;

  factory _$IndexerPatch([void Function(IndexerPatchBuilder)? updates]) =>
      (IndexerPatchBuilder()..update(updates))._build();

  _$IndexerPatch._({required this.enabled}) : super._();
  @override
  IndexerPatch rebuild(void Function(IndexerPatchBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IndexerPatchBuilder toBuilder() => IndexerPatchBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IndexerPatch && enabled == other.enabled;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IndexerPatch')
          ..add('enabled', enabled))
        .toString();
  }
}

class IndexerPatchBuilder
    implements Builder<IndexerPatch, IndexerPatchBuilder> {
  _$IndexerPatch? _$v;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  IndexerPatchBuilder() {
    IndexerPatch._defaults(this);
  }

  IndexerPatchBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _enabled = $v.enabled;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IndexerPatch other) {
    _$v = other as _$IndexerPatch;
  }

  @override
  void update(void Function(IndexerPatchBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IndexerPatch build() => _build();

  _$IndexerPatch _build() {
    final _$result = _$v ??
        _$IndexerPatch._(
          enabled: BuiltValueNullFieldError.checkNotNull(
              enabled, r'IndexerPatch', 'enabled'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

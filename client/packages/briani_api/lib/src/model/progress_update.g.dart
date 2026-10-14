// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_update.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ProgressUpdate extends ProgressUpdate {
  @override
  final int positionMs;
  @override
  final int? durationMs;
  @override
  final bool? watched;
  @override
  final int version;

  factory _$ProgressUpdate([void Function(ProgressUpdateBuilder)? updates]) =>
      (ProgressUpdateBuilder()..update(updates))._build();

  _$ProgressUpdate._(
      {required this.positionMs,
      this.durationMs,
      this.watched,
      required this.version})
      : super._();
  @override
  ProgressUpdate rebuild(void Function(ProgressUpdateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ProgressUpdateBuilder toBuilder() => ProgressUpdateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ProgressUpdate &&
        positionMs == other.positionMs &&
        durationMs == other.durationMs &&
        watched == other.watched &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, positionMs.hashCode);
    _$hash = $jc(_$hash, durationMs.hashCode);
    _$hash = $jc(_$hash, watched.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ProgressUpdate')
          ..add('positionMs', positionMs)
          ..add('durationMs', durationMs)
          ..add('watched', watched)
          ..add('version', version))
        .toString();
  }
}

class ProgressUpdateBuilder
    implements Builder<ProgressUpdate, ProgressUpdateBuilder> {
  _$ProgressUpdate? _$v;

  int? _positionMs;
  int? get positionMs => _$this._positionMs;
  set positionMs(int? positionMs) => _$this._positionMs = positionMs;

  int? _durationMs;
  int? get durationMs => _$this._durationMs;
  set durationMs(int? durationMs) => _$this._durationMs = durationMs;

  bool? _watched;
  bool? get watched => _$this._watched;
  set watched(bool? watched) => _$this._watched = watched;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  ProgressUpdateBuilder() {
    ProgressUpdate._defaults(this);
  }

  ProgressUpdateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _positionMs = $v.positionMs;
      _durationMs = $v.durationMs;
      _watched = $v.watched;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ProgressUpdate other) {
    _$v = other as _$ProgressUpdate;
  }

  @override
  void update(void Function(ProgressUpdateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ProgressUpdate build() => _build();

  _$ProgressUpdate _build() {
    final _$result = _$v ??
        _$ProgressUpdate._(
          positionMs: BuiltValueNullFieldError.checkNotNull(
              positionMs, r'ProgressUpdate', 'positionMs'),
          durationMs: durationMs,
          watched: watched,
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'ProgressUpdate', 'version'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

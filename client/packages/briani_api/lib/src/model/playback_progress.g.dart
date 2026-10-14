// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_progress.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlaybackProgress extends PlaybackProgress {
  @override
  final int positionMs;
  @override
  final int? durationMs;
  @override
  final bool watched;
  @override
  final DateTime updatedAt;
  @override
  final int version;

  factory _$PlaybackProgress(
          [void Function(PlaybackProgressBuilder)? updates]) =>
      (PlaybackProgressBuilder()..update(updates))._build();

  _$PlaybackProgress._(
      {required this.positionMs,
      this.durationMs,
      required this.watched,
      required this.updatedAt,
      required this.version})
      : super._();
  @override
  PlaybackProgress rebuild(void Function(PlaybackProgressBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlaybackProgressBuilder toBuilder() =>
      PlaybackProgressBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlaybackProgress &&
        positionMs == other.positionMs &&
        durationMs == other.durationMs &&
        watched == other.watched &&
        updatedAt == other.updatedAt &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, positionMs.hashCode);
    _$hash = $jc(_$hash, durationMs.hashCode);
    _$hash = $jc(_$hash, watched.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlaybackProgress')
          ..add('positionMs', positionMs)
          ..add('durationMs', durationMs)
          ..add('watched', watched)
          ..add('updatedAt', updatedAt)
          ..add('version', version))
        .toString();
  }
}

class PlaybackProgressBuilder
    implements Builder<PlaybackProgress, PlaybackProgressBuilder> {
  _$PlaybackProgress? _$v;

  int? _positionMs;
  int? get positionMs => _$this._positionMs;
  set positionMs(int? positionMs) => _$this._positionMs = positionMs;

  int? _durationMs;
  int? get durationMs => _$this._durationMs;
  set durationMs(int? durationMs) => _$this._durationMs = durationMs;

  bool? _watched;
  bool? get watched => _$this._watched;
  set watched(bool? watched) => _$this._watched = watched;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  PlaybackProgressBuilder() {
    PlaybackProgress._defaults(this);
  }

  PlaybackProgressBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _positionMs = $v.positionMs;
      _durationMs = $v.durationMs;
      _watched = $v.watched;
      _updatedAt = $v.updatedAt;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlaybackProgress other) {
    _$v = other as _$PlaybackProgress;
  }

  @override
  void update(void Function(PlaybackProgressBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlaybackProgress build() => _build();

  _$PlaybackProgress _build() {
    final _$result = _$v ??
        _$PlaybackProgress._(
          positionMs: BuiltValueNullFieldError.checkNotNull(
              positionMs, r'PlaybackProgress', 'positionMs'),
          durationMs: durationMs,
          watched: BuiltValueNullFieldError.checkNotNull(
              watched, r'PlaybackProgress', 'watched'),
          updatedAt: BuiltValueNullFieldError.checkNotNull(
              updatedAt, r'PlaybackProgress', 'updatedAt'),
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'PlaybackProgress', 'version'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

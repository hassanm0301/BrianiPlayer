// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'continue_watching.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ContinueWatching extends ContinueWatching {
  @override
  final Media media;
  @override
  final PlaybackProgress progress;

  factory _$ContinueWatching(
          [void Function(ContinueWatchingBuilder)? updates]) =>
      (ContinueWatchingBuilder()..update(updates))._build();

  _$ContinueWatching._({required this.media, required this.progress})
      : super._();
  @override
  ContinueWatching rebuild(void Function(ContinueWatchingBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ContinueWatchingBuilder toBuilder() =>
      ContinueWatchingBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ContinueWatching &&
        media == other.media &&
        progress == other.progress;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, media.hashCode);
    _$hash = $jc(_$hash, progress.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ContinueWatching')
          ..add('media', media)
          ..add('progress', progress))
        .toString();
  }
}

class ContinueWatchingBuilder
    implements Builder<ContinueWatching, ContinueWatchingBuilder> {
  _$ContinueWatching? _$v;

  MediaBuilder? _media;
  MediaBuilder get media => _$this._media ??= MediaBuilder();
  set media(MediaBuilder? media) => _$this._media = media;

  PlaybackProgressBuilder? _progress;
  PlaybackProgressBuilder get progress =>
      _$this._progress ??= PlaybackProgressBuilder();
  set progress(PlaybackProgressBuilder? progress) =>
      _$this._progress = progress;

  ContinueWatchingBuilder() {
    ContinueWatching._defaults(this);
  }

  ContinueWatchingBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _media = $v.media.toBuilder();
      _progress = $v.progress.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ContinueWatching other) {
    _$v = other as _$ContinueWatching;
  }

  @override
  void update(void Function(ContinueWatchingBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ContinueWatching build() => _build();

  _$ContinueWatching _build() {
    _$ContinueWatching _$result;
    try {
      _$result = _$v ??
          _$ContinueWatching._(
            media: media.build(),
            progress: progress.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'media';
        media.build();
        _$failedField = 'progress';
        progress.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ContinueWatching', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

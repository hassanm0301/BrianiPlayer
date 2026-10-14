// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_sidecar.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PlaybackSidecar extends PlaybackSidecar {
  @override
  final String id;
  @override
  final String name;
  @override
  final String? language;
  @override
  final String mimeType;
  @override
  final String url;

  factory _$PlaybackSidecar([void Function(PlaybackSidecarBuilder)? updates]) =>
      (PlaybackSidecarBuilder()..update(updates))._build();

  _$PlaybackSidecar._(
      {required this.id,
      required this.name,
      this.language,
      required this.mimeType,
      required this.url})
      : super._();
  @override
  PlaybackSidecar rebuild(void Function(PlaybackSidecarBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlaybackSidecarBuilder toBuilder() => PlaybackSidecarBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlaybackSidecar &&
        id == other.id &&
        name == other.name &&
        language == other.language &&
        mimeType == other.mimeType &&
        url == other.url;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, language.hashCode);
    _$hash = $jc(_$hash, mimeType.hashCode);
    _$hash = $jc(_$hash, url.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlaybackSidecar')
          ..add('id', id)
          ..add('name', name)
          ..add('language', language)
          ..add('mimeType', mimeType)
          ..add('url', url))
        .toString();
  }
}

class PlaybackSidecarBuilder
    implements Builder<PlaybackSidecar, PlaybackSidecarBuilder> {
  _$PlaybackSidecar? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _language;
  String? get language => _$this._language;
  set language(String? language) => _$this._language = language;

  String? _mimeType;
  String? get mimeType => _$this._mimeType;
  set mimeType(String? mimeType) => _$this._mimeType = mimeType;

  String? _url;
  String? get url => _$this._url;
  set url(String? url) => _$this._url = url;

  PlaybackSidecarBuilder() {
    PlaybackSidecar._defaults(this);
  }

  PlaybackSidecarBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _language = $v.language;
      _mimeType = $v.mimeType;
      _url = $v.url;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlaybackSidecar other) {
    _$v = other as _$PlaybackSidecar;
  }

  @override
  void update(void Function(PlaybackSidecarBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlaybackSidecar build() => _build();

  _$PlaybackSidecar _build() {
    final _$result = _$v ??
        _$PlaybackSidecar._(
          id: BuiltValueNullFieldError.checkNotNull(
              id, r'PlaybackSidecar', 'id'),
          name: BuiltValueNullFieldError.checkNotNull(
              name, r'PlaybackSidecar', 'name'),
          language: language,
          mimeType: BuiltValueNullFieldError.checkNotNull(
              mimeType, r'PlaybackSidecar', 'mimeType'),
          url: BuiltValueNullFieldError.checkNotNull(
              url, r'PlaybackSidecar', 'url'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

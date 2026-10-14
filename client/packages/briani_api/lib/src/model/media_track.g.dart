// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_track.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const MediaTrackKindEnum _$mediaTrackKindEnum_video =
    const MediaTrackKindEnum._('video');
const MediaTrackKindEnum _$mediaTrackKindEnum_audio =
    const MediaTrackKindEnum._('audio');
const MediaTrackKindEnum _$mediaTrackKindEnum_subtitle =
    const MediaTrackKindEnum._('subtitle');

MediaTrackKindEnum _$mediaTrackKindEnumValueOf(String name) {
  switch (name) {
    case 'video':
      return _$mediaTrackKindEnum_video;
    case 'audio':
      return _$mediaTrackKindEnum_audio;
    case 'subtitle':
      return _$mediaTrackKindEnum_subtitle;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<MediaTrackKindEnum> _$mediaTrackKindEnumValues =
    BuiltSet<MediaTrackKindEnum>(const <MediaTrackKindEnum>[
  _$mediaTrackKindEnum_video,
  _$mediaTrackKindEnum_audio,
  _$mediaTrackKindEnum_subtitle,
]);

Serializer<MediaTrackKindEnum> _$mediaTrackKindEnumSerializer =
    _$MediaTrackKindEnumSerializer();

class _$MediaTrackKindEnumSerializer
    implements PrimitiveSerializer<MediaTrackKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'video': 'video',
    'audio': 'audio',
    'subtitle': 'subtitle',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'video': 'video',
    'audio': 'audio',
    'subtitle': 'subtitle',
  };

  @override
  final Iterable<Type> types = const <Type>[MediaTrackKindEnum];
  @override
  final String wireName = 'MediaTrackKindEnum';

  @override
  Object serialize(Serializers serializers, MediaTrackKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  MediaTrackKindEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      MediaTrackKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$MediaTrack extends MediaTrack {
  @override
  final String id;
  @override
  final MediaTrackKindEnum kind;
  @override
  final String? codec;
  @override
  final String? language;
  @override
  final String? title;
  @override
  final bool? default_;

  factory _$MediaTrack([void Function(MediaTrackBuilder)? updates]) =>
      (MediaTrackBuilder()..update(updates))._build();

  _$MediaTrack._(
      {required this.id,
      required this.kind,
      this.codec,
      this.language,
      this.title,
      this.default_})
      : super._();
  @override
  MediaTrack rebuild(void Function(MediaTrackBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MediaTrackBuilder toBuilder() => MediaTrackBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MediaTrack &&
        id == other.id &&
        kind == other.kind &&
        codec == other.codec &&
        language == other.language &&
        title == other.title &&
        default_ == other.default_;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, codec.hashCode);
    _$hash = $jc(_$hash, language.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, default_.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MediaTrack')
          ..add('id', id)
          ..add('kind', kind)
          ..add('codec', codec)
          ..add('language', language)
          ..add('title', title)
          ..add('default_', default_))
        .toString();
  }
}

class MediaTrackBuilder implements Builder<MediaTrack, MediaTrackBuilder> {
  _$MediaTrack? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  MediaTrackKindEnum? _kind;
  MediaTrackKindEnum? get kind => _$this._kind;
  set kind(MediaTrackKindEnum? kind) => _$this._kind = kind;

  String? _codec;
  String? get codec => _$this._codec;
  set codec(String? codec) => _$this._codec = codec;

  String? _language;
  String? get language => _$this._language;
  set language(String? language) => _$this._language = language;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  bool? _default_;
  bool? get default_ => _$this._default_;
  set default_(bool? default_) => _$this._default_ = default_;

  MediaTrackBuilder() {
    MediaTrack._defaults(this);
  }

  MediaTrackBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _kind = $v.kind;
      _codec = $v.codec;
      _language = $v.language;
      _title = $v.title;
      _default_ = $v.default_;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MediaTrack other) {
    _$v = other as _$MediaTrack;
  }

  @override
  void update(void Function(MediaTrackBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MediaTrack build() => _build();

  _$MediaTrack _build() {
    final _$result = _$v ??
        _$MediaTrack._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'MediaTrack', 'id'),
          kind: BuiltValueNullFieldError.checkNotNull(
              kind, r'MediaTrack', 'kind'),
          codec: codec,
          language: language,
          title: title,
          default_: default_,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

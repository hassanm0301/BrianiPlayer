// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const MediaKindEnum _$mediaKindEnum_video = const MediaKindEnum._('video');
const MediaKindEnum _$mediaKindEnum_photo = const MediaKindEnum._('photo');

MediaKindEnum _$mediaKindEnumValueOf(String name) {
  switch (name) {
    case 'video':
      return _$mediaKindEnum_video;
    case 'photo':
      return _$mediaKindEnum_photo;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<MediaKindEnum> _$mediaKindEnumValues =
    BuiltSet<MediaKindEnum>(const <MediaKindEnum>[
  _$mediaKindEnum_video,
  _$mediaKindEnum_photo,
]);

const MediaProbeStateEnum _$mediaProbeStateEnum_pending =
    const MediaProbeStateEnum._('pending');
const MediaProbeStateEnum _$mediaProbeStateEnum_ready =
    const MediaProbeStateEnum._('ready');
const MediaProbeStateEnum _$mediaProbeStateEnum_unsupported =
    const MediaProbeStateEnum._('unsupported');
const MediaProbeStateEnum _$mediaProbeStateEnum_failed =
    const MediaProbeStateEnum._('failed');

MediaProbeStateEnum _$mediaProbeStateEnumValueOf(String name) {
  switch (name) {
    case 'pending':
      return _$mediaProbeStateEnum_pending;
    case 'ready':
      return _$mediaProbeStateEnum_ready;
    case 'unsupported':
      return _$mediaProbeStateEnum_unsupported;
    case 'failed':
      return _$mediaProbeStateEnum_failed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<MediaProbeStateEnum> _$mediaProbeStateEnumValues =
    BuiltSet<MediaProbeStateEnum>(const <MediaProbeStateEnum>[
  _$mediaProbeStateEnum_pending,
  _$mediaProbeStateEnum_ready,
  _$mediaProbeStateEnum_unsupported,
  _$mediaProbeStateEnum_failed,
]);

Serializer<MediaKindEnum> _$mediaKindEnumSerializer =
    _$MediaKindEnumSerializer();
Serializer<MediaProbeStateEnum> _$mediaProbeStateEnumSerializer =
    _$MediaProbeStateEnumSerializer();

class _$MediaKindEnumSerializer implements PrimitiveSerializer<MediaKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'video': 'video',
    'photo': 'photo',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'video': 'video',
    'photo': 'photo',
  };

  @override
  final Iterable<Type> types = const <Type>[MediaKindEnum];
  @override
  final String wireName = 'MediaKindEnum';

  @override
  Object serialize(Serializers serializers, MediaKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  MediaKindEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      MediaKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$MediaProbeStateEnumSerializer
    implements PrimitiveSerializer<MediaProbeStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'pending': 'pending',
    'ready': 'ready',
    'unsupported': 'unsupported',
    'failed': 'failed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'pending': 'pending',
    'ready': 'ready',
    'unsupported': 'unsupported',
    'failed': 'failed',
  };

  @override
  final Iterable<Type> types = const <Type>[MediaProbeStateEnum];
  @override
  final String wireName = 'MediaProbeStateEnum';

  @override
  Object serialize(Serializers serializers, MediaProbeStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  MediaProbeStateEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      MediaProbeStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Media extends Media {
  @override
  final String id;
  @override
  final String libraryId;
  @override
  final String entryId;
  @override
  final String name;
  @override
  final MediaKindEnum kind;
  @override
  final String mimeType;
  @override
  final int sizeBytes;
  @override
  final int? durationMs;
  @override
  final int? width;
  @override
  final int? height;
  @override
  final BuiltList<MediaTrack>? tracks;
  @override
  final bool complete;
  @override
  final MediaProbeStateEnum probeState;
  @override
  final int version;

  factory _$Media([void Function(MediaBuilder)? updates]) =>
      (MediaBuilder()..update(updates))._build();

  _$Media._(
      {required this.id,
      required this.libraryId,
      required this.entryId,
      required this.name,
      required this.kind,
      required this.mimeType,
      required this.sizeBytes,
      this.durationMs,
      this.width,
      this.height,
      this.tracks,
      required this.complete,
      required this.probeState,
      required this.version})
      : super._();
  @override
  Media rebuild(void Function(MediaBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MediaBuilder toBuilder() => MediaBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Media &&
        id == other.id &&
        libraryId == other.libraryId &&
        entryId == other.entryId &&
        name == other.name &&
        kind == other.kind &&
        mimeType == other.mimeType &&
        sizeBytes == other.sizeBytes &&
        durationMs == other.durationMs &&
        width == other.width &&
        height == other.height &&
        tracks == other.tracks &&
        complete == other.complete &&
        probeState == other.probeState &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, libraryId.hashCode);
    _$hash = $jc(_$hash, entryId.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, mimeType.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jc(_$hash, durationMs.hashCode);
    _$hash = $jc(_$hash, width.hashCode);
    _$hash = $jc(_$hash, height.hashCode);
    _$hash = $jc(_$hash, tracks.hashCode);
    _$hash = $jc(_$hash, complete.hashCode);
    _$hash = $jc(_$hash, probeState.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Media')
          ..add('id', id)
          ..add('libraryId', libraryId)
          ..add('entryId', entryId)
          ..add('name', name)
          ..add('kind', kind)
          ..add('mimeType', mimeType)
          ..add('sizeBytes', sizeBytes)
          ..add('durationMs', durationMs)
          ..add('width', width)
          ..add('height', height)
          ..add('tracks', tracks)
          ..add('complete', complete)
          ..add('probeState', probeState)
          ..add('version', version))
        .toString();
  }
}

class MediaBuilder implements Builder<Media, MediaBuilder> {
  _$Media? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _libraryId;
  String? get libraryId => _$this._libraryId;
  set libraryId(String? libraryId) => _$this._libraryId = libraryId;

  String? _entryId;
  String? get entryId => _$this._entryId;
  set entryId(String? entryId) => _$this._entryId = entryId;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  MediaKindEnum? _kind;
  MediaKindEnum? get kind => _$this._kind;
  set kind(MediaKindEnum? kind) => _$this._kind = kind;

  String? _mimeType;
  String? get mimeType => _$this._mimeType;
  set mimeType(String? mimeType) => _$this._mimeType = mimeType;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  int? _durationMs;
  int? get durationMs => _$this._durationMs;
  set durationMs(int? durationMs) => _$this._durationMs = durationMs;

  int? _width;
  int? get width => _$this._width;
  set width(int? width) => _$this._width = width;

  int? _height;
  int? get height => _$this._height;
  set height(int? height) => _$this._height = height;

  ListBuilder<MediaTrack>? _tracks;
  ListBuilder<MediaTrack> get tracks =>
      _$this._tracks ??= ListBuilder<MediaTrack>();
  set tracks(ListBuilder<MediaTrack>? tracks) => _$this._tracks = tracks;

  bool? _complete;
  bool? get complete => _$this._complete;
  set complete(bool? complete) => _$this._complete = complete;

  MediaProbeStateEnum? _probeState;
  MediaProbeStateEnum? get probeState => _$this._probeState;
  set probeState(MediaProbeStateEnum? probeState) =>
      _$this._probeState = probeState;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  MediaBuilder() {
    Media._defaults(this);
  }

  MediaBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _libraryId = $v.libraryId;
      _entryId = $v.entryId;
      _name = $v.name;
      _kind = $v.kind;
      _mimeType = $v.mimeType;
      _sizeBytes = $v.sizeBytes;
      _durationMs = $v.durationMs;
      _width = $v.width;
      _height = $v.height;
      _tracks = $v.tracks?.toBuilder();
      _complete = $v.complete;
      _probeState = $v.probeState;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Media other) {
    _$v = other as _$Media;
  }

  @override
  void update(void Function(MediaBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Media build() => _build();

  _$Media _build() {
    _$Media _$result;
    try {
      _$result = _$v ??
          _$Media._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'Media', 'id'),
            libraryId: BuiltValueNullFieldError.checkNotNull(
                libraryId, r'Media', 'libraryId'),
            entryId: BuiltValueNullFieldError.checkNotNull(
                entryId, r'Media', 'entryId'),
            name: BuiltValueNullFieldError.checkNotNull(name, r'Media', 'name'),
            kind: BuiltValueNullFieldError.checkNotNull(kind, r'Media', 'kind'),
            mimeType: BuiltValueNullFieldError.checkNotNull(
                mimeType, r'Media', 'mimeType'),
            sizeBytes: BuiltValueNullFieldError.checkNotNull(
                sizeBytes, r'Media', 'sizeBytes'),
            durationMs: durationMs,
            width: width,
            height: height,
            tracks: _tracks?.build(),
            complete: BuiltValueNullFieldError.checkNotNull(
                complete, r'Media', 'complete'),
            probeState: BuiltValueNullFieldError.checkNotNull(
                probeState, r'Media', 'probeState'),
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'Media', 'version'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'tracks';
        _tracks?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'Media', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

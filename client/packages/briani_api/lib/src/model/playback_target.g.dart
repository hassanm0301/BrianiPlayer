// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_target.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const PlaybackTargetKindEnum _$playbackTargetKindEnum_media =
    const PlaybackTargetKindEnum._('media');
const PlaybackTargetKindEnum _$playbackTargetKindEnum_downloadFile =
    const PlaybackTargetKindEnum._('downloadFile');

PlaybackTargetKindEnum _$playbackTargetKindEnumValueOf(String name) {
  switch (name) {
    case 'media':
      return _$playbackTargetKindEnum_media;
    case 'downloadFile':
      return _$playbackTargetKindEnum_downloadFile;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<PlaybackTargetKindEnum> _$playbackTargetKindEnumValues =
    BuiltSet<PlaybackTargetKindEnum>(const <PlaybackTargetKindEnum>[
  _$playbackTargetKindEnum_media,
  _$playbackTargetKindEnum_downloadFile,
]);

Serializer<PlaybackTargetKindEnum> _$playbackTargetKindEnumSerializer =
    _$PlaybackTargetKindEnumSerializer();

class _$PlaybackTargetKindEnumSerializer
    implements PrimitiveSerializer<PlaybackTargetKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'media': 'media',
    'downloadFile': 'downloadFile',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'media': 'media',
    'downloadFile': 'downloadFile',
  };

  @override
  final Iterable<Type> types = const <Type>[PlaybackTargetKindEnum];
  @override
  final String wireName = 'PlaybackTargetKindEnum';

  @override
  Object serialize(Serializers serializers, PlaybackTargetKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  PlaybackTargetKindEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      PlaybackTargetKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$PlaybackTarget extends PlaybackTarget {
  @override
  final PlaybackTargetKindEnum kind;
  @override
  final String id;

  factory _$PlaybackTarget([void Function(PlaybackTargetBuilder)? updates]) =>
      (PlaybackTargetBuilder()..update(updates))._build();

  _$PlaybackTarget._({required this.kind, required this.id}) : super._();
  @override
  PlaybackTarget rebuild(void Function(PlaybackTargetBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlaybackTargetBuilder toBuilder() => PlaybackTargetBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlaybackTarget && kind == other.kind && id == other.id;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlaybackTarget')
          ..add('kind', kind)
          ..add('id', id))
        .toString();
  }
}

class PlaybackTargetBuilder
    implements Builder<PlaybackTarget, PlaybackTargetBuilder> {
  _$PlaybackTarget? _$v;

  PlaybackTargetKindEnum? _kind;
  PlaybackTargetKindEnum? get kind => _$this._kind;
  set kind(PlaybackTargetKindEnum? kind) => _$this._kind = kind;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  PlaybackTargetBuilder() {
    PlaybackTarget._defaults(this);
  }

  PlaybackTargetBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _id = $v.id;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlaybackTarget other) {
    _$v = other as _$PlaybackTarget;
  }

  @override
  void update(void Function(PlaybackTargetBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlaybackTarget build() => _build();

  _$PlaybackTarget _build() {
    final _$result = _$v ??
        _$PlaybackTarget._(
          kind: BuiltValueNullFieldError.checkNotNull(
              kind, r'PlaybackTarget', 'kind'),
          id: BuiltValueNullFieldError.checkNotNull(
              id, r'PlaybackTarget', 'id'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

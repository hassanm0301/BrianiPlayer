// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_session.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const PlaybackSessionStateEnum _$playbackSessionStateEnum_metadataPending =
    const PlaybackSessionStateEnum._('metadataPending');
const PlaybackSessionStateEnum _$playbackSessionStateEnum_waitingForData =
    const PlaybackSessionStateEnum._('waitingForData');
const PlaybackSessionStateEnum _$playbackSessionStateEnum_ready =
    const PlaybackSessionStateEnum._('ready');
const PlaybackSessionStateEnum _$playbackSessionStateEnum_buffering =
    const PlaybackSessionStateEnum._('buffering');
const PlaybackSessionStateEnum _$playbackSessionStateEnum_complete =
    const PlaybackSessionStateEnum._('complete');
const PlaybackSessionStateEnum _$playbackSessionStateEnum_expired =
    const PlaybackSessionStateEnum._('expired');
const PlaybackSessionStateEnum _$playbackSessionStateEnum_revoked =
    const PlaybackSessionStateEnum._('revoked');
const PlaybackSessionStateEnum _$playbackSessionStateEnum_unavailable =
    const PlaybackSessionStateEnum._('unavailable');

PlaybackSessionStateEnum _$playbackSessionStateEnumValueOf(String name) {
  switch (name) {
    case 'metadataPending':
      return _$playbackSessionStateEnum_metadataPending;
    case 'waitingForData':
      return _$playbackSessionStateEnum_waitingForData;
    case 'ready':
      return _$playbackSessionStateEnum_ready;
    case 'buffering':
      return _$playbackSessionStateEnum_buffering;
    case 'complete':
      return _$playbackSessionStateEnum_complete;
    case 'expired':
      return _$playbackSessionStateEnum_expired;
    case 'revoked':
      return _$playbackSessionStateEnum_revoked;
    case 'unavailable':
      return _$playbackSessionStateEnum_unavailable;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<PlaybackSessionStateEnum> _$playbackSessionStateEnumValues =
    BuiltSet<PlaybackSessionStateEnum>(const <PlaybackSessionStateEnum>[
  _$playbackSessionStateEnum_metadataPending,
  _$playbackSessionStateEnum_waitingForData,
  _$playbackSessionStateEnum_ready,
  _$playbackSessionStateEnum_buffering,
  _$playbackSessionStateEnum_complete,
  _$playbackSessionStateEnum_expired,
  _$playbackSessionStateEnum_revoked,
  _$playbackSessionStateEnum_unavailable,
]);

Serializer<PlaybackSessionStateEnum> _$playbackSessionStateEnumSerializer =
    _$PlaybackSessionStateEnumSerializer();

class _$PlaybackSessionStateEnumSerializer
    implements PrimitiveSerializer<PlaybackSessionStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'metadataPending': 'metadataPending',
    'waitingForData': 'waitingForData',
    'ready': 'ready',
    'buffering': 'buffering',
    'complete': 'complete',
    'expired': 'expired',
    'revoked': 'revoked',
    'unavailable': 'unavailable',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'metadataPending': 'metadataPending',
    'waitingForData': 'waitingForData',
    'ready': 'ready',
    'buffering': 'buffering',
    'complete': 'complete',
    'expired': 'expired',
    'revoked': 'revoked',
    'unavailable': 'unavailable',
  };

  @override
  final Iterable<Type> types = const <Type>[PlaybackSessionStateEnum];
  @override
  final String wireName = 'PlaybackSessionStateEnum';

  @override
  Object serialize(Serializers serializers, PlaybackSessionStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  PlaybackSessionStateEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      PlaybackSessionStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$PlaybackSession extends PlaybackSession {
  @override
  final String id;
  @override
  final PlaybackSessionStateEnum state;
  @override
  final String? streamUrl;
  @override
  final DateTime activationExpiresAt;
  @override
  final DateTime? idleExpiresAt;
  @override
  final DateTime absoluteExpiresAt;
  @override
  final String generation;
  @override
  final int contiguousBytes;
  @override
  final int? totalBytes;
  @override
  final String? mimeType;
  @override
  final String? fileName;
  @override
  final BuiltList<PlaybackSidecar> sidecars;
  @override
  final int? retryAfterSeconds;
  @override
  final String? importedMediaId;

  factory _$PlaybackSession([void Function(PlaybackSessionBuilder)? updates]) =>
      (PlaybackSessionBuilder()..update(updates))._build();

  _$PlaybackSession._(
      {required this.id,
      required this.state,
      this.streamUrl,
      required this.activationExpiresAt,
      this.idleExpiresAt,
      required this.absoluteExpiresAt,
      required this.generation,
      required this.contiguousBytes,
      this.totalBytes,
      this.mimeType,
      this.fileName,
      required this.sidecars,
      this.retryAfterSeconds,
      this.importedMediaId})
      : super._();
  @override
  PlaybackSession rebuild(void Function(PlaybackSessionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlaybackSessionBuilder toBuilder() => PlaybackSessionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlaybackSession &&
        id == other.id &&
        state == other.state &&
        streamUrl == other.streamUrl &&
        activationExpiresAt == other.activationExpiresAt &&
        idleExpiresAt == other.idleExpiresAt &&
        absoluteExpiresAt == other.absoluteExpiresAt &&
        generation == other.generation &&
        contiguousBytes == other.contiguousBytes &&
        totalBytes == other.totalBytes &&
        mimeType == other.mimeType &&
        fileName == other.fileName &&
        sidecars == other.sidecars &&
        retryAfterSeconds == other.retryAfterSeconds &&
        importedMediaId == other.importedMediaId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, streamUrl.hashCode);
    _$hash = $jc(_$hash, activationExpiresAt.hashCode);
    _$hash = $jc(_$hash, idleExpiresAt.hashCode);
    _$hash = $jc(_$hash, absoluteExpiresAt.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, contiguousBytes.hashCode);
    _$hash = $jc(_$hash, totalBytes.hashCode);
    _$hash = $jc(_$hash, mimeType.hashCode);
    _$hash = $jc(_$hash, fileName.hashCode);
    _$hash = $jc(_$hash, sidecars.hashCode);
    _$hash = $jc(_$hash, retryAfterSeconds.hashCode);
    _$hash = $jc(_$hash, importedMediaId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlaybackSession')
          ..add('id', id)
          ..add('state', state)
          ..add('streamUrl', streamUrl)
          ..add('activationExpiresAt', activationExpiresAt)
          ..add('idleExpiresAt', idleExpiresAt)
          ..add('absoluteExpiresAt', absoluteExpiresAt)
          ..add('generation', generation)
          ..add('contiguousBytes', contiguousBytes)
          ..add('totalBytes', totalBytes)
          ..add('mimeType', mimeType)
          ..add('fileName', fileName)
          ..add('sidecars', sidecars)
          ..add('retryAfterSeconds', retryAfterSeconds)
          ..add('importedMediaId', importedMediaId))
        .toString();
  }
}

class PlaybackSessionBuilder
    implements Builder<PlaybackSession, PlaybackSessionBuilder> {
  _$PlaybackSession? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  PlaybackSessionStateEnum? _state;
  PlaybackSessionStateEnum? get state => _$this._state;
  set state(PlaybackSessionStateEnum? state) => _$this._state = state;

  String? _streamUrl;
  String? get streamUrl => _$this._streamUrl;
  set streamUrl(String? streamUrl) => _$this._streamUrl = streamUrl;

  DateTime? _activationExpiresAt;
  DateTime? get activationExpiresAt => _$this._activationExpiresAt;
  set activationExpiresAt(DateTime? activationExpiresAt) =>
      _$this._activationExpiresAt = activationExpiresAt;

  DateTime? _idleExpiresAt;
  DateTime? get idleExpiresAt => _$this._idleExpiresAt;
  set idleExpiresAt(DateTime? idleExpiresAt) =>
      _$this._idleExpiresAt = idleExpiresAt;

  DateTime? _absoluteExpiresAt;
  DateTime? get absoluteExpiresAt => _$this._absoluteExpiresAt;
  set absoluteExpiresAt(DateTime? absoluteExpiresAt) =>
      _$this._absoluteExpiresAt = absoluteExpiresAt;

  String? _generation;
  String? get generation => _$this._generation;
  set generation(String? generation) => _$this._generation = generation;

  int? _contiguousBytes;
  int? get contiguousBytes => _$this._contiguousBytes;
  set contiguousBytes(int? contiguousBytes) =>
      _$this._contiguousBytes = contiguousBytes;

  int? _totalBytes;
  int? get totalBytes => _$this._totalBytes;
  set totalBytes(int? totalBytes) => _$this._totalBytes = totalBytes;

  String? _mimeType;
  String? get mimeType => _$this._mimeType;
  set mimeType(String? mimeType) => _$this._mimeType = mimeType;

  String? _fileName;
  String? get fileName => _$this._fileName;
  set fileName(String? fileName) => _$this._fileName = fileName;

  ListBuilder<PlaybackSidecar>? _sidecars;
  ListBuilder<PlaybackSidecar> get sidecars =>
      _$this._sidecars ??= ListBuilder<PlaybackSidecar>();
  set sidecars(ListBuilder<PlaybackSidecar>? sidecars) =>
      _$this._sidecars = sidecars;

  int? _retryAfterSeconds;
  int? get retryAfterSeconds => _$this._retryAfterSeconds;
  set retryAfterSeconds(int? retryAfterSeconds) =>
      _$this._retryAfterSeconds = retryAfterSeconds;

  String? _importedMediaId;
  String? get importedMediaId => _$this._importedMediaId;
  set importedMediaId(String? importedMediaId) =>
      _$this._importedMediaId = importedMediaId;

  PlaybackSessionBuilder() {
    PlaybackSession._defaults(this);
  }

  PlaybackSessionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _state = $v.state;
      _streamUrl = $v.streamUrl;
      _activationExpiresAt = $v.activationExpiresAt;
      _idleExpiresAt = $v.idleExpiresAt;
      _absoluteExpiresAt = $v.absoluteExpiresAt;
      _generation = $v.generation;
      _contiguousBytes = $v.contiguousBytes;
      _totalBytes = $v.totalBytes;
      _mimeType = $v.mimeType;
      _fileName = $v.fileName;
      _sidecars = $v.sidecars.toBuilder();
      _retryAfterSeconds = $v.retryAfterSeconds;
      _importedMediaId = $v.importedMediaId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlaybackSession other) {
    _$v = other as _$PlaybackSession;
  }

  @override
  void update(void Function(PlaybackSessionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlaybackSession build() => _build();

  _$PlaybackSession _build() {
    _$PlaybackSession _$result;
    try {
      _$result = _$v ??
          _$PlaybackSession._(
            id: BuiltValueNullFieldError.checkNotNull(
                id, r'PlaybackSession', 'id'),
            state: BuiltValueNullFieldError.checkNotNull(
                state, r'PlaybackSession', 'state'),
            streamUrl: streamUrl,
            activationExpiresAt: BuiltValueNullFieldError.checkNotNull(
                activationExpiresAt, r'PlaybackSession', 'activationExpiresAt'),
            idleExpiresAt: idleExpiresAt,
            absoluteExpiresAt: BuiltValueNullFieldError.checkNotNull(
                absoluteExpiresAt, r'PlaybackSession', 'absoluteExpiresAt'),
            generation: BuiltValueNullFieldError.checkNotNull(
                generation, r'PlaybackSession', 'generation'),
            contiguousBytes: BuiltValueNullFieldError.checkNotNull(
                contiguousBytes, r'PlaybackSession', 'contiguousBytes'),
            totalBytes: totalBytes,
            mimeType: mimeType,
            fileName: fileName,
            sidecars: sidecars.build(),
            retryAfterSeconds: retryAfterSeconds,
            importedMediaId: importedMediaId,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'sidecars';
        sidecars.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'PlaybackSession', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

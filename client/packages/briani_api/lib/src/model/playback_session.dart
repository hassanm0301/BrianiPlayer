// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:briani_api/src/model/playback_sidecar.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'playback_session.g.dart';

/// PlaybackSession
///
/// Properties:
/// * [id] 
/// * [state] 
/// * [streamUrl] 
/// * [activationExpiresAt] 
/// * [idleExpiresAt] 
/// * [absoluteExpiresAt] 
/// * [generation] 
/// * [contiguousBytes] 
/// * [totalBytes] 
/// * [mimeType] 
/// * [fileName] 
/// * [sidecars] 
/// * [retryAfterSeconds] 
/// * [importedMediaId] - Authorized media identity when a download file has been imported; supports saving current playback progress.
@BuiltValue()
abstract class PlaybackSession implements Built<PlaybackSession, PlaybackSessionBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'state')
  PlaybackSessionStateEnum get state;
  // enum stateEnum {  metadataPending,  waitingForData,  ready,  buffering,  complete,  expired,  revoked,  unavailable,  };

  @BuiltValueField(wireName: r'streamUrl')
  String? get streamUrl;

  @BuiltValueField(wireName: r'activationExpiresAt')
  DateTime get activationExpiresAt;

  @BuiltValueField(wireName: r'idleExpiresAt')
  DateTime? get idleExpiresAt;

  @BuiltValueField(wireName: r'absoluteExpiresAt')
  DateTime get absoluteExpiresAt;

  @BuiltValueField(wireName: r'generation')
  String get generation;

  @BuiltValueField(wireName: r'contiguousBytes')
  int get contiguousBytes;

  @BuiltValueField(wireName: r'totalBytes')
  int? get totalBytes;

  @BuiltValueField(wireName: r'mimeType')
  String? get mimeType;

  @BuiltValueField(wireName: r'fileName')
  String? get fileName;

  @BuiltValueField(wireName: r'sidecars')
  BuiltList<PlaybackSidecar> get sidecars;

  @BuiltValueField(wireName: r'retryAfterSeconds')
  int? get retryAfterSeconds;

  /// Authorized media identity when a download file has been imported; supports saving current playback progress.
  @BuiltValueField(wireName: r'importedMediaId')
  String? get importedMediaId;

  PlaybackSession._();

  factory PlaybackSession([void updates(PlaybackSessionBuilder b)]) = _$PlaybackSession;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PlaybackSessionBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PlaybackSession> get serializer => _$PlaybackSessionSerializer();
}

class _$PlaybackSessionSerializer implements PrimitiveSerializer<PlaybackSession> {
  @override
  final Iterable<Type> types = const [PlaybackSession, _$PlaybackSession];

  @override
  final String wireName = r'PlaybackSession';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PlaybackSession object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'state';
    yield serializers.serialize(
      object.state,
      specifiedType: const FullType(PlaybackSessionStateEnum),
    );
    yield r'streamUrl';
    yield object.streamUrl == null ? null : serializers.serialize(
      object.streamUrl,
      specifiedType: const FullType.nullable(String),
    );
    yield r'activationExpiresAt';
    yield serializers.serialize(
      object.activationExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'idleExpiresAt';
    yield object.idleExpiresAt == null ? null : serializers.serialize(
      object.idleExpiresAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    yield r'absoluteExpiresAt';
    yield serializers.serialize(
      object.absoluteExpiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'generation';
    yield serializers.serialize(
      object.generation,
      specifiedType: const FullType(String),
    );
    yield r'contiguousBytes';
    yield serializers.serialize(
      object.contiguousBytes,
      specifiedType: const FullType(int),
    );
    yield r'totalBytes';
    yield object.totalBytes == null ? null : serializers.serialize(
      object.totalBytes,
      specifiedType: const FullType.nullable(int),
    );
    if (object.mimeType != null) {
      yield r'mimeType';
      yield serializers.serialize(
        object.mimeType,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.fileName != null) {
      yield r'fileName';
      yield serializers.serialize(
        object.fileName,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'sidecars';
    yield serializers.serialize(
      object.sidecars,
      specifiedType: const FullType(BuiltList, [FullType(PlaybackSidecar)]),
    );
    if (object.retryAfterSeconds != null) {
      yield r'retryAfterSeconds';
      yield serializers.serialize(
        object.retryAfterSeconds,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.importedMediaId != null) {
      yield r'importedMediaId';
      yield serializers.serialize(
        object.importedMediaId,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    PlaybackSession object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PlaybackSessionBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'state':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(PlaybackSessionStateEnum),
          ) as PlaybackSessionStateEnum;
          result.state = valueDes;
          break;
        case r'streamUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.streamUrl = valueDes;
          break;
        case r'activationExpiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.activationExpiresAt = valueDes;
          break;
        case r'idleExpiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.idleExpiresAt = valueDes;
          break;
        case r'absoluteExpiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.absoluteExpiresAt = valueDes;
          break;
        case r'generation':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.generation = valueDes;
          break;
        case r'contiguousBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.contiguousBytes = valueDes;
          break;
        case r'totalBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.totalBytes = valueDes;
          break;
        case r'mimeType':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.mimeType = valueDes;
          break;
        case r'fileName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.fileName = valueDes;
          break;
        case r'sidecars':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(PlaybackSidecar)]),
          ) as BuiltList<PlaybackSidecar>;
          result.sidecars.replace(valueDes);
          break;
        case r'retryAfterSeconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.retryAfterSeconds = valueDes;
          break;
        case r'importedMediaId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.importedMediaId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PlaybackSession deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PlaybackSessionBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


class PlaybackSessionStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'metadataPending')
  static const PlaybackSessionStateEnum metadataPending = _$playbackSessionStateEnum_metadataPending;
  @BuiltValueEnumConst(wireName: r'waitingForData')
  static const PlaybackSessionStateEnum waitingForData = _$playbackSessionStateEnum_waitingForData;
  @BuiltValueEnumConst(wireName: r'ready')
  static const PlaybackSessionStateEnum ready = _$playbackSessionStateEnum_ready;
  @BuiltValueEnumConst(wireName: r'buffering')
  static const PlaybackSessionStateEnum buffering = _$playbackSessionStateEnum_buffering;
  @BuiltValueEnumConst(wireName: r'complete')
  static const PlaybackSessionStateEnum complete = _$playbackSessionStateEnum_complete;
  @BuiltValueEnumConst(wireName: r'expired')
  static const PlaybackSessionStateEnum expired = _$playbackSessionStateEnum_expired;
  @BuiltValueEnumConst(wireName: r'revoked')
  static const PlaybackSessionStateEnum revoked = _$playbackSessionStateEnum_revoked;
  @BuiltValueEnumConst(wireName: r'unavailable')
  static const PlaybackSessionStateEnum unavailable = _$playbackSessionStateEnum_unavailable;

  static Serializer<PlaybackSessionStateEnum> get serializer => _$playbackSessionStateEnumSerializer;

  const PlaybackSessionStateEnum._(String name): super(name);

  static BuiltSet<PlaybackSessionStateEnum> get values => _$playbackSessionStateEnumValues;
  static PlaybackSessionStateEnum valueOf(String name) => _$playbackSessionStateEnumValueOf(name);
}


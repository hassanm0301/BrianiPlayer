// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:briani_api/src/model/playback_target.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'playback_create.g.dart';

/// PlaybackCreate
///
/// Properties:
/// * [target] 
/// * [mode] 
/// * [initialPositionMs] 
@BuiltValue()
abstract class PlaybackCreate implements Built<PlaybackCreate, PlaybackCreateBuilder> {
  @BuiltValueField(wireName: r'target')
  PlaybackTarget get target;

  @BuiltValueField(wireName: r'mode')
  PlaybackCreateModeEnum get mode;
  // enum modeEnum {  internal,  external,  };

  @BuiltValueField(wireName: r'initialPositionMs')
  int? get initialPositionMs;

  PlaybackCreate._();

  factory PlaybackCreate([void updates(PlaybackCreateBuilder b)]) = _$PlaybackCreate;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PlaybackCreateBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PlaybackCreate> get serializer => _$PlaybackCreateSerializer();
}

class _$PlaybackCreateSerializer implements PrimitiveSerializer<PlaybackCreate> {
  @override
  final Iterable<Type> types = const [PlaybackCreate, _$PlaybackCreate];

  @override
  final String wireName = r'PlaybackCreate';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PlaybackCreate object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'target';
    yield serializers.serialize(
      object.target,
      specifiedType: const FullType(PlaybackTarget),
    );
    yield r'mode';
    yield serializers.serialize(
      object.mode,
      specifiedType: const FullType(PlaybackCreateModeEnum),
    );
    if (object.initialPositionMs != null) {
      yield r'initialPositionMs';
      yield serializers.serialize(
        object.initialPositionMs,
        specifiedType: const FullType(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    PlaybackCreate object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PlaybackCreateBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'target':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(PlaybackTarget),
          ) as PlaybackTarget;
          result.target.replace(valueDes);
          break;
        case r'mode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(PlaybackCreateModeEnum),
          ) as PlaybackCreateModeEnum;
          result.mode = valueDes;
          break;
        case r'initialPositionMs':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.initialPositionMs = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  PlaybackCreate deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PlaybackCreateBuilder();
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


class PlaybackCreateModeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'internal')
  static const PlaybackCreateModeEnum internal = _$playbackCreateModeEnum_internal;
  @BuiltValueEnumConst(wireName: r'external')
  static const PlaybackCreateModeEnum external_ = _$playbackCreateModeEnum_external_;

  static Serializer<PlaybackCreateModeEnum> get serializer => _$playbackCreateModeEnumSerializer;

  const PlaybackCreateModeEnum._(String name): super(name);

  static BuiltSet<PlaybackCreateModeEnum> get values => _$playbackCreateModeEnumValues;
  static PlaybackCreateModeEnum valueOf(String name) => _$playbackCreateModeEnumValueOf(name);
}


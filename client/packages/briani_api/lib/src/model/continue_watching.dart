// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:briani_api/src/model/playback_progress.dart';
import 'package:briani_api/src/model/media.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'continue_watching.g.dart';

/// ContinueWatching
///
/// Properties:
/// * [media] 
/// * [progress] 
@BuiltValue()
abstract class ContinueWatching implements Built<ContinueWatching, ContinueWatchingBuilder> {
  @BuiltValueField(wireName: r'media')
  Media get media;

  @BuiltValueField(wireName: r'progress')
  PlaybackProgress get progress;

  ContinueWatching._();

  factory ContinueWatching([void updates(ContinueWatchingBuilder b)]) = _$ContinueWatching;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContinueWatchingBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContinueWatching> get serializer => _$ContinueWatchingSerializer();
}

class _$ContinueWatchingSerializer implements PrimitiveSerializer<ContinueWatching> {
  @override
  final Iterable<Type> types = const [ContinueWatching, _$ContinueWatching];

  @override
  final String wireName = r'ContinueWatching';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContinueWatching object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'media';
    yield serializers.serialize(
      object.media,
      specifiedType: const FullType(Media),
    );
    yield r'progress';
    yield serializers.serialize(
      object.progress,
      specifiedType: const FullType(PlaybackProgress),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ContinueWatching object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContinueWatchingBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'media':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(Media),
          ) as Media;
          result.media.replace(valueDes);
          break;
        case r'progress':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(PlaybackProgress),
          ) as PlaybackProgress;
          result.progress.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContinueWatching deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContinueWatchingBuilder();
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



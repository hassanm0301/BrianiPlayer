// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'progress_update.g.dart';

/// ProgressUpdate
///
/// Properties:
/// * [positionMs] 
/// * [durationMs] 
/// * [watched] 
/// * [version] 
@BuiltValue()
abstract class ProgressUpdate implements Built<ProgressUpdate, ProgressUpdateBuilder> {
  @BuiltValueField(wireName: r'positionMs')
  int get positionMs;

  @BuiltValueField(wireName: r'durationMs')
  int? get durationMs;

  @BuiltValueField(wireName: r'watched')
  bool? get watched;

  @BuiltValueField(wireName: r'version')
  int get version;

  ProgressUpdate._();

  factory ProgressUpdate([void updates(ProgressUpdateBuilder b)]) = _$ProgressUpdate;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ProgressUpdateBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ProgressUpdate> get serializer => _$ProgressUpdateSerializer();
}

class _$ProgressUpdateSerializer implements PrimitiveSerializer<ProgressUpdate> {
  @override
  final Iterable<Type> types = const [ProgressUpdate, _$ProgressUpdate];

  @override
  final String wireName = r'ProgressUpdate';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ProgressUpdate object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'positionMs';
    yield serializers.serialize(
      object.positionMs,
      specifiedType: const FullType(int),
    );
    yield r'durationMs';
    yield object.durationMs == null ? null : serializers.serialize(
      object.durationMs,
      specifiedType: const FullType.nullable(int),
    );
    if (object.watched != null) {
      yield r'watched';
      yield serializers.serialize(
        object.watched,
        specifiedType: const FullType(bool),
      );
    }
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ProgressUpdate object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ProgressUpdateBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'positionMs':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.positionMs = valueDes;
          break;
        case r'durationMs':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.durationMs = valueDes;
          break;
        case r'watched':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.watched = valueDes;
          break;
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.version = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ProgressUpdate deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ProgressUpdateBuilder();
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



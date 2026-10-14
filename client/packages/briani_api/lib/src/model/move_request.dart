// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'move_request.g.dart';

/// MoveRequest
///
/// Properties:
/// * [targetFolderId] 
/// * [version] 
@BuiltValue()
abstract class MoveRequest implements Built<MoveRequest, MoveRequestBuilder> {
  @BuiltValueField(wireName: r'targetFolderId')
  String? get targetFolderId;

  @BuiltValueField(wireName: r'version')
  int get version;

  MoveRequest._();

  factory MoveRequest([void updates(MoveRequestBuilder b)]) = _$MoveRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MoveRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MoveRequest> get serializer => _$MoveRequestSerializer();
}

class _$MoveRequestSerializer implements PrimitiveSerializer<MoveRequest> {
  @override
  final Iterable<Type> types = const [MoveRequest, _$MoveRequest];

  @override
  final String wireName = r'MoveRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MoveRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'targetFolderId';
    yield object.targetFolderId == null ? null : serializers.serialize(
      object.targetFolderId,
      specifiedType: const FullType.nullable(String),
    );
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    MoveRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MoveRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'targetFolderId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.targetFolderId = valueDes;
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
  MoveRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MoveRequestBuilder();
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



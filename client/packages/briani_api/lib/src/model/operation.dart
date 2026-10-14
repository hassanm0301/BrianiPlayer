// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:briani_api/src/model/problem.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'operation.g.dart';

/// Operation
///
/// Properties:
/// * [id] 
/// * [state] 
/// * [resourceId] 
/// * [resourceType] 
/// * [error] 
/// * [createdAt] 
/// * [updatedAt] 
@BuiltValue()
abstract class Operation implements Built<Operation, OperationBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'state')
  OperationStateEnum get state;
  // enum stateEnum {  pending,  running,  completed,  failed,  };

  @BuiltValueField(wireName: r'resourceId')
  String? get resourceId;

  @BuiltValueField(wireName: r'resourceType')
  String? get resourceType;

  @BuiltValueField(wireName: r'error')
  Problem? get error;

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  Operation._();

  factory Operation([void updates(OperationBuilder b)]) = _$Operation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(OperationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Operation> get serializer => _$OperationSerializer();
}

class _$OperationSerializer implements PrimitiveSerializer<Operation> {
  @override
  final Iterable<Type> types = const [Operation, _$Operation];

  @override
  final String wireName = r'Operation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Operation object, {
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
      specifiedType: const FullType(OperationStateEnum),
    );
    yield r'resourceId';
    yield object.resourceId == null ? null : serializers.serialize(
      object.resourceId,
      specifiedType: const FullType.nullable(String),
    );
    yield r'resourceType';
    yield object.resourceType == null ? null : serializers.serialize(
      object.resourceType,
      specifiedType: const FullType.nullable(String),
    );
    if (object.error != null) {
      yield r'error';
      yield serializers.serialize(
        object.error,
        specifiedType: const FullType(Problem),
      );
    }
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'updatedAt';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    Operation object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required OperationBuilder result,
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
            specifiedType: const FullType(OperationStateEnum),
          ) as OperationStateEnum;
          result.state = valueDes;
          break;
        case r'resourceId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.resourceId = valueDes;
          break;
        case r'resourceType':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.resourceType = valueDes;
          break;
        case r'error':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(Problem),
          ) as Problem?;
          if (valueDes == null) continue;
          result.error.replace(valueDes);
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
          break;
        case r'updatedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.updatedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Operation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = OperationBuilder();
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


class OperationStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'pending')
  static const OperationStateEnum pending = _$operationStateEnum_pending;
  @BuiltValueEnumConst(wireName: r'running')
  static const OperationStateEnum running = _$operationStateEnum_running;
  @BuiltValueEnumConst(wireName: r'completed')
  static const OperationStateEnum completed = _$operationStateEnum_completed;
  @BuiltValueEnumConst(wireName: r'failed')
  static const OperationStateEnum failed = _$operationStateEnum_failed;

  static Serializer<OperationStateEnum> get serializer => _$operationStateEnumSerializer;

  const OperationStateEnum._(String name): super(name);

  static BuiltSet<OperationStateEnum> get values => _$operationStateEnumValues;
  static OperationStateEnum valueOf(String name) => _$operationStateEnumValueOf(name);
}


// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'indexer_test_result.g.dart';

/// IndexerTestResult
///
/// Properties:
/// * [id] 
/// * [state] 
/// * [detail] 
/// * [checkedAt] 
@BuiltValue()
abstract class IndexerTestResult implements Built<IndexerTestResult, IndexerTestResultBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'state')
  IndexerTestResultStateEnum get state;
  // enum stateEnum {  healthy,  unavailable,  unknown,  };

  @BuiltValueField(wireName: r'detail')
  String get detail;

  @BuiltValueField(wireName: r'checkedAt')
  DateTime get checkedAt;

  IndexerTestResult._();

  factory IndexerTestResult([void updates(IndexerTestResultBuilder b)]) = _$IndexerTestResult;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(IndexerTestResultBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<IndexerTestResult> get serializer => _$IndexerTestResultSerializer();
}

class _$IndexerTestResultSerializer implements PrimitiveSerializer<IndexerTestResult> {
  @override
  final Iterable<Type> types = const [IndexerTestResult, _$IndexerTestResult];

  @override
  final String wireName = r'IndexerTestResult';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    IndexerTestResult object, {
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
      specifiedType: const FullType(IndexerTestResultStateEnum),
    );
    yield r'detail';
    yield serializers.serialize(
      object.detail,
      specifiedType: const FullType(String),
    );
    yield r'checkedAt';
    yield serializers.serialize(
      object.checkedAt,
      specifiedType: const FullType(DateTime),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    IndexerTestResult object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required IndexerTestResultBuilder result,
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
            specifiedType: const FullType(IndexerTestResultStateEnum),
          ) as IndexerTestResultStateEnum;
          result.state = valueDes;
          break;
        case r'detail':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.detail = valueDes;
          break;
        case r'checkedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.checkedAt = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  IndexerTestResult deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IndexerTestResultBuilder();
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


class IndexerTestResultStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'healthy')
  static const IndexerTestResultStateEnum healthy = _$indexerTestResultStateEnum_healthy;
  @BuiltValueEnumConst(wireName: r'unavailable')
  static const IndexerTestResultStateEnum unavailable = _$indexerTestResultStateEnum_unavailable;
  @BuiltValueEnumConst(wireName: r'unknown')
  static const IndexerTestResultStateEnum unknown = _$indexerTestResultStateEnum_unknown;

  static Serializer<IndexerTestResultStateEnum> get serializer => _$indexerTestResultStateEnumSerializer;

  const IndexerTestResultStateEnum._(String name): super(name);

  static BuiltSet<IndexerTestResultStateEnum> get values => _$indexerTestResultStateEnumValues;
  static IndexerTestResultStateEnum valueOf(String name) => _$indexerTestResultStateEnumValueOf(name);
}


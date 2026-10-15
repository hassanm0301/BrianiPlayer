// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:briani_api/src/model/discovery_result.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'discovery_snapshot.g.dart';

/// DiscoverySnapshot
///
/// Properties:
/// * [id] 
/// * [state] 
/// * [createdAt] 
/// * [expiresAt] 
/// * [items] 
/// * [nextCursor] 
/// * [totalKnown] 
/// * [truncated] 
/// * [warnings] - Human-readable warnings written by the server for display as-is.
@BuiltValue()
abstract class DiscoverySnapshot implements Built<DiscoverySnapshot, DiscoverySnapshotBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'state')
  DiscoverySnapshotStateEnum get state;
  // enum stateEnum {  queued,  running,  complete,  partial,  failed,  };

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'expiresAt')
  DateTime get expiresAt;

  @BuiltValueField(wireName: r'items')
  BuiltList<DiscoveryResult> get items;

  @BuiltValueField(wireName: r'nextCursor')
  String? get nextCursor;

  @BuiltValueField(wireName: r'totalKnown')
  int? get totalKnown;

  @BuiltValueField(wireName: r'truncated')
  bool get truncated;

  /// Human-readable warnings written by the server for display as-is.
  @BuiltValueField(wireName: r'warnings')
  BuiltList<String> get warnings;

  DiscoverySnapshot._();

  factory DiscoverySnapshot([void updates(DiscoverySnapshotBuilder b)]) = _$DiscoverySnapshot;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DiscoverySnapshotBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DiscoverySnapshot> get serializer => _$DiscoverySnapshotSerializer();
}

class _$DiscoverySnapshotSerializer implements PrimitiveSerializer<DiscoverySnapshot> {
  @override
  final Iterable<Type> types = const [DiscoverySnapshot, _$DiscoverySnapshot];

  @override
  final String wireName = r'DiscoverySnapshot';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DiscoverySnapshot object, {
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
      specifiedType: const FullType(DiscoverySnapshotStateEnum),
    );
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'expiresAt';
    yield serializers.serialize(
      object.expiresAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(DiscoveryResult)]),
    );
    yield r'nextCursor';
    yield object.nextCursor == null ? null : serializers.serialize(
      object.nextCursor,
      specifiedType: const FullType.nullable(String),
    );
    yield r'totalKnown';
    yield object.totalKnown == null ? null : serializers.serialize(
      object.totalKnown,
      specifiedType: const FullType.nullable(int),
    );
    yield r'truncated';
    yield serializers.serialize(
      object.truncated,
      specifiedType: const FullType(bool),
    );
    yield r'warnings';
    yield serializers.serialize(
      object.warnings,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DiscoverySnapshot object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DiscoverySnapshotBuilder result,
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
            specifiedType: const FullType(DiscoverySnapshotStateEnum),
          ) as DiscoverySnapshotStateEnum;
          result.state = valueDes;
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
          break;
        case r'expiresAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.expiresAt = valueDes;
          break;
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(DiscoveryResult)]),
          ) as BuiltList<DiscoveryResult>;
          result.items.replace(valueDes);
          break;
        case r'nextCursor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.nextCursor = valueDes;
          break;
        case r'totalKnown':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.totalKnown = valueDes;
          break;
        case r'truncated':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.truncated = valueDes;
          break;
        case r'warnings':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.warnings.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DiscoverySnapshot deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DiscoverySnapshotBuilder();
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


class DiscoverySnapshotStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'queued')
  static const DiscoverySnapshotStateEnum queued = _$discoverySnapshotStateEnum_queued;
  @BuiltValueEnumConst(wireName: r'running')
  static const DiscoverySnapshotStateEnum running = _$discoverySnapshotStateEnum_running;
  @BuiltValueEnumConst(wireName: r'complete')
  static const DiscoverySnapshotStateEnum complete = _$discoverySnapshotStateEnum_complete;
  @BuiltValueEnumConst(wireName: r'partial')
  static const DiscoverySnapshotStateEnum partial = _$discoverySnapshotStateEnum_partial;
  @BuiltValueEnumConst(wireName: r'failed')
  static const DiscoverySnapshotStateEnum failed = _$discoverySnapshotStateEnum_failed;

  static Serializer<DiscoverySnapshotStateEnum> get serializer => _$discoverySnapshotStateEnumSerializer;

  const DiscoverySnapshotStateEnum._(String name): super(name);

  static BuiltSet<DiscoverySnapshotStateEnum> get values => _$discoverySnapshotStateEnumValues;
  static DiscoverySnapshotStateEnum valueOf(String name) => _$discoverySnapshotStateEnumValueOf(name);
}


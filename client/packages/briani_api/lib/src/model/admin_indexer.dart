// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'admin_indexer.g.dart';

/// Summary of a configured torrent indexer. It never contains setting values or credentials.
///
/// Properties:
/// * [id] 
/// * [name] 
/// * [definition] 
/// * [enabled] 
/// * [privacy] 
/// * [priority] 
/// * [supportsSearch] 
/// * [supportsRecent] 
/// * [state] 
/// * [stateDetail] 
@BuiltValue()
abstract class AdminIndexer implements Built<AdminIndexer, AdminIndexerBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'definition')
  String get definition;

  @BuiltValueField(wireName: r'enabled')
  bool get enabled;

  @BuiltValueField(wireName: r'privacy')
  AdminIndexerPrivacyEnum get privacy;
  // enum privacyEnum {  public,  semiPrivate,  private,  unknown,  };

  @BuiltValueField(wireName: r'priority')
  int get priority;

  @BuiltValueField(wireName: r'supportsSearch')
  bool get supportsSearch;

  @BuiltValueField(wireName: r'supportsRecent')
  bool get supportsRecent;

  @BuiltValueField(wireName: r'state')
  AdminIndexerStateEnum get state;
  // enum stateEnum {  healthy,  degraded,  unavailable,  unknown,  };

  @BuiltValueField(wireName: r'stateDetail')
  String? get stateDetail;

  AdminIndexer._();

  factory AdminIndexer([void updates(AdminIndexerBuilder b)]) = _$AdminIndexer;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(AdminIndexerBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<AdminIndexer> get serializer => _$AdminIndexerSerializer();
}

class _$AdminIndexerSerializer implements PrimitiveSerializer<AdminIndexer> {
  @override
  final Iterable<Type> types = const [AdminIndexer, _$AdminIndexer];

  @override
  final String wireName = r'AdminIndexer';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    AdminIndexer object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'definition';
    yield serializers.serialize(
      object.definition,
      specifiedType: const FullType(String),
    );
    yield r'enabled';
    yield serializers.serialize(
      object.enabled,
      specifiedType: const FullType(bool),
    );
    yield r'privacy';
    yield serializers.serialize(
      object.privacy,
      specifiedType: const FullType(AdminIndexerPrivacyEnum),
    );
    yield r'priority';
    yield serializers.serialize(
      object.priority,
      specifiedType: const FullType(int),
    );
    yield r'supportsSearch';
    yield serializers.serialize(
      object.supportsSearch,
      specifiedType: const FullType(bool),
    );
    yield r'supportsRecent';
    yield serializers.serialize(
      object.supportsRecent,
      specifiedType: const FullType(bool),
    );
    yield r'state';
    yield serializers.serialize(
      object.state,
      specifiedType: const FullType(AdminIndexerStateEnum),
    );
    if (object.stateDetail != null) {
      yield r'stateDetail';
      yield serializers.serialize(
        object.stateDetail,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    AdminIndexer object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required AdminIndexerBuilder result,
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
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'definition':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.definition = valueDes;
          break;
        case r'enabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.enabled = valueDes;
          break;
        case r'privacy':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminIndexerPrivacyEnum),
          ) as AdminIndexerPrivacyEnum;
          result.privacy = valueDes;
          break;
        case r'priority':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.priority = valueDes;
          break;
        case r'supportsSearch':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.supportsSearch = valueDes;
          break;
        case r'supportsRecent':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.supportsRecent = valueDes;
          break;
        case r'state':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(AdminIndexerStateEnum),
          ) as AdminIndexerStateEnum;
          result.state = valueDes;
          break;
        case r'stateDetail':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.stateDetail = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  AdminIndexer deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = AdminIndexerBuilder();
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


class AdminIndexerPrivacyEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'public')
  static const AdminIndexerPrivacyEnum public = _$adminIndexerPrivacyEnum_public;
  @BuiltValueEnumConst(wireName: r'semiPrivate')
  static const AdminIndexerPrivacyEnum semiPrivate = _$adminIndexerPrivacyEnum_semiPrivate;
  @BuiltValueEnumConst(wireName: r'private')
  static const AdminIndexerPrivacyEnum private = _$adminIndexerPrivacyEnum_private;
  @BuiltValueEnumConst(wireName: r'unknown')
  static const AdminIndexerPrivacyEnum unknown = _$adminIndexerPrivacyEnum_unknown;

  static Serializer<AdminIndexerPrivacyEnum> get serializer => _$adminIndexerPrivacyEnumSerializer;

  const AdminIndexerPrivacyEnum._(String name): super(name);

  static BuiltSet<AdminIndexerPrivacyEnum> get values => _$adminIndexerPrivacyEnumValues;
  static AdminIndexerPrivacyEnum valueOf(String name) => _$adminIndexerPrivacyEnumValueOf(name);
}

class AdminIndexerStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'healthy')
  static const AdminIndexerStateEnum healthy = _$adminIndexerStateEnum_healthy;
  @BuiltValueEnumConst(wireName: r'degraded')
  static const AdminIndexerStateEnum degraded = _$adminIndexerStateEnum_degraded;
  @BuiltValueEnumConst(wireName: r'unavailable')
  static const AdminIndexerStateEnum unavailable = _$adminIndexerStateEnum_unavailable;
  @BuiltValueEnumConst(wireName: r'unknown')
  static const AdminIndexerStateEnum unknown = _$adminIndexerStateEnum_unknown;

  static Serializer<AdminIndexerStateEnum> get serializer => _$adminIndexerStateEnumSerializer;

  const AdminIndexerStateEnum._(String name): super(name);

  static BuiltSet<AdminIndexerStateEnum> get values => _$adminIndexerStateEnumValues;
  static AdminIndexerStateEnum valueOf(String name) => _$adminIndexerStateEnumValueOf(name);
}


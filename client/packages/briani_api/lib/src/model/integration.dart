// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:briani_api/src/model/service_health.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'integration.g.dart';

/// Integration
///
/// Properties:
/// * [kind] 
/// * [baseUrl] 
/// * [credentialConfigured] 
/// * [health] 
/// * [version] 
@BuiltValue()
abstract class Integration implements Built<Integration, IntegrationBuilder> {
  @BuiltValueField(wireName: r'kind')
  IntegrationKindEnum get kind;
  // enum kindEnum {  prowlarr,  qbittorrent,  };

  @BuiltValueField(wireName: r'baseUrl')
  String get baseUrl;

  @BuiltValueField(wireName: r'credentialConfigured')
  bool get credentialConfigured;

  @BuiltValueField(wireName: r'health')
  ServiceHealth get health;

  @BuiltValueField(wireName: r'version')
  int get version;

  Integration._();

  factory Integration([void updates(IntegrationBuilder b)]) = _$Integration;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(IntegrationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Integration> get serializer => _$IntegrationSerializer();
}

class _$IntegrationSerializer implements PrimitiveSerializer<Integration> {
  @override
  final Iterable<Type> types = const [Integration, _$Integration];

  @override
  final String wireName = r'Integration';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Integration object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(IntegrationKindEnum),
    );
    yield r'baseUrl';
    yield serializers.serialize(
      object.baseUrl,
      specifiedType: const FullType(String),
    );
    yield r'credentialConfigured';
    yield serializers.serialize(
      object.credentialConfigured,
      specifiedType: const FullType(bool),
    );
    yield r'health';
    yield serializers.serialize(
      object.health,
      specifiedType: const FullType(ServiceHealth),
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
    Integration object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required IntegrationBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(IntegrationKindEnum),
          ) as IntegrationKindEnum;
          result.kind = valueDes;
          break;
        case r'baseUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.baseUrl = valueDes;
          break;
        case r'credentialConfigured':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.credentialConfigured = valueDes;
          break;
        case r'health':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(ServiceHealth),
          ) as ServiceHealth;
          result.health.replace(valueDes);
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
  Integration deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IntegrationBuilder();
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


class IntegrationKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'prowlarr')
  static const IntegrationKindEnum prowlarr = _$integrationKindEnum_prowlarr;
  @BuiltValueEnumConst(wireName: r'qbittorrent')
  static const IntegrationKindEnum qbittorrent = _$integrationKindEnum_qbittorrent;

  static Serializer<IntegrationKindEnum> get serializer => _$integrationKindEnumSerializer;

  const IntegrationKindEnum._(String name): super(name);

  static BuiltSet<IntegrationKindEnum> get values => _$integrationKindEnumValues;
  static IntegrationKindEnum valueOf(String name) => _$integrationKindEnumValueOf(name);
}


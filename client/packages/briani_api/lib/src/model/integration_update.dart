// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'integration_update.g.dart';

/// Missing/null secret preserves existing credential. Store through protected server secret facilities; do not echo it. URL is validated against administrator deployment policy.
///
/// Properties:
/// * [baseUrl] 
/// * [username] 
/// * [secret] 
/// * [version] 
@BuiltValue()
abstract class IntegrationUpdate implements Built<IntegrationUpdate, IntegrationUpdateBuilder> {
  @BuiltValueField(wireName: r'baseUrl')
  String get baseUrl;

  @BuiltValueField(wireName: r'username')
  String? get username;

  @BuiltValueField(wireName: r'secret')
  String? get secret;

  @BuiltValueField(wireName: r'version')
  int get version;

  IntegrationUpdate._();

  factory IntegrationUpdate([void updates(IntegrationUpdateBuilder b)]) = _$IntegrationUpdate;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(IntegrationUpdateBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<IntegrationUpdate> get serializer => _$IntegrationUpdateSerializer();
}

class _$IntegrationUpdateSerializer implements PrimitiveSerializer<IntegrationUpdate> {
  @override
  final Iterable<Type> types = const [IntegrationUpdate, _$IntegrationUpdate];

  @override
  final String wireName = r'IntegrationUpdate';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    IntegrationUpdate object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'baseUrl';
    yield serializers.serialize(
      object.baseUrl,
      specifiedType: const FullType(String),
    );
    if (object.username != null) {
      yield r'username';
      yield serializers.serialize(
        object.username,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.secret != null) {
      yield r'secret';
      yield serializers.serialize(
        object.secret,
        specifiedType: const FullType.nullable(String),
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
    IntegrationUpdate object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required IntegrationUpdateBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'baseUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.baseUrl = valueDes;
          break;
        case r'username':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.username = valueDes;
          break;
        case r'secret':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.secret = valueDes;
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
  IntegrationUpdate deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IntegrationUpdateBuilder();
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



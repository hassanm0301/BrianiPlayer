// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'server_info.g.dart';

/// ServerInfo
///
/// Properties:
/// * [name] 
/// * [version] 
/// * [apiMajor] 
/// * [bootstrapRequired] 
/// * [capabilities] 
/// * [minimumClientVersion] 
/// * [publicBaseUrl] - Administrator-configured public playback origin. API credentials remain scoped to the selected server address.
@BuiltValue()
abstract class ServerInfo implements Built<ServerInfo, ServerInfoBuilder> {
  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'version')
  String get version;

  @BuiltValueField(wireName: r'apiMajor')
  int get apiMajor;

  @BuiltValueField(wireName: r'bootstrapRequired')
  bool get bootstrapRequired;

  @BuiltValueField(wireName: r'capabilities')
  BuiltList<String> get capabilities;

  @BuiltValueField(wireName: r'minimumClientVersion')
  String? get minimumClientVersion;

  /// Administrator-configured public playback origin. API credentials remain scoped to the selected server address.
  @BuiltValueField(wireName: r'publicBaseUrl')
  String? get publicBaseUrl;

  ServerInfo._();

  factory ServerInfo([void updates(ServerInfoBuilder b)]) = _$ServerInfo;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ServerInfoBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ServerInfo> get serializer => _$ServerInfoSerializer();
}

class _$ServerInfoSerializer implements PrimitiveSerializer<ServerInfo> {
  @override
  final Iterable<Type> types = const [ServerInfo, _$ServerInfo];

  @override
  final String wireName = r'ServerInfo';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ServerInfo object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(String),
    );
    yield r'apiMajor';
    yield serializers.serialize(
      object.apiMajor,
      specifiedType: const FullType(int),
    );
    yield r'bootstrapRequired';
    yield serializers.serialize(
      object.bootstrapRequired,
      specifiedType: const FullType(bool),
    );
    yield r'capabilities';
    yield serializers.serialize(
      object.capabilities,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
    if (object.minimumClientVersion != null) {
      yield r'minimumClientVersion';
      yield serializers.serialize(
        object.minimumClientVersion,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.publicBaseUrl != null) {
      yield r'publicBaseUrl';
      yield serializers.serialize(
        object.publicBaseUrl,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    ServerInfo object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ServerInfoBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.version = valueDes;
          break;
        case r'apiMajor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.apiMajor = valueDes;
          break;
        case r'bootstrapRequired':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.bootstrapRequired = valueDes;
          break;
        case r'capabilities':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.capabilities.replace(valueDes);
          break;
        case r'minimumClientVersion':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.minimumClientVersion = valueDes;
          break;
        case r'publicBaseUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.publicBaseUrl = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ServerInfo deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ServerInfoBuilder();
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



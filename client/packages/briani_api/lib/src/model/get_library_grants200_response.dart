// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:briani_api/src/model/library_grant.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'get_library_grants200_response.g.dart';

/// GetLibraryGrants200Response
///
/// Properties:
/// * [version] 
/// * [grants] 
@BuiltValue()
abstract class GetLibraryGrants200Response implements Built<GetLibraryGrants200Response, GetLibraryGrants200ResponseBuilder> {
  @BuiltValueField(wireName: r'version')
  int get version;

  @BuiltValueField(wireName: r'grants')
  BuiltList<LibraryGrant> get grants;

  GetLibraryGrants200Response._();

  factory GetLibraryGrants200Response([void updates(GetLibraryGrants200ResponseBuilder b)]) = _$GetLibraryGrants200Response;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GetLibraryGrants200ResponseBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GetLibraryGrants200Response> get serializer => _$GetLibraryGrants200ResponseSerializer();
}

class _$GetLibraryGrants200ResponseSerializer implements PrimitiveSerializer<GetLibraryGrants200Response> {
  @override
  final Iterable<Type> types = const [GetLibraryGrants200Response, _$GetLibraryGrants200Response];

  @override
  final String wireName = r'GetLibraryGrants200Response';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GetLibraryGrants200Response object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
    yield r'grants';
    yield serializers.serialize(
      object.grants,
      specifiedType: const FullType(BuiltList, [FullType(LibraryGrant)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    GetLibraryGrants200Response object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GetLibraryGrants200ResponseBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.version = valueDes;
          break;
        case r'grants':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(LibraryGrant)]),
          ) as BuiltList<LibraryGrant>;
          result.grants.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  GetLibraryGrants200Response deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GetLibraryGrants200ResponseBuilder();
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



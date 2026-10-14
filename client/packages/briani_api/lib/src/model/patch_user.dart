// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'patch_user.g.dart';

/// PatchUser
///
/// Properties:
/// * [displayName] 
/// * [role] 
/// * [enabled] 
/// * [version] 
@BuiltValue()
abstract class PatchUser implements Built<PatchUser, PatchUserBuilder> {
  @BuiltValueField(wireName: r'displayName')
  String? get displayName;

  @BuiltValueField(wireName: r'role')
  PatchUserRoleEnum? get role;
  // enum roleEnum {  administrator,  member,  };

  @BuiltValueField(wireName: r'enabled')
  bool? get enabled;

  @BuiltValueField(wireName: r'version')
  int get version;

  PatchUser._();

  factory PatchUser([void updates(PatchUserBuilder b)]) = _$PatchUser;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(PatchUserBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<PatchUser> get serializer => _$PatchUserSerializer();
}

class _$PatchUserSerializer implements PrimitiveSerializer<PatchUser> {
  @override
  final Iterable<Type> types = const [PatchUser, _$PatchUser];

  @override
  final String wireName = r'PatchUser';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    PatchUser object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    if (object.displayName != null) {
      yield r'displayName';
      yield serializers.serialize(
        object.displayName,
        specifiedType: const FullType(String),
      );
    }
    if (object.role != null) {
      yield r'role';
      yield serializers.serialize(
        object.role,
        specifiedType: const FullType(PatchUserRoleEnum),
      );
    }
    if (object.enabled != null) {
      yield r'enabled';
      yield serializers.serialize(
        object.enabled,
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
    PatchUser object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required PatchUserBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.displayName = valueDes;
          break;
        case r'role':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(PatchUserRoleEnum),
          ) as PatchUserRoleEnum?;
          if (valueDes == null) continue;
          result.role = valueDes;
          break;
        case r'enabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.enabled = valueDes;
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
  PatchUser deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = PatchUserBuilder();
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


class PatchUserRoleEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'administrator')
  static const PatchUserRoleEnum administrator = _$patchUserRoleEnum_administrator;
  @BuiltValueEnumConst(wireName: r'member')
  static const PatchUserRoleEnum member = _$patchUserRoleEnum_member;

  static Serializer<PatchUserRoleEnum> get serializer => _$patchUserRoleEnumSerializer;

  const PatchUserRoleEnum._(String name): super(name);

  static BuiltSet<PatchUserRoleEnum> get values => _$patchUserRoleEnumValues;
  static PatchUserRoleEnum valueOf(String name) => _$patchUserRoleEnumValueOf(name);
}


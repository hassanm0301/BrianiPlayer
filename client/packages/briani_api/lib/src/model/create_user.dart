// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'create_user.g.dart';

/// CreateUser
///
/// Properties:
/// * [username] 
/// * [displayName] 
/// * [password] - Any value is accepted; there are no length or content rules.
/// * [confirmPassword] - Must equal password; the server rejects a mismatch with code password_mismatch.
/// * [role] 
@BuiltValue()
abstract class CreateUser implements Built<CreateUser, CreateUserBuilder> {
  @BuiltValueField(wireName: r'username')
  String get username;

  @BuiltValueField(wireName: r'displayName')
  String get displayName;

  /// Any value is accepted; there are no length or content rules.
  @BuiltValueField(wireName: r'password')
  String get password;

  /// Must equal password; the server rejects a mismatch with code password_mismatch.
  @BuiltValueField(wireName: r'confirmPassword')
  String get confirmPassword;

  @BuiltValueField(wireName: r'role')
  CreateUserRoleEnum get role;
  // enum roleEnum {  administrator,  member,  };

  CreateUser._();

  factory CreateUser([void updates(CreateUserBuilder b)]) = _$CreateUser;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(CreateUserBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<CreateUser> get serializer => _$CreateUserSerializer();
}

class _$CreateUserSerializer implements PrimitiveSerializer<CreateUser> {
  @override
  final Iterable<Type> types = const [CreateUser, _$CreateUser];

  @override
  final String wireName = r'CreateUser';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    CreateUser object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'username';
    yield serializers.serialize(
      object.username,
      specifiedType: const FullType(String),
    );
    yield r'displayName';
    yield serializers.serialize(
      object.displayName,
      specifiedType: const FullType(String),
    );
    yield r'password';
    yield serializers.serialize(
      object.password,
      specifiedType: const FullType(String),
    );
    yield r'confirmPassword';
    yield serializers.serialize(
      object.confirmPassword,
      specifiedType: const FullType(String),
    );
    yield r'role';
    yield serializers.serialize(
      object.role,
      specifiedType: const FullType(CreateUserRoleEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    CreateUser object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required CreateUserBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'username':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.username = valueDes;
          break;
        case r'displayName':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.displayName = valueDes;
          break;
        case r'password':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.password = valueDes;
          break;
        case r'confirmPassword':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.confirmPassword = valueDes;
          break;
        case r'role':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(CreateUserRoleEnum),
          ) as CreateUserRoleEnum;
          result.role = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  CreateUser deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = CreateUserBuilder();
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


class CreateUserRoleEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'administrator')
  static const CreateUserRoleEnum administrator = _$createUserRoleEnum_administrator;
  @BuiltValueEnumConst(wireName: r'member')
  static const CreateUserRoleEnum member = _$createUserRoleEnum_member;

  static Serializer<CreateUserRoleEnum> get serializer => _$createUserRoleEnumSerializer;

  const CreateUserRoleEnum._(String name): super(name);

  static BuiltSet<CreateUserRoleEnum> get values => _$createUserRoleEnumValues;
  static CreateUserRoleEnum valueOf(String name) => _$createUserRoleEnumValueOf(name);
}


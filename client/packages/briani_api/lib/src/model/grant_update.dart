// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:briani_api/src/model/library_grant.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'grant_update.g.dart';

/// GrantUpdate
///
/// Properties:
/// * [version] 
/// * [grants] 
@BuiltValue()
abstract class GrantUpdate implements Built<GrantUpdate, GrantUpdateBuilder> {
  @BuiltValueField(wireName: r'version')
  int get version;

  @BuiltValueField(wireName: r'grants')
  BuiltList<LibraryGrant> get grants;

  GrantUpdate._();

  factory GrantUpdate([void updates(GrantUpdateBuilder b)]) = _$GrantUpdate;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(GrantUpdateBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<GrantUpdate> get serializer => _$GrantUpdateSerializer();
}

class _$GrantUpdateSerializer implements PrimitiveSerializer<GrantUpdate> {
  @override
  final Iterable<Type> types = const [GrantUpdate, _$GrantUpdate];

  @override
  final String wireName = r'GrantUpdate';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    GrantUpdate object, {
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
    GrantUpdate object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required GrantUpdateBuilder result,
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
  GrantUpdate deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = GrantUpdateBuilder();
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



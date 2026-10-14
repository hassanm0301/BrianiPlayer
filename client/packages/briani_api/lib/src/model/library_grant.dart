// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'library_grant.g.dart';

/// LibraryGrant
///
/// Properties:
/// * [userId] 
/// * [read] 
/// * [download] 
/// * [manage] 
/// * [quotaBytes] 
@BuiltValue()
abstract class LibraryGrant implements Built<LibraryGrant, LibraryGrantBuilder> {
  @BuiltValueField(wireName: r'userId')
  String get userId;

  @BuiltValueField(wireName: r'read')
  bool get read;

  @BuiltValueField(wireName: r'download')
  bool get download;

  @BuiltValueField(wireName: r'manage')
  bool get manage;

  @BuiltValueField(wireName: r'quotaBytes')
  int? get quotaBytes;

  LibraryGrant._();

  factory LibraryGrant([void updates(LibraryGrantBuilder b)]) = _$LibraryGrant;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LibraryGrantBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<LibraryGrant> get serializer => _$LibraryGrantSerializer();
}

class _$LibraryGrantSerializer implements PrimitiveSerializer<LibraryGrant> {
  @override
  final Iterable<Type> types = const [LibraryGrant, _$LibraryGrant];

  @override
  final String wireName = r'LibraryGrant';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LibraryGrant object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'userId';
    yield serializers.serialize(
      object.userId,
      specifiedType: const FullType(String),
    );
    yield r'read';
    yield serializers.serialize(
      object.read,
      specifiedType: const FullType(bool),
    );
    yield r'download';
    yield serializers.serialize(
      object.download,
      specifiedType: const FullType(bool),
    );
    yield r'manage';
    yield serializers.serialize(
      object.manage,
      specifiedType: const FullType(bool),
    );
    if (object.quotaBytes != null) {
      yield r'quotaBytes';
      yield serializers.serialize(
        object.quotaBytes,
        specifiedType: const FullType.nullable(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    LibraryGrant object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LibraryGrantBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'userId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.userId = valueDes;
          break;
        case r'read':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.read = valueDes;
          break;
        case r'download':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.download = valueDes;
          break;
        case r'manage':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.manage = valueDes;
          break;
        case r'quotaBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.quotaBytes = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  LibraryGrant deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LibraryGrantBuilder();
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



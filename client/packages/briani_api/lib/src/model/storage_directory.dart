// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'storage_directory.g.dart';

/// StorageDirectory
///
/// Properties:
/// * [relativePath] 
/// * [name] 
/// * [writable] 
/// * [alreadyAssigned] 
@BuiltValue()
abstract class StorageDirectory implements Built<StorageDirectory, StorageDirectoryBuilder> {
  @BuiltValueField(wireName: r'relativePath')
  String get relativePath;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'writable')
  bool get writable;

  @BuiltValueField(wireName: r'alreadyAssigned')
  bool get alreadyAssigned;

  StorageDirectory._();

  factory StorageDirectory([void updates(StorageDirectoryBuilder b)]) = _$StorageDirectory;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(StorageDirectoryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<StorageDirectory> get serializer => _$StorageDirectorySerializer();
}

class _$StorageDirectorySerializer implements PrimitiveSerializer<StorageDirectory> {
  @override
  final Iterable<Type> types = const [StorageDirectory, _$StorageDirectory];

  @override
  final String wireName = r'StorageDirectory';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    StorageDirectory object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'relativePath';
    yield serializers.serialize(
      object.relativePath,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'writable';
    yield serializers.serialize(
      object.writable,
      specifiedType: const FullType(bool),
    );
    yield r'alreadyAssigned';
    yield serializers.serialize(
      object.alreadyAssigned,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    StorageDirectory object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required StorageDirectoryBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'relativePath':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.relativePath = valueDes;
          break;
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'writable':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.writable = valueDes;
          break;
        case r'alreadyAssigned':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.alreadyAssigned = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  StorageDirectory deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = StorageDirectoryBuilder();
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



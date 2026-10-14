// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'storage_root.g.dart';

/// StorageRoot
///
/// Properties:
/// * [id] 
/// * [label] 
/// * [path] 
/// * [writable] 
/// * [freeBytes] 
/// * [totalBytes] 
/// * [reservedBytes] 
/// * [available] 
/// * [supportsHardLinks] 
@BuiltValue()
abstract class StorageRoot implements Built<StorageRoot, StorageRootBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'label')
  String get label;

  @BuiltValueField(wireName: r'path')
  String get path;

  @BuiltValueField(wireName: r'writable')
  bool get writable;

  @BuiltValueField(wireName: r'freeBytes')
  int? get freeBytes;

  @BuiltValueField(wireName: r'totalBytes')
  int? get totalBytes;

  @BuiltValueField(wireName: r'reservedBytes')
  int get reservedBytes;

  @BuiltValueField(wireName: r'available')
  bool get available;

  @BuiltValueField(wireName: r'supportsHardLinks')
  bool? get supportsHardLinks;

  StorageRoot._();

  factory StorageRoot([void updates(StorageRootBuilder b)]) = _$StorageRoot;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(StorageRootBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<StorageRoot> get serializer => _$StorageRootSerializer();
}

class _$StorageRootSerializer implements PrimitiveSerializer<StorageRoot> {
  @override
  final Iterable<Type> types = const [StorageRoot, _$StorageRoot];

  @override
  final String wireName = r'StorageRoot';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    StorageRoot object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'label';
    yield serializers.serialize(
      object.label,
      specifiedType: const FullType(String),
    );
    yield r'path';
    yield serializers.serialize(
      object.path,
      specifiedType: const FullType(String),
    );
    yield r'writable';
    yield serializers.serialize(
      object.writable,
      specifiedType: const FullType(bool),
    );
    yield r'freeBytes';
    yield object.freeBytes == null ? null : serializers.serialize(
      object.freeBytes,
      specifiedType: const FullType.nullable(int),
    );
    yield r'totalBytes';
    yield object.totalBytes == null ? null : serializers.serialize(
      object.totalBytes,
      specifiedType: const FullType.nullable(int),
    );
    yield r'reservedBytes';
    yield serializers.serialize(
      object.reservedBytes,
      specifiedType: const FullType(int),
    );
    yield r'available';
    yield serializers.serialize(
      object.available,
      specifiedType: const FullType(bool),
    );
    if (object.supportsHardLinks != null) {
      yield r'supportsHardLinks';
      yield serializers.serialize(
        object.supportsHardLinks,
        specifiedType: const FullType.nullable(bool),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    StorageRoot object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required StorageRootBuilder result,
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
        case r'label':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.label = valueDes;
          break;
        case r'path':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.path = valueDes;
          break;
        case r'writable':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.writable = valueDes;
          break;
        case r'freeBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.freeBytes = valueDes;
          break;
        case r'totalBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.totalBytes = valueDes;
          break;
        case r'reservedBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.reservedBytes = valueDes;
          break;
        case r'available':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.available = valueDes;
          break;
        case r'supportsHardLinks':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.supportsHardLinks = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  StorageRoot deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = StorageRootBuilder();
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



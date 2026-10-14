// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'library_create.g.dart';

/// LibraryCreate
///
/// Properties:
/// * [name] 
/// * [description] 
/// * [storageRootId] 
/// * [relativePath] 
/// * [readOnly] 
@BuiltValue()
abstract class LibraryCreate implements Built<LibraryCreate, LibraryCreateBuilder> {
  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'description')
  String? get description;

  @BuiltValueField(wireName: r'storageRootId')
  String get storageRootId;

  @BuiltValueField(wireName: r'relativePath')
  String get relativePath;

  @BuiltValueField(wireName: r'readOnly')
  bool get readOnly;

  LibraryCreate._();

  factory LibraryCreate([void updates(LibraryCreateBuilder b)]) = _$LibraryCreate;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LibraryCreateBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<LibraryCreate> get serializer => _$LibraryCreateSerializer();
}

class _$LibraryCreateSerializer implements PrimitiveSerializer<LibraryCreate> {
  @override
  final Iterable<Type> types = const [LibraryCreate, _$LibraryCreate];

  @override
  final String wireName = r'LibraryCreate';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LibraryCreate object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    if (object.description != null) {
      yield r'description';
      yield serializers.serialize(
        object.description,
        specifiedType: const FullType(String),
      );
    }
    yield r'storageRootId';
    yield serializers.serialize(
      object.storageRootId,
      specifiedType: const FullType(String),
    );
    yield r'relativePath';
    yield serializers.serialize(
      object.relativePath,
      specifiedType: const FullType(String),
    );
    yield r'readOnly';
    yield serializers.serialize(
      object.readOnly,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    LibraryCreate object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LibraryCreateBuilder result,
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
        case r'description':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.description = valueDes;
          break;
        case r'storageRootId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.storageRootId = valueDes;
          break;
        case r'relativePath':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.relativePath = valueDes;
          break;
        case r'readOnly':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.readOnly = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  LibraryCreate deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LibraryCreateBuilder();
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



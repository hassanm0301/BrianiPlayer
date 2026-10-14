// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'library_capabilities.g.dart';

/// LibraryCapabilities
///
/// Properties:
/// * [read] 
/// * [download] 
/// * [manage] 
@BuiltValue()
abstract class LibraryCapabilities implements Built<LibraryCapabilities, LibraryCapabilitiesBuilder> {
  @BuiltValueField(wireName: r'read')
  bool get read;

  @BuiltValueField(wireName: r'download')
  bool get download;

  @BuiltValueField(wireName: r'manage')
  bool get manage;

  LibraryCapabilities._();

  factory LibraryCapabilities([void updates(LibraryCapabilitiesBuilder b)]) = _$LibraryCapabilities;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(LibraryCapabilitiesBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<LibraryCapabilities> get serializer => _$LibraryCapabilitiesSerializer();
}

class _$LibraryCapabilitiesSerializer implements PrimitiveSerializer<LibraryCapabilities> {
  @override
  final Iterable<Type> types = const [LibraryCapabilities, _$LibraryCapabilities];

  @override
  final String wireName = r'LibraryCapabilities';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    LibraryCapabilities object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
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
  }

  @override
  Object serialize(
    Serializers serializers,
    LibraryCapabilities object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required LibraryCapabilitiesBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  LibraryCapabilities deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = LibraryCapabilitiesBuilder();
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



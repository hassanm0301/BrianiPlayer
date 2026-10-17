// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'indexer_patch.g.dart';

/// IndexerPatch
///
/// Properties:
/// * [enabled] 
@BuiltValue()
abstract class IndexerPatch implements Built<IndexerPatch, IndexerPatchBuilder> {
  @BuiltValueField(wireName: r'enabled')
  bool get enabled;

  IndexerPatch._();

  factory IndexerPatch([void updates(IndexerPatchBuilder b)]) = _$IndexerPatch;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(IndexerPatchBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<IndexerPatch> get serializer => _$IndexerPatchSerializer();
}

class _$IndexerPatchSerializer implements PrimitiveSerializer<IndexerPatch> {
  @override
  final Iterable<Type> types = const [IndexerPatch, _$IndexerPatch];

  @override
  final String wireName = r'IndexerPatch';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    IndexerPatch object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'enabled';
    yield serializers.serialize(
      object.enabled,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    IndexerPatch object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required IndexerPatchBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'enabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.enabled = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  IndexerPatch deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IndexerPatchBuilder();
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



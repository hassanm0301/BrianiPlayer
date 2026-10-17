// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'indexer_setting_option.g.dart';

/// IndexerSettingOption
///
/// Properties:
/// * [value] 
/// * [label] 
@BuiltValue()
abstract class IndexerSettingOption implements Built<IndexerSettingOption, IndexerSettingOptionBuilder> {
  @BuiltValueField(wireName: r'value')
  String get value;

  @BuiltValueField(wireName: r'label')
  String get label;

  IndexerSettingOption._();

  factory IndexerSettingOption([void updates(IndexerSettingOptionBuilder b)]) = _$IndexerSettingOption;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(IndexerSettingOptionBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<IndexerSettingOption> get serializer => _$IndexerSettingOptionSerializer();
}

class _$IndexerSettingOptionSerializer implements PrimitiveSerializer<IndexerSettingOption> {
  @override
  final Iterable<Type> types = const [IndexerSettingOption, _$IndexerSettingOption];

  @override
  final String wireName = r'IndexerSettingOption';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    IndexerSettingOption object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'value';
    yield serializers.serialize(
      object.value,
      specifiedType: const FullType(String),
    );
    yield r'label';
    yield serializers.serialize(
      object.label,
      specifiedType: const FullType(String),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    IndexerSettingOption object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required IndexerSettingOptionBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'value':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.value = valueDes;
          break;
        case r'label':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.label = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  IndexerSettingOption deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IndexerSettingOptionBuilder();
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



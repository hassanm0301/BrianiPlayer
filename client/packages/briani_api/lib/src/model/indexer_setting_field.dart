// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:briani_api/src/model/indexer_setting_option.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'indexer_setting_field.g.dart';

/// IndexerSettingField
///
/// Properties:
/// * [name] 
/// * [label] 
/// * [kind] 
/// * [advanced] 
/// * [helpText] 
/// * [unit] 
/// * [value] - Default value as text; always null for secret settings. For info settings this is plain text to show, not a value to send.
/// * [options] 
@BuiltValue()
abstract class IndexerSettingField implements Built<IndexerSettingField, IndexerSettingFieldBuilder> {
  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'label')
  String get label;

  @BuiltValueField(wireName: r'kind')
  IndexerSettingFieldKindEnum get kind;
  // enum kindEnum {  text,  secret,  integer,  decimal,  checkbox,  select,  info,  };

  @BuiltValueField(wireName: r'advanced')
  bool get advanced;

  @BuiltValueField(wireName: r'helpText')
  String? get helpText;

  @BuiltValueField(wireName: r'unit')
  String? get unit;

  /// Default value as text; always null for secret settings. For info settings this is plain text to show, not a value to send.
  @BuiltValueField(wireName: r'value')
  String? get value;

  @BuiltValueField(wireName: r'options')
  BuiltList<IndexerSettingOption>? get options;

  IndexerSettingField._();

  factory IndexerSettingField([void updates(IndexerSettingFieldBuilder b)]) = _$IndexerSettingField;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(IndexerSettingFieldBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<IndexerSettingField> get serializer => _$IndexerSettingFieldSerializer();
}

class _$IndexerSettingFieldSerializer implements PrimitiveSerializer<IndexerSettingField> {
  @override
  final Iterable<Type> types = const [IndexerSettingField, _$IndexerSettingField];

  @override
  final String wireName = r'IndexerSettingField';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    IndexerSettingField object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'label';
    yield serializers.serialize(
      object.label,
      specifiedType: const FullType(String),
    );
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(IndexerSettingFieldKindEnum),
    );
    yield r'advanced';
    yield serializers.serialize(
      object.advanced,
      specifiedType: const FullType(bool),
    );
    if (object.helpText != null) {
      yield r'helpText';
      yield serializers.serialize(
        object.helpText,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.unit != null) {
      yield r'unit';
      yield serializers.serialize(
        object.unit,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.value != null) {
      yield r'value';
      yield serializers.serialize(
        object.value,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.options != null) {
      yield r'options';
      yield serializers.serialize(
        object.options,
        specifiedType: const FullType.nullable(BuiltList, [FullType(IndexerSettingOption)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    IndexerSettingField object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required IndexerSettingFieldBuilder result,
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
        case r'label':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.label = valueDes;
          break;
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(IndexerSettingFieldKindEnum),
          ) as IndexerSettingFieldKindEnum;
          result.kind = valueDes;
          break;
        case r'advanced':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.advanced = valueDes;
          break;
        case r'helpText':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.helpText = valueDes;
          break;
        case r'unit':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.unit = valueDes;
          break;
        case r'value':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.value = valueDes;
          break;
        case r'options':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(IndexerSettingOption)]),
          ) as BuiltList<IndexerSettingOption>?;
          if (valueDes == null) continue;
          result.options.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  IndexerSettingField deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IndexerSettingFieldBuilder();
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


class IndexerSettingFieldKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'text')
  static const IndexerSettingFieldKindEnum text = _$indexerSettingFieldKindEnum_text;
  @BuiltValueEnumConst(wireName: r'secret')
  static const IndexerSettingFieldKindEnum secret = _$indexerSettingFieldKindEnum_secret;
  @BuiltValueEnumConst(wireName: r'integer')
  static const IndexerSettingFieldKindEnum integer = _$indexerSettingFieldKindEnum_integer;
  @BuiltValueEnumConst(wireName: r'decimal')
  static const IndexerSettingFieldKindEnum decimal = _$indexerSettingFieldKindEnum_decimal;
  @BuiltValueEnumConst(wireName: r'checkbox')
  static const IndexerSettingFieldKindEnum checkbox = _$indexerSettingFieldKindEnum_checkbox;
  @BuiltValueEnumConst(wireName: r'select')
  static const IndexerSettingFieldKindEnum select = _$indexerSettingFieldKindEnum_select;
  @BuiltValueEnumConst(wireName: r'info')
  static const IndexerSettingFieldKindEnum info = _$indexerSettingFieldKindEnum_info;

  static Serializer<IndexerSettingFieldKindEnum> get serializer => _$indexerSettingFieldKindEnumSerializer;

  const IndexerSettingFieldKindEnum._(String name): super(name);

  static BuiltSet<IndexerSettingFieldKindEnum> get values => _$indexerSettingFieldKindEnumValues;
  static IndexerSettingFieldKindEnum valueOf(String name) => _$indexerSettingFieldKindEnumValueOf(name);
}


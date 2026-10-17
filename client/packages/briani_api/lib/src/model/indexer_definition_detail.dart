// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:briani_api/src/model/indexer_setting_field.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'indexer_definition_detail.g.dart';

/// IndexerDefinitionDetail
///
/// Properties:
/// * [key] 
/// * [name] 
/// * [description] 
/// * [privacy] 
/// * [addable] 
/// * [setupNote] 
/// * [fields] 
@BuiltValue()
abstract class IndexerDefinitionDetail implements Built<IndexerDefinitionDetail, IndexerDefinitionDetailBuilder> {
  @BuiltValueField(wireName: r'key')
  String get key;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'description')
  String get description;

  @BuiltValueField(wireName: r'privacy')
  IndexerDefinitionDetailPrivacyEnum get privacy;
  // enum privacyEnum {  public,  semiPrivate,  private,  unknown,  };

  @BuiltValueField(wireName: r'addable')
  bool get addable;

  @BuiltValueField(wireName: r'setupNote')
  String? get setupNote;

  @BuiltValueField(wireName: r'fields')
  BuiltList<IndexerSettingField> get fields;

  IndexerDefinitionDetail._();

  factory IndexerDefinitionDetail([void updates(IndexerDefinitionDetailBuilder b)]) = _$IndexerDefinitionDetail;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(IndexerDefinitionDetailBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<IndexerDefinitionDetail> get serializer => _$IndexerDefinitionDetailSerializer();
}

class _$IndexerDefinitionDetailSerializer implements PrimitiveSerializer<IndexerDefinitionDetail> {
  @override
  final Iterable<Type> types = const [IndexerDefinitionDetail, _$IndexerDefinitionDetail];

  @override
  final String wireName = r'IndexerDefinitionDetail';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    IndexerDefinitionDetail object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'key';
    yield serializers.serialize(
      object.key,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'description';
    yield serializers.serialize(
      object.description,
      specifiedType: const FullType(String),
    );
    yield r'privacy';
    yield serializers.serialize(
      object.privacy,
      specifiedType: const FullType(IndexerDefinitionDetailPrivacyEnum),
    );
    yield r'addable';
    yield serializers.serialize(
      object.addable,
      specifiedType: const FullType(bool),
    );
    if (object.setupNote != null) {
      yield r'setupNote';
      yield serializers.serialize(
        object.setupNote,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'fields';
    yield serializers.serialize(
      object.fields,
      specifiedType: const FullType(BuiltList, [FullType(IndexerSettingField)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    IndexerDefinitionDetail object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required IndexerDefinitionDetailBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'key':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.key = valueDes;
          break;
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
            specifiedType: const FullType(String),
          ) as String;
          result.description = valueDes;
          break;
        case r'privacy':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(IndexerDefinitionDetailPrivacyEnum),
          ) as IndexerDefinitionDetailPrivacyEnum;
          result.privacy = valueDes;
          break;
        case r'addable':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.addable = valueDes;
          break;
        case r'setupNote':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.setupNote = valueDes;
          break;
        case r'fields':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(IndexerSettingField)]),
          ) as BuiltList<IndexerSettingField>;
          result.fields.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  IndexerDefinitionDetail deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IndexerDefinitionDetailBuilder();
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


class IndexerDefinitionDetailPrivacyEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'public')
  static const IndexerDefinitionDetailPrivacyEnum public = _$indexerDefinitionDetailPrivacyEnum_public;
  @BuiltValueEnumConst(wireName: r'semiPrivate')
  static const IndexerDefinitionDetailPrivacyEnum semiPrivate = _$indexerDefinitionDetailPrivacyEnum_semiPrivate;
  @BuiltValueEnumConst(wireName: r'private')
  static const IndexerDefinitionDetailPrivacyEnum private = _$indexerDefinitionDetailPrivacyEnum_private;
  @BuiltValueEnumConst(wireName: r'unknown')
  static const IndexerDefinitionDetailPrivacyEnum unknown = _$indexerDefinitionDetailPrivacyEnum_unknown;

  static Serializer<IndexerDefinitionDetailPrivacyEnum> get serializer => _$indexerDefinitionDetailPrivacyEnumSerializer;

  const IndexerDefinitionDetailPrivacyEnum._(String name): super(name);

  static BuiltSet<IndexerDefinitionDetailPrivacyEnum> get values => _$indexerDefinitionDetailPrivacyEnumValues;
  static IndexerDefinitionDetailPrivacyEnum valueOf(String name) => _$indexerDefinitionDetailPrivacyEnumValueOf(name);
}


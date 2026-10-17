// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'indexer_definition_summary.g.dart';

/// IndexerDefinitionSummary
///
/// Properties:
/// * [key] 
/// * [name] 
/// * [description] 
/// * [language] 
/// * [privacy] 
/// * [supportsSearch] 
/// * [supportsRecent] 
/// * [addable] 
/// * [setupNote] - Server-written reason the definition is set up in Prowlarr's own page instead.
@BuiltValue()
abstract class IndexerDefinitionSummary implements Built<IndexerDefinitionSummary, IndexerDefinitionSummaryBuilder> {
  @BuiltValueField(wireName: r'key')
  String get key;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'description')
  String get description;

  @BuiltValueField(wireName: r'language')
  String get language;

  @BuiltValueField(wireName: r'privacy')
  IndexerDefinitionSummaryPrivacyEnum get privacy;
  // enum privacyEnum {  public,  semiPrivate,  private,  unknown,  };

  @BuiltValueField(wireName: r'supportsSearch')
  bool get supportsSearch;

  @BuiltValueField(wireName: r'supportsRecent')
  bool get supportsRecent;

  @BuiltValueField(wireName: r'addable')
  bool get addable;

  /// Server-written reason the definition is set up in Prowlarr's own page instead.
  @BuiltValueField(wireName: r'setupNote')
  String? get setupNote;

  IndexerDefinitionSummary._();

  factory IndexerDefinitionSummary([void updates(IndexerDefinitionSummaryBuilder b)]) = _$IndexerDefinitionSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(IndexerDefinitionSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<IndexerDefinitionSummary> get serializer => _$IndexerDefinitionSummarySerializer();
}

class _$IndexerDefinitionSummarySerializer implements PrimitiveSerializer<IndexerDefinitionSummary> {
  @override
  final Iterable<Type> types = const [IndexerDefinitionSummary, _$IndexerDefinitionSummary];

  @override
  final String wireName = r'IndexerDefinitionSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    IndexerDefinitionSummary object, {
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
    yield r'language';
    yield serializers.serialize(
      object.language,
      specifiedType: const FullType(String),
    );
    yield r'privacy';
    yield serializers.serialize(
      object.privacy,
      specifiedType: const FullType(IndexerDefinitionSummaryPrivacyEnum),
    );
    yield r'supportsSearch';
    yield serializers.serialize(
      object.supportsSearch,
      specifiedType: const FullType(bool),
    );
    yield r'supportsRecent';
    yield serializers.serialize(
      object.supportsRecent,
      specifiedType: const FullType(bool),
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
  }

  @override
  Object serialize(
    Serializers serializers,
    IndexerDefinitionSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required IndexerDefinitionSummaryBuilder result,
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
        case r'language':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.language = valueDes;
          break;
        case r'privacy':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(IndexerDefinitionSummaryPrivacyEnum),
          ) as IndexerDefinitionSummaryPrivacyEnum;
          result.privacy = valueDes;
          break;
        case r'supportsSearch':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.supportsSearch = valueDes;
          break;
        case r'supportsRecent':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.supportsRecent = valueDes;
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
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  IndexerDefinitionSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = IndexerDefinitionSummaryBuilder();
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


class IndexerDefinitionSummaryPrivacyEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'public')
  static const IndexerDefinitionSummaryPrivacyEnum public = _$indexerDefinitionSummaryPrivacyEnum_public;
  @BuiltValueEnumConst(wireName: r'semiPrivate')
  static const IndexerDefinitionSummaryPrivacyEnum semiPrivate = _$indexerDefinitionSummaryPrivacyEnum_semiPrivate;
  @BuiltValueEnumConst(wireName: r'private')
  static const IndexerDefinitionSummaryPrivacyEnum private = _$indexerDefinitionSummaryPrivacyEnum_private;
  @BuiltValueEnumConst(wireName: r'unknown')
  static const IndexerDefinitionSummaryPrivacyEnum unknown = _$indexerDefinitionSummaryPrivacyEnum_unknown;

  static Serializer<IndexerDefinitionSummaryPrivacyEnum> get serializer => _$indexerDefinitionSummaryPrivacyEnumSerializer;

  const IndexerDefinitionSummaryPrivacyEnum._(String name): super(name);

  static BuiltSet<IndexerDefinitionSummaryPrivacyEnum> get values => _$indexerDefinitionSummaryPrivacyEnumValues;
  static IndexerDefinitionSummaryPrivacyEnum valueOf(String name) => _$indexerDefinitionSummaryPrivacyEnumValueOf(name);
}


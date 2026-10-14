// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'entry.g.dart';

/// Entry
///
/// Properties:
/// * [id] 
/// * [libraryId] 
/// * [parentId] 
/// * [kind] 
/// * [name] 
/// * [sizeBytes] 
/// * [modifiedAt] 
/// * [mediaId] 
/// * [thumbnailAvailable] 
/// * [version] 
@BuiltValue()
abstract class Entry implements Built<Entry, EntryBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'libraryId')
  String get libraryId;

  @BuiltValueField(wireName: r'parentId')
  String? get parentId;

  @BuiltValueField(wireName: r'kind')
  EntryKindEnum get kind;
  // enum kindEnum {  folder,  video,  photo,  subtitle,  };

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'sizeBytes')
  int? get sizeBytes;

  @BuiltValueField(wireName: r'modifiedAt')
  DateTime? get modifiedAt;

  @BuiltValueField(wireName: r'mediaId')
  String? get mediaId;

  @BuiltValueField(wireName: r'thumbnailAvailable')
  bool get thumbnailAvailable;

  @BuiltValueField(wireName: r'version')
  int get version;

  Entry._();

  factory Entry([void updates(EntryBuilder b)]) = _$Entry;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EntryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Entry> get serializer => _$EntrySerializer();
}

class _$EntrySerializer implements PrimitiveSerializer<Entry> {
  @override
  final Iterable<Type> types = const [Entry, _$Entry];

  @override
  final String wireName = r'Entry';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Entry object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'libraryId';
    yield serializers.serialize(
      object.libraryId,
      specifiedType: const FullType(String),
    );
    yield r'parentId';
    yield object.parentId == null ? null : serializers.serialize(
      object.parentId,
      specifiedType: const FullType.nullable(String),
    );
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(EntryKindEnum),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'sizeBytes';
    yield object.sizeBytes == null ? null : serializers.serialize(
      object.sizeBytes,
      specifiedType: const FullType.nullable(int),
    );
    yield r'modifiedAt';
    yield object.modifiedAt == null ? null : serializers.serialize(
      object.modifiedAt,
      specifiedType: const FullType.nullable(DateTime),
    );
    if (object.mediaId != null) {
      yield r'mediaId';
      yield serializers.serialize(
        object.mediaId,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'thumbnailAvailable';
    yield serializers.serialize(
      object.thumbnailAvailable,
      specifiedType: const FullType(bool),
    );
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    Entry object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required EntryBuilder result,
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
        case r'libraryId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.libraryId = valueDes;
          break;
        case r'parentId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.parentId = valueDes;
          break;
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(EntryKindEnum),
          ) as EntryKindEnum;
          result.kind = valueDes;
          break;
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'sizeBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.sizeBytes = valueDes;
          break;
        case r'modifiedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DateTime),
          ) as DateTime?;
          if (valueDes == null) continue;
          result.modifiedAt = valueDes;
          break;
        case r'mediaId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.mediaId = valueDes;
          break;
        case r'thumbnailAvailable':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.thumbnailAvailable = valueDes;
          break;
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.version = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Entry deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EntryBuilder();
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


class EntryKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'folder')
  static const EntryKindEnum folder = _$entryKindEnum_folder;
  @BuiltValueEnumConst(wireName: r'video')
  static const EntryKindEnum video = _$entryKindEnum_video;
  @BuiltValueEnumConst(wireName: r'photo')
  static const EntryKindEnum photo = _$entryKindEnum_photo;
  @BuiltValueEnumConst(wireName: r'subtitle')
  static const EntryKindEnum subtitle = _$entryKindEnum_subtitle;

  static Serializer<EntryKindEnum> get serializer => _$entryKindEnumSerializer;

  const EntryKindEnum._(String name): super(name);

  static BuiltSet<EntryKindEnum> get values => _$entryKindEnumValues;
  static EntryKindEnum valueOf(String name) => _$entryKindEnumValueOf(name);
}


// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download_file.g.dart';

/// DownloadFile
///
/// Properties:
/// * [id] 
/// * [downloadId] 
/// * [name] 
/// * [relativePath] 
/// * [sizeBytes] 
/// * [downloadedBytes] 
/// * [contiguousBytes] 
/// * [kind] 
/// * [selected] 
/// * [priority] 
/// * [playbackState] 
/// * [importedMediaId] 
/// * [version] 
@BuiltValue()
abstract class DownloadFile implements Built<DownloadFile, DownloadFileBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'downloadId')
  String get downloadId;

  @BuiltValueField(wireName: r'name')
  String get name;

  @BuiltValueField(wireName: r'relativePath')
  String get relativePath;

  @BuiltValueField(wireName: r'sizeBytes')
  int get sizeBytes;

  @BuiltValueField(wireName: r'downloadedBytes')
  int get downloadedBytes;

  @BuiltValueField(wireName: r'contiguousBytes')
  int get contiguousBytes;

  @BuiltValueField(wireName: r'kind')
  DownloadFileKindEnum get kind;
  // enum kindEnum {  video,  photo,  subtitle,  other,  };

  @BuiltValueField(wireName: r'selected')
  bool get selected;

  @BuiltValueField(wireName: r'priority')
  DownloadFilePriorityEnum get priority;
  // enum priorityEnum {  normal,  high,  maximum,  };

  @BuiltValueField(wireName: r'playbackState')
  DownloadFilePlaybackStateEnum get playbackState;
  // enum playbackStateEnum {  notSelected,  metadataPending,  waitingForData,  eligible,  complete,  unsupported,  unavailable,  };

  @BuiltValueField(wireName: r'importedMediaId')
  String? get importedMediaId;

  @BuiltValueField(wireName: r'version')
  int get version;

  DownloadFile._();

  factory DownloadFile([void updates(DownloadFileBuilder b)]) = _$DownloadFile;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadFileBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadFile> get serializer => _$DownloadFileSerializer();
}

class _$DownloadFileSerializer implements PrimitiveSerializer<DownloadFile> {
  @override
  final Iterable<Type> types = const [DownloadFile, _$DownloadFile];

  @override
  final String wireName = r'DownloadFile';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadFile object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'downloadId';
    yield serializers.serialize(
      object.downloadId,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield serializers.serialize(
      object.name,
      specifiedType: const FullType(String),
    );
    yield r'relativePath';
    yield serializers.serialize(
      object.relativePath,
      specifiedType: const FullType(String),
    );
    yield r'sizeBytes';
    yield serializers.serialize(
      object.sizeBytes,
      specifiedType: const FullType(int),
    );
    yield r'downloadedBytes';
    yield serializers.serialize(
      object.downloadedBytes,
      specifiedType: const FullType(int),
    );
    yield r'contiguousBytes';
    yield serializers.serialize(
      object.contiguousBytes,
      specifiedType: const FullType(int),
    );
    yield r'kind';
    yield serializers.serialize(
      object.kind,
      specifiedType: const FullType(DownloadFileKindEnum),
    );
    yield r'selected';
    yield serializers.serialize(
      object.selected,
      specifiedType: const FullType(bool),
    );
    yield r'priority';
    yield serializers.serialize(
      object.priority,
      specifiedType: const FullType(DownloadFilePriorityEnum),
    );
    yield r'playbackState';
    yield serializers.serialize(
      object.playbackState,
      specifiedType: const FullType(DownloadFilePlaybackStateEnum),
    );
    yield r'importedMediaId';
    yield object.importedMediaId == null ? null : serializers.serialize(
      object.importedMediaId,
      specifiedType: const FullType.nullable(String),
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
    DownloadFile object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadFileBuilder result,
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
        case r'downloadId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.downloadId = valueDes;
          break;
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.name = valueDes;
          break;
        case r'relativePath':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.relativePath = valueDes;
          break;
        case r'sizeBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.sizeBytes = valueDes;
          break;
        case r'downloadedBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.downloadedBytes = valueDes;
          break;
        case r'contiguousBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.contiguousBytes = valueDes;
          break;
        case r'kind':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadFileKindEnum),
          ) as DownloadFileKindEnum;
          result.kind = valueDes;
          break;
        case r'selected':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.selected = valueDes;
          break;
        case r'priority':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadFilePriorityEnum),
          ) as DownloadFilePriorityEnum;
          result.priority = valueDes;
          break;
        case r'playbackState':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadFilePlaybackStateEnum),
          ) as DownloadFilePlaybackStateEnum;
          result.playbackState = valueDes;
          break;
        case r'importedMediaId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.importedMediaId = valueDes;
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
  DownloadFile deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadFileBuilder();
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


class DownloadFileKindEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'video')
  static const DownloadFileKindEnum video = _$downloadFileKindEnum_video;
  @BuiltValueEnumConst(wireName: r'photo')
  static const DownloadFileKindEnum photo = _$downloadFileKindEnum_photo;
  @BuiltValueEnumConst(wireName: r'subtitle')
  static const DownloadFileKindEnum subtitle = _$downloadFileKindEnum_subtitle;
  @BuiltValueEnumConst(wireName: r'other')
  static const DownloadFileKindEnum other = _$downloadFileKindEnum_other;

  static Serializer<DownloadFileKindEnum> get serializer => _$downloadFileKindEnumSerializer;

  const DownloadFileKindEnum._(String name): super(name);

  static BuiltSet<DownloadFileKindEnum> get values => _$downloadFileKindEnumValues;
  static DownloadFileKindEnum valueOf(String name) => _$downloadFileKindEnumValueOf(name);
}

class DownloadFilePriorityEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'normal')
  static const DownloadFilePriorityEnum normal = _$downloadFilePriorityEnum_normal;
  @BuiltValueEnumConst(wireName: r'high')
  static const DownloadFilePriorityEnum high = _$downloadFilePriorityEnum_high;
  @BuiltValueEnumConst(wireName: r'maximum')
  static const DownloadFilePriorityEnum maximum = _$downloadFilePriorityEnum_maximum;

  static Serializer<DownloadFilePriorityEnum> get serializer => _$downloadFilePriorityEnumSerializer;

  const DownloadFilePriorityEnum._(String name): super(name);

  static BuiltSet<DownloadFilePriorityEnum> get values => _$downloadFilePriorityEnumValues;
  static DownloadFilePriorityEnum valueOf(String name) => _$downloadFilePriorityEnumValueOf(name);
}

class DownloadFilePlaybackStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'notSelected')
  static const DownloadFilePlaybackStateEnum notSelected = _$downloadFilePlaybackStateEnum_notSelected;
  @BuiltValueEnumConst(wireName: r'metadataPending')
  static const DownloadFilePlaybackStateEnum metadataPending = _$downloadFilePlaybackStateEnum_metadataPending;
  @BuiltValueEnumConst(wireName: r'waitingForData')
  static const DownloadFilePlaybackStateEnum waitingForData = _$downloadFilePlaybackStateEnum_waitingForData;
  @BuiltValueEnumConst(wireName: r'eligible')
  static const DownloadFilePlaybackStateEnum eligible = _$downloadFilePlaybackStateEnum_eligible;
  @BuiltValueEnumConst(wireName: r'complete')
  static const DownloadFilePlaybackStateEnum complete = _$downloadFilePlaybackStateEnum_complete;
  @BuiltValueEnumConst(wireName: r'unsupported')
  static const DownloadFilePlaybackStateEnum unsupported = _$downloadFilePlaybackStateEnum_unsupported;
  @BuiltValueEnumConst(wireName: r'unavailable')
  static const DownloadFilePlaybackStateEnum unavailable = _$downloadFilePlaybackStateEnum_unavailable;

  static Serializer<DownloadFilePlaybackStateEnum> get serializer => _$downloadFilePlaybackStateEnumSerializer;

  const DownloadFilePlaybackStateEnum._(String name): super(name);

  static BuiltSet<DownloadFilePlaybackStateEnum> get values => _$downloadFilePlaybackStateEnumValues;
  static DownloadFilePlaybackStateEnum valueOf(String name) => _$downloadFilePlaybackStateEnumValueOf(name);
}


// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download.g.dart';

/// Download
///
/// Properties:
/// * [id] 
/// * [libraryId] 
/// * [ownerId] 
/// * [name] 
/// * [state] 
/// * [selectedBytes] 
/// * [downloadedSelectedBytes] 
/// * [torrentBytes] 
/// * [downloadBps] 
/// * [uploadBps] 
/// * [seedersConnected] 
/// * [peersConnected] 
/// * [etaSeconds] 
/// * [sequential] 
/// * [firstLastMetadataAssist] 
/// * [generation] 
/// * [version] 
/// * [errorCode] 
/// * [errorDetail] 
/// * [createdAt] 
/// * [updatedAt] 
/// * [tags] 
/// * [sourceState] 
/// * [transferState] 
/// * [importState] 
@BuiltValue()
abstract class Download implements Built<Download, DownloadBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'libraryId')
  String get libraryId;

  @BuiltValueField(wireName: r'ownerId')
  String get ownerId;

  @BuiltValueField(wireName: r'name')
  String? get name;

  @BuiltValueField(wireName: r'state')
  DownloadStateEnum get state;
  // enum stateEnum {  resolving,  metadataPending,  awaitingSelection,  queued,  downloading,  paused,  stalled,  completeSelected,  importing,  seeding,  completed,  removing,  removed,  failed,  };

  @BuiltValueField(wireName: r'selectedBytes')
  int? get selectedBytes;

  @BuiltValueField(wireName: r'downloadedSelectedBytes')
  int get downloadedSelectedBytes;

  @BuiltValueField(wireName: r'torrentBytes')
  int? get torrentBytes;

  @BuiltValueField(wireName: r'downloadBps')
  int get downloadBps;

  @BuiltValueField(wireName: r'uploadBps')
  int get uploadBps;

  @BuiltValueField(wireName: r'seedersConnected')
  int? get seedersConnected;

  @BuiltValueField(wireName: r'peersConnected')
  int? get peersConnected;

  @BuiltValueField(wireName: r'etaSeconds')
  int? get etaSeconds;

  @BuiltValueField(wireName: r'sequential')
  bool get sequential;

  @BuiltValueField(wireName: r'firstLastMetadataAssist')
  bool get firstLastMetadataAssist;

  @BuiltValueField(wireName: r'generation')
  String get generation;

  @BuiltValueField(wireName: r'version')
  int get version;

  @BuiltValueField(wireName: r'errorCode')
  String? get errorCode;

  @BuiltValueField(wireName: r'errorDetail')
  String? get errorDetail;

  @BuiltValueField(wireName: r'createdAt')
  DateTime get createdAt;

  @BuiltValueField(wireName: r'updatedAt')
  DateTime get updatedAt;

  @BuiltValueField(wireName: r'tags')
  BuiltList<String> get tags;

  @BuiltValueField(wireName: r'sourceState')
  DownloadSourceStateEnum get sourceState;
  // enum sourceStateEnum {  resolving,  metadataPending,  ready,  failed,  };

  @BuiltValueField(wireName: r'transferState')
  DownloadTransferStateEnum get transferState;
  // enum transferStateEnum {  metadata,  queued,  downloading,  paused,  stalled,  checking,  seeding,  complete,  stopped,  failed,  };

  @BuiltValueField(wireName: r'importState')
  DownloadImportStateEnum get importState;
  // enum importStateEnum {  notReady,  pending,  running,  complete,  failed,  };

  Download._();

  factory Download([void updates(DownloadBuilder b)]) = _$Download;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Download> get serializer => _$DownloadSerializer();
}

class _$DownloadSerializer implements PrimitiveSerializer<Download> {
  @override
  final Iterable<Type> types = const [Download, _$Download];

  @override
  final String wireName = r'Download';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Download object, {
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
    yield r'ownerId';
    yield serializers.serialize(
      object.ownerId,
      specifiedType: const FullType(String),
    );
    yield r'name';
    yield object.name == null ? null : serializers.serialize(
      object.name,
      specifiedType: const FullType.nullable(String),
    );
    yield r'state';
    yield serializers.serialize(
      object.state,
      specifiedType: const FullType(DownloadStateEnum),
    );
    yield r'selectedBytes';
    yield object.selectedBytes == null ? null : serializers.serialize(
      object.selectedBytes,
      specifiedType: const FullType.nullable(int),
    );
    yield r'downloadedSelectedBytes';
    yield serializers.serialize(
      object.downloadedSelectedBytes,
      specifiedType: const FullType(int),
    );
    yield r'torrentBytes';
    yield object.torrentBytes == null ? null : serializers.serialize(
      object.torrentBytes,
      specifiedType: const FullType.nullable(int),
    );
    yield r'downloadBps';
    yield serializers.serialize(
      object.downloadBps,
      specifiedType: const FullType(int),
    );
    yield r'uploadBps';
    yield serializers.serialize(
      object.uploadBps,
      specifiedType: const FullType(int),
    );
    if (object.seedersConnected != null) {
      yield r'seedersConnected';
      yield serializers.serialize(
        object.seedersConnected,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.peersConnected != null) {
      yield r'peersConnected';
      yield serializers.serialize(
        object.peersConnected,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.etaSeconds != null) {
      yield r'etaSeconds';
      yield serializers.serialize(
        object.etaSeconds,
        specifiedType: const FullType.nullable(int),
      );
    }
    yield r'sequential';
    yield serializers.serialize(
      object.sequential,
      specifiedType: const FullType(bool),
    );
    yield r'firstLastMetadataAssist';
    yield serializers.serialize(
      object.firstLastMetadataAssist,
      specifiedType: const FullType(bool),
    );
    yield r'generation';
    yield serializers.serialize(
      object.generation,
      specifiedType: const FullType(String),
    );
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
    if (object.errorCode != null) {
      yield r'errorCode';
      yield serializers.serialize(
        object.errorCode,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.errorDetail != null) {
      yield r'errorDetail';
      yield serializers.serialize(
        object.errorDetail,
        specifiedType: const FullType.nullable(String),
      );
    }
    yield r'createdAt';
    yield serializers.serialize(
      object.createdAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'updatedAt';
    yield serializers.serialize(
      object.updatedAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'tags';
    yield serializers.serialize(
      object.tags,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
    yield r'sourceState';
    yield serializers.serialize(
      object.sourceState,
      specifiedType: const FullType(DownloadSourceStateEnum),
    );
    yield r'transferState';
    yield serializers.serialize(
      object.transferState,
      specifiedType: const FullType(DownloadTransferStateEnum),
    );
    yield r'importState';
    yield serializers.serialize(
      object.importState,
      specifiedType: const FullType(DownloadImportStateEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    Download object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadBuilder result,
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
        case r'ownerId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.ownerId = valueDes;
          break;
        case r'name':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.name = valueDes;
          break;
        case r'state':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadStateEnum),
          ) as DownloadStateEnum;
          result.state = valueDes;
          break;
        case r'selectedBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.selectedBytes = valueDes;
          break;
        case r'downloadedSelectedBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.downloadedSelectedBytes = valueDes;
          break;
        case r'torrentBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.torrentBytes = valueDes;
          break;
        case r'downloadBps':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.downloadBps = valueDes;
          break;
        case r'uploadBps':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.uploadBps = valueDes;
          break;
        case r'seedersConnected':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.seedersConnected = valueDes;
          break;
        case r'peersConnected':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.peersConnected = valueDes;
          break;
        case r'etaSeconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.etaSeconds = valueDes;
          break;
        case r'sequential':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.sequential = valueDes;
          break;
        case r'firstLastMetadataAssist':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.firstLastMetadataAssist = valueDes;
          break;
        case r'generation':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.generation = valueDes;
          break;
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.version = valueDes;
          break;
        case r'errorCode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.errorCode = valueDes;
          break;
        case r'errorDetail':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.errorDetail = valueDes;
          break;
        case r'createdAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.createdAt = valueDes;
          break;
        case r'updatedAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.updatedAt = valueDes;
          break;
        case r'tags':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.tags.replace(valueDes);
          break;
        case r'sourceState':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadSourceStateEnum),
          ) as DownloadSourceStateEnum;
          result.sourceState = valueDes;
          break;
        case r'transferState':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadTransferStateEnum),
          ) as DownloadTransferStateEnum;
          result.transferState = valueDes;
          break;
        case r'importState':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadImportStateEnum),
          ) as DownloadImportStateEnum;
          result.importState = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Download deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadBuilder();
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


class DownloadStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'resolving')
  static const DownloadStateEnum resolving = _$downloadStateEnum_resolving;
  @BuiltValueEnumConst(wireName: r'metadataPending')
  static const DownloadStateEnum metadataPending = _$downloadStateEnum_metadataPending;
  @BuiltValueEnumConst(wireName: r'awaitingSelection')
  static const DownloadStateEnum awaitingSelection = _$downloadStateEnum_awaitingSelection;
  @BuiltValueEnumConst(wireName: r'queued')
  static const DownloadStateEnum queued = _$downloadStateEnum_queued;
  @BuiltValueEnumConst(wireName: r'downloading')
  static const DownloadStateEnum downloading = _$downloadStateEnum_downloading;
  @BuiltValueEnumConst(wireName: r'paused')
  static const DownloadStateEnum paused = _$downloadStateEnum_paused;
  @BuiltValueEnumConst(wireName: r'stalled')
  static const DownloadStateEnum stalled = _$downloadStateEnum_stalled;
  @BuiltValueEnumConst(wireName: r'completeSelected')
  static const DownloadStateEnum completeSelected = _$downloadStateEnum_completeSelected;
  @BuiltValueEnumConst(wireName: r'importing')
  static const DownloadStateEnum importing = _$downloadStateEnum_importing;
  @BuiltValueEnumConst(wireName: r'seeding')
  static const DownloadStateEnum seeding = _$downloadStateEnum_seeding;
  @BuiltValueEnumConst(wireName: r'completed')
  static const DownloadStateEnum completed = _$downloadStateEnum_completed;
  @BuiltValueEnumConst(wireName: r'removing')
  static const DownloadStateEnum removing = _$downloadStateEnum_removing;
  @BuiltValueEnumConst(wireName: r'removed')
  static const DownloadStateEnum removed = _$downloadStateEnum_removed;
  @BuiltValueEnumConst(wireName: r'failed')
  static const DownloadStateEnum failed = _$downloadStateEnum_failed;

  static Serializer<DownloadStateEnum> get serializer => _$downloadStateEnumSerializer;

  const DownloadStateEnum._(String name): super(name);

  static BuiltSet<DownloadStateEnum> get values => _$downloadStateEnumValues;
  static DownloadStateEnum valueOf(String name) => _$downloadStateEnumValueOf(name);
}

class DownloadSourceStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'resolving')
  static const DownloadSourceStateEnum resolving = _$downloadSourceStateEnum_resolving;
  @BuiltValueEnumConst(wireName: r'metadataPending')
  static const DownloadSourceStateEnum metadataPending = _$downloadSourceStateEnum_metadataPending;
  @BuiltValueEnumConst(wireName: r'ready')
  static const DownloadSourceStateEnum ready = _$downloadSourceStateEnum_ready;
  @BuiltValueEnumConst(wireName: r'failed')
  static const DownloadSourceStateEnum failed = _$downloadSourceStateEnum_failed;

  static Serializer<DownloadSourceStateEnum> get serializer => _$downloadSourceStateEnumSerializer;

  const DownloadSourceStateEnum._(String name): super(name);

  static BuiltSet<DownloadSourceStateEnum> get values => _$downloadSourceStateEnumValues;
  static DownloadSourceStateEnum valueOf(String name) => _$downloadSourceStateEnumValueOf(name);
}

class DownloadTransferStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'metadata')
  static const DownloadTransferStateEnum metadata = _$downloadTransferStateEnum_metadata;
  @BuiltValueEnumConst(wireName: r'queued')
  static const DownloadTransferStateEnum queued = _$downloadTransferStateEnum_queued;
  @BuiltValueEnumConst(wireName: r'downloading')
  static const DownloadTransferStateEnum downloading = _$downloadTransferStateEnum_downloading;
  @BuiltValueEnumConst(wireName: r'paused')
  static const DownloadTransferStateEnum paused = _$downloadTransferStateEnum_paused;
  @BuiltValueEnumConst(wireName: r'stalled')
  static const DownloadTransferStateEnum stalled = _$downloadTransferStateEnum_stalled;
  @BuiltValueEnumConst(wireName: r'checking')
  static const DownloadTransferStateEnum checking = _$downloadTransferStateEnum_checking;
  @BuiltValueEnumConst(wireName: r'seeding')
  static const DownloadTransferStateEnum seeding = _$downloadTransferStateEnum_seeding;
  @BuiltValueEnumConst(wireName: r'complete')
  static const DownloadTransferStateEnum complete = _$downloadTransferStateEnum_complete;
  @BuiltValueEnumConst(wireName: r'stopped')
  static const DownloadTransferStateEnum stopped = _$downloadTransferStateEnum_stopped;
  @BuiltValueEnumConst(wireName: r'failed')
  static const DownloadTransferStateEnum failed = _$downloadTransferStateEnum_failed;

  static Serializer<DownloadTransferStateEnum> get serializer => _$downloadTransferStateEnumSerializer;

  const DownloadTransferStateEnum._(String name): super(name);

  static BuiltSet<DownloadTransferStateEnum> get values => _$downloadTransferStateEnumValues;
  static DownloadTransferStateEnum valueOf(String name) => _$downloadTransferStateEnumValueOf(name);
}

class DownloadImportStateEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'notReady')
  static const DownloadImportStateEnum notReady = _$downloadImportStateEnum_notReady;
  @BuiltValueEnumConst(wireName: r'pending')
  static const DownloadImportStateEnum pending = _$downloadImportStateEnum_pending;
  @BuiltValueEnumConst(wireName: r'running')
  static const DownloadImportStateEnum running = _$downloadImportStateEnum_running;
  @BuiltValueEnumConst(wireName: r'complete')
  static const DownloadImportStateEnum complete = _$downloadImportStateEnum_complete;
  @BuiltValueEnumConst(wireName: r'failed')
  static const DownloadImportStateEnum failed = _$downloadImportStateEnum_failed;

  static Serializer<DownloadImportStateEnum> get serializer => _$downloadImportStateEnumSerializer;

  const DownloadImportStateEnum._(String name): super(name);

  static BuiltSet<DownloadImportStateEnum> get values => _$downloadImportStateEnumValues;
  static DownloadImportStateEnum valueOf(String name) => _$downloadImportStateEnumValueOf(name);
}


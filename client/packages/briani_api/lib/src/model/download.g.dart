// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DownloadStateEnum _$downloadStateEnum_resolving =
    const DownloadStateEnum._('resolving');
const DownloadStateEnum _$downloadStateEnum_metadataPending =
    const DownloadStateEnum._('metadataPending');
const DownloadStateEnum _$downloadStateEnum_awaitingSelection =
    const DownloadStateEnum._('awaitingSelection');
const DownloadStateEnum _$downloadStateEnum_queued =
    const DownloadStateEnum._('queued');
const DownloadStateEnum _$downloadStateEnum_downloading =
    const DownloadStateEnum._('downloading');
const DownloadStateEnum _$downloadStateEnum_paused =
    const DownloadStateEnum._('paused');
const DownloadStateEnum _$downloadStateEnum_stalled =
    const DownloadStateEnum._('stalled');
const DownloadStateEnum _$downloadStateEnum_completeSelected =
    const DownloadStateEnum._('completeSelected');
const DownloadStateEnum _$downloadStateEnum_importing =
    const DownloadStateEnum._('importing');
const DownloadStateEnum _$downloadStateEnum_seeding =
    const DownloadStateEnum._('seeding');
const DownloadStateEnum _$downloadStateEnum_completed =
    const DownloadStateEnum._('completed');
const DownloadStateEnum _$downloadStateEnum_removing =
    const DownloadStateEnum._('removing');
const DownloadStateEnum _$downloadStateEnum_removed =
    const DownloadStateEnum._('removed');
const DownloadStateEnum _$downloadStateEnum_failed =
    const DownloadStateEnum._('failed');

DownloadStateEnum _$downloadStateEnumValueOf(String name) {
  switch (name) {
    case 'resolving':
      return _$downloadStateEnum_resolving;
    case 'metadataPending':
      return _$downloadStateEnum_metadataPending;
    case 'awaitingSelection':
      return _$downloadStateEnum_awaitingSelection;
    case 'queued':
      return _$downloadStateEnum_queued;
    case 'downloading':
      return _$downloadStateEnum_downloading;
    case 'paused':
      return _$downloadStateEnum_paused;
    case 'stalled':
      return _$downloadStateEnum_stalled;
    case 'completeSelected':
      return _$downloadStateEnum_completeSelected;
    case 'importing':
      return _$downloadStateEnum_importing;
    case 'seeding':
      return _$downloadStateEnum_seeding;
    case 'completed':
      return _$downloadStateEnum_completed;
    case 'removing':
      return _$downloadStateEnum_removing;
    case 'removed':
      return _$downloadStateEnum_removed;
    case 'failed':
      return _$downloadStateEnum_failed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadStateEnum> _$downloadStateEnumValues =
    BuiltSet<DownloadStateEnum>(const <DownloadStateEnum>[
  _$downloadStateEnum_resolving,
  _$downloadStateEnum_metadataPending,
  _$downloadStateEnum_awaitingSelection,
  _$downloadStateEnum_queued,
  _$downloadStateEnum_downloading,
  _$downloadStateEnum_paused,
  _$downloadStateEnum_stalled,
  _$downloadStateEnum_completeSelected,
  _$downloadStateEnum_importing,
  _$downloadStateEnum_seeding,
  _$downloadStateEnum_completed,
  _$downloadStateEnum_removing,
  _$downloadStateEnum_removed,
  _$downloadStateEnum_failed,
]);

const DownloadSourceStateEnum _$downloadSourceStateEnum_resolving =
    const DownloadSourceStateEnum._('resolving');
const DownloadSourceStateEnum _$downloadSourceStateEnum_metadataPending =
    const DownloadSourceStateEnum._('metadataPending');
const DownloadSourceStateEnum _$downloadSourceStateEnum_ready =
    const DownloadSourceStateEnum._('ready');
const DownloadSourceStateEnum _$downloadSourceStateEnum_failed =
    const DownloadSourceStateEnum._('failed');

DownloadSourceStateEnum _$downloadSourceStateEnumValueOf(String name) {
  switch (name) {
    case 'resolving':
      return _$downloadSourceStateEnum_resolving;
    case 'metadataPending':
      return _$downloadSourceStateEnum_metadataPending;
    case 'ready':
      return _$downloadSourceStateEnum_ready;
    case 'failed':
      return _$downloadSourceStateEnum_failed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadSourceStateEnum> _$downloadSourceStateEnumValues =
    BuiltSet<DownloadSourceStateEnum>(const <DownloadSourceStateEnum>[
  _$downloadSourceStateEnum_resolving,
  _$downloadSourceStateEnum_metadataPending,
  _$downloadSourceStateEnum_ready,
  _$downloadSourceStateEnum_failed,
]);

const DownloadTransferStateEnum _$downloadTransferStateEnum_metadata =
    const DownloadTransferStateEnum._('metadata');
const DownloadTransferStateEnum _$downloadTransferStateEnum_queued =
    const DownloadTransferStateEnum._('queued');
const DownloadTransferStateEnum _$downloadTransferStateEnum_downloading =
    const DownloadTransferStateEnum._('downloading');
const DownloadTransferStateEnum _$downloadTransferStateEnum_paused =
    const DownloadTransferStateEnum._('paused');
const DownloadTransferStateEnum _$downloadTransferStateEnum_stalled =
    const DownloadTransferStateEnum._('stalled');
const DownloadTransferStateEnum _$downloadTransferStateEnum_checking =
    const DownloadTransferStateEnum._('checking');
const DownloadTransferStateEnum _$downloadTransferStateEnum_seeding =
    const DownloadTransferStateEnum._('seeding');
const DownloadTransferStateEnum _$downloadTransferStateEnum_complete =
    const DownloadTransferStateEnum._('complete');
const DownloadTransferStateEnum _$downloadTransferStateEnum_stopped =
    const DownloadTransferStateEnum._('stopped');
const DownloadTransferStateEnum _$downloadTransferStateEnum_failed =
    const DownloadTransferStateEnum._('failed');

DownloadTransferStateEnum _$downloadTransferStateEnumValueOf(String name) {
  switch (name) {
    case 'metadata':
      return _$downloadTransferStateEnum_metadata;
    case 'queued':
      return _$downloadTransferStateEnum_queued;
    case 'downloading':
      return _$downloadTransferStateEnum_downloading;
    case 'paused':
      return _$downloadTransferStateEnum_paused;
    case 'stalled':
      return _$downloadTransferStateEnum_stalled;
    case 'checking':
      return _$downloadTransferStateEnum_checking;
    case 'seeding':
      return _$downloadTransferStateEnum_seeding;
    case 'complete':
      return _$downloadTransferStateEnum_complete;
    case 'stopped':
      return _$downloadTransferStateEnum_stopped;
    case 'failed':
      return _$downloadTransferStateEnum_failed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadTransferStateEnum> _$downloadTransferStateEnumValues =
    BuiltSet<DownloadTransferStateEnum>(const <DownloadTransferStateEnum>[
  _$downloadTransferStateEnum_metadata,
  _$downloadTransferStateEnum_queued,
  _$downloadTransferStateEnum_downloading,
  _$downloadTransferStateEnum_paused,
  _$downloadTransferStateEnum_stalled,
  _$downloadTransferStateEnum_checking,
  _$downloadTransferStateEnum_seeding,
  _$downloadTransferStateEnum_complete,
  _$downloadTransferStateEnum_stopped,
  _$downloadTransferStateEnum_failed,
]);

const DownloadImportStateEnum _$downloadImportStateEnum_notReady =
    const DownloadImportStateEnum._('notReady');
const DownloadImportStateEnum _$downloadImportStateEnum_pending =
    const DownloadImportStateEnum._('pending');
const DownloadImportStateEnum _$downloadImportStateEnum_running =
    const DownloadImportStateEnum._('running');
const DownloadImportStateEnum _$downloadImportStateEnum_complete =
    const DownloadImportStateEnum._('complete');
const DownloadImportStateEnum _$downloadImportStateEnum_failed =
    const DownloadImportStateEnum._('failed');

DownloadImportStateEnum _$downloadImportStateEnumValueOf(String name) {
  switch (name) {
    case 'notReady':
      return _$downloadImportStateEnum_notReady;
    case 'pending':
      return _$downloadImportStateEnum_pending;
    case 'running':
      return _$downloadImportStateEnum_running;
    case 'complete':
      return _$downloadImportStateEnum_complete;
    case 'failed':
      return _$downloadImportStateEnum_failed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadImportStateEnum> _$downloadImportStateEnumValues =
    BuiltSet<DownloadImportStateEnum>(const <DownloadImportStateEnum>[
  _$downloadImportStateEnum_notReady,
  _$downloadImportStateEnum_pending,
  _$downloadImportStateEnum_running,
  _$downloadImportStateEnum_complete,
  _$downloadImportStateEnum_failed,
]);

Serializer<DownloadStateEnum> _$downloadStateEnumSerializer =
    _$DownloadStateEnumSerializer();
Serializer<DownloadSourceStateEnum> _$downloadSourceStateEnumSerializer =
    _$DownloadSourceStateEnumSerializer();
Serializer<DownloadTransferStateEnum> _$downloadTransferStateEnumSerializer =
    _$DownloadTransferStateEnumSerializer();
Serializer<DownloadImportStateEnum> _$downloadImportStateEnumSerializer =
    _$DownloadImportStateEnumSerializer();

class _$DownloadStateEnumSerializer
    implements PrimitiveSerializer<DownloadStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'resolving': 'resolving',
    'metadataPending': 'metadataPending',
    'awaitingSelection': 'awaitingSelection',
    'queued': 'queued',
    'downloading': 'downloading',
    'paused': 'paused',
    'stalled': 'stalled',
    'completeSelected': 'completeSelected',
    'importing': 'importing',
    'seeding': 'seeding',
    'completed': 'completed',
    'removing': 'removing',
    'removed': 'removed',
    'failed': 'failed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'resolving': 'resolving',
    'metadataPending': 'metadataPending',
    'awaitingSelection': 'awaitingSelection',
    'queued': 'queued',
    'downloading': 'downloading',
    'paused': 'paused',
    'stalled': 'stalled',
    'completeSelected': 'completeSelected',
    'importing': 'importing',
    'seeding': 'seeding',
    'completed': 'completed',
    'removing': 'removing',
    'removed': 'removed',
    'failed': 'failed',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadStateEnum];
  @override
  final String wireName = 'DownloadStateEnum';

  @override
  Object serialize(Serializers serializers, DownloadStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadStateEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadSourceStateEnumSerializer
    implements PrimitiveSerializer<DownloadSourceStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'resolving': 'resolving',
    'metadataPending': 'metadataPending',
    'ready': 'ready',
    'failed': 'failed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'resolving': 'resolving',
    'metadataPending': 'metadataPending',
    'ready': 'ready',
    'failed': 'failed',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadSourceStateEnum];
  @override
  final String wireName = 'DownloadSourceStateEnum';

  @override
  Object serialize(Serializers serializers, DownloadSourceStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadSourceStateEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadSourceStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadTransferStateEnumSerializer
    implements PrimitiveSerializer<DownloadTransferStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'metadata': 'metadata',
    'queued': 'queued',
    'downloading': 'downloading',
    'paused': 'paused',
    'stalled': 'stalled',
    'checking': 'checking',
    'seeding': 'seeding',
    'complete': 'complete',
    'stopped': 'stopped',
    'failed': 'failed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'metadata': 'metadata',
    'queued': 'queued',
    'downloading': 'downloading',
    'paused': 'paused',
    'stalled': 'stalled',
    'checking': 'checking',
    'seeding': 'seeding',
    'complete': 'complete',
    'stopped': 'stopped',
    'failed': 'failed',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadTransferStateEnum];
  @override
  final String wireName = 'DownloadTransferStateEnum';

  @override
  Object serialize(Serializers serializers, DownloadTransferStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadTransferStateEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadTransferStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadImportStateEnumSerializer
    implements PrimitiveSerializer<DownloadImportStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'notReady': 'notReady',
    'pending': 'pending',
    'running': 'running',
    'complete': 'complete',
    'failed': 'failed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'notReady': 'notReady',
    'pending': 'pending',
    'running': 'running',
    'complete': 'complete',
    'failed': 'failed',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadImportStateEnum];
  @override
  final String wireName = 'DownloadImportStateEnum';

  @override
  Object serialize(Serializers serializers, DownloadImportStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadImportStateEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadImportStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Download extends Download {
  @override
  final String id;
  @override
  final String libraryId;
  @override
  final String ownerId;
  @override
  final String? name;
  @override
  final DownloadStateEnum state;
  @override
  final int? selectedBytes;
  @override
  final int downloadedSelectedBytes;
  @override
  final int? torrentBytes;
  @override
  final int downloadBps;
  @override
  final int uploadBps;
  @override
  final int? seedersConnected;
  @override
  final int? peersConnected;
  @override
  final int? etaSeconds;
  @override
  final bool sequential;
  @override
  final bool firstLastMetadataAssist;
  @override
  final String generation;
  @override
  final int version;
  @override
  final String? errorCode;
  @override
  final String? errorDetail;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final BuiltList<String> tags;
  @override
  final DownloadSourceStateEnum sourceState;
  @override
  final DownloadTransferStateEnum transferState;
  @override
  final DownloadImportStateEnum importState;

  factory _$Download([void Function(DownloadBuilder)? updates]) =>
      (DownloadBuilder()..update(updates))._build();

  _$Download._(
      {required this.id,
      required this.libraryId,
      required this.ownerId,
      this.name,
      required this.state,
      this.selectedBytes,
      required this.downloadedSelectedBytes,
      this.torrentBytes,
      required this.downloadBps,
      required this.uploadBps,
      this.seedersConnected,
      this.peersConnected,
      this.etaSeconds,
      required this.sequential,
      required this.firstLastMetadataAssist,
      required this.generation,
      required this.version,
      this.errorCode,
      this.errorDetail,
      required this.createdAt,
      required this.updatedAt,
      required this.tags,
      required this.sourceState,
      required this.transferState,
      required this.importState})
      : super._();
  @override
  Download rebuild(void Function(DownloadBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadBuilder toBuilder() => DownloadBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Download &&
        id == other.id &&
        libraryId == other.libraryId &&
        ownerId == other.ownerId &&
        name == other.name &&
        state == other.state &&
        selectedBytes == other.selectedBytes &&
        downloadedSelectedBytes == other.downloadedSelectedBytes &&
        torrentBytes == other.torrentBytes &&
        downloadBps == other.downloadBps &&
        uploadBps == other.uploadBps &&
        seedersConnected == other.seedersConnected &&
        peersConnected == other.peersConnected &&
        etaSeconds == other.etaSeconds &&
        sequential == other.sequential &&
        firstLastMetadataAssist == other.firstLastMetadataAssist &&
        generation == other.generation &&
        version == other.version &&
        errorCode == other.errorCode &&
        errorDetail == other.errorDetail &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        tags == other.tags &&
        sourceState == other.sourceState &&
        transferState == other.transferState &&
        importState == other.importState;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, libraryId.hashCode);
    _$hash = $jc(_$hash, ownerId.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, selectedBytes.hashCode);
    _$hash = $jc(_$hash, downloadedSelectedBytes.hashCode);
    _$hash = $jc(_$hash, torrentBytes.hashCode);
    _$hash = $jc(_$hash, downloadBps.hashCode);
    _$hash = $jc(_$hash, uploadBps.hashCode);
    _$hash = $jc(_$hash, seedersConnected.hashCode);
    _$hash = $jc(_$hash, peersConnected.hashCode);
    _$hash = $jc(_$hash, etaSeconds.hashCode);
    _$hash = $jc(_$hash, sequential.hashCode);
    _$hash = $jc(_$hash, firstLastMetadataAssist.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, errorCode.hashCode);
    _$hash = $jc(_$hash, errorDetail.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jc(_$hash, tags.hashCode);
    _$hash = $jc(_$hash, sourceState.hashCode);
    _$hash = $jc(_$hash, transferState.hashCode);
    _$hash = $jc(_$hash, importState.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Download')
          ..add('id', id)
          ..add('libraryId', libraryId)
          ..add('ownerId', ownerId)
          ..add('name', name)
          ..add('state', state)
          ..add('selectedBytes', selectedBytes)
          ..add('downloadedSelectedBytes', downloadedSelectedBytes)
          ..add('torrentBytes', torrentBytes)
          ..add('downloadBps', downloadBps)
          ..add('uploadBps', uploadBps)
          ..add('seedersConnected', seedersConnected)
          ..add('peersConnected', peersConnected)
          ..add('etaSeconds', etaSeconds)
          ..add('sequential', sequential)
          ..add('firstLastMetadataAssist', firstLastMetadataAssist)
          ..add('generation', generation)
          ..add('version', version)
          ..add('errorCode', errorCode)
          ..add('errorDetail', errorDetail)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt)
          ..add('tags', tags)
          ..add('sourceState', sourceState)
          ..add('transferState', transferState)
          ..add('importState', importState))
        .toString();
  }
}

class DownloadBuilder implements Builder<Download, DownloadBuilder> {
  _$Download? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _libraryId;
  String? get libraryId => _$this._libraryId;
  set libraryId(String? libraryId) => _$this._libraryId = libraryId;

  String? _ownerId;
  String? get ownerId => _$this._ownerId;
  set ownerId(String? ownerId) => _$this._ownerId = ownerId;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  DownloadStateEnum? _state;
  DownloadStateEnum? get state => _$this._state;
  set state(DownloadStateEnum? state) => _$this._state = state;

  int? _selectedBytes;
  int? get selectedBytes => _$this._selectedBytes;
  set selectedBytes(int? selectedBytes) =>
      _$this._selectedBytes = selectedBytes;

  int? _downloadedSelectedBytes;
  int? get downloadedSelectedBytes => _$this._downloadedSelectedBytes;
  set downloadedSelectedBytes(int? downloadedSelectedBytes) =>
      _$this._downloadedSelectedBytes = downloadedSelectedBytes;

  int? _torrentBytes;
  int? get torrentBytes => _$this._torrentBytes;
  set torrentBytes(int? torrentBytes) => _$this._torrentBytes = torrentBytes;

  int? _downloadBps;
  int? get downloadBps => _$this._downloadBps;
  set downloadBps(int? downloadBps) => _$this._downloadBps = downloadBps;

  int? _uploadBps;
  int? get uploadBps => _$this._uploadBps;
  set uploadBps(int? uploadBps) => _$this._uploadBps = uploadBps;

  int? _seedersConnected;
  int? get seedersConnected => _$this._seedersConnected;
  set seedersConnected(int? seedersConnected) =>
      _$this._seedersConnected = seedersConnected;

  int? _peersConnected;
  int? get peersConnected => _$this._peersConnected;
  set peersConnected(int? peersConnected) =>
      _$this._peersConnected = peersConnected;

  int? _etaSeconds;
  int? get etaSeconds => _$this._etaSeconds;
  set etaSeconds(int? etaSeconds) => _$this._etaSeconds = etaSeconds;

  bool? _sequential;
  bool? get sequential => _$this._sequential;
  set sequential(bool? sequential) => _$this._sequential = sequential;

  bool? _firstLastMetadataAssist;
  bool? get firstLastMetadataAssist => _$this._firstLastMetadataAssist;
  set firstLastMetadataAssist(bool? firstLastMetadataAssist) =>
      _$this._firstLastMetadataAssist = firstLastMetadataAssist;

  String? _generation;
  String? get generation => _$this._generation;
  set generation(String? generation) => _$this._generation = generation;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  String? _errorCode;
  String? get errorCode => _$this._errorCode;
  set errorCode(String? errorCode) => _$this._errorCode = errorCode;

  String? _errorDetail;
  String? get errorDetail => _$this._errorDetail;
  set errorDetail(String? errorDetail) => _$this._errorDetail = errorDetail;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  ListBuilder<String>? _tags;
  ListBuilder<String> get tags => _$this._tags ??= ListBuilder<String>();
  set tags(ListBuilder<String>? tags) => _$this._tags = tags;

  DownloadSourceStateEnum? _sourceState;
  DownloadSourceStateEnum? get sourceState => _$this._sourceState;
  set sourceState(DownloadSourceStateEnum? sourceState) =>
      _$this._sourceState = sourceState;

  DownloadTransferStateEnum? _transferState;
  DownloadTransferStateEnum? get transferState => _$this._transferState;
  set transferState(DownloadTransferStateEnum? transferState) =>
      _$this._transferState = transferState;

  DownloadImportStateEnum? _importState;
  DownloadImportStateEnum? get importState => _$this._importState;
  set importState(DownloadImportStateEnum? importState) =>
      _$this._importState = importState;

  DownloadBuilder() {
    Download._defaults(this);
  }

  DownloadBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _libraryId = $v.libraryId;
      _ownerId = $v.ownerId;
      _name = $v.name;
      _state = $v.state;
      _selectedBytes = $v.selectedBytes;
      _downloadedSelectedBytes = $v.downloadedSelectedBytes;
      _torrentBytes = $v.torrentBytes;
      _downloadBps = $v.downloadBps;
      _uploadBps = $v.uploadBps;
      _seedersConnected = $v.seedersConnected;
      _peersConnected = $v.peersConnected;
      _etaSeconds = $v.etaSeconds;
      _sequential = $v.sequential;
      _firstLastMetadataAssist = $v.firstLastMetadataAssist;
      _generation = $v.generation;
      _version = $v.version;
      _errorCode = $v.errorCode;
      _errorDetail = $v.errorDetail;
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _tags = $v.tags.toBuilder();
      _sourceState = $v.sourceState;
      _transferState = $v.transferState;
      _importState = $v.importState;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Download other) {
    _$v = other as _$Download;
  }

  @override
  void update(void Function(DownloadBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Download build() => _build();

  _$Download _build() {
    _$Download _$result;
    try {
      _$result = _$v ??
          _$Download._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'Download', 'id'),
            libraryId: BuiltValueNullFieldError.checkNotNull(
                libraryId, r'Download', 'libraryId'),
            ownerId: BuiltValueNullFieldError.checkNotNull(
                ownerId, r'Download', 'ownerId'),
            name: name,
            state: BuiltValueNullFieldError.checkNotNull(
                state, r'Download', 'state'),
            selectedBytes: selectedBytes,
            downloadedSelectedBytes: BuiltValueNullFieldError.checkNotNull(
                downloadedSelectedBytes,
                r'Download',
                'downloadedSelectedBytes'),
            torrentBytes: torrentBytes,
            downloadBps: BuiltValueNullFieldError.checkNotNull(
                downloadBps, r'Download', 'downloadBps'),
            uploadBps: BuiltValueNullFieldError.checkNotNull(
                uploadBps, r'Download', 'uploadBps'),
            seedersConnected: seedersConnected,
            peersConnected: peersConnected,
            etaSeconds: etaSeconds,
            sequential: BuiltValueNullFieldError.checkNotNull(
                sequential, r'Download', 'sequential'),
            firstLastMetadataAssist: BuiltValueNullFieldError.checkNotNull(
                firstLastMetadataAssist,
                r'Download',
                'firstLastMetadataAssist'),
            generation: BuiltValueNullFieldError.checkNotNull(
                generation, r'Download', 'generation'),
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'Download', 'version'),
            errorCode: errorCode,
            errorDetail: errorDetail,
            createdAt: BuiltValueNullFieldError.checkNotNull(
                createdAt, r'Download', 'createdAt'),
            updatedAt: BuiltValueNullFieldError.checkNotNull(
                updatedAt, r'Download', 'updatedAt'),
            tags: tags.build(),
            sourceState: BuiltValueNullFieldError.checkNotNull(
                sourceState, r'Download', 'sourceState'),
            transferState: BuiltValueNullFieldError.checkNotNull(
                transferState, r'Download', 'transferState'),
            importState: BuiltValueNullFieldError.checkNotNull(
                importState, r'Download', 'importState'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'tags';
        tags.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'Download', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

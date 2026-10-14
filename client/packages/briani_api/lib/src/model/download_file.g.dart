// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_file.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DownloadFileKindEnum _$downloadFileKindEnum_video =
    const DownloadFileKindEnum._('video');
const DownloadFileKindEnum _$downloadFileKindEnum_photo =
    const DownloadFileKindEnum._('photo');
const DownloadFileKindEnum _$downloadFileKindEnum_subtitle =
    const DownloadFileKindEnum._('subtitle');
const DownloadFileKindEnum _$downloadFileKindEnum_other =
    const DownloadFileKindEnum._('other');

DownloadFileKindEnum _$downloadFileKindEnumValueOf(String name) {
  switch (name) {
    case 'video':
      return _$downloadFileKindEnum_video;
    case 'photo':
      return _$downloadFileKindEnum_photo;
    case 'subtitle':
      return _$downloadFileKindEnum_subtitle;
    case 'other':
      return _$downloadFileKindEnum_other;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadFileKindEnum> _$downloadFileKindEnumValues =
    BuiltSet<DownloadFileKindEnum>(const <DownloadFileKindEnum>[
  _$downloadFileKindEnum_video,
  _$downloadFileKindEnum_photo,
  _$downloadFileKindEnum_subtitle,
  _$downloadFileKindEnum_other,
]);

const DownloadFilePriorityEnum _$downloadFilePriorityEnum_normal =
    const DownloadFilePriorityEnum._('normal');
const DownloadFilePriorityEnum _$downloadFilePriorityEnum_high =
    const DownloadFilePriorityEnum._('high');
const DownloadFilePriorityEnum _$downloadFilePriorityEnum_maximum =
    const DownloadFilePriorityEnum._('maximum');

DownloadFilePriorityEnum _$downloadFilePriorityEnumValueOf(String name) {
  switch (name) {
    case 'normal':
      return _$downloadFilePriorityEnum_normal;
    case 'high':
      return _$downloadFilePriorityEnum_high;
    case 'maximum':
      return _$downloadFilePriorityEnum_maximum;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadFilePriorityEnum> _$downloadFilePriorityEnumValues =
    BuiltSet<DownloadFilePriorityEnum>(const <DownloadFilePriorityEnum>[
  _$downloadFilePriorityEnum_normal,
  _$downloadFilePriorityEnum_high,
  _$downloadFilePriorityEnum_maximum,
]);

const DownloadFilePlaybackStateEnum
    _$downloadFilePlaybackStateEnum_notSelected =
    const DownloadFilePlaybackStateEnum._('notSelected');
const DownloadFilePlaybackStateEnum
    _$downloadFilePlaybackStateEnum_metadataPending =
    const DownloadFilePlaybackStateEnum._('metadataPending');
const DownloadFilePlaybackStateEnum
    _$downloadFilePlaybackStateEnum_waitingForData =
    const DownloadFilePlaybackStateEnum._('waitingForData');
const DownloadFilePlaybackStateEnum _$downloadFilePlaybackStateEnum_eligible =
    const DownloadFilePlaybackStateEnum._('eligible');
const DownloadFilePlaybackStateEnum _$downloadFilePlaybackStateEnum_complete =
    const DownloadFilePlaybackStateEnum._('complete');
const DownloadFilePlaybackStateEnum
    _$downloadFilePlaybackStateEnum_unsupported =
    const DownloadFilePlaybackStateEnum._('unsupported');
const DownloadFilePlaybackStateEnum
    _$downloadFilePlaybackStateEnum_unavailable =
    const DownloadFilePlaybackStateEnum._('unavailable');

DownloadFilePlaybackStateEnum _$downloadFilePlaybackStateEnumValueOf(
    String name) {
  switch (name) {
    case 'notSelected':
      return _$downloadFilePlaybackStateEnum_notSelected;
    case 'metadataPending':
      return _$downloadFilePlaybackStateEnum_metadataPending;
    case 'waitingForData':
      return _$downloadFilePlaybackStateEnum_waitingForData;
    case 'eligible':
      return _$downloadFilePlaybackStateEnum_eligible;
    case 'complete':
      return _$downloadFilePlaybackStateEnum_complete;
    case 'unsupported':
      return _$downloadFilePlaybackStateEnum_unsupported;
    case 'unavailable':
      return _$downloadFilePlaybackStateEnum_unavailable;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadFilePlaybackStateEnum>
    _$downloadFilePlaybackStateEnumValues = BuiltSet<
        DownloadFilePlaybackStateEnum>(const <DownloadFilePlaybackStateEnum>[
  _$downloadFilePlaybackStateEnum_notSelected,
  _$downloadFilePlaybackStateEnum_metadataPending,
  _$downloadFilePlaybackStateEnum_waitingForData,
  _$downloadFilePlaybackStateEnum_eligible,
  _$downloadFilePlaybackStateEnum_complete,
  _$downloadFilePlaybackStateEnum_unsupported,
  _$downloadFilePlaybackStateEnum_unavailable,
]);

Serializer<DownloadFileKindEnum> _$downloadFileKindEnumSerializer =
    _$DownloadFileKindEnumSerializer();
Serializer<DownloadFilePriorityEnum> _$downloadFilePriorityEnumSerializer =
    _$DownloadFilePriorityEnumSerializer();
Serializer<DownloadFilePlaybackStateEnum>
    _$downloadFilePlaybackStateEnumSerializer =
    _$DownloadFilePlaybackStateEnumSerializer();

class _$DownloadFileKindEnumSerializer
    implements PrimitiveSerializer<DownloadFileKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'video': 'video',
    'photo': 'photo',
    'subtitle': 'subtitle',
    'other': 'other',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'video': 'video',
    'photo': 'photo',
    'subtitle': 'subtitle',
    'other': 'other',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadFileKindEnum];
  @override
  final String wireName = 'DownloadFileKindEnum';

  @override
  Object serialize(Serializers serializers, DownloadFileKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadFileKindEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadFileKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadFilePriorityEnumSerializer
    implements PrimitiveSerializer<DownloadFilePriorityEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'normal': 'normal',
    'high': 'high',
    'maximum': 'maximum',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'normal': 'normal',
    'high': 'high',
    'maximum': 'maximum',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadFilePriorityEnum];
  @override
  final String wireName = 'DownloadFilePriorityEnum';

  @override
  Object serialize(Serializers serializers, DownloadFilePriorityEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadFilePriorityEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadFilePriorityEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadFilePlaybackStateEnumSerializer
    implements PrimitiveSerializer<DownloadFilePlaybackStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'notSelected': 'notSelected',
    'metadataPending': 'metadataPending',
    'waitingForData': 'waitingForData',
    'eligible': 'eligible',
    'complete': 'complete',
    'unsupported': 'unsupported',
    'unavailable': 'unavailable',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'notSelected': 'notSelected',
    'metadataPending': 'metadataPending',
    'waitingForData': 'waitingForData',
    'eligible': 'eligible',
    'complete': 'complete',
    'unsupported': 'unsupported',
    'unavailable': 'unavailable',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadFilePlaybackStateEnum];
  @override
  final String wireName = 'DownloadFilePlaybackStateEnum';

  @override
  Object serialize(
          Serializers serializers, DownloadFilePlaybackStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadFilePlaybackStateEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadFilePlaybackStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadFile extends DownloadFile {
  @override
  final String id;
  @override
  final String downloadId;
  @override
  final String name;
  @override
  final String relativePath;
  @override
  final int sizeBytes;
  @override
  final int downloadedBytes;
  @override
  final int contiguousBytes;
  @override
  final DownloadFileKindEnum kind;
  @override
  final bool selected;
  @override
  final DownloadFilePriorityEnum priority;
  @override
  final DownloadFilePlaybackStateEnum playbackState;
  @override
  final String? importedMediaId;
  @override
  final int version;

  factory _$DownloadFile([void Function(DownloadFileBuilder)? updates]) =>
      (DownloadFileBuilder()..update(updates))._build();

  _$DownloadFile._(
      {required this.id,
      required this.downloadId,
      required this.name,
      required this.relativePath,
      required this.sizeBytes,
      required this.downloadedBytes,
      required this.contiguousBytes,
      required this.kind,
      required this.selected,
      required this.priority,
      required this.playbackState,
      this.importedMediaId,
      required this.version})
      : super._();
  @override
  DownloadFile rebuild(void Function(DownloadFileBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadFileBuilder toBuilder() => DownloadFileBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadFile &&
        id == other.id &&
        downloadId == other.downloadId &&
        name == other.name &&
        relativePath == other.relativePath &&
        sizeBytes == other.sizeBytes &&
        downloadedBytes == other.downloadedBytes &&
        contiguousBytes == other.contiguousBytes &&
        kind == other.kind &&
        selected == other.selected &&
        priority == other.priority &&
        playbackState == other.playbackState &&
        importedMediaId == other.importedMediaId &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, downloadId.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, relativePath.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jc(_$hash, downloadedBytes.hashCode);
    _$hash = $jc(_$hash, contiguousBytes.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, selected.hashCode);
    _$hash = $jc(_$hash, priority.hashCode);
    _$hash = $jc(_$hash, playbackState.hashCode);
    _$hash = $jc(_$hash, importedMediaId.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DownloadFile')
          ..add('id', id)
          ..add('downloadId', downloadId)
          ..add('name', name)
          ..add('relativePath', relativePath)
          ..add('sizeBytes', sizeBytes)
          ..add('downloadedBytes', downloadedBytes)
          ..add('contiguousBytes', contiguousBytes)
          ..add('kind', kind)
          ..add('selected', selected)
          ..add('priority', priority)
          ..add('playbackState', playbackState)
          ..add('importedMediaId', importedMediaId)
          ..add('version', version))
        .toString();
  }
}

class DownloadFileBuilder
    implements Builder<DownloadFile, DownloadFileBuilder> {
  _$DownloadFile? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _downloadId;
  String? get downloadId => _$this._downloadId;
  set downloadId(String? downloadId) => _$this._downloadId = downloadId;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _relativePath;
  String? get relativePath => _$this._relativePath;
  set relativePath(String? relativePath) => _$this._relativePath = relativePath;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  int? _downloadedBytes;
  int? get downloadedBytes => _$this._downloadedBytes;
  set downloadedBytes(int? downloadedBytes) =>
      _$this._downloadedBytes = downloadedBytes;

  int? _contiguousBytes;
  int? get contiguousBytes => _$this._contiguousBytes;
  set contiguousBytes(int? contiguousBytes) =>
      _$this._contiguousBytes = contiguousBytes;

  DownloadFileKindEnum? _kind;
  DownloadFileKindEnum? get kind => _$this._kind;
  set kind(DownloadFileKindEnum? kind) => _$this._kind = kind;

  bool? _selected;
  bool? get selected => _$this._selected;
  set selected(bool? selected) => _$this._selected = selected;

  DownloadFilePriorityEnum? _priority;
  DownloadFilePriorityEnum? get priority => _$this._priority;
  set priority(DownloadFilePriorityEnum? priority) =>
      _$this._priority = priority;

  DownloadFilePlaybackStateEnum? _playbackState;
  DownloadFilePlaybackStateEnum? get playbackState => _$this._playbackState;
  set playbackState(DownloadFilePlaybackStateEnum? playbackState) =>
      _$this._playbackState = playbackState;

  String? _importedMediaId;
  String? get importedMediaId => _$this._importedMediaId;
  set importedMediaId(String? importedMediaId) =>
      _$this._importedMediaId = importedMediaId;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  DownloadFileBuilder() {
    DownloadFile._defaults(this);
  }

  DownloadFileBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _downloadId = $v.downloadId;
      _name = $v.name;
      _relativePath = $v.relativePath;
      _sizeBytes = $v.sizeBytes;
      _downloadedBytes = $v.downloadedBytes;
      _contiguousBytes = $v.contiguousBytes;
      _kind = $v.kind;
      _selected = $v.selected;
      _priority = $v.priority;
      _playbackState = $v.playbackState;
      _importedMediaId = $v.importedMediaId;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadFile other) {
    _$v = other as _$DownloadFile;
  }

  @override
  void update(void Function(DownloadFileBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadFile build() => _build();

  _$DownloadFile _build() {
    final _$result = _$v ??
        _$DownloadFile._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'DownloadFile', 'id'),
          downloadId: BuiltValueNullFieldError.checkNotNull(
              downloadId, r'DownloadFile', 'downloadId'),
          name: BuiltValueNullFieldError.checkNotNull(
              name, r'DownloadFile', 'name'),
          relativePath: BuiltValueNullFieldError.checkNotNull(
              relativePath, r'DownloadFile', 'relativePath'),
          sizeBytes: BuiltValueNullFieldError.checkNotNull(
              sizeBytes, r'DownloadFile', 'sizeBytes'),
          downloadedBytes: BuiltValueNullFieldError.checkNotNull(
              downloadedBytes, r'DownloadFile', 'downloadedBytes'),
          contiguousBytes: BuiltValueNullFieldError.checkNotNull(
              contiguousBytes, r'DownloadFile', 'contiguousBytes'),
          kind: BuiltValueNullFieldError.checkNotNull(
              kind, r'DownloadFile', 'kind'),
          selected: BuiltValueNullFieldError.checkNotNull(
              selected, r'DownloadFile', 'selected'),
          priority: BuiltValueNullFieldError.checkNotNull(
              priority, r'DownloadFile', 'priority'),
          playbackState: BuiltValueNullFieldError.checkNotNull(
              playbackState, r'DownloadFile', 'playbackState'),
          importedMediaId: importedMediaId,
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'DownloadFile', 'version'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

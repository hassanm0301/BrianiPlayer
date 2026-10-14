// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const EntryKindEnum _$entryKindEnum_folder = const EntryKindEnum._('folder');
const EntryKindEnum _$entryKindEnum_video = const EntryKindEnum._('video');
const EntryKindEnum _$entryKindEnum_photo = const EntryKindEnum._('photo');
const EntryKindEnum _$entryKindEnum_subtitle =
    const EntryKindEnum._('subtitle');

EntryKindEnum _$entryKindEnumValueOf(String name) {
  switch (name) {
    case 'folder':
      return _$entryKindEnum_folder;
    case 'video':
      return _$entryKindEnum_video;
    case 'photo':
      return _$entryKindEnum_photo;
    case 'subtitle':
      return _$entryKindEnum_subtitle;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<EntryKindEnum> _$entryKindEnumValues =
    BuiltSet<EntryKindEnum>(const <EntryKindEnum>[
  _$entryKindEnum_folder,
  _$entryKindEnum_video,
  _$entryKindEnum_photo,
  _$entryKindEnum_subtitle,
]);

Serializer<EntryKindEnum> _$entryKindEnumSerializer =
    _$EntryKindEnumSerializer();

class _$EntryKindEnumSerializer implements PrimitiveSerializer<EntryKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'folder': 'folder',
    'video': 'video',
    'photo': 'photo',
    'subtitle': 'subtitle',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'folder': 'folder',
    'video': 'video',
    'photo': 'photo',
    'subtitle': 'subtitle',
  };

  @override
  final Iterable<Type> types = const <Type>[EntryKindEnum];
  @override
  final String wireName = 'EntryKindEnum';

  @override
  Object serialize(Serializers serializers, EntryKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  EntryKindEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      EntryKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Entry extends Entry {
  @override
  final String id;
  @override
  final String libraryId;
  @override
  final String? parentId;
  @override
  final EntryKindEnum kind;
  @override
  final String name;
  @override
  final int? sizeBytes;
  @override
  final DateTime? modifiedAt;
  @override
  final String? mediaId;
  @override
  final bool thumbnailAvailable;
  @override
  final int version;

  factory _$Entry([void Function(EntryBuilder)? updates]) =>
      (EntryBuilder()..update(updates))._build();

  _$Entry._(
      {required this.id,
      required this.libraryId,
      this.parentId,
      required this.kind,
      required this.name,
      this.sizeBytes,
      this.modifiedAt,
      this.mediaId,
      required this.thumbnailAvailable,
      required this.version})
      : super._();
  @override
  Entry rebuild(void Function(EntryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EntryBuilder toBuilder() => EntryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Entry &&
        id == other.id &&
        libraryId == other.libraryId &&
        parentId == other.parentId &&
        kind == other.kind &&
        name == other.name &&
        sizeBytes == other.sizeBytes &&
        modifiedAt == other.modifiedAt &&
        mediaId == other.mediaId &&
        thumbnailAvailable == other.thumbnailAvailable &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, libraryId.hashCode);
    _$hash = $jc(_$hash, parentId.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jc(_$hash, modifiedAt.hashCode);
    _$hash = $jc(_$hash, mediaId.hashCode);
    _$hash = $jc(_$hash, thumbnailAvailable.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Entry')
          ..add('id', id)
          ..add('libraryId', libraryId)
          ..add('parentId', parentId)
          ..add('kind', kind)
          ..add('name', name)
          ..add('sizeBytes', sizeBytes)
          ..add('modifiedAt', modifiedAt)
          ..add('mediaId', mediaId)
          ..add('thumbnailAvailable', thumbnailAvailable)
          ..add('version', version))
        .toString();
  }
}

class EntryBuilder implements Builder<Entry, EntryBuilder> {
  _$Entry? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _libraryId;
  String? get libraryId => _$this._libraryId;
  set libraryId(String? libraryId) => _$this._libraryId = libraryId;

  String? _parentId;
  String? get parentId => _$this._parentId;
  set parentId(String? parentId) => _$this._parentId = parentId;

  EntryKindEnum? _kind;
  EntryKindEnum? get kind => _$this._kind;
  set kind(EntryKindEnum? kind) => _$this._kind = kind;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  DateTime? _modifiedAt;
  DateTime? get modifiedAt => _$this._modifiedAt;
  set modifiedAt(DateTime? modifiedAt) => _$this._modifiedAt = modifiedAt;

  String? _mediaId;
  String? get mediaId => _$this._mediaId;
  set mediaId(String? mediaId) => _$this._mediaId = mediaId;

  bool? _thumbnailAvailable;
  bool? get thumbnailAvailable => _$this._thumbnailAvailable;
  set thumbnailAvailable(bool? thumbnailAvailable) =>
      _$this._thumbnailAvailable = thumbnailAvailable;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  EntryBuilder() {
    Entry._defaults(this);
  }

  EntryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _libraryId = $v.libraryId;
      _parentId = $v.parentId;
      _kind = $v.kind;
      _name = $v.name;
      _sizeBytes = $v.sizeBytes;
      _modifiedAt = $v.modifiedAt;
      _mediaId = $v.mediaId;
      _thumbnailAvailable = $v.thumbnailAvailable;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Entry other) {
    _$v = other as _$Entry;
  }

  @override
  void update(void Function(EntryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Entry build() => _build();

  _$Entry _build() {
    final _$result = _$v ??
        _$Entry._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'Entry', 'id'),
          libraryId: BuiltValueNullFieldError.checkNotNull(
              libraryId, r'Entry', 'libraryId'),
          parentId: parentId,
          kind: BuiltValueNullFieldError.checkNotNull(kind, r'Entry', 'kind'),
          name: BuiltValueNullFieldError.checkNotNull(name, r'Entry', 'name'),
          sizeBytes: sizeBytes,
          modifiedAt: modifiedAt,
          mediaId: mediaId,
          thumbnailAvailable: BuiltValueNullFieldError.checkNotNull(
              thumbnailAvailable, r'Entry', 'thumbnailAvailable'),
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'Entry', 'version'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

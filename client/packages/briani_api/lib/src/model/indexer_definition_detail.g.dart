// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_definition_detail.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const IndexerDefinitionDetailPrivacyEnum
    _$indexerDefinitionDetailPrivacyEnum_public =
    const IndexerDefinitionDetailPrivacyEnum._('public');
const IndexerDefinitionDetailPrivacyEnum
    _$indexerDefinitionDetailPrivacyEnum_semiPrivate =
    const IndexerDefinitionDetailPrivacyEnum._('semiPrivate');
const IndexerDefinitionDetailPrivacyEnum
    _$indexerDefinitionDetailPrivacyEnum_private =
    const IndexerDefinitionDetailPrivacyEnum._('private');
const IndexerDefinitionDetailPrivacyEnum
    _$indexerDefinitionDetailPrivacyEnum_unknown =
    const IndexerDefinitionDetailPrivacyEnum._('unknown');

IndexerDefinitionDetailPrivacyEnum _$indexerDefinitionDetailPrivacyEnumValueOf(
    String name) {
  switch (name) {
    case 'public':
      return _$indexerDefinitionDetailPrivacyEnum_public;
    case 'semiPrivate':
      return _$indexerDefinitionDetailPrivacyEnum_semiPrivate;
    case 'private':
      return _$indexerDefinitionDetailPrivacyEnum_private;
    case 'unknown':
      return _$indexerDefinitionDetailPrivacyEnum_unknown;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<IndexerDefinitionDetailPrivacyEnum>
    _$indexerDefinitionDetailPrivacyEnumValues = BuiltSet<
        IndexerDefinitionDetailPrivacyEnum>(const <IndexerDefinitionDetailPrivacyEnum>[
  _$indexerDefinitionDetailPrivacyEnum_public,
  _$indexerDefinitionDetailPrivacyEnum_semiPrivate,
  _$indexerDefinitionDetailPrivacyEnum_private,
  _$indexerDefinitionDetailPrivacyEnum_unknown,
]);

Serializer<IndexerDefinitionDetailPrivacyEnum>
    _$indexerDefinitionDetailPrivacyEnumSerializer =
    _$IndexerDefinitionDetailPrivacyEnumSerializer();

class _$IndexerDefinitionDetailPrivacyEnumSerializer
    implements PrimitiveSerializer<IndexerDefinitionDetailPrivacyEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'public': 'public',
    'semiPrivate': 'semiPrivate',
    'private': 'private',
    'unknown': 'unknown',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'public': 'public',
    'semiPrivate': 'semiPrivate',
    'private': 'private',
    'unknown': 'unknown',
  };

  @override
  final Iterable<Type> types = const <Type>[IndexerDefinitionDetailPrivacyEnum];
  @override
  final String wireName = 'IndexerDefinitionDetailPrivacyEnum';

  @override
  Object serialize(
          Serializers serializers, IndexerDefinitionDetailPrivacyEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  IndexerDefinitionDetailPrivacyEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      IndexerDefinitionDetailPrivacyEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$IndexerDefinitionDetail extends IndexerDefinitionDetail {
  @override
  final String key;
  @override
  final String name;
  @override
  final String description;
  @override
  final IndexerDefinitionDetailPrivacyEnum privacy;
  @override
  final bool addable;
  @override
  final String? setupNote;
  @override
  final BuiltList<IndexerSettingField> fields;

  factory _$IndexerDefinitionDetail(
          [void Function(IndexerDefinitionDetailBuilder)? updates]) =>
      (IndexerDefinitionDetailBuilder()..update(updates))._build();

  _$IndexerDefinitionDetail._(
      {required this.key,
      required this.name,
      required this.description,
      required this.privacy,
      required this.addable,
      this.setupNote,
      required this.fields})
      : super._();
  @override
  IndexerDefinitionDetail rebuild(
          void Function(IndexerDefinitionDetailBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IndexerDefinitionDetailBuilder toBuilder() =>
      IndexerDefinitionDetailBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IndexerDefinitionDetail &&
        key == other.key &&
        name == other.name &&
        description == other.description &&
        privacy == other.privacy &&
        addable == other.addable &&
        setupNote == other.setupNote &&
        fields == other.fields;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, key.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, privacy.hashCode);
    _$hash = $jc(_$hash, addable.hashCode);
    _$hash = $jc(_$hash, setupNote.hashCode);
    _$hash = $jc(_$hash, fields.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IndexerDefinitionDetail')
          ..add('key', key)
          ..add('name', name)
          ..add('description', description)
          ..add('privacy', privacy)
          ..add('addable', addable)
          ..add('setupNote', setupNote)
          ..add('fields', fields))
        .toString();
  }
}

class IndexerDefinitionDetailBuilder
    implements
        Builder<IndexerDefinitionDetail, IndexerDefinitionDetailBuilder> {
  _$IndexerDefinitionDetail? _$v;

  String? _key;
  String? get key => _$this._key;
  set key(String? key) => _$this._key = key;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  IndexerDefinitionDetailPrivacyEnum? _privacy;
  IndexerDefinitionDetailPrivacyEnum? get privacy => _$this._privacy;
  set privacy(IndexerDefinitionDetailPrivacyEnum? privacy) =>
      _$this._privacy = privacy;

  bool? _addable;
  bool? get addable => _$this._addable;
  set addable(bool? addable) => _$this._addable = addable;

  String? _setupNote;
  String? get setupNote => _$this._setupNote;
  set setupNote(String? setupNote) => _$this._setupNote = setupNote;

  ListBuilder<IndexerSettingField>? _fields;
  ListBuilder<IndexerSettingField> get fields =>
      _$this._fields ??= ListBuilder<IndexerSettingField>();
  set fields(ListBuilder<IndexerSettingField>? fields) =>
      _$this._fields = fields;

  IndexerDefinitionDetailBuilder() {
    IndexerDefinitionDetail._defaults(this);
  }

  IndexerDefinitionDetailBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _key = $v.key;
      _name = $v.name;
      _description = $v.description;
      _privacy = $v.privacy;
      _addable = $v.addable;
      _setupNote = $v.setupNote;
      _fields = $v.fields.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IndexerDefinitionDetail other) {
    _$v = other as _$IndexerDefinitionDetail;
  }

  @override
  void update(void Function(IndexerDefinitionDetailBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IndexerDefinitionDetail build() => _build();

  _$IndexerDefinitionDetail _build() {
    _$IndexerDefinitionDetail _$result;
    try {
      _$result = _$v ??
          _$IndexerDefinitionDetail._(
            key: BuiltValueNullFieldError.checkNotNull(
                key, r'IndexerDefinitionDetail', 'key'),
            name: BuiltValueNullFieldError.checkNotNull(
                name, r'IndexerDefinitionDetail', 'name'),
            description: BuiltValueNullFieldError.checkNotNull(
                description, r'IndexerDefinitionDetail', 'description'),
            privacy: BuiltValueNullFieldError.checkNotNull(
                privacy, r'IndexerDefinitionDetail', 'privacy'),
            addable: BuiltValueNullFieldError.checkNotNull(
                addable, r'IndexerDefinitionDetail', 'addable'),
            setupNote: setupNote,
            fields: fields.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'fields';
        fields.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'IndexerDefinitionDetail', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

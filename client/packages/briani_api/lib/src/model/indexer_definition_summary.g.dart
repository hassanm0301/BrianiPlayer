// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_definition_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const IndexerDefinitionSummaryPrivacyEnum
    _$indexerDefinitionSummaryPrivacyEnum_public =
    const IndexerDefinitionSummaryPrivacyEnum._('public');
const IndexerDefinitionSummaryPrivacyEnum
    _$indexerDefinitionSummaryPrivacyEnum_semiPrivate =
    const IndexerDefinitionSummaryPrivacyEnum._('semiPrivate');
const IndexerDefinitionSummaryPrivacyEnum
    _$indexerDefinitionSummaryPrivacyEnum_private =
    const IndexerDefinitionSummaryPrivacyEnum._('private');
const IndexerDefinitionSummaryPrivacyEnum
    _$indexerDefinitionSummaryPrivacyEnum_unknown =
    const IndexerDefinitionSummaryPrivacyEnum._('unknown');

IndexerDefinitionSummaryPrivacyEnum
    _$indexerDefinitionSummaryPrivacyEnumValueOf(String name) {
  switch (name) {
    case 'public':
      return _$indexerDefinitionSummaryPrivacyEnum_public;
    case 'semiPrivate':
      return _$indexerDefinitionSummaryPrivacyEnum_semiPrivate;
    case 'private':
      return _$indexerDefinitionSummaryPrivacyEnum_private;
    case 'unknown':
      return _$indexerDefinitionSummaryPrivacyEnum_unknown;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<IndexerDefinitionSummaryPrivacyEnum>
    _$indexerDefinitionSummaryPrivacyEnumValues = BuiltSet<
        IndexerDefinitionSummaryPrivacyEnum>(const <IndexerDefinitionSummaryPrivacyEnum>[
  _$indexerDefinitionSummaryPrivacyEnum_public,
  _$indexerDefinitionSummaryPrivacyEnum_semiPrivate,
  _$indexerDefinitionSummaryPrivacyEnum_private,
  _$indexerDefinitionSummaryPrivacyEnum_unknown,
]);

Serializer<IndexerDefinitionSummaryPrivacyEnum>
    _$indexerDefinitionSummaryPrivacyEnumSerializer =
    _$IndexerDefinitionSummaryPrivacyEnumSerializer();

class _$IndexerDefinitionSummaryPrivacyEnumSerializer
    implements PrimitiveSerializer<IndexerDefinitionSummaryPrivacyEnum> {
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
  final Iterable<Type> types = const <Type>[
    IndexerDefinitionSummaryPrivacyEnum
  ];
  @override
  final String wireName = 'IndexerDefinitionSummaryPrivacyEnum';

  @override
  Object serialize(
          Serializers serializers, IndexerDefinitionSummaryPrivacyEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  IndexerDefinitionSummaryPrivacyEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      IndexerDefinitionSummaryPrivacyEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$IndexerDefinitionSummary extends IndexerDefinitionSummary {
  @override
  final String key;
  @override
  final String name;
  @override
  final String description;
  @override
  final String language;
  @override
  final IndexerDefinitionSummaryPrivacyEnum privacy;
  @override
  final bool supportsSearch;
  @override
  final bool supportsRecent;
  @override
  final bool addable;
  @override
  final String? setupNote;

  factory _$IndexerDefinitionSummary(
          [void Function(IndexerDefinitionSummaryBuilder)? updates]) =>
      (IndexerDefinitionSummaryBuilder()..update(updates))._build();

  _$IndexerDefinitionSummary._(
      {required this.key,
      required this.name,
      required this.description,
      required this.language,
      required this.privacy,
      required this.supportsSearch,
      required this.supportsRecent,
      required this.addable,
      this.setupNote})
      : super._();
  @override
  IndexerDefinitionSummary rebuild(
          void Function(IndexerDefinitionSummaryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IndexerDefinitionSummaryBuilder toBuilder() =>
      IndexerDefinitionSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IndexerDefinitionSummary &&
        key == other.key &&
        name == other.name &&
        description == other.description &&
        language == other.language &&
        privacy == other.privacy &&
        supportsSearch == other.supportsSearch &&
        supportsRecent == other.supportsRecent &&
        addable == other.addable &&
        setupNote == other.setupNote;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, key.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, language.hashCode);
    _$hash = $jc(_$hash, privacy.hashCode);
    _$hash = $jc(_$hash, supportsSearch.hashCode);
    _$hash = $jc(_$hash, supportsRecent.hashCode);
    _$hash = $jc(_$hash, addable.hashCode);
    _$hash = $jc(_$hash, setupNote.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IndexerDefinitionSummary')
          ..add('key', key)
          ..add('name', name)
          ..add('description', description)
          ..add('language', language)
          ..add('privacy', privacy)
          ..add('supportsSearch', supportsSearch)
          ..add('supportsRecent', supportsRecent)
          ..add('addable', addable)
          ..add('setupNote', setupNote))
        .toString();
  }
}

class IndexerDefinitionSummaryBuilder
    implements
        Builder<IndexerDefinitionSummary, IndexerDefinitionSummaryBuilder> {
  _$IndexerDefinitionSummary? _$v;

  String? _key;
  String? get key => _$this._key;
  set key(String? key) => _$this._key = key;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  String? _language;
  String? get language => _$this._language;
  set language(String? language) => _$this._language = language;

  IndexerDefinitionSummaryPrivacyEnum? _privacy;
  IndexerDefinitionSummaryPrivacyEnum? get privacy => _$this._privacy;
  set privacy(IndexerDefinitionSummaryPrivacyEnum? privacy) =>
      _$this._privacy = privacy;

  bool? _supportsSearch;
  bool? get supportsSearch => _$this._supportsSearch;
  set supportsSearch(bool? supportsSearch) =>
      _$this._supportsSearch = supportsSearch;

  bool? _supportsRecent;
  bool? get supportsRecent => _$this._supportsRecent;
  set supportsRecent(bool? supportsRecent) =>
      _$this._supportsRecent = supportsRecent;

  bool? _addable;
  bool? get addable => _$this._addable;
  set addable(bool? addable) => _$this._addable = addable;

  String? _setupNote;
  String? get setupNote => _$this._setupNote;
  set setupNote(String? setupNote) => _$this._setupNote = setupNote;

  IndexerDefinitionSummaryBuilder() {
    IndexerDefinitionSummary._defaults(this);
  }

  IndexerDefinitionSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _key = $v.key;
      _name = $v.name;
      _description = $v.description;
      _language = $v.language;
      _privacy = $v.privacy;
      _supportsSearch = $v.supportsSearch;
      _supportsRecent = $v.supportsRecent;
      _addable = $v.addable;
      _setupNote = $v.setupNote;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IndexerDefinitionSummary other) {
    _$v = other as _$IndexerDefinitionSummary;
  }

  @override
  void update(void Function(IndexerDefinitionSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IndexerDefinitionSummary build() => _build();

  _$IndexerDefinitionSummary _build() {
    final _$result = _$v ??
        _$IndexerDefinitionSummary._(
          key: BuiltValueNullFieldError.checkNotNull(
              key, r'IndexerDefinitionSummary', 'key'),
          name: BuiltValueNullFieldError.checkNotNull(
              name, r'IndexerDefinitionSummary', 'name'),
          description: BuiltValueNullFieldError.checkNotNull(
              description, r'IndexerDefinitionSummary', 'description'),
          language: BuiltValueNullFieldError.checkNotNull(
              language, r'IndexerDefinitionSummary', 'language'),
          privacy: BuiltValueNullFieldError.checkNotNull(
              privacy, r'IndexerDefinitionSummary', 'privacy'),
          supportsSearch: BuiltValueNullFieldError.checkNotNull(
              supportsSearch, r'IndexerDefinitionSummary', 'supportsSearch'),
          supportsRecent: BuiltValueNullFieldError.checkNotNull(
              supportsRecent, r'IndexerDefinitionSummary', 'supportsRecent'),
          addable: BuiltValueNullFieldError.checkNotNull(
              addable, r'IndexerDefinitionSummary', 'addable'),
          setupNote: setupNote,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

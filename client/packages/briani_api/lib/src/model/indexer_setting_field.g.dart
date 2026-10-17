// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_setting_field.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const IndexerSettingFieldKindEnum _$indexerSettingFieldKindEnum_text =
    const IndexerSettingFieldKindEnum._('text');
const IndexerSettingFieldKindEnum _$indexerSettingFieldKindEnum_secret =
    const IndexerSettingFieldKindEnum._('secret');
const IndexerSettingFieldKindEnum _$indexerSettingFieldKindEnum_integer =
    const IndexerSettingFieldKindEnum._('integer');
const IndexerSettingFieldKindEnum _$indexerSettingFieldKindEnum_decimal =
    const IndexerSettingFieldKindEnum._('decimal');
const IndexerSettingFieldKindEnum _$indexerSettingFieldKindEnum_checkbox =
    const IndexerSettingFieldKindEnum._('checkbox');
const IndexerSettingFieldKindEnum _$indexerSettingFieldKindEnum_select =
    const IndexerSettingFieldKindEnum._('select');
const IndexerSettingFieldKindEnum _$indexerSettingFieldKindEnum_info =
    const IndexerSettingFieldKindEnum._('info');

IndexerSettingFieldKindEnum _$indexerSettingFieldKindEnumValueOf(String name) {
  switch (name) {
    case 'text':
      return _$indexerSettingFieldKindEnum_text;
    case 'secret':
      return _$indexerSettingFieldKindEnum_secret;
    case 'integer':
      return _$indexerSettingFieldKindEnum_integer;
    case 'decimal':
      return _$indexerSettingFieldKindEnum_decimal;
    case 'checkbox':
      return _$indexerSettingFieldKindEnum_checkbox;
    case 'select':
      return _$indexerSettingFieldKindEnum_select;
    case 'info':
      return _$indexerSettingFieldKindEnum_info;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<IndexerSettingFieldKindEnum>
    _$indexerSettingFieldKindEnumValues =
    BuiltSet<IndexerSettingFieldKindEnum>(const <IndexerSettingFieldKindEnum>[
  _$indexerSettingFieldKindEnum_text,
  _$indexerSettingFieldKindEnum_secret,
  _$indexerSettingFieldKindEnum_integer,
  _$indexerSettingFieldKindEnum_decimal,
  _$indexerSettingFieldKindEnum_checkbox,
  _$indexerSettingFieldKindEnum_select,
  _$indexerSettingFieldKindEnum_info,
]);

Serializer<IndexerSettingFieldKindEnum>
    _$indexerSettingFieldKindEnumSerializer =
    _$IndexerSettingFieldKindEnumSerializer();

class _$IndexerSettingFieldKindEnumSerializer
    implements PrimitiveSerializer<IndexerSettingFieldKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'text': 'text',
    'secret': 'secret',
    'integer': 'integer',
    'decimal': 'decimal',
    'checkbox': 'checkbox',
    'select': 'select',
    'info': 'info',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'text': 'text',
    'secret': 'secret',
    'integer': 'integer',
    'decimal': 'decimal',
    'checkbox': 'checkbox',
    'select': 'select',
    'info': 'info',
  };

  @override
  final Iterable<Type> types = const <Type>[IndexerSettingFieldKindEnum];
  @override
  final String wireName = 'IndexerSettingFieldKindEnum';

  @override
  Object serialize(Serializers serializers, IndexerSettingFieldKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  IndexerSettingFieldKindEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      IndexerSettingFieldKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$IndexerSettingField extends IndexerSettingField {
  @override
  final String name;
  @override
  final String label;
  @override
  final IndexerSettingFieldKindEnum kind;
  @override
  final bool advanced;
  @override
  final String? helpText;
  @override
  final String? unit;
  @override
  final String? value;
  @override
  final BuiltList<IndexerSettingOption>? options;

  factory _$IndexerSettingField(
          [void Function(IndexerSettingFieldBuilder)? updates]) =>
      (IndexerSettingFieldBuilder()..update(updates))._build();

  _$IndexerSettingField._(
      {required this.name,
      required this.label,
      required this.kind,
      required this.advanced,
      this.helpText,
      this.unit,
      this.value,
      this.options})
      : super._();
  @override
  IndexerSettingField rebuild(
          void Function(IndexerSettingFieldBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IndexerSettingFieldBuilder toBuilder() =>
      IndexerSettingFieldBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IndexerSettingField &&
        name == other.name &&
        label == other.label &&
        kind == other.kind &&
        advanced == other.advanced &&
        helpText == other.helpText &&
        unit == other.unit &&
        value == other.value &&
        options == other.options;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, advanced.hashCode);
    _$hash = $jc(_$hash, helpText.hashCode);
    _$hash = $jc(_$hash, unit.hashCode);
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jc(_$hash, options.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IndexerSettingField')
          ..add('name', name)
          ..add('label', label)
          ..add('kind', kind)
          ..add('advanced', advanced)
          ..add('helpText', helpText)
          ..add('unit', unit)
          ..add('value', value)
          ..add('options', options))
        .toString();
  }
}

class IndexerSettingFieldBuilder
    implements Builder<IndexerSettingField, IndexerSettingFieldBuilder> {
  _$IndexerSettingField? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  IndexerSettingFieldKindEnum? _kind;
  IndexerSettingFieldKindEnum? get kind => _$this._kind;
  set kind(IndexerSettingFieldKindEnum? kind) => _$this._kind = kind;

  bool? _advanced;
  bool? get advanced => _$this._advanced;
  set advanced(bool? advanced) => _$this._advanced = advanced;

  String? _helpText;
  String? get helpText => _$this._helpText;
  set helpText(String? helpText) => _$this._helpText = helpText;

  String? _unit;
  String? get unit => _$this._unit;
  set unit(String? unit) => _$this._unit = unit;

  String? _value;
  String? get value => _$this._value;
  set value(String? value) => _$this._value = value;

  ListBuilder<IndexerSettingOption>? _options;
  ListBuilder<IndexerSettingOption> get options =>
      _$this._options ??= ListBuilder<IndexerSettingOption>();
  set options(ListBuilder<IndexerSettingOption>? options) =>
      _$this._options = options;

  IndexerSettingFieldBuilder() {
    IndexerSettingField._defaults(this);
  }

  IndexerSettingFieldBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _label = $v.label;
      _kind = $v.kind;
      _advanced = $v.advanced;
      _helpText = $v.helpText;
      _unit = $v.unit;
      _value = $v.value;
      _options = $v.options?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IndexerSettingField other) {
    _$v = other as _$IndexerSettingField;
  }

  @override
  void update(void Function(IndexerSettingFieldBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IndexerSettingField build() => _build();

  _$IndexerSettingField _build() {
    _$IndexerSettingField _$result;
    try {
      _$result = _$v ??
          _$IndexerSettingField._(
            name: BuiltValueNullFieldError.checkNotNull(
                name, r'IndexerSettingField', 'name'),
            label: BuiltValueNullFieldError.checkNotNull(
                label, r'IndexerSettingField', 'label'),
            kind: BuiltValueNullFieldError.checkNotNull(
                kind, r'IndexerSettingField', 'kind'),
            advanced: BuiltValueNullFieldError.checkNotNull(
                advanced, r'IndexerSettingField', 'advanced'),
            helpText: helpText,
            unit: unit,
            value: value,
            options: _options?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'options';
        _options?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'IndexerSettingField', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

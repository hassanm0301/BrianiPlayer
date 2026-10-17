// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_setting_option.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$IndexerSettingOption extends IndexerSettingOption {
  @override
  final String value;
  @override
  final String label;

  factory _$IndexerSettingOption(
          [void Function(IndexerSettingOptionBuilder)? updates]) =>
      (IndexerSettingOptionBuilder()..update(updates))._build();

  _$IndexerSettingOption._({required this.value, required this.label})
      : super._();
  @override
  IndexerSettingOption rebuild(
          void Function(IndexerSettingOptionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IndexerSettingOptionBuilder toBuilder() =>
      IndexerSettingOptionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IndexerSettingOption &&
        value == other.value &&
        label == other.label;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IndexerSettingOption')
          ..add('value', value)
          ..add('label', label))
        .toString();
  }
}

class IndexerSettingOptionBuilder
    implements Builder<IndexerSettingOption, IndexerSettingOptionBuilder> {
  _$IndexerSettingOption? _$v;

  String? _value;
  String? get value => _$this._value;
  set value(String? value) => _$this._value = value;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  IndexerSettingOptionBuilder() {
    IndexerSettingOption._defaults(this);
  }

  IndexerSettingOptionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _value = $v.value;
      _label = $v.label;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IndexerSettingOption other) {
    _$v = other as _$IndexerSettingOption;
  }

  @override
  void update(void Function(IndexerSettingOptionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IndexerSettingOption build() => _build();

  _$IndexerSettingOption _build() {
    final _$result = _$v ??
        _$IndexerSettingOption._(
          value: BuiltValueNullFieldError.checkNotNull(
              value, r'IndexerSettingOption', 'value'),
          label: BuiltValueNullFieldError.checkNotNull(
              label, r'IndexerSettingOption', 'label'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

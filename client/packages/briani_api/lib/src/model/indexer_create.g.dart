// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_create.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$IndexerCreate extends IndexerCreate {
  @override
  final String definition;
  @override
  final String? name;
  @override
  final bool? enabled;
  @override
  final BuiltMap<String, String>? settings;

  factory _$IndexerCreate([void Function(IndexerCreateBuilder)? updates]) =>
      (IndexerCreateBuilder()..update(updates))._build();

  _$IndexerCreate._(
      {required this.definition, this.name, this.enabled, this.settings})
      : super._();
  @override
  IndexerCreate rebuild(void Function(IndexerCreateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IndexerCreateBuilder toBuilder() => IndexerCreateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IndexerCreate &&
        definition == other.definition &&
        name == other.name &&
        enabled == other.enabled &&
        settings == other.settings;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, definition.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, settings.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IndexerCreate')
          ..add('definition', definition)
          ..add('name', name)
          ..add('enabled', enabled)
          ..add('settings', settings))
        .toString();
  }
}

class IndexerCreateBuilder
    implements Builder<IndexerCreate, IndexerCreateBuilder> {
  _$IndexerCreate? _$v;

  String? _definition;
  String? get definition => _$this._definition;
  set definition(String? definition) => _$this._definition = definition;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  MapBuilder<String, String>? _settings;
  MapBuilder<String, String> get settings =>
      _$this._settings ??= MapBuilder<String, String>();
  set settings(MapBuilder<String, String>? settings) =>
      _$this._settings = settings;

  IndexerCreateBuilder() {
    IndexerCreate._defaults(this);
  }

  IndexerCreateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _definition = $v.definition;
      _name = $v.name;
      _enabled = $v.enabled;
      _settings = $v.settings?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IndexerCreate other) {
    _$v = other as _$IndexerCreate;
  }

  @override
  void update(void Function(IndexerCreateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IndexerCreate build() => _build();

  _$IndexerCreate _build() {
    _$IndexerCreate _$result;
    try {
      _$result = _$v ??
          _$IndexerCreate._(
            definition: BuiltValueNullFieldError.checkNotNull(
                definition, r'IndexerCreate', 'definition'),
            name: name,
            enabled: enabled,
            settings: _settings?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'settings';
        _settings?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'IndexerCreate', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

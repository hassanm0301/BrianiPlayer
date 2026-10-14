// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ProviderStateEnum _$providerStateEnum_healthy =
    const ProviderStateEnum._('healthy');
const ProviderStateEnum _$providerStateEnum_degraded =
    const ProviderStateEnum._('degraded');
const ProviderStateEnum _$providerStateEnum_unavailable =
    const ProviderStateEnum._('unavailable');
const ProviderStateEnum _$providerStateEnum_unknown =
    const ProviderStateEnum._('unknown');

ProviderStateEnum _$providerStateEnumValueOf(String name) {
  switch (name) {
    case 'healthy':
      return _$providerStateEnum_healthy;
    case 'degraded':
      return _$providerStateEnum_degraded;
    case 'unavailable':
      return _$providerStateEnum_unavailable;
    case 'unknown':
      return _$providerStateEnum_unknown;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ProviderStateEnum> _$providerStateEnumValues =
    BuiltSet<ProviderStateEnum>(const <ProviderStateEnum>[
  _$providerStateEnum_healthy,
  _$providerStateEnum_degraded,
  _$providerStateEnum_unavailable,
  _$providerStateEnum_unknown,
]);

Serializer<ProviderStateEnum> _$providerStateEnumSerializer =
    _$ProviderStateEnumSerializer();

class _$ProviderStateEnumSerializer
    implements PrimitiveSerializer<ProviderStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'healthy': 'healthy',
    'degraded': 'degraded',
    'unavailable': 'unavailable',
    'unknown': 'unknown',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'healthy': 'healthy',
    'degraded': 'degraded',
    'unavailable': 'unavailable',
    'unknown': 'unknown',
  };

  @override
  final Iterable<Type> types = const <Type>[ProviderStateEnum];
  @override
  final String wireName = 'ProviderStateEnum';

  @override
  Object serialize(Serializers serializers, ProviderStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  ProviderStateEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      ProviderStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Provider extends Provider {
  @override
  final String id;
  @override
  final String name;
  @override
  final bool enabled;
  @override
  final bool supportsSearch;
  @override
  final bool supportsRecent;
  @override
  final BuiltList<int> categories;
  @override
  final ProviderStateEnum state;
  @override
  final String? warning;

  factory _$Provider([void Function(ProviderBuilder)? updates]) =>
      (ProviderBuilder()..update(updates))._build();

  _$Provider._(
      {required this.id,
      required this.name,
      required this.enabled,
      required this.supportsSearch,
      required this.supportsRecent,
      required this.categories,
      required this.state,
      this.warning})
      : super._();
  @override
  Provider rebuild(void Function(ProviderBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ProviderBuilder toBuilder() => ProviderBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Provider &&
        id == other.id &&
        name == other.name &&
        enabled == other.enabled &&
        supportsSearch == other.supportsSearch &&
        supportsRecent == other.supportsRecent &&
        categories == other.categories &&
        state == other.state &&
        warning == other.warning;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, supportsSearch.hashCode);
    _$hash = $jc(_$hash, supportsRecent.hashCode);
    _$hash = $jc(_$hash, categories.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, warning.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Provider')
          ..add('id', id)
          ..add('name', name)
          ..add('enabled', enabled)
          ..add('supportsSearch', supportsSearch)
          ..add('supportsRecent', supportsRecent)
          ..add('categories', categories)
          ..add('state', state)
          ..add('warning', warning))
        .toString();
  }
}

class ProviderBuilder implements Builder<Provider, ProviderBuilder> {
  _$Provider? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  bool? _supportsSearch;
  bool? get supportsSearch => _$this._supportsSearch;
  set supportsSearch(bool? supportsSearch) =>
      _$this._supportsSearch = supportsSearch;

  bool? _supportsRecent;
  bool? get supportsRecent => _$this._supportsRecent;
  set supportsRecent(bool? supportsRecent) =>
      _$this._supportsRecent = supportsRecent;

  ListBuilder<int>? _categories;
  ListBuilder<int> get categories => _$this._categories ??= ListBuilder<int>();
  set categories(ListBuilder<int>? categories) =>
      _$this._categories = categories;

  ProviderStateEnum? _state;
  ProviderStateEnum? get state => _$this._state;
  set state(ProviderStateEnum? state) => _$this._state = state;

  String? _warning;
  String? get warning => _$this._warning;
  set warning(String? warning) => _$this._warning = warning;

  ProviderBuilder() {
    Provider._defaults(this);
  }

  ProviderBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _enabled = $v.enabled;
      _supportsSearch = $v.supportsSearch;
      _supportsRecent = $v.supportsRecent;
      _categories = $v.categories.toBuilder();
      _state = $v.state;
      _warning = $v.warning;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Provider other) {
    _$v = other as _$Provider;
  }

  @override
  void update(void Function(ProviderBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Provider build() => _build();

  _$Provider _build() {
    _$Provider _$result;
    try {
      _$result = _$v ??
          _$Provider._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'Provider', 'id'),
            name: BuiltValueNullFieldError.checkNotNull(
                name, r'Provider', 'name'),
            enabled: BuiltValueNullFieldError.checkNotNull(
                enabled, r'Provider', 'enabled'),
            supportsSearch: BuiltValueNullFieldError.checkNotNull(
                supportsSearch, r'Provider', 'supportsSearch'),
            supportsRecent: BuiltValueNullFieldError.checkNotNull(
                supportsRecent, r'Provider', 'supportsRecent'),
            categories: categories.build(),
            state: BuiltValueNullFieldError.checkNotNull(
                state, r'Provider', 'state'),
            warning: warning,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'categories';
        categories.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'Provider', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

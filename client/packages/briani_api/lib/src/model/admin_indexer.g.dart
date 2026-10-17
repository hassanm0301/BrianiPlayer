// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_indexer.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const AdminIndexerPrivacyEnum _$adminIndexerPrivacyEnum_public =
    const AdminIndexerPrivacyEnum._('public');
const AdminIndexerPrivacyEnum _$adminIndexerPrivacyEnum_semiPrivate =
    const AdminIndexerPrivacyEnum._('semiPrivate');
const AdminIndexerPrivacyEnum _$adminIndexerPrivacyEnum_private =
    const AdminIndexerPrivacyEnum._('private');
const AdminIndexerPrivacyEnum _$adminIndexerPrivacyEnum_unknown =
    const AdminIndexerPrivacyEnum._('unknown');

AdminIndexerPrivacyEnum _$adminIndexerPrivacyEnumValueOf(String name) {
  switch (name) {
    case 'public':
      return _$adminIndexerPrivacyEnum_public;
    case 'semiPrivate':
      return _$adminIndexerPrivacyEnum_semiPrivate;
    case 'private':
      return _$adminIndexerPrivacyEnum_private;
    case 'unknown':
      return _$adminIndexerPrivacyEnum_unknown;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AdminIndexerPrivacyEnum> _$adminIndexerPrivacyEnumValues =
    BuiltSet<AdminIndexerPrivacyEnum>(const <AdminIndexerPrivacyEnum>[
  _$adminIndexerPrivacyEnum_public,
  _$adminIndexerPrivacyEnum_semiPrivate,
  _$adminIndexerPrivacyEnum_private,
  _$adminIndexerPrivacyEnum_unknown,
]);

const AdminIndexerStateEnum _$adminIndexerStateEnum_healthy =
    const AdminIndexerStateEnum._('healthy');
const AdminIndexerStateEnum _$adminIndexerStateEnum_degraded =
    const AdminIndexerStateEnum._('degraded');
const AdminIndexerStateEnum _$adminIndexerStateEnum_unavailable =
    const AdminIndexerStateEnum._('unavailable');
const AdminIndexerStateEnum _$adminIndexerStateEnum_unknown =
    const AdminIndexerStateEnum._('unknown');

AdminIndexerStateEnum _$adminIndexerStateEnumValueOf(String name) {
  switch (name) {
    case 'healthy':
      return _$adminIndexerStateEnum_healthy;
    case 'degraded':
      return _$adminIndexerStateEnum_degraded;
    case 'unavailable':
      return _$adminIndexerStateEnum_unavailable;
    case 'unknown':
      return _$adminIndexerStateEnum_unknown;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<AdminIndexerStateEnum> _$adminIndexerStateEnumValues =
    BuiltSet<AdminIndexerStateEnum>(const <AdminIndexerStateEnum>[
  _$adminIndexerStateEnum_healthy,
  _$adminIndexerStateEnum_degraded,
  _$adminIndexerStateEnum_unavailable,
  _$adminIndexerStateEnum_unknown,
]);

Serializer<AdminIndexerPrivacyEnum> _$adminIndexerPrivacyEnumSerializer =
    _$AdminIndexerPrivacyEnumSerializer();
Serializer<AdminIndexerStateEnum> _$adminIndexerStateEnumSerializer =
    _$AdminIndexerStateEnumSerializer();

class _$AdminIndexerPrivacyEnumSerializer
    implements PrimitiveSerializer<AdminIndexerPrivacyEnum> {
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
  final Iterable<Type> types = const <Type>[AdminIndexerPrivacyEnum];
  @override
  final String wireName = 'AdminIndexerPrivacyEnum';

  @override
  Object serialize(Serializers serializers, AdminIndexerPrivacyEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  AdminIndexerPrivacyEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      AdminIndexerPrivacyEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$AdminIndexerStateEnumSerializer
    implements PrimitiveSerializer<AdminIndexerStateEnum> {
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
  final Iterable<Type> types = const <Type>[AdminIndexerStateEnum];
  @override
  final String wireName = 'AdminIndexerStateEnum';

  @override
  Object serialize(Serializers serializers, AdminIndexerStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  AdminIndexerStateEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      AdminIndexerStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$AdminIndexer extends AdminIndexer {
  @override
  final String id;
  @override
  final String name;
  @override
  final String definition;
  @override
  final bool enabled;
  @override
  final AdminIndexerPrivacyEnum privacy;
  @override
  final int priority;
  @override
  final bool supportsSearch;
  @override
  final bool supportsRecent;
  @override
  final AdminIndexerStateEnum state;
  @override
  final String? stateDetail;

  factory _$AdminIndexer([void Function(AdminIndexerBuilder)? updates]) =>
      (AdminIndexerBuilder()..update(updates))._build();

  _$AdminIndexer._(
      {required this.id,
      required this.name,
      required this.definition,
      required this.enabled,
      required this.privacy,
      required this.priority,
      required this.supportsSearch,
      required this.supportsRecent,
      required this.state,
      this.stateDetail})
      : super._();
  @override
  AdminIndexer rebuild(void Function(AdminIndexerBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AdminIndexerBuilder toBuilder() => AdminIndexerBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AdminIndexer &&
        id == other.id &&
        name == other.name &&
        definition == other.definition &&
        enabled == other.enabled &&
        privacy == other.privacy &&
        priority == other.priority &&
        supportsSearch == other.supportsSearch &&
        supportsRecent == other.supportsRecent &&
        state == other.state &&
        stateDetail == other.stateDetail;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, definition.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, privacy.hashCode);
    _$hash = $jc(_$hash, priority.hashCode);
    _$hash = $jc(_$hash, supportsSearch.hashCode);
    _$hash = $jc(_$hash, supportsRecent.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, stateDetail.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AdminIndexer')
          ..add('id', id)
          ..add('name', name)
          ..add('definition', definition)
          ..add('enabled', enabled)
          ..add('privacy', privacy)
          ..add('priority', priority)
          ..add('supportsSearch', supportsSearch)
          ..add('supportsRecent', supportsRecent)
          ..add('state', state)
          ..add('stateDetail', stateDetail))
        .toString();
  }
}

class AdminIndexerBuilder
    implements Builder<AdminIndexer, AdminIndexerBuilder> {
  _$AdminIndexer? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _definition;
  String? get definition => _$this._definition;
  set definition(String? definition) => _$this._definition = definition;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  AdminIndexerPrivacyEnum? _privacy;
  AdminIndexerPrivacyEnum? get privacy => _$this._privacy;
  set privacy(AdminIndexerPrivacyEnum? privacy) => _$this._privacy = privacy;

  int? _priority;
  int? get priority => _$this._priority;
  set priority(int? priority) => _$this._priority = priority;

  bool? _supportsSearch;
  bool? get supportsSearch => _$this._supportsSearch;
  set supportsSearch(bool? supportsSearch) =>
      _$this._supportsSearch = supportsSearch;

  bool? _supportsRecent;
  bool? get supportsRecent => _$this._supportsRecent;
  set supportsRecent(bool? supportsRecent) =>
      _$this._supportsRecent = supportsRecent;

  AdminIndexerStateEnum? _state;
  AdminIndexerStateEnum? get state => _$this._state;
  set state(AdminIndexerStateEnum? state) => _$this._state = state;

  String? _stateDetail;
  String? get stateDetail => _$this._stateDetail;
  set stateDetail(String? stateDetail) => _$this._stateDetail = stateDetail;

  AdminIndexerBuilder() {
    AdminIndexer._defaults(this);
  }

  AdminIndexerBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _definition = $v.definition;
      _enabled = $v.enabled;
      _privacy = $v.privacy;
      _priority = $v.priority;
      _supportsSearch = $v.supportsSearch;
      _supportsRecent = $v.supportsRecent;
      _state = $v.state;
      _stateDetail = $v.stateDetail;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AdminIndexer other) {
    _$v = other as _$AdminIndexer;
  }

  @override
  void update(void Function(AdminIndexerBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AdminIndexer build() => _build();

  _$AdminIndexer _build() {
    final _$result = _$v ??
        _$AdminIndexer._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'AdminIndexer', 'id'),
          name: BuiltValueNullFieldError.checkNotNull(
              name, r'AdminIndexer', 'name'),
          definition: BuiltValueNullFieldError.checkNotNull(
              definition, r'AdminIndexer', 'definition'),
          enabled: BuiltValueNullFieldError.checkNotNull(
              enabled, r'AdminIndexer', 'enabled'),
          privacy: BuiltValueNullFieldError.checkNotNull(
              privacy, r'AdminIndexer', 'privacy'),
          priority: BuiltValueNullFieldError.checkNotNull(
              priority, r'AdminIndexer', 'priority'),
          supportsSearch: BuiltValueNullFieldError.checkNotNull(
              supportsSearch, r'AdminIndexer', 'supportsSearch'),
          supportsRecent: BuiltValueNullFieldError.checkNotNull(
              supportsRecent, r'AdminIndexer', 'supportsRecent'),
          state: BuiltValueNullFieldError.checkNotNull(
              state, r'AdminIndexer', 'state'),
          stateDetail: stateDetail,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

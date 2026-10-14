// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_health.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const ServiceHealthStateEnum _$serviceHealthStateEnum_healthy =
    const ServiceHealthStateEnum._('healthy');
const ServiceHealthStateEnum _$serviceHealthStateEnum_degraded =
    const ServiceHealthStateEnum._('degraded');
const ServiceHealthStateEnum _$serviceHealthStateEnum_unavailable =
    const ServiceHealthStateEnum._('unavailable');
const ServiceHealthStateEnum _$serviceHealthStateEnum_unknown =
    const ServiceHealthStateEnum._('unknown');

ServiceHealthStateEnum _$serviceHealthStateEnumValueOf(String name) {
  switch (name) {
    case 'healthy':
      return _$serviceHealthStateEnum_healthy;
    case 'degraded':
      return _$serviceHealthStateEnum_degraded;
    case 'unavailable':
      return _$serviceHealthStateEnum_unavailable;
    case 'unknown':
      return _$serviceHealthStateEnum_unknown;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<ServiceHealthStateEnum> _$serviceHealthStateEnumValues =
    BuiltSet<ServiceHealthStateEnum>(const <ServiceHealthStateEnum>[
  _$serviceHealthStateEnum_healthy,
  _$serviceHealthStateEnum_degraded,
  _$serviceHealthStateEnum_unavailable,
  _$serviceHealthStateEnum_unknown,
]);

Serializer<ServiceHealthStateEnum> _$serviceHealthStateEnumSerializer =
    _$ServiceHealthStateEnumSerializer();

class _$ServiceHealthStateEnumSerializer
    implements PrimitiveSerializer<ServiceHealthStateEnum> {
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
  final Iterable<Type> types = const <Type>[ServiceHealthStateEnum];
  @override
  final String wireName = 'ServiceHealthStateEnum';

  @override
  Object serialize(Serializers serializers, ServiceHealthStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  ServiceHealthStateEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      ServiceHealthStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$ServiceHealth extends ServiceHealth {
  @override
  final String service;
  @override
  final ServiceHealthStateEnum state;
  @override
  final String? detail;
  @override
  final DateTime checkedAt;

  factory _$ServiceHealth([void Function(ServiceHealthBuilder)? updates]) =>
      (ServiceHealthBuilder()..update(updates))._build();

  _$ServiceHealth._(
      {required this.service,
      required this.state,
      this.detail,
      required this.checkedAt})
      : super._();
  @override
  ServiceHealth rebuild(void Function(ServiceHealthBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ServiceHealthBuilder toBuilder() => ServiceHealthBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ServiceHealth &&
        service == other.service &&
        state == other.state &&
        detail == other.detail &&
        checkedAt == other.checkedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, service.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, detail.hashCode);
    _$hash = $jc(_$hash, checkedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ServiceHealth')
          ..add('service', service)
          ..add('state', state)
          ..add('detail', detail)
          ..add('checkedAt', checkedAt))
        .toString();
  }
}

class ServiceHealthBuilder
    implements Builder<ServiceHealth, ServiceHealthBuilder> {
  _$ServiceHealth? _$v;

  String? _service;
  String? get service => _$this._service;
  set service(String? service) => _$this._service = service;

  ServiceHealthStateEnum? _state;
  ServiceHealthStateEnum? get state => _$this._state;
  set state(ServiceHealthStateEnum? state) => _$this._state = state;

  String? _detail;
  String? get detail => _$this._detail;
  set detail(String? detail) => _$this._detail = detail;

  DateTime? _checkedAt;
  DateTime? get checkedAt => _$this._checkedAt;
  set checkedAt(DateTime? checkedAt) => _$this._checkedAt = checkedAt;

  ServiceHealthBuilder() {
    ServiceHealth._defaults(this);
  }

  ServiceHealthBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _service = $v.service;
      _state = $v.state;
      _detail = $v.detail;
      _checkedAt = $v.checkedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ServiceHealth other) {
    _$v = other as _$ServiceHealth;
  }

  @override
  void update(void Function(ServiceHealthBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ServiceHealth build() => _build();

  _$ServiceHealth _build() {
    final _$result = _$v ??
        _$ServiceHealth._(
          service: BuiltValueNullFieldError.checkNotNull(
              service, r'ServiceHealth', 'service'),
          state: BuiltValueNullFieldError.checkNotNull(
              state, r'ServiceHealth', 'state'),
          detail: detail,
          checkedAt: BuiltValueNullFieldError.checkNotNull(
              checkedAt, r'ServiceHealth', 'checkedAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

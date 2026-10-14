// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_pending.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DevicePendingStateEnum _$devicePendingStateEnum_pending =
    const DevicePendingStateEnum._('pending');
const DevicePendingStateEnum _$devicePendingStateEnum_expired =
    const DevicePendingStateEnum._('expired');
const DevicePendingStateEnum _$devicePendingStateEnum_denied =
    const DevicePendingStateEnum._('denied');

DevicePendingStateEnum _$devicePendingStateEnumValueOf(String name) {
  switch (name) {
    case 'pending':
      return _$devicePendingStateEnum_pending;
    case 'expired':
      return _$devicePendingStateEnum_expired;
    case 'denied':
      return _$devicePendingStateEnum_denied;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DevicePendingStateEnum> _$devicePendingStateEnumValues =
    BuiltSet<DevicePendingStateEnum>(const <DevicePendingStateEnum>[
  _$devicePendingStateEnum_pending,
  _$devicePendingStateEnum_expired,
  _$devicePendingStateEnum_denied,
]);

Serializer<DevicePendingStateEnum> _$devicePendingStateEnumSerializer =
    _$DevicePendingStateEnumSerializer();

class _$DevicePendingStateEnumSerializer
    implements PrimitiveSerializer<DevicePendingStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'pending': 'pending',
    'expired': 'expired',
    'denied': 'denied',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'pending': 'pending',
    'expired': 'expired',
    'denied': 'denied',
  };

  @override
  final Iterable<Type> types = const <Type>[DevicePendingStateEnum];
  @override
  final String wireName = 'DevicePendingStateEnum';

  @override
  Object serialize(Serializers serializers, DevicePendingStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DevicePendingStateEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DevicePendingStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DevicePending extends DevicePending {
  @override
  final DevicePendingStateEnum state;
  @override
  final int? retryAfterSeconds;

  factory _$DevicePending([void Function(DevicePendingBuilder)? updates]) =>
      (DevicePendingBuilder()..update(updates))._build();

  _$DevicePending._({required this.state, this.retryAfterSeconds}) : super._();
  @override
  DevicePending rebuild(void Function(DevicePendingBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DevicePendingBuilder toBuilder() => DevicePendingBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DevicePending &&
        state == other.state &&
        retryAfterSeconds == other.retryAfterSeconds;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, retryAfterSeconds.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DevicePending')
          ..add('state', state)
          ..add('retryAfterSeconds', retryAfterSeconds))
        .toString();
  }
}

class DevicePendingBuilder
    implements Builder<DevicePending, DevicePendingBuilder> {
  _$DevicePending? _$v;

  DevicePendingStateEnum? _state;
  DevicePendingStateEnum? get state => _$this._state;
  set state(DevicePendingStateEnum? state) => _$this._state = state;

  int? _retryAfterSeconds;
  int? get retryAfterSeconds => _$this._retryAfterSeconds;
  set retryAfterSeconds(int? retryAfterSeconds) =>
      _$this._retryAfterSeconds = retryAfterSeconds;

  DevicePendingBuilder() {
    DevicePending._defaults(this);
  }

  DevicePendingBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _state = $v.state;
      _retryAfterSeconds = $v.retryAfterSeconds;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DevicePending other) {
    _$v = other as _$DevicePending;
  }

  @override
  void update(void Function(DevicePendingBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DevicePending build() => _build();

  _$DevicePending _build() {
    final _$result = _$v ??
        _$DevicePending._(
          state: BuiltValueNullFieldError.checkNotNull(
              state, r'DevicePending', 'state'),
          retryAfterSeconds: retryAfterSeconds,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

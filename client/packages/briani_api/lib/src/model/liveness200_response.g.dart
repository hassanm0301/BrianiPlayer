// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'liveness200_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const Liveness200ResponseStatusEnum _$liveness200ResponseStatusEnum_ok =
    const Liveness200ResponseStatusEnum._('ok');
const Liveness200ResponseStatusEnum
    _$liveness200ResponseStatusEnum_unavailable =
    const Liveness200ResponseStatusEnum._('unavailable');

Liveness200ResponseStatusEnum _$liveness200ResponseStatusEnumValueOf(
    String name) {
  switch (name) {
    case 'ok':
      return _$liveness200ResponseStatusEnum_ok;
    case 'unavailable':
      return _$liveness200ResponseStatusEnum_unavailable;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<Liveness200ResponseStatusEnum>
    _$liveness200ResponseStatusEnumValues = BuiltSet<
        Liveness200ResponseStatusEnum>(const <Liveness200ResponseStatusEnum>[
  _$liveness200ResponseStatusEnum_ok,
  _$liveness200ResponseStatusEnum_unavailable,
]);

Serializer<Liveness200ResponseStatusEnum>
    _$liveness200ResponseStatusEnumSerializer =
    _$Liveness200ResponseStatusEnumSerializer();

class _$Liveness200ResponseStatusEnumSerializer
    implements PrimitiveSerializer<Liveness200ResponseStatusEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'ok': 'ok',
    'unavailable': 'unavailable',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'ok': 'ok',
    'unavailable': 'unavailable',
  };

  @override
  final Iterable<Type> types = const <Type>[Liveness200ResponseStatusEnum];
  @override
  final String wireName = 'Liveness200ResponseStatusEnum';

  @override
  Object serialize(
          Serializers serializers, Liveness200ResponseStatusEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  Liveness200ResponseStatusEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      Liveness200ResponseStatusEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Liveness200Response extends Liveness200Response {
  @override
  final Liveness200ResponseStatusEnum status;

  factory _$Liveness200Response(
          [void Function(Liveness200ResponseBuilder)? updates]) =>
      (Liveness200ResponseBuilder()..update(updates))._build();

  _$Liveness200Response._({required this.status}) : super._();
  @override
  Liveness200Response rebuild(
          void Function(Liveness200ResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  Liveness200ResponseBuilder toBuilder() =>
      Liveness200ResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Liveness200Response && status == other.status;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Liveness200Response')
          ..add('status', status))
        .toString();
  }
}

class Liveness200ResponseBuilder
    implements Builder<Liveness200Response, Liveness200ResponseBuilder> {
  _$Liveness200Response? _$v;

  Liveness200ResponseStatusEnum? _status;
  Liveness200ResponseStatusEnum? get status => _$this._status;
  set status(Liveness200ResponseStatusEnum? status) => _$this._status = status;

  Liveness200ResponseBuilder() {
    Liveness200Response._defaults(this);
  }

  Liveness200ResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _status = $v.status;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Liveness200Response other) {
    _$v = other as _$Liveness200Response;
  }

  @override
  void update(void Function(Liveness200ResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Liveness200Response build() => _build();

  _$Liveness200Response _build() {
    final _$result = _$v ??
        _$Liveness200Response._(
          status: BuiltValueNullFieldError.checkNotNull(
              status, r'Liveness200Response', 'status'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

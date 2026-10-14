// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operation.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const OperationStateEnum _$operationStateEnum_pending =
    const OperationStateEnum._('pending');
const OperationStateEnum _$operationStateEnum_running =
    const OperationStateEnum._('running');
const OperationStateEnum _$operationStateEnum_completed =
    const OperationStateEnum._('completed');
const OperationStateEnum _$operationStateEnum_failed =
    const OperationStateEnum._('failed');

OperationStateEnum _$operationStateEnumValueOf(String name) {
  switch (name) {
    case 'pending':
      return _$operationStateEnum_pending;
    case 'running':
      return _$operationStateEnum_running;
    case 'completed':
      return _$operationStateEnum_completed;
    case 'failed':
      return _$operationStateEnum_failed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<OperationStateEnum> _$operationStateEnumValues =
    BuiltSet<OperationStateEnum>(const <OperationStateEnum>[
  _$operationStateEnum_pending,
  _$operationStateEnum_running,
  _$operationStateEnum_completed,
  _$operationStateEnum_failed,
]);

Serializer<OperationStateEnum> _$operationStateEnumSerializer =
    _$OperationStateEnumSerializer();

class _$OperationStateEnumSerializer
    implements PrimitiveSerializer<OperationStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'pending': 'pending',
    'running': 'running',
    'completed': 'completed',
    'failed': 'failed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'pending': 'pending',
    'running': 'running',
    'completed': 'completed',
    'failed': 'failed',
  };

  @override
  final Iterable<Type> types = const <Type>[OperationStateEnum];
  @override
  final String wireName = 'OperationStateEnum';

  @override
  Object serialize(Serializers serializers, OperationStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  OperationStateEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      OperationStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Operation extends Operation {
  @override
  final String id;
  @override
  final OperationStateEnum state;
  @override
  final String? resourceId;
  @override
  final String? resourceType;
  @override
  final Problem? error;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  factory _$Operation([void Function(OperationBuilder)? updates]) =>
      (OperationBuilder()..update(updates))._build();

  _$Operation._(
      {required this.id,
      required this.state,
      this.resourceId,
      this.resourceType,
      this.error,
      required this.createdAt,
      required this.updatedAt})
      : super._();
  @override
  Operation rebuild(void Function(OperationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  OperationBuilder toBuilder() => OperationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Operation &&
        id == other.id &&
        state == other.state &&
        resourceId == other.resourceId &&
        resourceType == other.resourceType &&
        error == other.error &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, resourceId.hashCode);
    _$hash = $jc(_$hash, resourceType.hashCode);
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Operation')
          ..add('id', id)
          ..add('state', state)
          ..add('resourceId', resourceId)
          ..add('resourceType', resourceType)
          ..add('error', error)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class OperationBuilder implements Builder<Operation, OperationBuilder> {
  _$Operation? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  OperationStateEnum? _state;
  OperationStateEnum? get state => _$this._state;
  set state(OperationStateEnum? state) => _$this._state = state;

  String? _resourceId;
  String? get resourceId => _$this._resourceId;
  set resourceId(String? resourceId) => _$this._resourceId = resourceId;

  String? _resourceType;
  String? get resourceType => _$this._resourceType;
  set resourceType(String? resourceType) => _$this._resourceType = resourceType;

  ProblemBuilder? _error;
  ProblemBuilder get error => _$this._error ??= ProblemBuilder();
  set error(ProblemBuilder? error) => _$this._error = error;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  OperationBuilder() {
    Operation._defaults(this);
  }

  OperationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _state = $v.state;
      _resourceId = $v.resourceId;
      _resourceType = $v.resourceType;
      _error = $v.error?.toBuilder();
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Operation other) {
    _$v = other as _$Operation;
  }

  @override
  void update(void Function(OperationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Operation build() => _build();

  _$Operation _build() {
    _$Operation _$result;
    try {
      _$result = _$v ??
          _$Operation._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'Operation', 'id'),
            state: BuiltValueNullFieldError.checkNotNull(
                state, r'Operation', 'state'),
            resourceId: resourceId,
            resourceType: resourceType,
            error: _error?.build(),
            createdAt: BuiltValueNullFieldError.checkNotNull(
                createdAt, r'Operation', 'createdAt'),
            updatedAt: BuiltValueNullFieldError.checkNotNull(
                updatedAt, r'Operation', 'updatedAt'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'error';
        _error?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'Operation', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_test_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const IndexerTestResultStateEnum _$indexerTestResultStateEnum_healthy =
    const IndexerTestResultStateEnum._('healthy');
const IndexerTestResultStateEnum _$indexerTestResultStateEnum_unavailable =
    const IndexerTestResultStateEnum._('unavailable');
const IndexerTestResultStateEnum _$indexerTestResultStateEnum_unknown =
    const IndexerTestResultStateEnum._('unknown');

IndexerTestResultStateEnum _$indexerTestResultStateEnumValueOf(String name) {
  switch (name) {
    case 'healthy':
      return _$indexerTestResultStateEnum_healthy;
    case 'unavailable':
      return _$indexerTestResultStateEnum_unavailable;
    case 'unknown':
      return _$indexerTestResultStateEnum_unknown;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<IndexerTestResultStateEnum> _$indexerTestResultStateEnumValues =
    BuiltSet<IndexerTestResultStateEnum>(const <IndexerTestResultStateEnum>[
  _$indexerTestResultStateEnum_healthy,
  _$indexerTestResultStateEnum_unavailable,
  _$indexerTestResultStateEnum_unknown,
]);

Serializer<IndexerTestResultStateEnum> _$indexerTestResultStateEnumSerializer =
    _$IndexerTestResultStateEnumSerializer();

class _$IndexerTestResultStateEnumSerializer
    implements PrimitiveSerializer<IndexerTestResultStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'healthy': 'healthy',
    'unavailable': 'unavailable',
    'unknown': 'unknown',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'healthy': 'healthy',
    'unavailable': 'unavailable',
    'unknown': 'unknown',
  };

  @override
  final Iterable<Type> types = const <Type>[IndexerTestResultStateEnum];
  @override
  final String wireName = 'IndexerTestResultStateEnum';

  @override
  Object serialize(Serializers serializers, IndexerTestResultStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  IndexerTestResultStateEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      IndexerTestResultStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$IndexerTestResult extends IndexerTestResult {
  @override
  final String id;
  @override
  final IndexerTestResultStateEnum state;
  @override
  final String detail;
  @override
  final DateTime checkedAt;

  factory _$IndexerTestResult(
          [void Function(IndexerTestResultBuilder)? updates]) =>
      (IndexerTestResultBuilder()..update(updates))._build();

  _$IndexerTestResult._(
      {required this.id,
      required this.state,
      required this.detail,
      required this.checkedAt})
      : super._();
  @override
  IndexerTestResult rebuild(void Function(IndexerTestResultBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IndexerTestResultBuilder toBuilder() =>
      IndexerTestResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is IndexerTestResult &&
        id == other.id &&
        state == other.state &&
        detail == other.detail &&
        checkedAt == other.checkedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, detail.hashCode);
    _$hash = $jc(_$hash, checkedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'IndexerTestResult')
          ..add('id', id)
          ..add('state', state)
          ..add('detail', detail)
          ..add('checkedAt', checkedAt))
        .toString();
  }
}

class IndexerTestResultBuilder
    implements Builder<IndexerTestResult, IndexerTestResultBuilder> {
  _$IndexerTestResult? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  IndexerTestResultStateEnum? _state;
  IndexerTestResultStateEnum? get state => _$this._state;
  set state(IndexerTestResultStateEnum? state) => _$this._state = state;

  String? _detail;
  String? get detail => _$this._detail;
  set detail(String? detail) => _$this._detail = detail;

  DateTime? _checkedAt;
  DateTime? get checkedAt => _$this._checkedAt;
  set checkedAt(DateTime? checkedAt) => _$this._checkedAt = checkedAt;

  IndexerTestResultBuilder() {
    IndexerTestResult._defaults(this);
  }

  IndexerTestResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _state = $v.state;
      _detail = $v.detail;
      _checkedAt = $v.checkedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(IndexerTestResult other) {
    _$v = other as _$IndexerTestResult;
  }

  @override
  void update(void Function(IndexerTestResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  IndexerTestResult build() => _build();

  _$IndexerTestResult _build() {
    final _$result = _$v ??
        _$IndexerTestResult._(
          id: BuiltValueNullFieldError.checkNotNull(
              id, r'IndexerTestResult', 'id'),
          state: BuiltValueNullFieldError.checkNotNull(
              state, r'IndexerTestResult', 'state'),
          detail: BuiltValueNullFieldError.checkNotNull(
              detail, r'IndexerTestResult', 'detail'),
          checkedAt: BuiltValueNullFieldError.checkNotNull(
              checkedAt, r'IndexerTestResult', 'checkedAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_snapshot.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DiscoverySnapshotStateEnum _$discoverySnapshotStateEnum_queued =
    const DiscoverySnapshotStateEnum._('queued');
const DiscoverySnapshotStateEnum _$discoverySnapshotStateEnum_running =
    const DiscoverySnapshotStateEnum._('running');
const DiscoverySnapshotStateEnum _$discoverySnapshotStateEnum_complete =
    const DiscoverySnapshotStateEnum._('complete');
const DiscoverySnapshotStateEnum _$discoverySnapshotStateEnum_partial =
    const DiscoverySnapshotStateEnum._('partial');
const DiscoverySnapshotStateEnum _$discoverySnapshotStateEnum_failed =
    const DiscoverySnapshotStateEnum._('failed');

DiscoverySnapshotStateEnum _$discoverySnapshotStateEnumValueOf(String name) {
  switch (name) {
    case 'queued':
      return _$discoverySnapshotStateEnum_queued;
    case 'running':
      return _$discoverySnapshotStateEnum_running;
    case 'complete':
      return _$discoverySnapshotStateEnum_complete;
    case 'partial':
      return _$discoverySnapshotStateEnum_partial;
    case 'failed':
      return _$discoverySnapshotStateEnum_failed;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DiscoverySnapshotStateEnum> _$discoverySnapshotStateEnumValues =
    BuiltSet<DiscoverySnapshotStateEnum>(const <DiscoverySnapshotStateEnum>[
  _$discoverySnapshotStateEnum_queued,
  _$discoverySnapshotStateEnum_running,
  _$discoverySnapshotStateEnum_complete,
  _$discoverySnapshotStateEnum_partial,
  _$discoverySnapshotStateEnum_failed,
]);

Serializer<DiscoverySnapshotStateEnum> _$discoverySnapshotStateEnumSerializer =
    _$DiscoverySnapshotStateEnumSerializer();

class _$DiscoverySnapshotStateEnumSerializer
    implements PrimitiveSerializer<DiscoverySnapshotStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'queued': 'queued',
    'running': 'running',
    'complete': 'complete',
    'partial': 'partial',
    'failed': 'failed',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'queued': 'queued',
    'running': 'running',
    'complete': 'complete',
    'partial': 'partial',
    'failed': 'failed',
  };

  @override
  final Iterable<Type> types = const <Type>[DiscoverySnapshotStateEnum];
  @override
  final String wireName = 'DiscoverySnapshotStateEnum';

  @override
  Object serialize(Serializers serializers, DiscoverySnapshotStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DiscoverySnapshotStateEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DiscoverySnapshotStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DiscoverySnapshot extends DiscoverySnapshot {
  @override
  final String id;
  @override
  final DiscoverySnapshotStateEnum state;
  @override
  final DateTime createdAt;
  @override
  final DateTime expiresAt;
  @override
  final BuiltList<DiscoveryResult> items;
  @override
  final String? nextCursor;
  @override
  final int? totalKnown;
  @override
  final bool truncated;
  @override
  final BuiltList<String> warnings;

  factory _$DiscoverySnapshot(
          [void Function(DiscoverySnapshotBuilder)? updates]) =>
      (DiscoverySnapshotBuilder()..update(updates))._build();

  _$DiscoverySnapshot._(
      {required this.id,
      required this.state,
      required this.createdAt,
      required this.expiresAt,
      required this.items,
      this.nextCursor,
      this.totalKnown,
      required this.truncated,
      required this.warnings})
      : super._();
  @override
  DiscoverySnapshot rebuild(void Function(DiscoverySnapshotBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DiscoverySnapshotBuilder toBuilder() =>
      DiscoverySnapshotBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DiscoverySnapshot &&
        id == other.id &&
        state == other.state &&
        createdAt == other.createdAt &&
        expiresAt == other.expiresAt &&
        items == other.items &&
        nextCursor == other.nextCursor &&
        totalKnown == other.totalKnown &&
        truncated == other.truncated &&
        warnings == other.warnings;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, nextCursor.hashCode);
    _$hash = $jc(_$hash, totalKnown.hashCode);
    _$hash = $jc(_$hash, truncated.hashCode);
    _$hash = $jc(_$hash, warnings.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DiscoverySnapshot')
          ..add('id', id)
          ..add('state', state)
          ..add('createdAt', createdAt)
          ..add('expiresAt', expiresAt)
          ..add('items', items)
          ..add('nextCursor', nextCursor)
          ..add('totalKnown', totalKnown)
          ..add('truncated', truncated)
          ..add('warnings', warnings))
        .toString();
  }
}

class DiscoverySnapshotBuilder
    implements Builder<DiscoverySnapshot, DiscoverySnapshotBuilder> {
  _$DiscoverySnapshot? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  DiscoverySnapshotStateEnum? _state;
  DiscoverySnapshotStateEnum? get state => _$this._state;
  set state(DiscoverySnapshotStateEnum? state) => _$this._state = state;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  ListBuilder<DiscoveryResult>? _items;
  ListBuilder<DiscoveryResult> get items =>
      _$this._items ??= ListBuilder<DiscoveryResult>();
  set items(ListBuilder<DiscoveryResult>? items) => _$this._items = items;

  String? _nextCursor;
  String? get nextCursor => _$this._nextCursor;
  set nextCursor(String? nextCursor) => _$this._nextCursor = nextCursor;

  int? _totalKnown;
  int? get totalKnown => _$this._totalKnown;
  set totalKnown(int? totalKnown) => _$this._totalKnown = totalKnown;

  bool? _truncated;
  bool? get truncated => _$this._truncated;
  set truncated(bool? truncated) => _$this._truncated = truncated;

  ListBuilder<String>? _warnings;
  ListBuilder<String> get warnings =>
      _$this._warnings ??= ListBuilder<String>();
  set warnings(ListBuilder<String>? warnings) => _$this._warnings = warnings;

  DiscoverySnapshotBuilder() {
    DiscoverySnapshot._defaults(this);
  }

  DiscoverySnapshotBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _state = $v.state;
      _createdAt = $v.createdAt;
      _expiresAt = $v.expiresAt;
      _items = $v.items.toBuilder();
      _nextCursor = $v.nextCursor;
      _totalKnown = $v.totalKnown;
      _truncated = $v.truncated;
      _warnings = $v.warnings.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DiscoverySnapshot other) {
    _$v = other as _$DiscoverySnapshot;
  }

  @override
  void update(void Function(DiscoverySnapshotBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DiscoverySnapshot build() => _build();

  _$DiscoverySnapshot _build() {
    _$DiscoverySnapshot _$result;
    try {
      _$result = _$v ??
          _$DiscoverySnapshot._(
            id: BuiltValueNullFieldError.checkNotNull(
                id, r'DiscoverySnapshot', 'id'),
            state: BuiltValueNullFieldError.checkNotNull(
                state, r'DiscoverySnapshot', 'state'),
            createdAt: BuiltValueNullFieldError.checkNotNull(
                createdAt, r'DiscoverySnapshot', 'createdAt'),
            expiresAt: BuiltValueNullFieldError.checkNotNull(
                expiresAt, r'DiscoverySnapshot', 'expiresAt'),
            items: items.build(),
            nextCursor: nextCursor,
            totalKnown: totalKnown,
            truncated: BuiltValueNullFieldError.checkNotNull(
                truncated, r'DiscoverySnapshot', 'truncated'),
            warnings: warnings.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();

        _$failedField = 'warnings';
        warnings.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'DiscoverySnapshot', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

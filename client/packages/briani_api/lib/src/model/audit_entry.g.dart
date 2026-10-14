// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_entry.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$AuditEntry extends AuditEntry {
  @override
  final String id;
  @override
  final DateTime occurredAt;
  @override
  final String? actorId;
  @override
  final String action;
  @override
  final String? resourceType;
  @override
  final String? resourceId;
  @override
  final String outcome;
  @override
  final String? detail;

  factory _$AuditEntry([void Function(AuditEntryBuilder)? updates]) =>
      (AuditEntryBuilder()..update(updates))._build();

  _$AuditEntry._(
      {required this.id,
      required this.occurredAt,
      this.actorId,
      required this.action,
      this.resourceType,
      this.resourceId,
      required this.outcome,
      this.detail})
      : super._();
  @override
  AuditEntry rebuild(void Function(AuditEntryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  AuditEntryBuilder toBuilder() => AuditEntryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is AuditEntry &&
        id == other.id &&
        occurredAt == other.occurredAt &&
        actorId == other.actorId &&
        action == other.action &&
        resourceType == other.resourceType &&
        resourceId == other.resourceId &&
        outcome == other.outcome &&
        detail == other.detail;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, occurredAt.hashCode);
    _$hash = $jc(_$hash, actorId.hashCode);
    _$hash = $jc(_$hash, action.hashCode);
    _$hash = $jc(_$hash, resourceType.hashCode);
    _$hash = $jc(_$hash, resourceId.hashCode);
    _$hash = $jc(_$hash, outcome.hashCode);
    _$hash = $jc(_$hash, detail.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'AuditEntry')
          ..add('id', id)
          ..add('occurredAt', occurredAt)
          ..add('actorId', actorId)
          ..add('action', action)
          ..add('resourceType', resourceType)
          ..add('resourceId', resourceId)
          ..add('outcome', outcome)
          ..add('detail', detail))
        .toString();
  }
}

class AuditEntryBuilder implements Builder<AuditEntry, AuditEntryBuilder> {
  _$AuditEntry? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  DateTime? _occurredAt;
  DateTime? get occurredAt => _$this._occurredAt;
  set occurredAt(DateTime? occurredAt) => _$this._occurredAt = occurredAt;

  String? _actorId;
  String? get actorId => _$this._actorId;
  set actorId(String? actorId) => _$this._actorId = actorId;

  String? _action;
  String? get action => _$this._action;
  set action(String? action) => _$this._action = action;

  String? _resourceType;
  String? get resourceType => _$this._resourceType;
  set resourceType(String? resourceType) => _$this._resourceType = resourceType;

  String? _resourceId;
  String? get resourceId => _$this._resourceId;
  set resourceId(String? resourceId) => _$this._resourceId = resourceId;

  String? _outcome;
  String? get outcome => _$this._outcome;
  set outcome(String? outcome) => _$this._outcome = outcome;

  String? _detail;
  String? get detail => _$this._detail;
  set detail(String? detail) => _$this._detail = detail;

  AuditEntryBuilder() {
    AuditEntry._defaults(this);
  }

  AuditEntryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _occurredAt = $v.occurredAt;
      _actorId = $v.actorId;
      _action = $v.action;
      _resourceType = $v.resourceType;
      _resourceId = $v.resourceId;
      _outcome = $v.outcome;
      _detail = $v.detail;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(AuditEntry other) {
    _$v = other as _$AuditEntry;
  }

  @override
  void update(void Function(AuditEntryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  AuditEntry build() => _build();

  _$AuditEntry _build() {
    final _$result = _$v ??
        _$AuditEntry._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'AuditEntry', 'id'),
          occurredAt: BuiltValueNullFieldError.checkNotNull(
              occurredAt, r'AuditEntry', 'occurredAt'),
          actorId: actorId,
          action: BuiltValueNullFieldError.checkNotNull(
              action, r'AuditEntry', 'action'),
          resourceType: resourceType,
          resourceId: resourceId,
          outcome: BuiltValueNullFieldError.checkNotNull(
              outcome, r'AuditEntry', 'outcome'),
          detail: detail,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

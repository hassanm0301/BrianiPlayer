// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const EventTypeEnum _$eventTypeEnum_downloadPeriodUpdated =
    const EventTypeEnum._('downloadPeriodUpdated');
const EventTypeEnum _$eventTypeEnum_mediaPeriodChanged =
    const EventTypeEnum._('mediaPeriodChanged');
const EventTypeEnum _$eventTypeEnum_playbackPeriodState =
    const EventTypeEnum._('playbackPeriodState');
const EventTypeEnum _$eventTypeEnum_jobPeriodUpdated =
    const EventTypeEnum._('jobPeriodUpdated');
const EventTypeEnum _$eventTypeEnum_servicePeriodHealth =
    const EventTypeEnum._('servicePeriodHealth');
const EventTypeEnum _$eventTypeEnum_permissionsPeriodChanged =
    const EventTypeEnum._('permissionsPeriodChanged');
const EventTypeEnum _$eventTypeEnum_snapshotPeriodRequired =
    const EventTypeEnum._('snapshotPeriodRequired');

EventTypeEnum _$eventTypeEnumValueOf(String name) {
  switch (name) {
    case 'downloadPeriodUpdated':
      return _$eventTypeEnum_downloadPeriodUpdated;
    case 'mediaPeriodChanged':
      return _$eventTypeEnum_mediaPeriodChanged;
    case 'playbackPeriodState':
      return _$eventTypeEnum_playbackPeriodState;
    case 'jobPeriodUpdated':
      return _$eventTypeEnum_jobPeriodUpdated;
    case 'servicePeriodHealth':
      return _$eventTypeEnum_servicePeriodHealth;
    case 'permissionsPeriodChanged':
      return _$eventTypeEnum_permissionsPeriodChanged;
    case 'snapshotPeriodRequired':
      return _$eventTypeEnum_snapshotPeriodRequired;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<EventTypeEnum> _$eventTypeEnumValues =
    BuiltSet<EventTypeEnum>(const <EventTypeEnum>[
  _$eventTypeEnum_downloadPeriodUpdated,
  _$eventTypeEnum_mediaPeriodChanged,
  _$eventTypeEnum_playbackPeriodState,
  _$eventTypeEnum_jobPeriodUpdated,
  _$eventTypeEnum_servicePeriodHealth,
  _$eventTypeEnum_permissionsPeriodChanged,
  _$eventTypeEnum_snapshotPeriodRequired,
]);

Serializer<EventTypeEnum> _$eventTypeEnumSerializer =
    _$EventTypeEnumSerializer();

class _$EventTypeEnumSerializer implements PrimitiveSerializer<EventTypeEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'downloadPeriodUpdated': 'download.updated',
    'mediaPeriodChanged': 'media.changed',
    'playbackPeriodState': 'playback.state',
    'jobPeriodUpdated': 'job.updated',
    'servicePeriodHealth': 'service.health',
    'permissionsPeriodChanged': 'permissions.changed',
    'snapshotPeriodRequired': 'snapshot.required',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'download.updated': 'downloadPeriodUpdated',
    'media.changed': 'mediaPeriodChanged',
    'playback.state': 'playbackPeriodState',
    'job.updated': 'jobPeriodUpdated',
    'service.health': 'servicePeriodHealth',
    'permissions.changed': 'permissionsPeriodChanged',
    'snapshot.required': 'snapshotPeriodRequired',
  };

  @override
  final Iterable<Type> types = const <Type>[EventTypeEnum];
  @override
  final String wireName = 'EventTypeEnum';

  @override
  Object serialize(Serializers serializers, EventTypeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  EventTypeEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      EventTypeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Event extends Event {
  @override
  final String id;
  @override
  final EventTypeEnum type;
  @override
  final DateTime occurredAt;
  @override
  final BuiltMap<String, JsonObject?> payload;

  factory _$Event([void Function(EventBuilder)? updates]) =>
      (EventBuilder()..update(updates))._build();

  _$Event._(
      {required this.id,
      required this.type,
      required this.occurredAt,
      required this.payload})
      : super._();
  @override
  Event rebuild(void Function(EventBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  EventBuilder toBuilder() => EventBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Event &&
        id == other.id &&
        type == other.type &&
        occurredAt == other.occurredAt &&
        payload == other.payload;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, occurredAt.hashCode);
    _$hash = $jc(_$hash, payload.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Event')
          ..add('id', id)
          ..add('type', type)
          ..add('occurredAt', occurredAt)
          ..add('payload', payload))
        .toString();
  }
}

class EventBuilder implements Builder<Event, EventBuilder> {
  _$Event? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  EventTypeEnum? _type;
  EventTypeEnum? get type => _$this._type;
  set type(EventTypeEnum? type) => _$this._type = type;

  DateTime? _occurredAt;
  DateTime? get occurredAt => _$this._occurredAt;
  set occurredAt(DateTime? occurredAt) => _$this._occurredAt = occurredAt;

  MapBuilder<String, JsonObject?>? _payload;
  MapBuilder<String, JsonObject?> get payload =>
      _$this._payload ??= MapBuilder<String, JsonObject?>();
  set payload(MapBuilder<String, JsonObject?>? payload) =>
      _$this._payload = payload;

  EventBuilder() {
    Event._defaults(this);
  }

  EventBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _type = $v.type;
      _occurredAt = $v.occurredAt;
      _payload = $v.payload.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Event other) {
    _$v = other as _$Event;
  }

  @override
  void update(void Function(EventBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Event build() => _build();

  _$Event _build() {
    _$Event _$result;
    try {
      _$result = _$v ??
          _$Event._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'Event', 'id'),
            type: BuiltValueNullFieldError.checkNotNull(type, r'Event', 'type'),
            occurredAt: BuiltValueNullFieldError.checkNotNull(
                occurredAt, r'Event', 'occurredAt'),
            payload: payload.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'payload';
        payload.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'Event', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'event.g.dart';

/// Event
///
/// Properties:
/// * [id] 
/// * [type] 
/// * [occurredAt] 
/// * [payload] 
@BuiltValue()
abstract class Event implements Built<Event, EventBuilder> {
  @BuiltValueField(wireName: r'id')
  String get id;

  @BuiltValueField(wireName: r'type')
  EventTypeEnum get type;
  // enum typeEnum {  download.updated,  media.changed,  playback.state,  job.updated,  service.health,  permissions.changed,  snapshot.required,  };

  @BuiltValueField(wireName: r'occurredAt')
  DateTime get occurredAt;

  @BuiltValueField(wireName: r'payload')
  BuiltMap<String, JsonObject?> get payload;

  Event._();

  factory Event([void updates(EventBuilder b)]) = _$Event;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EventBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<Event> get serializer => _$EventSerializer();
}

class _$EventSerializer implements PrimitiveSerializer<Event> {
  @override
  final Iterable<Type> types = const [Event, _$Event];

  @override
  final String wireName = r'Event';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    Event object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'id';
    yield serializers.serialize(
      object.id,
      specifiedType: const FullType(String),
    );
    yield r'type';
    yield serializers.serialize(
      object.type,
      specifiedType: const FullType(EventTypeEnum),
    );
    yield r'occurredAt';
    yield serializers.serialize(
      object.occurredAt,
      specifiedType: const FullType(DateTime),
    );
    yield r'payload';
    yield serializers.serialize(
      object.payload,
      specifiedType: const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    Event object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required EventBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'id':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.id = valueDes;
          break;
        case r'type':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(EventTypeEnum),
          ) as EventTypeEnum;
          result.type = valueDes;
          break;
        case r'occurredAt':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DateTime),
          ) as DateTime;
          result.occurredAt = valueDes;
          break;
        case r'payload':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
          ) as BuiltMap<String, JsonObject?>;
          result.payload.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  Event deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EventBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


class EventTypeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'download.updated')
  static const EventTypeEnum downloadPeriodUpdated = _$eventTypeEnum_downloadPeriodUpdated;
  @BuiltValueEnumConst(wireName: r'media.changed')
  static const EventTypeEnum mediaPeriodChanged = _$eventTypeEnum_mediaPeriodChanged;
  @BuiltValueEnumConst(wireName: r'playback.state')
  static const EventTypeEnum playbackPeriodState = _$eventTypeEnum_playbackPeriodState;
  @BuiltValueEnumConst(wireName: r'job.updated')
  static const EventTypeEnum jobPeriodUpdated = _$eventTypeEnum_jobPeriodUpdated;
  @BuiltValueEnumConst(wireName: r'service.health')
  static const EventTypeEnum servicePeriodHealth = _$eventTypeEnum_servicePeriodHealth;
  @BuiltValueEnumConst(wireName: r'permissions.changed')
  static const EventTypeEnum permissionsPeriodChanged = _$eventTypeEnum_permissionsPeriodChanged;
  @BuiltValueEnumConst(wireName: r'snapshot.required')
  static const EventTypeEnum snapshotPeriodRequired = _$eventTypeEnum_snapshotPeriodRequired;

  static Serializer<EventTypeEnum> get serializer => _$eventTypeEnumSerializer;

  const EventTypeEnum._(String name): super(name);

  static BuiltSet<EventTypeEnum> get values => _$eventTypeEnumValues;
  static EventTypeEnum valueOf(String name) => _$eventTypeEnumValueOf(name);
}


// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'tracker_summary.g.dart';

/// No passkeys, full credential-bearing URLs or user secrets.
///
/// Properties:
/// * [host] 
/// * [state] 
/// * [peers] 
/// * [message] 
@BuiltValue()
abstract class TrackerSummary implements Built<TrackerSummary, TrackerSummaryBuilder> {
  @BuiltValueField(wireName: r'host')
  String get host;

  @BuiltValueField(wireName: r'state')
  String get state;

  @BuiltValueField(wireName: r'peers')
  int? get peers;

  @BuiltValueField(wireName: r'message')
  String? get message;

  TrackerSummary._();

  factory TrackerSummary([void updates(TrackerSummaryBuilder b)]) = _$TrackerSummary;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(TrackerSummaryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<TrackerSummary> get serializer => _$TrackerSummarySerializer();
}

class _$TrackerSummarySerializer implements PrimitiveSerializer<TrackerSummary> {
  @override
  final Iterable<Type> types = const [TrackerSummary, _$TrackerSummary];

  @override
  final String wireName = r'TrackerSummary';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    TrackerSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'host';
    yield serializers.serialize(
      object.host,
      specifiedType: const FullType(String),
    );
    yield r'state';
    yield serializers.serialize(
      object.state,
      specifiedType: const FullType(String),
    );
    if (object.peers != null) {
      yield r'peers';
      yield serializers.serialize(
        object.peers,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.message != null) {
      yield r'message';
      yield serializers.serialize(
        object.message,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    TrackerSummary object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required TrackerSummaryBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'host':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.host = valueDes;
          break;
        case r'state':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.state = valueDes;
          break;
        case r'peers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.peers = valueDes;
          break;
        case r'message':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.message = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  TrackerSummary deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = TrackerSummaryBuilder();
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



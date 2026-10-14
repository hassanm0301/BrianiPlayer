// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:briani_api/src/model/tracker_summary.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download_diagnostics.g.dart';

/// DownloadDiagnostics
///
/// Properties:
/// * [downloadId] 
/// * [engineState] 
/// * [generation] 
/// * [trackers] 
/// * [warnings] 
@BuiltValue()
abstract class DownloadDiagnostics implements Built<DownloadDiagnostics, DownloadDiagnosticsBuilder> {
  @BuiltValueField(wireName: r'downloadId')
  String get downloadId;

  @BuiltValueField(wireName: r'engineState')
  String get engineState;

  @BuiltValueField(wireName: r'generation')
  String get generation;

  @BuiltValueField(wireName: r'trackers')
  BuiltList<TrackerSummary> get trackers;

  @BuiltValueField(wireName: r'warnings')
  BuiltList<String> get warnings;

  DownloadDiagnostics._();

  factory DownloadDiagnostics([void updates(DownloadDiagnosticsBuilder b)]) = _$DownloadDiagnostics;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadDiagnosticsBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadDiagnostics> get serializer => _$DownloadDiagnosticsSerializer();
}

class _$DownloadDiagnosticsSerializer implements PrimitiveSerializer<DownloadDiagnostics> {
  @override
  final Iterable<Type> types = const [DownloadDiagnostics, _$DownloadDiagnostics];

  @override
  final String wireName = r'DownloadDiagnostics';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadDiagnostics object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'downloadId';
    yield serializers.serialize(
      object.downloadId,
      specifiedType: const FullType(String),
    );
    yield r'engineState';
    yield serializers.serialize(
      object.engineState,
      specifiedType: const FullType(String),
    );
    yield r'generation';
    yield serializers.serialize(
      object.generation,
      specifiedType: const FullType(String),
    );
    yield r'trackers';
    yield serializers.serialize(
      object.trackers,
      specifiedType: const FullType(BuiltList, [FullType(TrackerSummary)]),
    );
    yield r'warnings';
    yield serializers.serialize(
      object.warnings,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DownloadDiagnostics object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadDiagnosticsBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'downloadId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.downloadId = valueDes;
          break;
        case r'engineState':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.engineState = valueDes;
          break;
        case r'generation':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.generation = valueDes;
          break;
        case r'trackers':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(TrackerSummary)]),
          ) as BuiltList<TrackerSummary>;
          result.trackers.replace(valueDes);
          break;
        case r'warnings':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.warnings.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DownloadDiagnostics deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadDiagnosticsBuilder();
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



// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:briani_api/src/model/file_choice.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download_selection.g.dart';

/// DownloadSelection
///
/// Properties:
/// * [files] 
/// * [autoStart] 
/// * [version] 
@BuiltValue()
abstract class DownloadSelection implements Built<DownloadSelection, DownloadSelectionBuilder> {
  @BuiltValueField(wireName: r'files')
  BuiltList<FileChoice> get files;

  @BuiltValueField(wireName: r'autoStart')
  bool get autoStart;

  @BuiltValueField(wireName: r'version')
  int get version;

  DownloadSelection._();

  factory DownloadSelection([void updates(DownloadSelectionBuilder b)]) = _$DownloadSelection;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadSelectionBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadSelection> get serializer => _$DownloadSelectionSerializer();
}

class _$DownloadSelectionSerializer implements PrimitiveSerializer<DownloadSelection> {
  @override
  final Iterable<Type> types = const [DownloadSelection, _$DownloadSelection];

  @override
  final String wireName = r'DownloadSelection';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadSelection object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'files';
    yield serializers.serialize(
      object.files,
      specifiedType: const FullType(BuiltList, [FullType(FileChoice)]),
    );
    yield r'autoStart';
    yield serializers.serialize(
      object.autoStart,
      specifiedType: const FullType(bool),
    );
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    DownloadSelection object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadSelectionBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'files':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(FileChoice)]),
          ) as BuiltList<FileChoice>;
          result.files.replace(valueDes);
          break;
        case r'autoStart':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.autoStart = valueDes;
          break;
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.version = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DownloadSelection deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadSelectionBuilder();
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



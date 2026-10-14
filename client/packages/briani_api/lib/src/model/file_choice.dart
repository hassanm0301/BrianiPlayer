// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'file_choice.g.dart';

/// FileChoice
///
/// Properties:
/// * [fileId] 
/// * [selected] 
/// * [priority] 
@BuiltValue()
abstract class FileChoice implements Built<FileChoice, FileChoiceBuilder> {
  @BuiltValueField(wireName: r'fileId')
  String get fileId;

  @BuiltValueField(wireName: r'selected')
  bool get selected;

  @BuiltValueField(wireName: r'priority')
  FileChoicePriorityEnum get priority;
  // enum priorityEnum {  normal,  high,  maximum,  };

  FileChoice._();

  factory FileChoice([void updates(FileChoiceBuilder b)]) = _$FileChoice;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(FileChoiceBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<FileChoice> get serializer => _$FileChoiceSerializer();
}

class _$FileChoiceSerializer implements PrimitiveSerializer<FileChoice> {
  @override
  final Iterable<Type> types = const [FileChoice, _$FileChoice];

  @override
  final String wireName = r'FileChoice';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    FileChoice object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'fileId';
    yield serializers.serialize(
      object.fileId,
      specifiedType: const FullType(String),
    );
    yield r'selected';
    yield serializers.serialize(
      object.selected,
      specifiedType: const FullType(bool),
    );
    yield r'priority';
    yield serializers.serialize(
      object.priority,
      specifiedType: const FullType(FileChoicePriorityEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    FileChoice object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required FileChoiceBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'fileId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.fileId = valueDes;
          break;
        case r'selected':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.selected = valueDes;
          break;
        case r'priority':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(FileChoicePriorityEnum),
          ) as FileChoicePriorityEnum;
          result.priority = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  FileChoice deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = FileChoiceBuilder();
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


class FileChoicePriorityEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'normal')
  static const FileChoicePriorityEnum normal = _$fileChoicePriorityEnum_normal;
  @BuiltValueEnumConst(wireName: r'high')
  static const FileChoicePriorityEnum high = _$fileChoicePriorityEnum_high;
  @BuiltValueEnumConst(wireName: r'maximum')
  static const FileChoicePriorityEnum maximum = _$fileChoicePriorityEnum_maximum;

  static Serializer<FileChoicePriorityEnum> get serializer => _$fileChoicePriorityEnumSerializer;

  const FileChoicePriorityEnum._(String name): super(name);

  static BuiltSet<FileChoicePriorityEnum> get values => _$fileChoicePriorityEnumValues;
  static FileChoicePriorityEnum valueOf(String name) => _$fileChoicePriorityEnumValueOf(name);
}


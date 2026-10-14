// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'download_action.g.dart';

/// DownloadAction
///
/// Properties:
/// * [action] 
/// * [version] 
/// * [deleteData] 
/// * [force] 
/// * [confirmation] 
@BuiltValue()
abstract class DownloadAction implements Built<DownloadAction, DownloadActionBuilder> {
  @BuiltValueField(wireName: r'action')
  DownloadActionActionEnum get action;
  // enum actionEnum {  pause,  resume,  retry,  remove,  reannounce,  recheck,  };

  @BuiltValueField(wireName: r'version')
  int get version;

  @BuiltValueField(wireName: r'deleteData')
  bool? get deleteData;

  @BuiltValueField(wireName: r'force')
  bool? get force;

  @BuiltValueField(wireName: r'confirmation')
  String? get confirmation;

  DownloadAction._();

  factory DownloadAction([void updates(DownloadActionBuilder b)]) = _$DownloadAction;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DownloadActionBuilder b) => b
      ..deleteData = false
      ..force = false;

  @BuiltValueSerializer(custom: true)
  static Serializer<DownloadAction> get serializer => _$DownloadActionSerializer();
}

class _$DownloadActionSerializer implements PrimitiveSerializer<DownloadAction> {
  @override
  final Iterable<Type> types = const [DownloadAction, _$DownloadAction];

  @override
  final String wireName = r'DownloadAction';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DownloadAction object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'action';
    yield serializers.serialize(
      object.action,
      specifiedType: const FullType(DownloadActionActionEnum),
    );
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
    if (object.deleteData != null) {
      yield r'deleteData';
      yield serializers.serialize(
        object.deleteData,
        specifiedType: const FullType(bool),
      );
    }
    if (object.force != null) {
      yield r'force';
      yield serializers.serialize(
        object.force,
        specifiedType: const FullType(bool),
      );
    }
    if (object.confirmation != null) {
      yield r'confirmation';
      yield serializers.serialize(
        object.confirmation,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    DownloadAction object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DownloadActionBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'action':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DownloadActionActionEnum),
          ) as DownloadActionActionEnum;
          result.action = valueDes;
          break;
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.version = valueDes;
          break;
        case r'deleteData':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.deleteData = valueDes;
          break;
        case r'force':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.force = valueDes;
          break;
        case r'confirmation':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.confirmation = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  DownloadAction deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DownloadActionBuilder();
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


class DownloadActionActionEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'pause')
  static const DownloadActionActionEnum pause = _$downloadActionActionEnum_pause;
  @BuiltValueEnumConst(wireName: r'resume')
  static const DownloadActionActionEnum resume = _$downloadActionActionEnum_resume;
  @BuiltValueEnumConst(wireName: r'retry')
  static const DownloadActionActionEnum retry = _$downloadActionActionEnum_retry;
  @BuiltValueEnumConst(wireName: r'remove')
  static const DownloadActionActionEnum remove = _$downloadActionActionEnum_remove;
  @BuiltValueEnumConst(wireName: r'reannounce')
  static const DownloadActionActionEnum reannounce = _$downloadActionActionEnum_reannounce;
  @BuiltValueEnumConst(wireName: r'recheck')
  static const DownloadActionActionEnum recheck = _$downloadActionActionEnum_recheck;

  static Serializer<DownloadActionActionEnum> get serializer => _$downloadActionActionEnumSerializer;

  const DownloadActionActionEnum._(String name): super(name);

  static BuiltSet<DownloadActionActionEnum> get values => _$downloadActionActionEnumValues;
  static DownloadActionActionEnum valueOf(String name) => _$downloadActionActionEnumValueOf(name);
}


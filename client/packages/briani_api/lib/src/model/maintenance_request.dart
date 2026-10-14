// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'maintenance_request.g.dart';

/// Database snapshot is not a full-stack backup and this endpoint never controls Docker.
///
/// Properties:
/// * [action] 
/// * [libraryId] 
@BuiltValue()
abstract class MaintenanceRequest implements Built<MaintenanceRequest, MaintenanceRequestBuilder> {
  @BuiltValueField(wireName: r'action')
  MaintenanceRequestActionEnum get action;
  // enum actionEnum {  rescanLibraries,  pruneThumbnailCache,  databaseSnapshot,  };

  @BuiltValueField(wireName: r'libraryId')
  String? get libraryId;

  MaintenanceRequest._();

  factory MaintenanceRequest([void updates(MaintenanceRequestBuilder b)]) = _$MaintenanceRequest;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(MaintenanceRequestBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<MaintenanceRequest> get serializer => _$MaintenanceRequestSerializer();
}

class _$MaintenanceRequestSerializer implements PrimitiveSerializer<MaintenanceRequest> {
  @override
  final Iterable<Type> types = const [MaintenanceRequest, _$MaintenanceRequest];

  @override
  final String wireName = r'MaintenanceRequest';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    MaintenanceRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'action';
    yield serializers.serialize(
      object.action,
      specifiedType: const FullType(MaintenanceRequestActionEnum),
    );
    if (object.libraryId != null) {
      yield r'libraryId';
      yield serializers.serialize(
        object.libraryId,
        specifiedType: const FullType.nullable(String),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    MaintenanceRequest object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required MaintenanceRequestBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'action':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(MaintenanceRequestActionEnum),
          ) as MaintenanceRequestActionEnum;
          result.action = valueDes;
          break;
        case r'libraryId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.libraryId = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  MaintenanceRequest deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = MaintenanceRequestBuilder();
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


class MaintenanceRequestActionEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'rescanLibraries')
  static const MaintenanceRequestActionEnum rescanLibraries = _$maintenanceRequestActionEnum_rescanLibraries;
  @BuiltValueEnumConst(wireName: r'pruneThumbnailCache')
  static const MaintenanceRequestActionEnum pruneThumbnailCache = _$maintenanceRequestActionEnum_pruneThumbnailCache;
  @BuiltValueEnumConst(wireName: r'databaseSnapshot')
  static const MaintenanceRequestActionEnum databaseSnapshot = _$maintenanceRequestActionEnum_databaseSnapshot;

  static Serializer<MaintenanceRequestActionEnum> get serializer => _$maintenanceRequestActionEnumSerializer;

  const MaintenanceRequestActionEnum._(String name): super(name);

  static BuiltSet<MaintenanceRequestActionEnum> get values => _$maintenanceRequestActionEnumValues;
  static MaintenanceRequestActionEnum valueOf(String name) => _$maintenanceRequestActionEnumValueOf(name);
}


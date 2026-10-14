// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'user_preferences_folder_preferences_inner.g.dart';

/// UserPreferencesFolderPreferencesInner
///
/// Properties:
/// * [libraryId] 
/// * [folderId] 
/// * [layout] 
/// * [sort] 
/// * [order] 
@BuiltValue()
abstract class UserPreferencesFolderPreferencesInner implements Built<UserPreferencesFolderPreferencesInner, UserPreferencesFolderPreferencesInnerBuilder> {
  @BuiltValueField(wireName: r'libraryId')
  String get libraryId;

  @BuiltValueField(wireName: r'folderId')
  String? get folderId;

  @BuiltValueField(wireName: r'layout')
  UserPreferencesFolderPreferencesInnerLayoutEnum get layout;
  // enum layoutEnum {  grid,  list,  };

  @BuiltValueField(wireName: r'sort')
  UserPreferencesFolderPreferencesInnerSortEnum get sort;
  // enum sortEnum {  name,  date,  size,  };

  @BuiltValueField(wireName: r'order')
  UserPreferencesFolderPreferencesInnerOrderEnum get order;
  // enum orderEnum {  asc,  desc,  };

  UserPreferencesFolderPreferencesInner._();

  factory UserPreferencesFolderPreferencesInner([void updates(UserPreferencesFolderPreferencesInnerBuilder b)]) = _$UserPreferencesFolderPreferencesInner;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UserPreferencesFolderPreferencesInnerBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UserPreferencesFolderPreferencesInner> get serializer => _$UserPreferencesFolderPreferencesInnerSerializer();
}

class _$UserPreferencesFolderPreferencesInnerSerializer implements PrimitiveSerializer<UserPreferencesFolderPreferencesInner> {
  @override
  final Iterable<Type> types = const [UserPreferencesFolderPreferencesInner, _$UserPreferencesFolderPreferencesInner];

  @override
  final String wireName = r'UserPreferencesFolderPreferencesInner';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UserPreferencesFolderPreferencesInner object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'libraryId';
    yield serializers.serialize(
      object.libraryId,
      specifiedType: const FullType(String),
    );
    yield r'folderId';
    yield object.folderId == null ? null : serializers.serialize(
      object.folderId,
      specifiedType: const FullType.nullable(String),
    );
    yield r'layout';
    yield serializers.serialize(
      object.layout,
      specifiedType: const FullType(UserPreferencesFolderPreferencesInnerLayoutEnum),
    );
    yield r'sort';
    yield serializers.serialize(
      object.sort,
      specifiedType: const FullType(UserPreferencesFolderPreferencesInnerSortEnum),
    );
    yield r'order';
    yield serializers.serialize(
      object.order,
      specifiedType: const FullType(UserPreferencesFolderPreferencesInnerOrderEnum),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    UserPreferencesFolderPreferencesInner object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UserPreferencesFolderPreferencesInnerBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'libraryId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.libraryId = valueDes;
          break;
        case r'folderId':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.folderId = valueDes;
          break;
        case r'layout':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(UserPreferencesFolderPreferencesInnerLayoutEnum),
          ) as UserPreferencesFolderPreferencesInnerLayoutEnum;
          result.layout = valueDes;
          break;
        case r'sort':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(UserPreferencesFolderPreferencesInnerSortEnum),
          ) as UserPreferencesFolderPreferencesInnerSortEnum;
          result.sort = valueDes;
          break;
        case r'order':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(UserPreferencesFolderPreferencesInnerOrderEnum),
          ) as UserPreferencesFolderPreferencesInnerOrderEnum;
          result.order = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UserPreferencesFolderPreferencesInner deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UserPreferencesFolderPreferencesInnerBuilder();
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


class UserPreferencesFolderPreferencesInnerLayoutEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'grid')
  static const UserPreferencesFolderPreferencesInnerLayoutEnum grid = _$userPreferencesFolderPreferencesInnerLayoutEnum_grid;
  @BuiltValueEnumConst(wireName: r'list')
  static const UserPreferencesFolderPreferencesInnerLayoutEnum list = _$userPreferencesFolderPreferencesInnerLayoutEnum_list;

  static Serializer<UserPreferencesFolderPreferencesInnerLayoutEnum> get serializer => _$userPreferencesFolderPreferencesInnerLayoutEnumSerializer;

  const UserPreferencesFolderPreferencesInnerLayoutEnum._(String name): super(name);

  static BuiltSet<UserPreferencesFolderPreferencesInnerLayoutEnum> get values => _$userPreferencesFolderPreferencesInnerLayoutEnumValues;
  static UserPreferencesFolderPreferencesInnerLayoutEnum valueOf(String name) => _$userPreferencesFolderPreferencesInnerLayoutEnumValueOf(name);
}

class UserPreferencesFolderPreferencesInnerSortEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'name')
  static const UserPreferencesFolderPreferencesInnerSortEnum byName = _$userPreferencesFolderPreferencesInnerSortEnum_byName;
  @BuiltValueEnumConst(wireName: r'date')
  static const UserPreferencesFolderPreferencesInnerSortEnum date = _$userPreferencesFolderPreferencesInnerSortEnum_date;
  @BuiltValueEnumConst(wireName: r'size')
  static const UserPreferencesFolderPreferencesInnerSortEnum size = _$userPreferencesFolderPreferencesInnerSortEnum_size;

  static Serializer<UserPreferencesFolderPreferencesInnerSortEnum> get serializer => _$userPreferencesFolderPreferencesInnerSortEnumSerializer;

  const UserPreferencesFolderPreferencesInnerSortEnum._(String name): super(name);

  static BuiltSet<UserPreferencesFolderPreferencesInnerSortEnum> get values => _$userPreferencesFolderPreferencesInnerSortEnumValues;
  static UserPreferencesFolderPreferencesInnerSortEnum valueOf(String name) => _$userPreferencesFolderPreferencesInnerSortEnumValueOf(name);
}

class UserPreferencesFolderPreferencesInnerOrderEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'asc')
  static const UserPreferencesFolderPreferencesInnerOrderEnum asc = _$userPreferencesFolderPreferencesInnerOrderEnum_asc;
  @BuiltValueEnumConst(wireName: r'desc')
  static const UserPreferencesFolderPreferencesInnerOrderEnum desc = _$userPreferencesFolderPreferencesInnerOrderEnum_desc;

  static Serializer<UserPreferencesFolderPreferencesInnerOrderEnum> get serializer => _$userPreferencesFolderPreferencesInnerOrderEnumSerializer;

  const UserPreferencesFolderPreferencesInnerOrderEnum._(String name): super(name);

  static BuiltSet<UserPreferencesFolderPreferencesInnerOrderEnum> get values => _$userPreferencesFolderPreferencesInnerOrderEnumValues;
  static UserPreferencesFolderPreferencesInnerOrderEnum valueOf(String name) => _$userPreferencesFolderPreferencesInnerOrderEnumValueOf(name);
}


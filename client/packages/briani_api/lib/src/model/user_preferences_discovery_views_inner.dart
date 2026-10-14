// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'user_preferences_discovery_views_inner.g.dart';

/// UserPreferencesDiscoveryViewsInner
///
/// Properties:
/// * [mode] 
/// * [sort] 
/// * [order] 
/// * [providerIds] 
/// * [categories] 
/// * [minSizeBytes] 
/// * [maxSizeBytes] 
/// * [minSeeders] 
@BuiltValue()
abstract class UserPreferencesDiscoveryViewsInner implements Built<UserPreferencesDiscoveryViewsInner, UserPreferencesDiscoveryViewsInnerBuilder> {
  @BuiltValueField(wireName: r'mode')
  UserPreferencesDiscoveryViewsInnerModeEnum get mode;
  // enum modeEnum {  latest,  mostSeeded,  search,  };

  @BuiltValueField(wireName: r'sort')
  UserPreferencesDiscoveryViewsInnerSortEnum get sort;
  // enum sortEnum {  publishedAt,  seeders,  leechers,  peers,  sizeBytes,  title,  };

  @BuiltValueField(wireName: r'order')
  UserPreferencesDiscoveryViewsInnerOrderEnum get order;
  // enum orderEnum {  asc,  desc,  };

  @BuiltValueField(wireName: r'providerIds')
  BuiltList<String> get providerIds;

  @BuiltValueField(wireName: r'categories')
  BuiltList<int> get categories;

  @BuiltValueField(wireName: r'minSizeBytes')
  int? get minSizeBytes;

  @BuiltValueField(wireName: r'maxSizeBytes')
  int? get maxSizeBytes;

  @BuiltValueField(wireName: r'minSeeders')
  int? get minSeeders;

  UserPreferencesDiscoveryViewsInner._();

  factory UserPreferencesDiscoveryViewsInner([void updates(UserPreferencesDiscoveryViewsInnerBuilder b)]) = _$UserPreferencesDiscoveryViewsInner;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UserPreferencesDiscoveryViewsInnerBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UserPreferencesDiscoveryViewsInner> get serializer => _$UserPreferencesDiscoveryViewsInnerSerializer();
}

class _$UserPreferencesDiscoveryViewsInnerSerializer implements PrimitiveSerializer<UserPreferencesDiscoveryViewsInner> {
  @override
  final Iterable<Type> types = const [UserPreferencesDiscoveryViewsInner, _$UserPreferencesDiscoveryViewsInner];

  @override
  final String wireName = r'UserPreferencesDiscoveryViewsInner';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UserPreferencesDiscoveryViewsInner object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'mode';
    yield serializers.serialize(
      object.mode,
      specifiedType: const FullType(UserPreferencesDiscoveryViewsInnerModeEnum),
    );
    yield r'sort';
    yield serializers.serialize(
      object.sort,
      specifiedType: const FullType(UserPreferencesDiscoveryViewsInnerSortEnum),
    );
    yield r'order';
    yield serializers.serialize(
      object.order,
      specifiedType: const FullType(UserPreferencesDiscoveryViewsInnerOrderEnum),
    );
    yield r'providerIds';
    yield serializers.serialize(
      object.providerIds,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
    yield r'categories';
    yield serializers.serialize(
      object.categories,
      specifiedType: const FullType(BuiltList, [FullType(int)]),
    );
    if (object.minSizeBytes != null) {
      yield r'minSizeBytes';
      yield serializers.serialize(
        object.minSizeBytes,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.maxSizeBytes != null) {
      yield r'maxSizeBytes';
      yield serializers.serialize(
        object.maxSizeBytes,
        specifiedType: const FullType.nullable(int),
      );
    }
    if (object.minSeeders != null) {
      yield r'minSeeders';
      yield serializers.serialize(
        object.minSeeders,
        specifiedType: const FullType.nullable(int),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    UserPreferencesDiscoveryViewsInner object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UserPreferencesDiscoveryViewsInnerBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'mode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(UserPreferencesDiscoveryViewsInnerModeEnum),
          ) as UserPreferencesDiscoveryViewsInnerModeEnum;
          result.mode = valueDes;
          break;
        case r'sort':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(UserPreferencesDiscoveryViewsInnerSortEnum),
          ) as UserPreferencesDiscoveryViewsInnerSortEnum;
          result.sort = valueDes;
          break;
        case r'order':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(UserPreferencesDiscoveryViewsInnerOrderEnum),
          ) as UserPreferencesDiscoveryViewsInnerOrderEnum;
          result.order = valueDes;
          break;
        case r'providerIds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.providerIds.replace(valueDes);
          break;
        case r'categories':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(int)]),
          ) as BuiltList<int>;
          result.categories.replace(valueDes);
          break;
        case r'minSizeBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.minSizeBytes = valueDes;
          break;
        case r'maxSizeBytes':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.maxSizeBytes = valueDes;
          break;
        case r'minSeeders':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.minSeeders = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UserPreferencesDiscoveryViewsInner deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UserPreferencesDiscoveryViewsInnerBuilder();
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


class UserPreferencesDiscoveryViewsInnerModeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'latest')
  static const UserPreferencesDiscoveryViewsInnerModeEnum latest = _$userPreferencesDiscoveryViewsInnerModeEnum_latest;
  @BuiltValueEnumConst(wireName: r'mostSeeded')
  static const UserPreferencesDiscoveryViewsInnerModeEnum mostSeeded = _$userPreferencesDiscoveryViewsInnerModeEnum_mostSeeded;
  @BuiltValueEnumConst(wireName: r'search')
  static const UserPreferencesDiscoveryViewsInnerModeEnum search = _$userPreferencesDiscoveryViewsInnerModeEnum_search;

  static Serializer<UserPreferencesDiscoveryViewsInnerModeEnum> get serializer => _$userPreferencesDiscoveryViewsInnerModeEnumSerializer;

  const UserPreferencesDiscoveryViewsInnerModeEnum._(String name): super(name);

  static BuiltSet<UserPreferencesDiscoveryViewsInnerModeEnum> get values => _$userPreferencesDiscoveryViewsInnerModeEnumValues;
  static UserPreferencesDiscoveryViewsInnerModeEnum valueOf(String name) => _$userPreferencesDiscoveryViewsInnerModeEnumValueOf(name);
}

class UserPreferencesDiscoveryViewsInnerSortEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'publishedAt')
  static const UserPreferencesDiscoveryViewsInnerSortEnum publishedAt = _$userPreferencesDiscoveryViewsInnerSortEnum_publishedAt;
  @BuiltValueEnumConst(wireName: r'seeders')
  static const UserPreferencesDiscoveryViewsInnerSortEnum seeders = _$userPreferencesDiscoveryViewsInnerSortEnum_seeders;
  @BuiltValueEnumConst(wireName: r'leechers')
  static const UserPreferencesDiscoveryViewsInnerSortEnum leechers = _$userPreferencesDiscoveryViewsInnerSortEnum_leechers;
  @BuiltValueEnumConst(wireName: r'peers')
  static const UserPreferencesDiscoveryViewsInnerSortEnum peers = _$userPreferencesDiscoveryViewsInnerSortEnum_peers;
  @BuiltValueEnumConst(wireName: r'sizeBytes')
  static const UserPreferencesDiscoveryViewsInnerSortEnum sizeBytes = _$userPreferencesDiscoveryViewsInnerSortEnum_sizeBytes;
  @BuiltValueEnumConst(wireName: r'title')
  static const UserPreferencesDiscoveryViewsInnerSortEnum title = _$userPreferencesDiscoveryViewsInnerSortEnum_title;

  static Serializer<UserPreferencesDiscoveryViewsInnerSortEnum> get serializer => _$userPreferencesDiscoveryViewsInnerSortEnumSerializer;

  const UserPreferencesDiscoveryViewsInnerSortEnum._(String name): super(name);

  static BuiltSet<UserPreferencesDiscoveryViewsInnerSortEnum> get values => _$userPreferencesDiscoveryViewsInnerSortEnumValues;
  static UserPreferencesDiscoveryViewsInnerSortEnum valueOf(String name) => _$userPreferencesDiscoveryViewsInnerSortEnumValueOf(name);
}

class UserPreferencesDiscoveryViewsInnerOrderEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'asc')
  static const UserPreferencesDiscoveryViewsInnerOrderEnum asc = _$userPreferencesDiscoveryViewsInnerOrderEnum_asc;
  @BuiltValueEnumConst(wireName: r'desc')
  static const UserPreferencesDiscoveryViewsInnerOrderEnum desc = _$userPreferencesDiscoveryViewsInnerOrderEnum_desc;

  static Serializer<UserPreferencesDiscoveryViewsInnerOrderEnum> get serializer => _$userPreferencesDiscoveryViewsInnerOrderEnumSerializer;

  const UserPreferencesDiscoveryViewsInnerOrderEnum._(String name): super(name);

  static BuiltSet<UserPreferencesDiscoveryViewsInnerOrderEnum> get values => _$userPreferencesDiscoveryViewsInnerOrderEnumValues;
  static UserPreferencesDiscoveryViewsInnerOrderEnum valueOf(String name) => _$userPreferencesDiscoveryViewsInnerOrderEnumValueOf(name);
}


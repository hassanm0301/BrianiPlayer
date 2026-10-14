// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'discovery_query.g.dart';

/// Size/seeder filters apply to the bounded fetched result snapshot; unknown counts do not satisfy a numeric minimum. Validate min <= max. No exhaustive indexer pagination is promised.
///
/// Properties:
/// * [mode] 
/// * [query] 
/// * [providerIds] 
/// * [categories] 
/// * [sort] 
/// * [order] 
/// * [minSizeBytes] 
/// * [maxSizeBytes] 
/// * [minSeeders] 
@BuiltValue()
abstract class DiscoveryQuery implements Built<DiscoveryQuery, DiscoveryQueryBuilder> {
  @BuiltValueField(wireName: r'mode')
  DiscoveryQueryModeEnum get mode;
  // enum modeEnum {  latest,  mostSeeded,  search,  };

  @BuiltValueField(wireName: r'query')
  String? get query;

  @BuiltValueField(wireName: r'providerIds')
  BuiltList<String>? get providerIds;

  @BuiltValueField(wireName: r'categories')
  BuiltList<int>? get categories;

  @BuiltValueField(wireName: r'sort')
  DiscoveryQuerySortEnum? get sort;
  // enum sortEnum {  publishedAt,  seeders,  leechers,  peers,  sizeBytes,  title,  };

  @BuiltValueField(wireName: r'order')
  DiscoveryQueryOrderEnum? get order;
  // enum orderEnum {  asc,  desc,  };

  @BuiltValueField(wireName: r'minSizeBytes')
  int? get minSizeBytes;

  @BuiltValueField(wireName: r'maxSizeBytes')
  int? get maxSizeBytes;

  @BuiltValueField(wireName: r'minSeeders')
  int? get minSeeders;

  DiscoveryQuery._();

  factory DiscoveryQuery([void updates(DiscoveryQueryBuilder b)]) = _$DiscoveryQuery;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(DiscoveryQueryBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<DiscoveryQuery> get serializer => _$DiscoveryQuerySerializer();
}

class _$DiscoveryQuerySerializer implements PrimitiveSerializer<DiscoveryQuery> {
  @override
  final Iterable<Type> types = const [DiscoveryQuery, _$DiscoveryQuery];

  @override
  final String wireName = r'DiscoveryQuery';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    DiscoveryQuery object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'mode';
    yield serializers.serialize(
      object.mode,
      specifiedType: const FullType(DiscoveryQueryModeEnum),
    );
    if (object.query != null) {
      yield r'query';
      yield serializers.serialize(
        object.query,
        specifiedType: const FullType(String),
      );
    }
    if (object.providerIds != null) {
      yield r'providerIds';
      yield serializers.serialize(
        object.providerIds,
        specifiedType: const FullType(BuiltList, [FullType(String)]),
      );
    }
    if (object.categories != null) {
      yield r'categories';
      yield serializers.serialize(
        object.categories,
        specifiedType: const FullType(BuiltList, [FullType(int)]),
      );
    }
    if (object.sort != null) {
      yield r'sort';
      yield serializers.serialize(
        object.sort,
        specifiedType: const FullType(DiscoveryQuerySortEnum),
      );
    }
    if (object.order != null) {
      yield r'order';
      yield serializers.serialize(
        object.order,
        specifiedType: const FullType(DiscoveryQueryOrderEnum),
      );
    }
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
    DiscoveryQuery object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required DiscoveryQueryBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'mode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(DiscoveryQueryModeEnum),
          ) as DiscoveryQueryModeEnum;
          result.mode = valueDes;
          break;
        case r'query':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.query = valueDes;
          break;
        case r'providerIds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(String)]),
          ) as BuiltList<String>?;
          if (valueDes == null) continue;
          result.providerIds.replace(valueDes);
          break;
        case r'categories':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(int)]),
          ) as BuiltList<int>?;
          if (valueDes == null) continue;
          result.categories.replace(valueDes);
          break;
        case r'sort':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DiscoveryQuerySortEnum),
          ) as DiscoveryQuerySortEnum?;
          if (valueDes == null) continue;
          result.sort = valueDes;
          break;
        case r'order':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(DiscoveryQueryOrderEnum),
          ) as DiscoveryQueryOrderEnum?;
          if (valueDes == null) continue;
          result.order = valueDes;
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
  DiscoveryQuery deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = DiscoveryQueryBuilder();
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


class DiscoveryQueryModeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'latest')
  static const DiscoveryQueryModeEnum latest = _$discoveryQueryModeEnum_latest;
  @BuiltValueEnumConst(wireName: r'mostSeeded')
  static const DiscoveryQueryModeEnum mostSeeded = _$discoveryQueryModeEnum_mostSeeded;
  @BuiltValueEnumConst(wireName: r'search')
  static const DiscoveryQueryModeEnum search = _$discoveryQueryModeEnum_search;

  static Serializer<DiscoveryQueryModeEnum> get serializer => _$discoveryQueryModeEnumSerializer;

  const DiscoveryQueryModeEnum._(String name): super(name);

  static BuiltSet<DiscoveryQueryModeEnum> get values => _$discoveryQueryModeEnumValues;
  static DiscoveryQueryModeEnum valueOf(String name) => _$discoveryQueryModeEnumValueOf(name);
}

class DiscoveryQuerySortEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'publishedAt')
  static const DiscoveryQuerySortEnum publishedAt = _$discoveryQuerySortEnum_publishedAt;
  @BuiltValueEnumConst(wireName: r'seeders')
  static const DiscoveryQuerySortEnum seeders = _$discoveryQuerySortEnum_seeders;
  @BuiltValueEnumConst(wireName: r'leechers')
  static const DiscoveryQuerySortEnum leechers = _$discoveryQuerySortEnum_leechers;
  @BuiltValueEnumConst(wireName: r'peers')
  static const DiscoveryQuerySortEnum peers = _$discoveryQuerySortEnum_peers;
  @BuiltValueEnumConst(wireName: r'sizeBytes')
  static const DiscoveryQuerySortEnum sizeBytes = _$discoveryQuerySortEnum_sizeBytes;
  @BuiltValueEnumConst(wireName: r'title')
  static const DiscoveryQuerySortEnum title = _$discoveryQuerySortEnum_title;

  static Serializer<DiscoveryQuerySortEnum> get serializer => _$discoveryQuerySortEnumSerializer;

  const DiscoveryQuerySortEnum._(String name): super(name);

  static BuiltSet<DiscoveryQuerySortEnum> get values => _$discoveryQuerySortEnumValues;
  static DiscoveryQuerySortEnum valueOf(String name) => _$discoveryQuerySortEnumValueOf(name);
}

class DiscoveryQueryOrderEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'asc')
  static const DiscoveryQueryOrderEnum asc = _$discoveryQueryOrderEnum_asc;
  @BuiltValueEnumConst(wireName: r'desc')
  static const DiscoveryQueryOrderEnum desc = _$discoveryQueryOrderEnum_desc;

  static Serializer<DiscoveryQueryOrderEnum> get serializer => _$discoveryQueryOrderEnumSerializer;

  const DiscoveryQueryOrderEnum._(String name): super(name);

  static BuiltSet<DiscoveryQueryOrderEnum> get values => _$discoveryQueryOrderEnumValues;
  static DiscoveryQueryOrderEnum valueOf(String name) => _$discoveryQueryOrderEnumValueOf(name);
}


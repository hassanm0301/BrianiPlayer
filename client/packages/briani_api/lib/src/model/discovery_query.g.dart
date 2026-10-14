// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_query.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DiscoveryQueryModeEnum _$discoveryQueryModeEnum_latest =
    const DiscoveryQueryModeEnum._('latest');
const DiscoveryQueryModeEnum _$discoveryQueryModeEnum_mostSeeded =
    const DiscoveryQueryModeEnum._('mostSeeded');
const DiscoveryQueryModeEnum _$discoveryQueryModeEnum_search =
    const DiscoveryQueryModeEnum._('search');

DiscoveryQueryModeEnum _$discoveryQueryModeEnumValueOf(String name) {
  switch (name) {
    case 'latest':
      return _$discoveryQueryModeEnum_latest;
    case 'mostSeeded':
      return _$discoveryQueryModeEnum_mostSeeded;
    case 'search':
      return _$discoveryQueryModeEnum_search;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DiscoveryQueryModeEnum> _$discoveryQueryModeEnumValues =
    BuiltSet<DiscoveryQueryModeEnum>(const <DiscoveryQueryModeEnum>[
  _$discoveryQueryModeEnum_latest,
  _$discoveryQueryModeEnum_mostSeeded,
  _$discoveryQueryModeEnum_search,
]);

const DiscoveryQuerySortEnum _$discoveryQuerySortEnum_publishedAt =
    const DiscoveryQuerySortEnum._('publishedAt');
const DiscoveryQuerySortEnum _$discoveryQuerySortEnum_seeders =
    const DiscoveryQuerySortEnum._('seeders');
const DiscoveryQuerySortEnum _$discoveryQuerySortEnum_leechers =
    const DiscoveryQuerySortEnum._('leechers');
const DiscoveryQuerySortEnum _$discoveryQuerySortEnum_peers =
    const DiscoveryQuerySortEnum._('peers');
const DiscoveryQuerySortEnum _$discoveryQuerySortEnum_sizeBytes =
    const DiscoveryQuerySortEnum._('sizeBytes');
const DiscoveryQuerySortEnum _$discoveryQuerySortEnum_title =
    const DiscoveryQuerySortEnum._('title');

DiscoveryQuerySortEnum _$discoveryQuerySortEnumValueOf(String name) {
  switch (name) {
    case 'publishedAt':
      return _$discoveryQuerySortEnum_publishedAt;
    case 'seeders':
      return _$discoveryQuerySortEnum_seeders;
    case 'leechers':
      return _$discoveryQuerySortEnum_leechers;
    case 'peers':
      return _$discoveryQuerySortEnum_peers;
    case 'sizeBytes':
      return _$discoveryQuerySortEnum_sizeBytes;
    case 'title':
      return _$discoveryQuerySortEnum_title;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DiscoveryQuerySortEnum> _$discoveryQuerySortEnumValues =
    BuiltSet<DiscoveryQuerySortEnum>(const <DiscoveryQuerySortEnum>[
  _$discoveryQuerySortEnum_publishedAt,
  _$discoveryQuerySortEnum_seeders,
  _$discoveryQuerySortEnum_leechers,
  _$discoveryQuerySortEnum_peers,
  _$discoveryQuerySortEnum_sizeBytes,
  _$discoveryQuerySortEnum_title,
]);

const DiscoveryQueryOrderEnum _$discoveryQueryOrderEnum_asc =
    const DiscoveryQueryOrderEnum._('asc');
const DiscoveryQueryOrderEnum _$discoveryQueryOrderEnum_desc =
    const DiscoveryQueryOrderEnum._('desc');

DiscoveryQueryOrderEnum _$discoveryQueryOrderEnumValueOf(String name) {
  switch (name) {
    case 'asc':
      return _$discoveryQueryOrderEnum_asc;
    case 'desc':
      return _$discoveryQueryOrderEnum_desc;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DiscoveryQueryOrderEnum> _$discoveryQueryOrderEnumValues =
    BuiltSet<DiscoveryQueryOrderEnum>(const <DiscoveryQueryOrderEnum>[
  _$discoveryQueryOrderEnum_asc,
  _$discoveryQueryOrderEnum_desc,
]);

Serializer<DiscoveryQueryModeEnum> _$discoveryQueryModeEnumSerializer =
    _$DiscoveryQueryModeEnumSerializer();
Serializer<DiscoveryQuerySortEnum> _$discoveryQuerySortEnumSerializer =
    _$DiscoveryQuerySortEnumSerializer();
Serializer<DiscoveryQueryOrderEnum> _$discoveryQueryOrderEnumSerializer =
    _$DiscoveryQueryOrderEnumSerializer();

class _$DiscoveryQueryModeEnumSerializer
    implements PrimitiveSerializer<DiscoveryQueryModeEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'latest': 'latest',
    'mostSeeded': 'mostSeeded',
    'search': 'search',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'latest': 'latest',
    'mostSeeded': 'mostSeeded',
    'search': 'search',
  };

  @override
  final Iterable<Type> types = const <Type>[DiscoveryQueryModeEnum];
  @override
  final String wireName = 'DiscoveryQueryModeEnum';

  @override
  Object serialize(Serializers serializers, DiscoveryQueryModeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DiscoveryQueryModeEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DiscoveryQueryModeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DiscoveryQuerySortEnumSerializer
    implements PrimitiveSerializer<DiscoveryQuerySortEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'publishedAt': 'publishedAt',
    'seeders': 'seeders',
    'leechers': 'leechers',
    'peers': 'peers',
    'sizeBytes': 'sizeBytes',
    'title': 'title',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'publishedAt': 'publishedAt',
    'seeders': 'seeders',
    'leechers': 'leechers',
    'peers': 'peers',
    'sizeBytes': 'sizeBytes',
    'title': 'title',
  };

  @override
  final Iterable<Type> types = const <Type>[DiscoveryQuerySortEnum];
  @override
  final String wireName = 'DiscoveryQuerySortEnum';

  @override
  Object serialize(Serializers serializers, DiscoveryQuerySortEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DiscoveryQuerySortEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DiscoveryQuerySortEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DiscoveryQueryOrderEnumSerializer
    implements PrimitiveSerializer<DiscoveryQueryOrderEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'asc': 'asc',
    'desc': 'desc',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'asc': 'asc',
    'desc': 'desc',
  };

  @override
  final Iterable<Type> types = const <Type>[DiscoveryQueryOrderEnum];
  @override
  final String wireName = 'DiscoveryQueryOrderEnum';

  @override
  Object serialize(Serializers serializers, DiscoveryQueryOrderEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DiscoveryQueryOrderEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DiscoveryQueryOrderEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DiscoveryQuery extends DiscoveryQuery {
  @override
  final DiscoveryQueryModeEnum mode;
  @override
  final String? query;
  @override
  final BuiltList<String>? providerIds;
  @override
  final BuiltList<int>? categories;
  @override
  final DiscoveryQuerySortEnum? sort;
  @override
  final DiscoveryQueryOrderEnum? order;
  @override
  final int? minSizeBytes;
  @override
  final int? maxSizeBytes;
  @override
  final int? minSeeders;

  factory _$DiscoveryQuery([void Function(DiscoveryQueryBuilder)? updates]) =>
      (DiscoveryQueryBuilder()..update(updates))._build();

  _$DiscoveryQuery._(
      {required this.mode,
      this.query,
      this.providerIds,
      this.categories,
      this.sort,
      this.order,
      this.minSizeBytes,
      this.maxSizeBytes,
      this.minSeeders})
      : super._();
  @override
  DiscoveryQuery rebuild(void Function(DiscoveryQueryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DiscoveryQueryBuilder toBuilder() => DiscoveryQueryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DiscoveryQuery &&
        mode == other.mode &&
        query == other.query &&
        providerIds == other.providerIds &&
        categories == other.categories &&
        sort == other.sort &&
        order == other.order &&
        minSizeBytes == other.minSizeBytes &&
        maxSizeBytes == other.maxSizeBytes &&
        minSeeders == other.minSeeders;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mode.hashCode);
    _$hash = $jc(_$hash, query.hashCode);
    _$hash = $jc(_$hash, providerIds.hashCode);
    _$hash = $jc(_$hash, categories.hashCode);
    _$hash = $jc(_$hash, sort.hashCode);
    _$hash = $jc(_$hash, order.hashCode);
    _$hash = $jc(_$hash, minSizeBytes.hashCode);
    _$hash = $jc(_$hash, maxSizeBytes.hashCode);
    _$hash = $jc(_$hash, minSeeders.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DiscoveryQuery')
          ..add('mode', mode)
          ..add('query', query)
          ..add('providerIds', providerIds)
          ..add('categories', categories)
          ..add('sort', sort)
          ..add('order', order)
          ..add('minSizeBytes', minSizeBytes)
          ..add('maxSizeBytes', maxSizeBytes)
          ..add('minSeeders', minSeeders))
        .toString();
  }
}

class DiscoveryQueryBuilder
    implements Builder<DiscoveryQuery, DiscoveryQueryBuilder> {
  _$DiscoveryQuery? _$v;

  DiscoveryQueryModeEnum? _mode;
  DiscoveryQueryModeEnum? get mode => _$this._mode;
  set mode(DiscoveryQueryModeEnum? mode) => _$this._mode = mode;

  String? _query;
  String? get query => _$this._query;
  set query(String? query) => _$this._query = query;

  ListBuilder<String>? _providerIds;
  ListBuilder<String> get providerIds =>
      _$this._providerIds ??= ListBuilder<String>();
  set providerIds(ListBuilder<String>? providerIds) =>
      _$this._providerIds = providerIds;

  ListBuilder<int>? _categories;
  ListBuilder<int> get categories => _$this._categories ??= ListBuilder<int>();
  set categories(ListBuilder<int>? categories) =>
      _$this._categories = categories;

  DiscoveryQuerySortEnum? _sort;
  DiscoveryQuerySortEnum? get sort => _$this._sort;
  set sort(DiscoveryQuerySortEnum? sort) => _$this._sort = sort;

  DiscoveryQueryOrderEnum? _order;
  DiscoveryQueryOrderEnum? get order => _$this._order;
  set order(DiscoveryQueryOrderEnum? order) => _$this._order = order;

  int? _minSizeBytes;
  int? get minSizeBytes => _$this._minSizeBytes;
  set minSizeBytes(int? minSizeBytes) => _$this._minSizeBytes = minSizeBytes;

  int? _maxSizeBytes;
  int? get maxSizeBytes => _$this._maxSizeBytes;
  set maxSizeBytes(int? maxSizeBytes) => _$this._maxSizeBytes = maxSizeBytes;

  int? _minSeeders;
  int? get minSeeders => _$this._minSeeders;
  set minSeeders(int? minSeeders) => _$this._minSeeders = minSeeders;

  DiscoveryQueryBuilder() {
    DiscoveryQuery._defaults(this);
  }

  DiscoveryQueryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mode = $v.mode;
      _query = $v.query;
      _providerIds = $v.providerIds?.toBuilder();
      _categories = $v.categories?.toBuilder();
      _sort = $v.sort;
      _order = $v.order;
      _minSizeBytes = $v.minSizeBytes;
      _maxSizeBytes = $v.maxSizeBytes;
      _minSeeders = $v.minSeeders;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DiscoveryQuery other) {
    _$v = other as _$DiscoveryQuery;
  }

  @override
  void update(void Function(DiscoveryQueryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DiscoveryQuery build() => _build();

  _$DiscoveryQuery _build() {
    _$DiscoveryQuery _$result;
    try {
      _$result = _$v ??
          _$DiscoveryQuery._(
            mode: BuiltValueNullFieldError.checkNotNull(
                mode, r'DiscoveryQuery', 'mode'),
            query: query,
            providerIds: _providerIds?.build(),
            categories: _categories?.build(),
            sort: sort,
            order: order,
            minSizeBytes: minSizeBytes,
            maxSizeBytes: maxSizeBytes,
            minSeeders: minSeeders,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'providerIds';
        _providerIds?.build();
        _$failedField = 'categories';
        _categories?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'DiscoveryQuery', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

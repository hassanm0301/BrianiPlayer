// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences_discovery_views_inner.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const UserPreferencesDiscoveryViewsInnerModeEnum
    _$userPreferencesDiscoveryViewsInnerModeEnum_latest =
    const UserPreferencesDiscoveryViewsInnerModeEnum._('latest');
const UserPreferencesDiscoveryViewsInnerModeEnum
    _$userPreferencesDiscoveryViewsInnerModeEnum_mostSeeded =
    const UserPreferencesDiscoveryViewsInnerModeEnum._('mostSeeded');
const UserPreferencesDiscoveryViewsInnerModeEnum
    _$userPreferencesDiscoveryViewsInnerModeEnum_search =
    const UserPreferencesDiscoveryViewsInnerModeEnum._('search');

UserPreferencesDiscoveryViewsInnerModeEnum
    _$userPreferencesDiscoveryViewsInnerModeEnumValueOf(String name) {
  switch (name) {
    case 'latest':
      return _$userPreferencesDiscoveryViewsInnerModeEnum_latest;
    case 'mostSeeded':
      return _$userPreferencesDiscoveryViewsInnerModeEnum_mostSeeded;
    case 'search':
      return _$userPreferencesDiscoveryViewsInnerModeEnum_search;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<UserPreferencesDiscoveryViewsInnerModeEnum>
    _$userPreferencesDiscoveryViewsInnerModeEnumValues = BuiltSet<
        UserPreferencesDiscoveryViewsInnerModeEnum>(const <UserPreferencesDiscoveryViewsInnerModeEnum>[
  _$userPreferencesDiscoveryViewsInnerModeEnum_latest,
  _$userPreferencesDiscoveryViewsInnerModeEnum_mostSeeded,
  _$userPreferencesDiscoveryViewsInnerModeEnum_search,
]);

const UserPreferencesDiscoveryViewsInnerSortEnum
    _$userPreferencesDiscoveryViewsInnerSortEnum_publishedAt =
    const UserPreferencesDiscoveryViewsInnerSortEnum._('publishedAt');
const UserPreferencesDiscoveryViewsInnerSortEnum
    _$userPreferencesDiscoveryViewsInnerSortEnum_seeders =
    const UserPreferencesDiscoveryViewsInnerSortEnum._('seeders');
const UserPreferencesDiscoveryViewsInnerSortEnum
    _$userPreferencesDiscoveryViewsInnerSortEnum_leechers =
    const UserPreferencesDiscoveryViewsInnerSortEnum._('leechers');
const UserPreferencesDiscoveryViewsInnerSortEnum
    _$userPreferencesDiscoveryViewsInnerSortEnum_peers =
    const UserPreferencesDiscoveryViewsInnerSortEnum._('peers');
const UserPreferencesDiscoveryViewsInnerSortEnum
    _$userPreferencesDiscoveryViewsInnerSortEnum_sizeBytes =
    const UserPreferencesDiscoveryViewsInnerSortEnum._('sizeBytes');
const UserPreferencesDiscoveryViewsInnerSortEnum
    _$userPreferencesDiscoveryViewsInnerSortEnum_title =
    const UserPreferencesDiscoveryViewsInnerSortEnum._('title');

UserPreferencesDiscoveryViewsInnerSortEnum
    _$userPreferencesDiscoveryViewsInnerSortEnumValueOf(String name) {
  switch (name) {
    case 'publishedAt':
      return _$userPreferencesDiscoveryViewsInnerSortEnum_publishedAt;
    case 'seeders':
      return _$userPreferencesDiscoveryViewsInnerSortEnum_seeders;
    case 'leechers':
      return _$userPreferencesDiscoveryViewsInnerSortEnum_leechers;
    case 'peers':
      return _$userPreferencesDiscoveryViewsInnerSortEnum_peers;
    case 'sizeBytes':
      return _$userPreferencesDiscoveryViewsInnerSortEnum_sizeBytes;
    case 'title':
      return _$userPreferencesDiscoveryViewsInnerSortEnum_title;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<UserPreferencesDiscoveryViewsInnerSortEnum>
    _$userPreferencesDiscoveryViewsInnerSortEnumValues = BuiltSet<
        UserPreferencesDiscoveryViewsInnerSortEnum>(const <UserPreferencesDiscoveryViewsInnerSortEnum>[
  _$userPreferencesDiscoveryViewsInnerSortEnum_publishedAt,
  _$userPreferencesDiscoveryViewsInnerSortEnum_seeders,
  _$userPreferencesDiscoveryViewsInnerSortEnum_leechers,
  _$userPreferencesDiscoveryViewsInnerSortEnum_peers,
  _$userPreferencesDiscoveryViewsInnerSortEnum_sizeBytes,
  _$userPreferencesDiscoveryViewsInnerSortEnum_title,
]);

const UserPreferencesDiscoveryViewsInnerOrderEnum
    _$userPreferencesDiscoveryViewsInnerOrderEnum_asc =
    const UserPreferencesDiscoveryViewsInnerOrderEnum._('asc');
const UserPreferencesDiscoveryViewsInnerOrderEnum
    _$userPreferencesDiscoveryViewsInnerOrderEnum_desc =
    const UserPreferencesDiscoveryViewsInnerOrderEnum._('desc');

UserPreferencesDiscoveryViewsInnerOrderEnum
    _$userPreferencesDiscoveryViewsInnerOrderEnumValueOf(String name) {
  switch (name) {
    case 'asc':
      return _$userPreferencesDiscoveryViewsInnerOrderEnum_asc;
    case 'desc':
      return _$userPreferencesDiscoveryViewsInnerOrderEnum_desc;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<UserPreferencesDiscoveryViewsInnerOrderEnum>
    _$userPreferencesDiscoveryViewsInnerOrderEnumValues = BuiltSet<
        UserPreferencesDiscoveryViewsInnerOrderEnum>(const <UserPreferencesDiscoveryViewsInnerOrderEnum>[
  _$userPreferencesDiscoveryViewsInnerOrderEnum_asc,
  _$userPreferencesDiscoveryViewsInnerOrderEnum_desc,
]);

Serializer<UserPreferencesDiscoveryViewsInnerModeEnum>
    _$userPreferencesDiscoveryViewsInnerModeEnumSerializer =
    _$UserPreferencesDiscoveryViewsInnerModeEnumSerializer();
Serializer<UserPreferencesDiscoveryViewsInnerSortEnum>
    _$userPreferencesDiscoveryViewsInnerSortEnumSerializer =
    _$UserPreferencesDiscoveryViewsInnerSortEnumSerializer();
Serializer<UserPreferencesDiscoveryViewsInnerOrderEnum>
    _$userPreferencesDiscoveryViewsInnerOrderEnumSerializer =
    _$UserPreferencesDiscoveryViewsInnerOrderEnumSerializer();

class _$UserPreferencesDiscoveryViewsInnerModeEnumSerializer
    implements PrimitiveSerializer<UserPreferencesDiscoveryViewsInnerModeEnum> {
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
  final Iterable<Type> types = const <Type>[
    UserPreferencesDiscoveryViewsInnerModeEnum
  ];
  @override
  final String wireName = 'UserPreferencesDiscoveryViewsInnerModeEnum';

  @override
  Object serialize(Serializers serializers,
          UserPreferencesDiscoveryViewsInnerModeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  UserPreferencesDiscoveryViewsInnerModeEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      UserPreferencesDiscoveryViewsInnerModeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$UserPreferencesDiscoveryViewsInnerSortEnumSerializer
    implements PrimitiveSerializer<UserPreferencesDiscoveryViewsInnerSortEnum> {
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
  final Iterable<Type> types = const <Type>[
    UserPreferencesDiscoveryViewsInnerSortEnum
  ];
  @override
  final String wireName = 'UserPreferencesDiscoveryViewsInnerSortEnum';

  @override
  Object serialize(Serializers serializers,
          UserPreferencesDiscoveryViewsInnerSortEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  UserPreferencesDiscoveryViewsInnerSortEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      UserPreferencesDiscoveryViewsInnerSortEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$UserPreferencesDiscoveryViewsInnerOrderEnumSerializer
    implements
        PrimitiveSerializer<UserPreferencesDiscoveryViewsInnerOrderEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'asc': 'asc',
    'desc': 'desc',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'asc': 'asc',
    'desc': 'desc',
  };

  @override
  final Iterable<Type> types = const <Type>[
    UserPreferencesDiscoveryViewsInnerOrderEnum
  ];
  @override
  final String wireName = 'UserPreferencesDiscoveryViewsInnerOrderEnum';

  @override
  Object serialize(Serializers serializers,
          UserPreferencesDiscoveryViewsInnerOrderEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  UserPreferencesDiscoveryViewsInnerOrderEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      UserPreferencesDiscoveryViewsInnerOrderEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$UserPreferencesDiscoveryViewsInner
    extends UserPreferencesDiscoveryViewsInner {
  @override
  final UserPreferencesDiscoveryViewsInnerModeEnum mode;
  @override
  final UserPreferencesDiscoveryViewsInnerSortEnum sort;
  @override
  final UserPreferencesDiscoveryViewsInnerOrderEnum order;
  @override
  final BuiltList<String> providerIds;
  @override
  final BuiltList<int> categories;
  @override
  final int? minSizeBytes;
  @override
  final int? maxSizeBytes;
  @override
  final int? minSeeders;

  factory _$UserPreferencesDiscoveryViewsInner(
          [void Function(UserPreferencesDiscoveryViewsInnerBuilder)?
              updates]) =>
      (UserPreferencesDiscoveryViewsInnerBuilder()..update(updates))._build();

  _$UserPreferencesDiscoveryViewsInner._(
      {required this.mode,
      required this.sort,
      required this.order,
      required this.providerIds,
      required this.categories,
      this.minSizeBytes,
      this.maxSizeBytes,
      this.minSeeders})
      : super._();
  @override
  UserPreferencesDiscoveryViewsInner rebuild(
          void Function(UserPreferencesDiscoveryViewsInnerBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  UserPreferencesDiscoveryViewsInnerBuilder toBuilder() =>
      UserPreferencesDiscoveryViewsInnerBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UserPreferencesDiscoveryViewsInner &&
        mode == other.mode &&
        sort == other.sort &&
        order == other.order &&
        providerIds == other.providerIds &&
        categories == other.categories &&
        minSizeBytes == other.minSizeBytes &&
        maxSizeBytes == other.maxSizeBytes &&
        minSeeders == other.minSeeders;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, mode.hashCode);
    _$hash = $jc(_$hash, sort.hashCode);
    _$hash = $jc(_$hash, order.hashCode);
    _$hash = $jc(_$hash, providerIds.hashCode);
    _$hash = $jc(_$hash, categories.hashCode);
    _$hash = $jc(_$hash, minSizeBytes.hashCode);
    _$hash = $jc(_$hash, maxSizeBytes.hashCode);
    _$hash = $jc(_$hash, minSeeders.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'UserPreferencesDiscoveryViewsInner')
          ..add('mode', mode)
          ..add('sort', sort)
          ..add('order', order)
          ..add('providerIds', providerIds)
          ..add('categories', categories)
          ..add('minSizeBytes', minSizeBytes)
          ..add('maxSizeBytes', maxSizeBytes)
          ..add('minSeeders', minSeeders))
        .toString();
  }
}

class UserPreferencesDiscoveryViewsInnerBuilder
    implements
        Builder<UserPreferencesDiscoveryViewsInner,
            UserPreferencesDiscoveryViewsInnerBuilder> {
  _$UserPreferencesDiscoveryViewsInner? _$v;

  UserPreferencesDiscoveryViewsInnerModeEnum? _mode;
  UserPreferencesDiscoveryViewsInnerModeEnum? get mode => _$this._mode;
  set mode(UserPreferencesDiscoveryViewsInnerModeEnum? mode) =>
      _$this._mode = mode;

  UserPreferencesDiscoveryViewsInnerSortEnum? _sort;
  UserPreferencesDiscoveryViewsInnerSortEnum? get sort => _$this._sort;
  set sort(UserPreferencesDiscoveryViewsInnerSortEnum? sort) =>
      _$this._sort = sort;

  UserPreferencesDiscoveryViewsInnerOrderEnum? _order;
  UserPreferencesDiscoveryViewsInnerOrderEnum? get order => _$this._order;
  set order(UserPreferencesDiscoveryViewsInnerOrderEnum? order) =>
      _$this._order = order;

  ListBuilder<String>? _providerIds;
  ListBuilder<String> get providerIds =>
      _$this._providerIds ??= ListBuilder<String>();
  set providerIds(ListBuilder<String>? providerIds) =>
      _$this._providerIds = providerIds;

  ListBuilder<int>? _categories;
  ListBuilder<int> get categories => _$this._categories ??= ListBuilder<int>();
  set categories(ListBuilder<int>? categories) =>
      _$this._categories = categories;

  int? _minSizeBytes;
  int? get minSizeBytes => _$this._minSizeBytes;
  set minSizeBytes(int? minSizeBytes) => _$this._minSizeBytes = minSizeBytes;

  int? _maxSizeBytes;
  int? get maxSizeBytes => _$this._maxSizeBytes;
  set maxSizeBytes(int? maxSizeBytes) => _$this._maxSizeBytes = maxSizeBytes;

  int? _minSeeders;
  int? get minSeeders => _$this._minSeeders;
  set minSeeders(int? minSeeders) => _$this._minSeeders = minSeeders;

  UserPreferencesDiscoveryViewsInnerBuilder() {
    UserPreferencesDiscoveryViewsInner._defaults(this);
  }

  UserPreferencesDiscoveryViewsInnerBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _mode = $v.mode;
      _sort = $v.sort;
      _order = $v.order;
      _providerIds = $v.providerIds.toBuilder();
      _categories = $v.categories.toBuilder();
      _minSizeBytes = $v.minSizeBytes;
      _maxSizeBytes = $v.maxSizeBytes;
      _minSeeders = $v.minSeeders;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UserPreferencesDiscoveryViewsInner other) {
    _$v = other as _$UserPreferencesDiscoveryViewsInner;
  }

  @override
  void update(
      void Function(UserPreferencesDiscoveryViewsInnerBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UserPreferencesDiscoveryViewsInner build() => _build();

  _$UserPreferencesDiscoveryViewsInner _build() {
    _$UserPreferencesDiscoveryViewsInner _$result;
    try {
      _$result = _$v ??
          _$UserPreferencesDiscoveryViewsInner._(
            mode: BuiltValueNullFieldError.checkNotNull(
                mode, r'UserPreferencesDiscoveryViewsInner', 'mode'),
            sort: BuiltValueNullFieldError.checkNotNull(
                sort, r'UserPreferencesDiscoveryViewsInner', 'sort'),
            order: BuiltValueNullFieldError.checkNotNull(
                order, r'UserPreferencesDiscoveryViewsInner', 'order'),
            providerIds: providerIds.build(),
            categories: categories.build(),
            minSizeBytes: minSizeBytes,
            maxSizeBytes: maxSizeBytes,
            minSeeders: minSeeders,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'providerIds';
        providerIds.build();
        _$failedField = 'categories';
        categories.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'UserPreferencesDiscoveryViewsInner', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

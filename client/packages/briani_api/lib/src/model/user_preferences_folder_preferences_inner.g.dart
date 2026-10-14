// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences_folder_preferences_inner.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const UserPreferencesFolderPreferencesInnerLayoutEnum
    _$userPreferencesFolderPreferencesInnerLayoutEnum_grid =
    const UserPreferencesFolderPreferencesInnerLayoutEnum._('grid');
const UserPreferencesFolderPreferencesInnerLayoutEnum
    _$userPreferencesFolderPreferencesInnerLayoutEnum_list =
    const UserPreferencesFolderPreferencesInnerLayoutEnum._('list');

UserPreferencesFolderPreferencesInnerLayoutEnum
    _$userPreferencesFolderPreferencesInnerLayoutEnumValueOf(String name) {
  switch (name) {
    case 'grid':
      return _$userPreferencesFolderPreferencesInnerLayoutEnum_grid;
    case 'list':
      return _$userPreferencesFolderPreferencesInnerLayoutEnum_list;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<UserPreferencesFolderPreferencesInnerLayoutEnum>
    _$userPreferencesFolderPreferencesInnerLayoutEnumValues = BuiltSet<
        UserPreferencesFolderPreferencesInnerLayoutEnum>(const <UserPreferencesFolderPreferencesInnerLayoutEnum>[
  _$userPreferencesFolderPreferencesInnerLayoutEnum_grid,
  _$userPreferencesFolderPreferencesInnerLayoutEnum_list,
]);

const UserPreferencesFolderPreferencesInnerSortEnum
    _$userPreferencesFolderPreferencesInnerSortEnum_byName =
    const UserPreferencesFolderPreferencesInnerSortEnum._('byName');
const UserPreferencesFolderPreferencesInnerSortEnum
    _$userPreferencesFolderPreferencesInnerSortEnum_date =
    const UserPreferencesFolderPreferencesInnerSortEnum._('date');
const UserPreferencesFolderPreferencesInnerSortEnum
    _$userPreferencesFolderPreferencesInnerSortEnum_size =
    const UserPreferencesFolderPreferencesInnerSortEnum._('size');

UserPreferencesFolderPreferencesInnerSortEnum
    _$userPreferencesFolderPreferencesInnerSortEnumValueOf(String name) {
  switch (name) {
    case 'byName':
      return _$userPreferencesFolderPreferencesInnerSortEnum_byName;
    case 'date':
      return _$userPreferencesFolderPreferencesInnerSortEnum_date;
    case 'size':
      return _$userPreferencesFolderPreferencesInnerSortEnum_size;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<UserPreferencesFolderPreferencesInnerSortEnum>
    _$userPreferencesFolderPreferencesInnerSortEnumValues = BuiltSet<
        UserPreferencesFolderPreferencesInnerSortEnum>(const <UserPreferencesFolderPreferencesInnerSortEnum>[
  _$userPreferencesFolderPreferencesInnerSortEnum_byName,
  _$userPreferencesFolderPreferencesInnerSortEnum_date,
  _$userPreferencesFolderPreferencesInnerSortEnum_size,
]);

const UserPreferencesFolderPreferencesInnerOrderEnum
    _$userPreferencesFolderPreferencesInnerOrderEnum_asc =
    const UserPreferencesFolderPreferencesInnerOrderEnum._('asc');
const UserPreferencesFolderPreferencesInnerOrderEnum
    _$userPreferencesFolderPreferencesInnerOrderEnum_desc =
    const UserPreferencesFolderPreferencesInnerOrderEnum._('desc');

UserPreferencesFolderPreferencesInnerOrderEnum
    _$userPreferencesFolderPreferencesInnerOrderEnumValueOf(String name) {
  switch (name) {
    case 'asc':
      return _$userPreferencesFolderPreferencesInnerOrderEnum_asc;
    case 'desc':
      return _$userPreferencesFolderPreferencesInnerOrderEnum_desc;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<UserPreferencesFolderPreferencesInnerOrderEnum>
    _$userPreferencesFolderPreferencesInnerOrderEnumValues = BuiltSet<
        UserPreferencesFolderPreferencesInnerOrderEnum>(const <UserPreferencesFolderPreferencesInnerOrderEnum>[
  _$userPreferencesFolderPreferencesInnerOrderEnum_asc,
  _$userPreferencesFolderPreferencesInnerOrderEnum_desc,
]);

Serializer<UserPreferencesFolderPreferencesInnerLayoutEnum>
    _$userPreferencesFolderPreferencesInnerLayoutEnumSerializer =
    _$UserPreferencesFolderPreferencesInnerLayoutEnumSerializer();
Serializer<UserPreferencesFolderPreferencesInnerSortEnum>
    _$userPreferencesFolderPreferencesInnerSortEnumSerializer =
    _$UserPreferencesFolderPreferencesInnerSortEnumSerializer();
Serializer<UserPreferencesFolderPreferencesInnerOrderEnum>
    _$userPreferencesFolderPreferencesInnerOrderEnumSerializer =
    _$UserPreferencesFolderPreferencesInnerOrderEnumSerializer();

class _$UserPreferencesFolderPreferencesInnerLayoutEnumSerializer
    implements
        PrimitiveSerializer<UserPreferencesFolderPreferencesInnerLayoutEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'grid': 'grid',
    'list': 'list',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'grid': 'grid',
    'list': 'list',
  };

  @override
  final Iterable<Type> types = const <Type>[
    UserPreferencesFolderPreferencesInnerLayoutEnum
  ];
  @override
  final String wireName = 'UserPreferencesFolderPreferencesInnerLayoutEnum';

  @override
  Object serialize(Serializers serializers,
          UserPreferencesFolderPreferencesInnerLayoutEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  UserPreferencesFolderPreferencesInnerLayoutEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      UserPreferencesFolderPreferencesInnerLayoutEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$UserPreferencesFolderPreferencesInnerSortEnumSerializer
    implements
        PrimitiveSerializer<UserPreferencesFolderPreferencesInnerSortEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'byName': 'name',
    'date': 'date',
    'size': 'size',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'name': 'byName',
    'date': 'date',
    'size': 'size',
  };

  @override
  final Iterable<Type> types = const <Type>[
    UserPreferencesFolderPreferencesInnerSortEnum
  ];
  @override
  final String wireName = 'UserPreferencesFolderPreferencesInnerSortEnum';

  @override
  Object serialize(Serializers serializers,
          UserPreferencesFolderPreferencesInnerSortEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  UserPreferencesFolderPreferencesInnerSortEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      UserPreferencesFolderPreferencesInnerSortEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$UserPreferencesFolderPreferencesInnerOrderEnumSerializer
    implements
        PrimitiveSerializer<UserPreferencesFolderPreferencesInnerOrderEnum> {
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
    UserPreferencesFolderPreferencesInnerOrderEnum
  ];
  @override
  final String wireName = 'UserPreferencesFolderPreferencesInnerOrderEnum';

  @override
  Object serialize(Serializers serializers,
          UserPreferencesFolderPreferencesInnerOrderEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  UserPreferencesFolderPreferencesInnerOrderEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      UserPreferencesFolderPreferencesInnerOrderEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$UserPreferencesFolderPreferencesInner
    extends UserPreferencesFolderPreferencesInner {
  @override
  final String libraryId;
  @override
  final String? folderId;
  @override
  final UserPreferencesFolderPreferencesInnerLayoutEnum layout;
  @override
  final UserPreferencesFolderPreferencesInnerSortEnum sort;
  @override
  final UserPreferencesFolderPreferencesInnerOrderEnum order;

  factory _$UserPreferencesFolderPreferencesInner(
          [void Function(UserPreferencesFolderPreferencesInnerBuilder)?
              updates]) =>
      (UserPreferencesFolderPreferencesInnerBuilder()..update(updates))
          ._build();

  _$UserPreferencesFolderPreferencesInner._(
      {required this.libraryId,
      this.folderId,
      required this.layout,
      required this.sort,
      required this.order})
      : super._();
  @override
  UserPreferencesFolderPreferencesInner rebuild(
          void Function(UserPreferencesFolderPreferencesInnerBuilder)
              updates) =>
      (toBuilder()..update(updates)).build();

  @override
  UserPreferencesFolderPreferencesInnerBuilder toBuilder() =>
      UserPreferencesFolderPreferencesInnerBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UserPreferencesFolderPreferencesInner &&
        libraryId == other.libraryId &&
        folderId == other.folderId &&
        layout == other.layout &&
        sort == other.sort &&
        order == other.order;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, libraryId.hashCode);
    _$hash = $jc(_$hash, folderId.hashCode);
    _$hash = $jc(_$hash, layout.hashCode);
    _$hash = $jc(_$hash, sort.hashCode);
    _$hash = $jc(_$hash, order.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(
            r'UserPreferencesFolderPreferencesInner')
          ..add('libraryId', libraryId)
          ..add('folderId', folderId)
          ..add('layout', layout)
          ..add('sort', sort)
          ..add('order', order))
        .toString();
  }
}

class UserPreferencesFolderPreferencesInnerBuilder
    implements
        Builder<UserPreferencesFolderPreferencesInner,
            UserPreferencesFolderPreferencesInnerBuilder> {
  _$UserPreferencesFolderPreferencesInner? _$v;

  String? _libraryId;
  String? get libraryId => _$this._libraryId;
  set libraryId(String? libraryId) => _$this._libraryId = libraryId;

  String? _folderId;
  String? get folderId => _$this._folderId;
  set folderId(String? folderId) => _$this._folderId = folderId;

  UserPreferencesFolderPreferencesInnerLayoutEnum? _layout;
  UserPreferencesFolderPreferencesInnerLayoutEnum? get layout => _$this._layout;
  set layout(UserPreferencesFolderPreferencesInnerLayoutEnum? layout) =>
      _$this._layout = layout;

  UserPreferencesFolderPreferencesInnerSortEnum? _sort;
  UserPreferencesFolderPreferencesInnerSortEnum? get sort => _$this._sort;
  set sort(UserPreferencesFolderPreferencesInnerSortEnum? sort) =>
      _$this._sort = sort;

  UserPreferencesFolderPreferencesInnerOrderEnum? _order;
  UserPreferencesFolderPreferencesInnerOrderEnum? get order => _$this._order;
  set order(UserPreferencesFolderPreferencesInnerOrderEnum? order) =>
      _$this._order = order;

  UserPreferencesFolderPreferencesInnerBuilder() {
    UserPreferencesFolderPreferencesInner._defaults(this);
  }

  UserPreferencesFolderPreferencesInnerBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _libraryId = $v.libraryId;
      _folderId = $v.folderId;
      _layout = $v.layout;
      _sort = $v.sort;
      _order = $v.order;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UserPreferencesFolderPreferencesInner other) {
    _$v = other as _$UserPreferencesFolderPreferencesInner;
  }

  @override
  void update(
      void Function(UserPreferencesFolderPreferencesInnerBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  UserPreferencesFolderPreferencesInner build() => _build();

  _$UserPreferencesFolderPreferencesInner _build() {
    final _$result = _$v ??
        _$UserPreferencesFolderPreferencesInner._(
          libraryId: BuiltValueNullFieldError.checkNotNull(
              libraryId, r'UserPreferencesFolderPreferencesInner', 'libraryId'),
          folderId: folderId,
          layout: BuiltValueNullFieldError.checkNotNull(
              layout, r'UserPreferencesFolderPreferencesInner', 'layout'),
          sort: BuiltValueNullFieldError.checkNotNull(
              sort, r'UserPreferencesFolderPreferencesInner', 'sort'),
          order: BuiltValueNullFieldError.checkNotNull(
              order, r'UserPreferencesFolderPreferencesInner', 'order'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

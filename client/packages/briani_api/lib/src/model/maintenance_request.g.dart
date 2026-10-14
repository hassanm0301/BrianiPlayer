// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const MaintenanceRequestActionEnum
    _$maintenanceRequestActionEnum_rescanLibraries =
    const MaintenanceRequestActionEnum._('rescanLibraries');
const MaintenanceRequestActionEnum
    _$maintenanceRequestActionEnum_pruneThumbnailCache =
    const MaintenanceRequestActionEnum._('pruneThumbnailCache');
const MaintenanceRequestActionEnum
    _$maintenanceRequestActionEnum_databaseSnapshot =
    const MaintenanceRequestActionEnum._('databaseSnapshot');

MaintenanceRequestActionEnum _$maintenanceRequestActionEnumValueOf(
    String name) {
  switch (name) {
    case 'rescanLibraries':
      return _$maintenanceRequestActionEnum_rescanLibraries;
    case 'pruneThumbnailCache':
      return _$maintenanceRequestActionEnum_pruneThumbnailCache;
    case 'databaseSnapshot':
      return _$maintenanceRequestActionEnum_databaseSnapshot;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<MaintenanceRequestActionEnum>
    _$maintenanceRequestActionEnumValues =
    BuiltSet<MaintenanceRequestActionEnum>(const <MaintenanceRequestActionEnum>[
  _$maintenanceRequestActionEnum_rescanLibraries,
  _$maintenanceRequestActionEnum_pruneThumbnailCache,
  _$maintenanceRequestActionEnum_databaseSnapshot,
]);

Serializer<MaintenanceRequestActionEnum>
    _$maintenanceRequestActionEnumSerializer =
    _$MaintenanceRequestActionEnumSerializer();

class _$MaintenanceRequestActionEnumSerializer
    implements PrimitiveSerializer<MaintenanceRequestActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'rescanLibraries': 'rescanLibraries',
    'pruneThumbnailCache': 'pruneThumbnailCache',
    'databaseSnapshot': 'databaseSnapshot',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'rescanLibraries': 'rescanLibraries',
    'pruneThumbnailCache': 'pruneThumbnailCache',
    'databaseSnapshot': 'databaseSnapshot',
  };

  @override
  final Iterable<Type> types = const <Type>[MaintenanceRequestActionEnum];
  @override
  final String wireName = 'MaintenanceRequestActionEnum';

  @override
  Object serialize(Serializers serializers, MaintenanceRequestActionEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  MaintenanceRequestActionEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      MaintenanceRequestActionEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$MaintenanceRequest extends MaintenanceRequest {
  @override
  final MaintenanceRequestActionEnum action;
  @override
  final String? libraryId;

  factory _$MaintenanceRequest(
          [void Function(MaintenanceRequestBuilder)? updates]) =>
      (MaintenanceRequestBuilder()..update(updates))._build();

  _$MaintenanceRequest._({required this.action, this.libraryId}) : super._();
  @override
  MaintenanceRequest rebuild(
          void Function(MaintenanceRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MaintenanceRequestBuilder toBuilder() =>
      MaintenanceRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MaintenanceRequest &&
        action == other.action &&
        libraryId == other.libraryId;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, action.hashCode);
    _$hash = $jc(_$hash, libraryId.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MaintenanceRequest')
          ..add('action', action)
          ..add('libraryId', libraryId))
        .toString();
  }
}

class MaintenanceRequestBuilder
    implements Builder<MaintenanceRequest, MaintenanceRequestBuilder> {
  _$MaintenanceRequest? _$v;

  MaintenanceRequestActionEnum? _action;
  MaintenanceRequestActionEnum? get action => _$this._action;
  set action(MaintenanceRequestActionEnum? action) => _$this._action = action;

  String? _libraryId;
  String? get libraryId => _$this._libraryId;
  set libraryId(String? libraryId) => _$this._libraryId = libraryId;

  MaintenanceRequestBuilder() {
    MaintenanceRequest._defaults(this);
  }

  MaintenanceRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _action = $v.action;
      _libraryId = $v.libraryId;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MaintenanceRequest other) {
    _$v = other as _$MaintenanceRequest;
  }

  @override
  void update(void Function(MaintenanceRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MaintenanceRequest build() => _build();

  _$MaintenanceRequest _build() {
    final _$result = _$v ??
        _$MaintenanceRequest._(
          action: BuiltValueNullFieldError.checkNotNull(
              action, r'MaintenanceRequest', 'action'),
          libraryId: libraryId,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_action.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DownloadActionActionEnum _$downloadActionActionEnum_pause =
    const DownloadActionActionEnum._('pause');
const DownloadActionActionEnum _$downloadActionActionEnum_resume =
    const DownloadActionActionEnum._('resume');
const DownloadActionActionEnum _$downloadActionActionEnum_retry =
    const DownloadActionActionEnum._('retry');
const DownloadActionActionEnum _$downloadActionActionEnum_remove =
    const DownloadActionActionEnum._('remove');
const DownloadActionActionEnum _$downloadActionActionEnum_reannounce =
    const DownloadActionActionEnum._('reannounce');
const DownloadActionActionEnum _$downloadActionActionEnum_recheck =
    const DownloadActionActionEnum._('recheck');

DownloadActionActionEnum _$downloadActionActionEnumValueOf(String name) {
  switch (name) {
    case 'pause':
      return _$downloadActionActionEnum_pause;
    case 'resume':
      return _$downloadActionActionEnum_resume;
    case 'retry':
      return _$downloadActionActionEnum_retry;
    case 'remove':
      return _$downloadActionActionEnum_remove;
    case 'reannounce':
      return _$downloadActionActionEnum_reannounce;
    case 'recheck':
      return _$downloadActionActionEnum_recheck;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadActionActionEnum> _$downloadActionActionEnumValues =
    BuiltSet<DownloadActionActionEnum>(const <DownloadActionActionEnum>[
  _$downloadActionActionEnum_pause,
  _$downloadActionActionEnum_resume,
  _$downloadActionActionEnum_retry,
  _$downloadActionActionEnum_remove,
  _$downloadActionActionEnum_reannounce,
  _$downloadActionActionEnum_recheck,
]);

Serializer<DownloadActionActionEnum> _$downloadActionActionEnumSerializer =
    _$DownloadActionActionEnumSerializer();

class _$DownloadActionActionEnumSerializer
    implements PrimitiveSerializer<DownloadActionActionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'pause': 'pause',
    'resume': 'resume',
    'retry': 'retry',
    'remove': 'remove',
    'reannounce': 'reannounce',
    'recheck': 'recheck',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'pause': 'pause',
    'resume': 'resume',
    'retry': 'retry',
    'remove': 'remove',
    'reannounce': 'reannounce',
    'recheck': 'recheck',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadActionActionEnum];
  @override
  final String wireName = 'DownloadActionActionEnum';

  @override
  Object serialize(Serializers serializers, DownloadActionActionEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadActionActionEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadActionActionEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadAction extends DownloadAction {
  @override
  final DownloadActionActionEnum action;
  @override
  final int version;
  @override
  final bool? deleteData;
  @override
  final bool? force;
  @override
  final String? confirmation;

  factory _$DownloadAction([void Function(DownloadActionBuilder)? updates]) =>
      (DownloadActionBuilder()..update(updates))._build();

  _$DownloadAction._(
      {required this.action,
      required this.version,
      this.deleteData,
      this.force,
      this.confirmation})
      : super._();
  @override
  DownloadAction rebuild(void Function(DownloadActionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadActionBuilder toBuilder() => DownloadActionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadAction &&
        action == other.action &&
        version == other.version &&
        deleteData == other.deleteData &&
        force == other.force &&
        confirmation == other.confirmation;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, action.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, deleteData.hashCode);
    _$hash = $jc(_$hash, force.hashCode);
    _$hash = $jc(_$hash, confirmation.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DownloadAction')
          ..add('action', action)
          ..add('version', version)
          ..add('deleteData', deleteData)
          ..add('force', force)
          ..add('confirmation', confirmation))
        .toString();
  }
}

class DownloadActionBuilder
    implements Builder<DownloadAction, DownloadActionBuilder> {
  _$DownloadAction? _$v;

  DownloadActionActionEnum? _action;
  DownloadActionActionEnum? get action => _$this._action;
  set action(DownloadActionActionEnum? action) => _$this._action = action;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  bool? _deleteData;
  bool? get deleteData => _$this._deleteData;
  set deleteData(bool? deleteData) => _$this._deleteData = deleteData;

  bool? _force;
  bool? get force => _$this._force;
  set force(bool? force) => _$this._force = force;

  String? _confirmation;
  String? get confirmation => _$this._confirmation;
  set confirmation(String? confirmation) => _$this._confirmation = confirmation;

  DownloadActionBuilder() {
    DownloadAction._defaults(this);
  }

  DownloadActionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _action = $v.action;
      _version = $v.version;
      _deleteData = $v.deleteData;
      _force = $v.force;
      _confirmation = $v.confirmation;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadAction other) {
    _$v = other as _$DownloadAction;
  }

  @override
  void update(void Function(DownloadActionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadAction build() => _build();

  _$DownloadAction _build() {
    final _$result = _$v ??
        _$DownloadAction._(
          action: BuiltValueNullFieldError.checkNotNull(
              action, r'DownloadAction', 'action'),
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'DownloadAction', 'version'),
          deleteData: deleteData,
          force: force,
          confirmation: confirmation,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

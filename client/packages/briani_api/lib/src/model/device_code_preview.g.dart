// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_code_preview.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeviceCodePreview extends DeviceCodePreview {
  @override
  final String deviceName;
  @override
  final DateTime expiresAt;

  factory _$DeviceCodePreview(
          [void Function(DeviceCodePreviewBuilder)? updates]) =>
      (DeviceCodePreviewBuilder()..update(updates))._build();

  _$DeviceCodePreview._({required this.deviceName, required this.expiresAt})
      : super._();
  @override
  DeviceCodePreview rebuild(void Function(DeviceCodePreviewBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeviceCodePreviewBuilder toBuilder() =>
      DeviceCodePreviewBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceCodePreview &&
        deviceName == other.deviceName &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deviceName.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceCodePreview')
          ..add('deviceName', deviceName)
          ..add('expiresAt', expiresAt))
        .toString();
  }
}

class DeviceCodePreviewBuilder
    implements Builder<DeviceCodePreview, DeviceCodePreviewBuilder> {
  _$DeviceCodePreview? _$v;

  String? _deviceName;
  String? get deviceName => _$this._deviceName;
  set deviceName(String? deviceName) => _$this._deviceName = deviceName;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  DeviceCodePreviewBuilder() {
    DeviceCodePreview._defaults(this);
  }

  DeviceCodePreviewBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceName = $v.deviceName;
      _expiresAt = $v.expiresAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceCodePreview other) {
    _$v = other as _$DeviceCodePreview;
  }

  @override
  void update(void Function(DeviceCodePreviewBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceCodePreview build() => _build();

  _$DeviceCodePreview _build() {
    final _$result = _$v ??
        _$DeviceCodePreview._(
          deviceName: BuiltValueNullFieldError.checkNotNull(
              deviceName, r'DeviceCodePreview', 'deviceName'),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt, r'DeviceCodePreview', 'expiresAt'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

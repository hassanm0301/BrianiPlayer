// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_code_request.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeviceCodeRequest extends DeviceCodeRequest {
  @override
  final String deviceName;

  factory _$DeviceCodeRequest(
          [void Function(DeviceCodeRequestBuilder)? updates]) =>
      (DeviceCodeRequestBuilder()..update(updates))._build();

  _$DeviceCodeRequest._({required this.deviceName}) : super._();
  @override
  DeviceCodeRequest rebuild(void Function(DeviceCodeRequestBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeviceCodeRequestBuilder toBuilder() =>
      DeviceCodeRequestBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceCodeRequest && deviceName == other.deviceName;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deviceName.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceCodeRequest')
          ..add('deviceName', deviceName))
        .toString();
  }
}

class DeviceCodeRequestBuilder
    implements Builder<DeviceCodeRequest, DeviceCodeRequestBuilder> {
  _$DeviceCodeRequest? _$v;

  String? _deviceName;
  String? get deviceName => _$this._deviceName;
  set deviceName(String? deviceName) => _$this._deviceName = deviceName;

  DeviceCodeRequestBuilder() {
    DeviceCodeRequest._defaults(this);
  }

  DeviceCodeRequestBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceName = $v.deviceName;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceCodeRequest other) {
    _$v = other as _$DeviceCodeRequest;
  }

  @override
  void update(void Function(DeviceCodeRequestBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceCodeRequest build() => _build();

  _$DeviceCodeRequest _build() {
    final _$result = _$v ??
        _$DeviceCodeRequest._(
          deviceName: BuiltValueNullFieldError.checkNotNull(
              deviceName, r'DeviceCodeRequest', 'deviceName'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

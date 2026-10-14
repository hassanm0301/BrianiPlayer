// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_code_poll.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeviceCodePoll extends DeviceCodePoll {
  @override
  final String deviceSecret;

  factory _$DeviceCodePoll([void Function(DeviceCodePollBuilder)? updates]) =>
      (DeviceCodePollBuilder()..update(updates))._build();

  _$DeviceCodePoll._({required this.deviceSecret}) : super._();
  @override
  DeviceCodePoll rebuild(void Function(DeviceCodePollBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeviceCodePollBuilder toBuilder() => DeviceCodePollBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceCodePoll && deviceSecret == other.deviceSecret;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deviceSecret.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceCodePoll')
          ..add('deviceSecret', deviceSecret))
        .toString();
  }
}

class DeviceCodePollBuilder
    implements Builder<DeviceCodePoll, DeviceCodePollBuilder> {
  _$DeviceCodePoll? _$v;

  String? _deviceSecret;
  String? get deviceSecret => _$this._deviceSecret;
  set deviceSecret(String? deviceSecret) => _$this._deviceSecret = deviceSecret;

  DeviceCodePollBuilder() {
    DeviceCodePoll._defaults(this);
  }

  DeviceCodePollBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceSecret = $v.deviceSecret;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceCodePoll other) {
    _$v = other as _$DeviceCodePoll;
  }

  @override
  void update(void Function(DeviceCodePollBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceCodePoll build() => _build();

  _$DeviceCodePoll _build() {
    final _$result = _$v ??
        _$DeviceCodePoll._(
          deviceSecret: BuiltValueNullFieldError.checkNotNull(
              deviceSecret, r'DeviceCodePoll', 'deviceSecret'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

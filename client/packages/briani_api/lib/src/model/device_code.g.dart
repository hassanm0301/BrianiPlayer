// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_code.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeviceCode extends DeviceCode {
  @override
  final String deviceSecret;
  @override
  final String userCode;
  @override
  final DateTime expiresAt;
  @override
  final int pollIntervalSeconds;

  factory _$DeviceCode([void Function(DeviceCodeBuilder)? updates]) =>
      (DeviceCodeBuilder()..update(updates))._build();

  _$DeviceCode._(
      {required this.deviceSecret,
      required this.userCode,
      required this.expiresAt,
      required this.pollIntervalSeconds})
      : super._();
  @override
  DeviceCode rebuild(void Function(DeviceCodeBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeviceCodeBuilder toBuilder() => DeviceCodeBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceCode &&
        deviceSecret == other.deviceSecret &&
        userCode == other.userCode &&
        expiresAt == other.expiresAt &&
        pollIntervalSeconds == other.pollIntervalSeconds;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, deviceSecret.hashCode);
    _$hash = $jc(_$hash, userCode.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, pollIntervalSeconds.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceCode')
          ..add('deviceSecret', deviceSecret)
          ..add('userCode', userCode)
          ..add('expiresAt', expiresAt)
          ..add('pollIntervalSeconds', pollIntervalSeconds))
        .toString();
  }
}

class DeviceCodeBuilder implements Builder<DeviceCode, DeviceCodeBuilder> {
  _$DeviceCode? _$v;

  String? _deviceSecret;
  String? get deviceSecret => _$this._deviceSecret;
  set deviceSecret(String? deviceSecret) => _$this._deviceSecret = deviceSecret;

  String? _userCode;
  String? get userCode => _$this._userCode;
  set userCode(String? userCode) => _$this._userCode = userCode;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  int? _pollIntervalSeconds;
  int? get pollIntervalSeconds => _$this._pollIntervalSeconds;
  set pollIntervalSeconds(int? pollIntervalSeconds) =>
      _$this._pollIntervalSeconds = pollIntervalSeconds;

  DeviceCodeBuilder() {
    DeviceCode._defaults(this);
  }

  DeviceCodeBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _deviceSecret = $v.deviceSecret;
      _userCode = $v.userCode;
      _expiresAt = $v.expiresAt;
      _pollIntervalSeconds = $v.pollIntervalSeconds;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceCode other) {
    _$v = other as _$DeviceCode;
  }

  @override
  void update(void Function(DeviceCodeBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceCode build() => _build();

  _$DeviceCode _build() {
    final _$result = _$v ??
        _$DeviceCode._(
          deviceSecret: BuiltValueNullFieldError.checkNotNull(
              deviceSecret, r'DeviceCode', 'deviceSecret'),
          userCode: BuiltValueNullFieldError.checkNotNull(
              userCode, r'DeviceCode', 'userCode'),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt, r'DeviceCode', 'expiresAt'),
          pollIntervalSeconds: BuiltValueNullFieldError.checkNotNull(
              pollIntervalSeconds, r'DeviceCode', 'pollIntervalSeconds'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

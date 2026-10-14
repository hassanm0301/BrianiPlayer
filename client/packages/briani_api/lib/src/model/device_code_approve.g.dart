// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_code_approve.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DeviceCodeApprove extends DeviceCodeApprove {
  @override
  final String userCode;

  factory _$DeviceCodeApprove(
          [void Function(DeviceCodeApproveBuilder)? updates]) =>
      (DeviceCodeApproveBuilder()..update(updates))._build();

  _$DeviceCodeApprove._({required this.userCode}) : super._();
  @override
  DeviceCodeApprove rebuild(void Function(DeviceCodeApproveBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DeviceCodeApproveBuilder toBuilder() =>
      DeviceCodeApproveBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DeviceCodeApprove && userCode == other.userCode;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userCode.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DeviceCodeApprove')
          ..add('userCode', userCode))
        .toString();
  }
}

class DeviceCodeApproveBuilder
    implements Builder<DeviceCodeApprove, DeviceCodeApproveBuilder> {
  _$DeviceCodeApprove? _$v;

  String? _userCode;
  String? get userCode => _$this._userCode;
  set userCode(String? userCode) => _$this._userCode = userCode;

  DeviceCodeApproveBuilder() {
    DeviceCodeApprove._defaults(this);
  }

  DeviceCodeApproveBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userCode = $v.userCode;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DeviceCodeApprove other) {
    _$v = other as _$DeviceCodeApprove;
  }

  @override
  void update(void Function(DeviceCodeApproveBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DeviceCodeApprove build() => _build();

  _$DeviceCodeApprove _build() {
    final _$result = _$v ??
        _$DeviceCodeApprove._(
          userCode: BuiltValueNullFieldError.checkNotNull(
              userCode, r'DeviceCodeApprove', 'userCode'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

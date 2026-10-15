// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'password_reset.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$PasswordReset extends PasswordReset {
  @override
  final String newPassword;
  @override
  final String confirmNewPassword;
  @override
  final int version;

  factory _$PasswordReset([void Function(PasswordResetBuilder)? updates]) =>
      (PasswordResetBuilder()..update(updates))._build();

  _$PasswordReset._(
      {required this.newPassword,
      required this.confirmNewPassword,
      required this.version})
      : super._();
  @override
  PasswordReset rebuild(void Function(PasswordResetBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PasswordResetBuilder toBuilder() => PasswordResetBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PasswordReset &&
        newPassword == other.newPassword &&
        confirmNewPassword == other.confirmNewPassword &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, newPassword.hashCode);
    _$hash = $jc(_$hash, confirmNewPassword.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PasswordReset')
          ..add('newPassword', newPassword)
          ..add('confirmNewPassword', confirmNewPassword)
          ..add('version', version))
        .toString();
  }
}

class PasswordResetBuilder
    implements Builder<PasswordReset, PasswordResetBuilder> {
  _$PasswordReset? _$v;

  String? _newPassword;
  String? get newPassword => _$this._newPassword;
  set newPassword(String? newPassword) => _$this._newPassword = newPassword;

  String? _confirmNewPassword;
  String? get confirmNewPassword => _$this._confirmNewPassword;
  set confirmNewPassword(String? confirmNewPassword) =>
      _$this._confirmNewPassword = confirmNewPassword;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  PasswordResetBuilder() {
    PasswordReset._defaults(this);
  }

  PasswordResetBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _newPassword = $v.newPassword;
      _confirmNewPassword = $v.confirmNewPassword;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PasswordReset other) {
    _$v = other as _$PasswordReset;
  }

  @override
  void update(void Function(PasswordResetBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PasswordReset build() => _build();

  _$PasswordReset _build() {
    final _$result = _$v ??
        _$PasswordReset._(
          newPassword: BuiltValueNullFieldError.checkNotNull(
              newPassword, r'PasswordReset', 'newPassword'),
          confirmNewPassword: BuiltValueNullFieldError.checkNotNull(
              confirmNewPassword, r'PasswordReset', 'confirmNewPassword'),
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'PasswordReset', 'version'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_grant.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LibraryGrant extends LibraryGrant {
  @override
  final String userId;
  @override
  final bool read;
  @override
  final bool download;
  @override
  final bool manage;
  @override
  final int? quotaBytes;

  factory _$LibraryGrant([void Function(LibraryGrantBuilder)? updates]) =>
      (LibraryGrantBuilder()..update(updates))._build();

  _$LibraryGrant._(
      {required this.userId,
      required this.read,
      required this.download,
      required this.manage,
      this.quotaBytes})
      : super._();
  @override
  LibraryGrant rebuild(void Function(LibraryGrantBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LibraryGrantBuilder toBuilder() => LibraryGrantBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LibraryGrant &&
        userId == other.userId &&
        read == other.read &&
        download == other.download &&
        manage == other.manage &&
        quotaBytes == other.quotaBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, userId.hashCode);
    _$hash = $jc(_$hash, read.hashCode);
    _$hash = $jc(_$hash, download.hashCode);
    _$hash = $jc(_$hash, manage.hashCode);
    _$hash = $jc(_$hash, quotaBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LibraryGrant')
          ..add('userId', userId)
          ..add('read', read)
          ..add('download', download)
          ..add('manage', manage)
          ..add('quotaBytes', quotaBytes))
        .toString();
  }
}

class LibraryGrantBuilder
    implements Builder<LibraryGrant, LibraryGrantBuilder> {
  _$LibraryGrant? _$v;

  String? _userId;
  String? get userId => _$this._userId;
  set userId(String? userId) => _$this._userId = userId;

  bool? _read;
  bool? get read => _$this._read;
  set read(bool? read) => _$this._read = read;

  bool? _download;
  bool? get download => _$this._download;
  set download(bool? download) => _$this._download = download;

  bool? _manage;
  bool? get manage => _$this._manage;
  set manage(bool? manage) => _$this._manage = manage;

  int? _quotaBytes;
  int? get quotaBytes => _$this._quotaBytes;
  set quotaBytes(int? quotaBytes) => _$this._quotaBytes = quotaBytes;

  LibraryGrantBuilder() {
    LibraryGrant._defaults(this);
  }

  LibraryGrantBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _userId = $v.userId;
      _read = $v.read;
      _download = $v.download;
      _manage = $v.manage;
      _quotaBytes = $v.quotaBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LibraryGrant other) {
    _$v = other as _$LibraryGrant;
  }

  @override
  void update(void Function(LibraryGrantBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LibraryGrant build() => _build();

  _$LibraryGrant _build() {
    final _$result = _$v ??
        _$LibraryGrant._(
          userId: BuiltValueNullFieldError.checkNotNull(
              userId, r'LibraryGrant', 'userId'),
          read: BuiltValueNullFieldError.checkNotNull(
              read, r'LibraryGrant', 'read'),
          download: BuiltValueNullFieldError.checkNotNull(
              download, r'LibraryGrant', 'download'),
          manage: BuiltValueNullFieldError.checkNotNull(
              manage, r'LibraryGrant', 'manage'),
          quotaBytes: quotaBytes,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

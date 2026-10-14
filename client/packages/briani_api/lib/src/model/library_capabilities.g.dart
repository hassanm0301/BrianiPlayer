// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_capabilities.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LibraryCapabilities extends LibraryCapabilities {
  @override
  final bool read;
  @override
  final bool download;
  @override
  final bool manage;

  factory _$LibraryCapabilities(
          [void Function(LibraryCapabilitiesBuilder)? updates]) =>
      (LibraryCapabilitiesBuilder()..update(updates))._build();

  _$LibraryCapabilities._(
      {required this.read, required this.download, required this.manage})
      : super._();
  @override
  LibraryCapabilities rebuild(
          void Function(LibraryCapabilitiesBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LibraryCapabilitiesBuilder toBuilder() =>
      LibraryCapabilitiesBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LibraryCapabilities &&
        read == other.read &&
        download == other.download &&
        manage == other.manage;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, read.hashCode);
    _$hash = $jc(_$hash, download.hashCode);
    _$hash = $jc(_$hash, manage.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LibraryCapabilities')
          ..add('read', read)
          ..add('download', download)
          ..add('manage', manage))
        .toString();
  }
}

class LibraryCapabilitiesBuilder
    implements Builder<LibraryCapabilities, LibraryCapabilitiesBuilder> {
  _$LibraryCapabilities? _$v;

  bool? _read;
  bool? get read => _$this._read;
  set read(bool? read) => _$this._read = read;

  bool? _download;
  bool? get download => _$this._download;
  set download(bool? download) => _$this._download = download;

  bool? _manage;
  bool? get manage => _$this._manage;
  set manage(bool? manage) => _$this._manage = manage;

  LibraryCapabilitiesBuilder() {
    LibraryCapabilities._defaults(this);
  }

  LibraryCapabilitiesBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _read = $v.read;
      _download = $v.download;
      _manage = $v.manage;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LibraryCapabilities other) {
    _$v = other as _$LibraryCapabilities;
  }

  @override
  void update(void Function(LibraryCapabilitiesBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LibraryCapabilities build() => _build();

  _$LibraryCapabilities _build() {
    final _$result = _$v ??
        _$LibraryCapabilities._(
          read: BuiltValueNullFieldError.checkNotNull(
              read, r'LibraryCapabilities', 'read'),
          download: BuiltValueNullFieldError.checkNotNull(
              download, r'LibraryCapabilities', 'download'),
          manage: BuiltValueNullFieldError.checkNotNull(
              manage, r'LibraryCapabilities', 'manage'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

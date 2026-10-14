// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_root.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$StorageRoot extends StorageRoot {
  @override
  final String id;
  @override
  final String label;
  @override
  final String path;
  @override
  final bool writable;
  @override
  final int? freeBytes;
  @override
  final int? totalBytes;
  @override
  final int reservedBytes;
  @override
  final bool available;
  @override
  final bool? supportsHardLinks;

  factory _$StorageRoot([void Function(StorageRootBuilder)? updates]) =>
      (StorageRootBuilder()..update(updates))._build();

  _$StorageRoot._(
      {required this.id,
      required this.label,
      required this.path,
      required this.writable,
      this.freeBytes,
      this.totalBytes,
      required this.reservedBytes,
      required this.available,
      this.supportsHardLinks})
      : super._();
  @override
  StorageRoot rebuild(void Function(StorageRootBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  StorageRootBuilder toBuilder() => StorageRootBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is StorageRoot &&
        id == other.id &&
        label == other.label &&
        path == other.path &&
        writable == other.writable &&
        freeBytes == other.freeBytes &&
        totalBytes == other.totalBytes &&
        reservedBytes == other.reservedBytes &&
        available == other.available &&
        supportsHardLinks == other.supportsHardLinks;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, label.hashCode);
    _$hash = $jc(_$hash, path.hashCode);
    _$hash = $jc(_$hash, writable.hashCode);
    _$hash = $jc(_$hash, freeBytes.hashCode);
    _$hash = $jc(_$hash, totalBytes.hashCode);
    _$hash = $jc(_$hash, reservedBytes.hashCode);
    _$hash = $jc(_$hash, available.hashCode);
    _$hash = $jc(_$hash, supportsHardLinks.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'StorageRoot')
          ..add('id', id)
          ..add('label', label)
          ..add('path', path)
          ..add('writable', writable)
          ..add('freeBytes', freeBytes)
          ..add('totalBytes', totalBytes)
          ..add('reservedBytes', reservedBytes)
          ..add('available', available)
          ..add('supportsHardLinks', supportsHardLinks))
        .toString();
  }
}

class StorageRootBuilder implements Builder<StorageRoot, StorageRootBuilder> {
  _$StorageRoot? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _label;
  String? get label => _$this._label;
  set label(String? label) => _$this._label = label;

  String? _path;
  String? get path => _$this._path;
  set path(String? path) => _$this._path = path;

  bool? _writable;
  bool? get writable => _$this._writable;
  set writable(bool? writable) => _$this._writable = writable;

  int? _freeBytes;
  int? get freeBytes => _$this._freeBytes;
  set freeBytes(int? freeBytes) => _$this._freeBytes = freeBytes;

  int? _totalBytes;
  int? get totalBytes => _$this._totalBytes;
  set totalBytes(int? totalBytes) => _$this._totalBytes = totalBytes;

  int? _reservedBytes;
  int? get reservedBytes => _$this._reservedBytes;
  set reservedBytes(int? reservedBytes) =>
      _$this._reservedBytes = reservedBytes;

  bool? _available;
  bool? get available => _$this._available;
  set available(bool? available) => _$this._available = available;

  bool? _supportsHardLinks;
  bool? get supportsHardLinks => _$this._supportsHardLinks;
  set supportsHardLinks(bool? supportsHardLinks) =>
      _$this._supportsHardLinks = supportsHardLinks;

  StorageRootBuilder() {
    StorageRoot._defaults(this);
  }

  StorageRootBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _label = $v.label;
      _path = $v.path;
      _writable = $v.writable;
      _freeBytes = $v.freeBytes;
      _totalBytes = $v.totalBytes;
      _reservedBytes = $v.reservedBytes;
      _available = $v.available;
      _supportsHardLinks = $v.supportsHardLinks;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(StorageRoot other) {
    _$v = other as _$StorageRoot;
  }

  @override
  void update(void Function(StorageRootBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  StorageRoot build() => _build();

  _$StorageRoot _build() {
    final _$result = _$v ??
        _$StorageRoot._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'StorageRoot', 'id'),
          label: BuiltValueNullFieldError.checkNotNull(
              label, r'StorageRoot', 'label'),
          path: BuiltValueNullFieldError.checkNotNull(
              path, r'StorageRoot', 'path'),
          writable: BuiltValueNullFieldError.checkNotNull(
              writable, r'StorageRoot', 'writable'),
          freeBytes: freeBytes,
          totalBytes: totalBytes,
          reservedBytes: BuiltValueNullFieldError.checkNotNull(
              reservedBytes, r'StorageRoot', 'reservedBytes'),
          available: BuiltValueNullFieldError.checkNotNull(
              available, r'StorageRoot', 'available'),
          supportsHardLinks: supportsHardLinks,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

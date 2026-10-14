// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_directory.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$StorageDirectory extends StorageDirectory {
  @override
  final String relativePath;
  @override
  final String name;
  @override
  final bool writable;
  @override
  final bool alreadyAssigned;

  factory _$StorageDirectory(
          [void Function(StorageDirectoryBuilder)? updates]) =>
      (StorageDirectoryBuilder()..update(updates))._build();

  _$StorageDirectory._(
      {required this.relativePath,
      required this.name,
      required this.writable,
      required this.alreadyAssigned})
      : super._();
  @override
  StorageDirectory rebuild(void Function(StorageDirectoryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  StorageDirectoryBuilder toBuilder() =>
      StorageDirectoryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is StorageDirectory &&
        relativePath == other.relativePath &&
        name == other.name &&
        writable == other.writable &&
        alreadyAssigned == other.alreadyAssigned;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, relativePath.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, writable.hashCode);
    _$hash = $jc(_$hash, alreadyAssigned.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'StorageDirectory')
          ..add('relativePath', relativePath)
          ..add('name', name)
          ..add('writable', writable)
          ..add('alreadyAssigned', alreadyAssigned))
        .toString();
  }
}

class StorageDirectoryBuilder
    implements Builder<StorageDirectory, StorageDirectoryBuilder> {
  _$StorageDirectory? _$v;

  String? _relativePath;
  String? get relativePath => _$this._relativePath;
  set relativePath(String? relativePath) => _$this._relativePath = relativePath;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  bool? _writable;
  bool? get writable => _$this._writable;
  set writable(bool? writable) => _$this._writable = writable;

  bool? _alreadyAssigned;
  bool? get alreadyAssigned => _$this._alreadyAssigned;
  set alreadyAssigned(bool? alreadyAssigned) =>
      _$this._alreadyAssigned = alreadyAssigned;

  StorageDirectoryBuilder() {
    StorageDirectory._defaults(this);
  }

  StorageDirectoryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _relativePath = $v.relativePath;
      _name = $v.name;
      _writable = $v.writable;
      _alreadyAssigned = $v.alreadyAssigned;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(StorageDirectory other) {
    _$v = other as _$StorageDirectory;
  }

  @override
  void update(void Function(StorageDirectoryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  StorageDirectory build() => _build();

  _$StorageDirectory _build() {
    final _$result = _$v ??
        _$StorageDirectory._(
          relativePath: BuiltValueNullFieldError.checkNotNull(
              relativePath, r'StorageDirectory', 'relativePath'),
          name: BuiltValueNullFieldError.checkNotNull(
              name, r'StorageDirectory', 'name'),
          writable: BuiltValueNullFieldError.checkNotNull(
              writable, r'StorageDirectory', 'writable'),
          alreadyAssigned: BuiltValueNullFieldError.checkNotNull(
              alreadyAssigned, r'StorageDirectory', 'alreadyAssigned'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

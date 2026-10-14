// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_create.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LibraryCreate extends LibraryCreate {
  @override
  final String name;
  @override
  final String? description;
  @override
  final String storageRootId;
  @override
  final String relativePath;
  @override
  final bool readOnly;

  factory _$LibraryCreate([void Function(LibraryCreateBuilder)? updates]) =>
      (LibraryCreateBuilder()..update(updates))._build();

  _$LibraryCreate._(
      {required this.name,
      this.description,
      required this.storageRootId,
      required this.relativePath,
      required this.readOnly})
      : super._();
  @override
  LibraryCreate rebuild(void Function(LibraryCreateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LibraryCreateBuilder toBuilder() => LibraryCreateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LibraryCreate &&
        name == other.name &&
        description == other.description &&
        storageRootId == other.storageRootId &&
        relativePath == other.relativePath &&
        readOnly == other.readOnly;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, storageRootId.hashCode);
    _$hash = $jc(_$hash, relativePath.hashCode);
    _$hash = $jc(_$hash, readOnly.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LibraryCreate')
          ..add('name', name)
          ..add('description', description)
          ..add('storageRootId', storageRootId)
          ..add('relativePath', relativePath)
          ..add('readOnly', readOnly))
        .toString();
  }
}

class LibraryCreateBuilder
    implements Builder<LibraryCreate, LibraryCreateBuilder> {
  _$LibraryCreate? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  String? _storageRootId;
  String? get storageRootId => _$this._storageRootId;
  set storageRootId(String? storageRootId) =>
      _$this._storageRootId = storageRootId;

  String? _relativePath;
  String? get relativePath => _$this._relativePath;
  set relativePath(String? relativePath) => _$this._relativePath = relativePath;

  bool? _readOnly;
  bool? get readOnly => _$this._readOnly;
  set readOnly(bool? readOnly) => _$this._readOnly = readOnly;

  LibraryCreateBuilder() {
    LibraryCreate._defaults(this);
  }

  LibraryCreateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _description = $v.description;
      _storageRootId = $v.storageRootId;
      _relativePath = $v.relativePath;
      _readOnly = $v.readOnly;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LibraryCreate other) {
    _$v = other as _$LibraryCreate;
  }

  @override
  void update(void Function(LibraryCreateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LibraryCreate build() => _build();

  _$LibraryCreate _build() {
    final _$result = _$v ??
        _$LibraryCreate._(
          name: BuiltValueNullFieldError.checkNotNull(
              name, r'LibraryCreate', 'name'),
          description: description,
          storageRootId: BuiltValueNullFieldError.checkNotNull(
              storageRootId, r'LibraryCreate', 'storageRootId'),
          relativePath: BuiltValueNullFieldError.checkNotNull(
              relativePath, r'LibraryCreate', 'relativePath'),
          readOnly: BuiltValueNullFieldError.checkNotNull(
              readOnly, r'LibraryCreate', 'readOnly'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

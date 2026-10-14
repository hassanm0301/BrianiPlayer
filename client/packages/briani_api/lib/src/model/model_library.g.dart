// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_library.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ModelLibrary extends ModelLibrary {
  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final bool readOnly;
  @override
  final bool enabled;
  @override
  final int version;
  @override
  final LibraryCapabilities capabilities;
  @override
  final String? rootPath;
  @override
  final int? scanIntervalSeconds;

  factory _$ModelLibrary([void Function(ModelLibraryBuilder)? updates]) =>
      (ModelLibraryBuilder()..update(updates))._build();

  _$ModelLibrary._(
      {required this.id,
      required this.name,
      required this.description,
      required this.readOnly,
      required this.enabled,
      required this.version,
      required this.capabilities,
      this.rootPath,
      this.scanIntervalSeconds})
      : super._();
  @override
  ModelLibrary rebuild(void Function(ModelLibraryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ModelLibraryBuilder toBuilder() => ModelLibraryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ModelLibrary &&
        id == other.id &&
        name == other.name &&
        description == other.description &&
        readOnly == other.readOnly &&
        enabled == other.enabled &&
        version == other.version &&
        capabilities == other.capabilities &&
        rootPath == other.rootPath &&
        scanIntervalSeconds == other.scanIntervalSeconds;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, readOnly.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, capabilities.hashCode);
    _$hash = $jc(_$hash, rootPath.hashCode);
    _$hash = $jc(_$hash, scanIntervalSeconds.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'ModelLibrary')
          ..add('id', id)
          ..add('name', name)
          ..add('description', description)
          ..add('readOnly', readOnly)
          ..add('enabled', enabled)
          ..add('version', version)
          ..add('capabilities', capabilities)
          ..add('rootPath', rootPath)
          ..add('scanIntervalSeconds', scanIntervalSeconds))
        .toString();
  }
}

class ModelLibraryBuilder
    implements Builder<ModelLibrary, ModelLibraryBuilder> {
  _$ModelLibrary? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  bool? _readOnly;
  bool? get readOnly => _$this._readOnly;
  set readOnly(bool? readOnly) => _$this._readOnly = readOnly;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  LibraryCapabilitiesBuilder? _capabilities;
  LibraryCapabilitiesBuilder get capabilities =>
      _$this._capabilities ??= LibraryCapabilitiesBuilder();
  set capabilities(LibraryCapabilitiesBuilder? capabilities) =>
      _$this._capabilities = capabilities;

  String? _rootPath;
  String? get rootPath => _$this._rootPath;
  set rootPath(String? rootPath) => _$this._rootPath = rootPath;

  int? _scanIntervalSeconds;
  int? get scanIntervalSeconds => _$this._scanIntervalSeconds;
  set scanIntervalSeconds(int? scanIntervalSeconds) =>
      _$this._scanIntervalSeconds = scanIntervalSeconds;

  ModelLibraryBuilder() {
    ModelLibrary._defaults(this);
  }

  ModelLibraryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _name = $v.name;
      _description = $v.description;
      _readOnly = $v.readOnly;
      _enabled = $v.enabled;
      _version = $v.version;
      _capabilities = $v.capabilities.toBuilder();
      _rootPath = $v.rootPath;
      _scanIntervalSeconds = $v.scanIntervalSeconds;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ModelLibrary other) {
    _$v = other as _$ModelLibrary;
  }

  @override
  void update(void Function(ModelLibraryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ModelLibrary build() => _build();

  _$ModelLibrary _build() {
    _$ModelLibrary _$result;
    try {
      _$result = _$v ??
          _$ModelLibrary._(
            id: BuiltValueNullFieldError.checkNotNull(
                id, r'ModelLibrary', 'id'),
            name: BuiltValueNullFieldError.checkNotNull(
                name, r'ModelLibrary', 'name'),
            description: BuiltValueNullFieldError.checkNotNull(
                description, r'ModelLibrary', 'description'),
            readOnly: BuiltValueNullFieldError.checkNotNull(
                readOnly, r'ModelLibrary', 'readOnly'),
            enabled: BuiltValueNullFieldError.checkNotNull(
                enabled, r'ModelLibrary', 'enabled'),
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'ModelLibrary', 'version'),
            capabilities: capabilities.build(),
            rootPath: rootPath,
            scanIntervalSeconds: scanIntervalSeconds,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'capabilities';
        capabilities.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'ModelLibrary', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

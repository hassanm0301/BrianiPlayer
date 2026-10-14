// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_patch.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$LibraryPatch extends LibraryPatch {
  @override
  final String? name;
  @override
  final String? description;
  @override
  final bool? enabled;
  @override
  final bool? readOnly;
  @override
  final int version;
  @override
  final int? scanIntervalSeconds;

  factory _$LibraryPatch([void Function(LibraryPatchBuilder)? updates]) =>
      (LibraryPatchBuilder()..update(updates))._build();

  _$LibraryPatch._(
      {this.name,
      this.description,
      this.enabled,
      this.readOnly,
      required this.version,
      this.scanIntervalSeconds})
      : super._();
  @override
  LibraryPatch rebuild(void Function(LibraryPatchBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  LibraryPatchBuilder toBuilder() => LibraryPatchBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is LibraryPatch &&
        name == other.name &&
        description == other.description &&
        enabled == other.enabled &&
        readOnly == other.readOnly &&
        version == other.version &&
        scanIntervalSeconds == other.scanIntervalSeconds;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, name.hashCode);
    _$hash = $jc(_$hash, description.hashCode);
    _$hash = $jc(_$hash, enabled.hashCode);
    _$hash = $jc(_$hash, readOnly.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, scanIntervalSeconds.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'LibraryPatch')
          ..add('name', name)
          ..add('description', description)
          ..add('enabled', enabled)
          ..add('readOnly', readOnly)
          ..add('version', version)
          ..add('scanIntervalSeconds', scanIntervalSeconds))
        .toString();
  }
}

class LibraryPatchBuilder
    implements Builder<LibraryPatch, LibraryPatchBuilder> {
  _$LibraryPatch? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  String? _description;
  String? get description => _$this._description;
  set description(String? description) => _$this._description = description;

  bool? _enabled;
  bool? get enabled => _$this._enabled;
  set enabled(bool? enabled) => _$this._enabled = enabled;

  bool? _readOnly;
  bool? get readOnly => _$this._readOnly;
  set readOnly(bool? readOnly) => _$this._readOnly = readOnly;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  int? _scanIntervalSeconds;
  int? get scanIntervalSeconds => _$this._scanIntervalSeconds;
  set scanIntervalSeconds(int? scanIntervalSeconds) =>
      _$this._scanIntervalSeconds = scanIntervalSeconds;

  LibraryPatchBuilder() {
    LibraryPatch._defaults(this);
  }

  LibraryPatchBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _description = $v.description;
      _enabled = $v.enabled;
      _readOnly = $v.readOnly;
      _version = $v.version;
      _scanIntervalSeconds = $v.scanIntervalSeconds;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(LibraryPatch other) {
    _$v = other as _$LibraryPatch;
  }

  @override
  void update(void Function(LibraryPatchBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  LibraryPatch build() => _build();

  _$LibraryPatch _build() {
    final _$result = _$v ??
        _$LibraryPatch._(
          name: name,
          description: description,
          enabled: enabled,
          readOnly: readOnly,
          version: BuiltValueNullFieldError.checkNotNull(
              version, r'LibraryPatch', 'version'),
          scanIntervalSeconds: scanIntervalSeconds,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

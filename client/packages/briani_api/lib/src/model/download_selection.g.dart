// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_selection.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DownloadSelection extends DownloadSelection {
  @override
  final BuiltList<FileChoice> files;
  @override
  final bool autoStart;
  @override
  final int version;

  factory _$DownloadSelection(
          [void Function(DownloadSelectionBuilder)? updates]) =>
      (DownloadSelectionBuilder()..update(updates))._build();

  _$DownloadSelection._(
      {required this.files, required this.autoStart, required this.version})
      : super._();
  @override
  DownloadSelection rebuild(void Function(DownloadSelectionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadSelectionBuilder toBuilder() =>
      DownloadSelectionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadSelection &&
        files == other.files &&
        autoStart == other.autoStart &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, files.hashCode);
    _$hash = $jc(_$hash, autoStart.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DownloadSelection')
          ..add('files', files)
          ..add('autoStart', autoStart)
          ..add('version', version))
        .toString();
  }
}

class DownloadSelectionBuilder
    implements Builder<DownloadSelection, DownloadSelectionBuilder> {
  _$DownloadSelection? _$v;

  ListBuilder<FileChoice>? _files;
  ListBuilder<FileChoice> get files =>
      _$this._files ??= ListBuilder<FileChoice>();
  set files(ListBuilder<FileChoice>? files) => _$this._files = files;

  bool? _autoStart;
  bool? get autoStart => _$this._autoStart;
  set autoStart(bool? autoStart) => _$this._autoStart = autoStart;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  DownloadSelectionBuilder() {
    DownloadSelection._defaults(this);
  }

  DownloadSelectionBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _files = $v.files.toBuilder();
      _autoStart = $v.autoStart;
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadSelection other) {
    _$v = other as _$DownloadSelection;
  }

  @override
  void update(void Function(DownloadSelectionBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadSelection build() => _build();

  _$DownloadSelection _build() {
    _$DownloadSelection _$result;
    try {
      _$result = _$v ??
          _$DownloadSelection._(
            files: files.build(),
            autoStart: BuiltValueNullFieldError.checkNotNull(
                autoStart, r'DownloadSelection', 'autoStart'),
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'DownloadSelection', 'version'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'files';
        files.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'DownloadSelection', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

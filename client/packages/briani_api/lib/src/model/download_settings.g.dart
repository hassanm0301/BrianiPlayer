// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_settings.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DownloadSettings extends DownloadSettings {
  @override
  final int version;
  @override
  final int? downloadLimitBytesPerSecond;
  @override
  final int? uploadLimitBytesPerSecond;
  @override
  final double? ratioLimit;
  @override
  final int? seedTimeMinutes;
  @override
  final int? queuePosition;
  @override
  final BuiltList<String>? tags;

  factory _$DownloadSettings(
          [void Function(DownloadSettingsBuilder)? updates]) =>
      (DownloadSettingsBuilder()..update(updates))._build();

  _$DownloadSettings._(
      {required this.version,
      this.downloadLimitBytesPerSecond,
      this.uploadLimitBytesPerSecond,
      this.ratioLimit,
      this.seedTimeMinutes,
      this.queuePosition,
      this.tags})
      : super._();
  @override
  DownloadSettings rebuild(void Function(DownloadSettingsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadSettingsBuilder toBuilder() =>
      DownloadSettingsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadSettings &&
        version == other.version &&
        downloadLimitBytesPerSecond == other.downloadLimitBytesPerSecond &&
        uploadLimitBytesPerSecond == other.uploadLimitBytesPerSecond &&
        ratioLimit == other.ratioLimit &&
        seedTimeMinutes == other.seedTimeMinutes &&
        queuePosition == other.queuePosition &&
        tags == other.tags;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jc(_$hash, downloadLimitBytesPerSecond.hashCode);
    _$hash = $jc(_$hash, uploadLimitBytesPerSecond.hashCode);
    _$hash = $jc(_$hash, ratioLimit.hashCode);
    _$hash = $jc(_$hash, seedTimeMinutes.hashCode);
    _$hash = $jc(_$hash, queuePosition.hashCode);
    _$hash = $jc(_$hash, tags.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DownloadSettings')
          ..add('version', version)
          ..add('downloadLimitBytesPerSecond', downloadLimitBytesPerSecond)
          ..add('uploadLimitBytesPerSecond', uploadLimitBytesPerSecond)
          ..add('ratioLimit', ratioLimit)
          ..add('seedTimeMinutes', seedTimeMinutes)
          ..add('queuePosition', queuePosition)
          ..add('tags', tags))
        .toString();
  }
}

class DownloadSettingsBuilder
    implements Builder<DownloadSettings, DownloadSettingsBuilder> {
  _$DownloadSettings? _$v;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  int? _downloadLimitBytesPerSecond;
  int? get downloadLimitBytesPerSecond => _$this._downloadLimitBytesPerSecond;
  set downloadLimitBytesPerSecond(int? downloadLimitBytesPerSecond) =>
      _$this._downloadLimitBytesPerSecond = downloadLimitBytesPerSecond;

  int? _uploadLimitBytesPerSecond;
  int? get uploadLimitBytesPerSecond => _$this._uploadLimitBytesPerSecond;
  set uploadLimitBytesPerSecond(int? uploadLimitBytesPerSecond) =>
      _$this._uploadLimitBytesPerSecond = uploadLimitBytesPerSecond;

  double? _ratioLimit;
  double? get ratioLimit => _$this._ratioLimit;
  set ratioLimit(double? ratioLimit) => _$this._ratioLimit = ratioLimit;

  int? _seedTimeMinutes;
  int? get seedTimeMinutes => _$this._seedTimeMinutes;
  set seedTimeMinutes(int? seedTimeMinutes) =>
      _$this._seedTimeMinutes = seedTimeMinutes;

  int? _queuePosition;
  int? get queuePosition => _$this._queuePosition;
  set queuePosition(int? queuePosition) =>
      _$this._queuePosition = queuePosition;

  ListBuilder<String>? _tags;
  ListBuilder<String> get tags => _$this._tags ??= ListBuilder<String>();
  set tags(ListBuilder<String>? tags) => _$this._tags = tags;

  DownloadSettingsBuilder() {
    DownloadSettings._defaults(this);
  }

  DownloadSettingsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _version = $v.version;
      _downloadLimitBytesPerSecond = $v.downloadLimitBytesPerSecond;
      _uploadLimitBytesPerSecond = $v.uploadLimitBytesPerSecond;
      _ratioLimit = $v.ratioLimit;
      _seedTimeMinutes = $v.seedTimeMinutes;
      _queuePosition = $v.queuePosition;
      _tags = $v.tags?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadSettings other) {
    _$v = other as _$DownloadSettings;
  }

  @override
  void update(void Function(DownloadSettingsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadSettings build() => _build();

  _$DownloadSettings _build() {
    _$DownloadSettings _$result;
    try {
      _$result = _$v ??
          _$DownloadSettings._(
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'DownloadSettings', 'version'),
            downloadLimitBytesPerSecond: downloadLimitBytesPerSecond,
            uploadLimitBytesPerSecond: uploadLimitBytesPerSecond,
            ratioLimit: ratioLimit,
            seedTimeMinutes: seedTimeMinutes,
            queuePosition: queuePosition,
            tags: _tags?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'tags';
        _tags?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'DownloadSettings', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

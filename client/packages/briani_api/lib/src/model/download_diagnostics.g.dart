// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_diagnostics.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DownloadDiagnostics extends DownloadDiagnostics {
  @override
  final String downloadId;
  @override
  final String engineState;
  @override
  final String generation;
  @override
  final BuiltList<TrackerSummary> trackers;
  @override
  final BuiltList<String> warnings;

  factory _$DownloadDiagnostics(
          [void Function(DownloadDiagnosticsBuilder)? updates]) =>
      (DownloadDiagnosticsBuilder()..update(updates))._build();

  _$DownloadDiagnostics._(
      {required this.downloadId,
      required this.engineState,
      required this.generation,
      required this.trackers,
      required this.warnings})
      : super._();
  @override
  DownloadDiagnostics rebuild(
          void Function(DownloadDiagnosticsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadDiagnosticsBuilder toBuilder() =>
      DownloadDiagnosticsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadDiagnostics &&
        downloadId == other.downloadId &&
        engineState == other.engineState &&
        generation == other.generation &&
        trackers == other.trackers &&
        warnings == other.warnings;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, downloadId.hashCode);
    _$hash = $jc(_$hash, engineState.hashCode);
    _$hash = $jc(_$hash, generation.hashCode);
    _$hash = $jc(_$hash, trackers.hashCode);
    _$hash = $jc(_$hash, warnings.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DownloadDiagnostics')
          ..add('downloadId', downloadId)
          ..add('engineState', engineState)
          ..add('generation', generation)
          ..add('trackers', trackers)
          ..add('warnings', warnings))
        .toString();
  }
}

class DownloadDiagnosticsBuilder
    implements Builder<DownloadDiagnostics, DownloadDiagnosticsBuilder> {
  _$DownloadDiagnostics? _$v;

  String? _downloadId;
  String? get downloadId => _$this._downloadId;
  set downloadId(String? downloadId) => _$this._downloadId = downloadId;

  String? _engineState;
  String? get engineState => _$this._engineState;
  set engineState(String? engineState) => _$this._engineState = engineState;

  String? _generation;
  String? get generation => _$this._generation;
  set generation(String? generation) => _$this._generation = generation;

  ListBuilder<TrackerSummary>? _trackers;
  ListBuilder<TrackerSummary> get trackers =>
      _$this._trackers ??= ListBuilder<TrackerSummary>();
  set trackers(ListBuilder<TrackerSummary>? trackers) =>
      _$this._trackers = trackers;

  ListBuilder<String>? _warnings;
  ListBuilder<String> get warnings =>
      _$this._warnings ??= ListBuilder<String>();
  set warnings(ListBuilder<String>? warnings) => _$this._warnings = warnings;

  DownloadDiagnosticsBuilder() {
    DownloadDiagnostics._defaults(this);
  }

  DownloadDiagnosticsBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _downloadId = $v.downloadId;
      _engineState = $v.engineState;
      _generation = $v.generation;
      _trackers = $v.trackers.toBuilder();
      _warnings = $v.warnings.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadDiagnostics other) {
    _$v = other as _$DownloadDiagnostics;
  }

  @override
  void update(void Function(DownloadDiagnosticsBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadDiagnostics build() => _build();

  _$DownloadDiagnostics _build() {
    _$DownloadDiagnostics _$result;
    try {
      _$result = _$v ??
          _$DownloadDiagnostics._(
            downloadId: BuiltValueNullFieldError.checkNotNull(
                downloadId, r'DownloadDiagnostics', 'downloadId'),
            engineState: BuiltValueNullFieldError.checkNotNull(
                engineState, r'DownloadDiagnostics', 'engineState'),
            generation: BuiltValueNullFieldError.checkNotNull(
                generation, r'DownloadDiagnostics', 'generation'),
            trackers: trackers.build(),
            warnings: warnings.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'trackers';
        trackers.build();
        _$failedField = 'warnings';
        warnings.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'DownloadDiagnostics', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

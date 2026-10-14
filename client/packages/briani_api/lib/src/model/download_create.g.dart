// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_create.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DownloadCreate extends DownloadCreate {
  @override
  final String libraryId;
  @override
  final DownloadSource source_;

  factory _$DownloadCreate([void Function(DownloadCreateBuilder)? updates]) =>
      (DownloadCreateBuilder()..update(updates))._build();

  _$DownloadCreate._({required this.libraryId, required this.source_})
      : super._();
  @override
  DownloadCreate rebuild(void Function(DownloadCreateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadCreateBuilder toBuilder() => DownloadCreateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadCreate &&
        libraryId == other.libraryId &&
        source_ == other.source_;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, libraryId.hashCode);
    _$hash = $jc(_$hash, source_.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DownloadCreate')
          ..add('libraryId', libraryId)
          ..add('source_', source_))
        .toString();
  }
}

class DownloadCreateBuilder
    implements Builder<DownloadCreate, DownloadCreateBuilder> {
  _$DownloadCreate? _$v;

  String? _libraryId;
  String? get libraryId => _$this._libraryId;
  set libraryId(String? libraryId) => _$this._libraryId = libraryId;

  DownloadSourceBuilder? _source_;
  DownloadSourceBuilder get source_ =>
      _$this._source_ ??= DownloadSourceBuilder();
  set source_(DownloadSourceBuilder? source_) => _$this._source_ = source_;

  DownloadCreateBuilder() {
    DownloadCreate._defaults(this);
  }

  DownloadCreateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _libraryId = $v.libraryId;
      _source_ = $v.source_.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadCreate other) {
    _$v = other as _$DownloadCreate;
  }

  @override
  void update(void Function(DownloadCreateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadCreate build() => _build();

  _$DownloadCreate _build() {
    _$DownloadCreate _$result;
    try {
      _$result = _$v ??
          _$DownloadCreate._(
            libraryId: BuiltValueNullFieldError.checkNotNull(
                libraryId, r'DownloadCreate', 'libraryId'),
            source_: source_.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'source_';
        source_.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'DownloadCreate', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'torrent_upload.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$TorrentUpload extends TorrentUpload {
  @override
  final String id;
  @override
  final DateTime expiresAt;
  @override
  final int sizeBytes;

  factory _$TorrentUpload([void Function(TorrentUploadBuilder)? updates]) =>
      (TorrentUploadBuilder()..update(updates))._build();

  _$TorrentUpload._(
      {required this.id, required this.expiresAt, required this.sizeBytes})
      : super._();
  @override
  TorrentUpload rebuild(void Function(TorrentUploadBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TorrentUploadBuilder toBuilder() => TorrentUploadBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TorrentUpload &&
        id == other.id &&
        expiresAt == other.expiresAt &&
        sizeBytes == other.sizeBytes;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'TorrentUpload')
          ..add('id', id)
          ..add('expiresAt', expiresAt)
          ..add('sizeBytes', sizeBytes))
        .toString();
  }
}

class TorrentUploadBuilder
    implements Builder<TorrentUpload, TorrentUploadBuilder> {
  _$TorrentUpload? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  TorrentUploadBuilder() {
    TorrentUpload._defaults(this);
  }

  TorrentUploadBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _expiresAt = $v.expiresAt;
      _sizeBytes = $v.sizeBytes;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(TorrentUpload other) {
    _$v = other as _$TorrentUpload;
  }

  @override
  void update(void Function(TorrentUploadBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TorrentUpload build() => _build();

  _$TorrentUpload _build() {
    final _$result = _$v ??
        _$TorrentUpload._(
          id: BuiltValueNullFieldError.checkNotNull(id, r'TorrentUpload', 'id'),
          expiresAt: BuiltValueNullFieldError.checkNotNull(
              expiresAt, r'TorrentUpload', 'expiresAt'),
          sizeBytes: BuiltValueNullFieldError.checkNotNull(
              sizeBytes, r'TorrentUpload', 'sizeBytes'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

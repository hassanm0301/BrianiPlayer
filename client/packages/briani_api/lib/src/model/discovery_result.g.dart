// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_result.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$DiscoveryResult extends DiscoveryResult {
  @override
  final String id;
  @override
  final String title;
  @override
  final int? sizeBytes;
  @override
  final int? seeders;
  @override
  final int? leechers;
  @override
  final int? peers;
  @override
  final String providerId;
  @override
  final String providerName;
  @override
  final DateTime? publishedAt;
  @override
  final DateTime fetchedAt;
  @override
  final bool stale;
  @override
  final bool downloadable;
  @override
  final BuiltList<int>? categories;

  factory _$DiscoveryResult([void Function(DiscoveryResultBuilder)? updates]) =>
      (DiscoveryResultBuilder()..update(updates))._build();

  _$DiscoveryResult._(
      {required this.id,
      required this.title,
      this.sizeBytes,
      this.seeders,
      this.leechers,
      this.peers,
      required this.providerId,
      required this.providerName,
      this.publishedAt,
      required this.fetchedAt,
      required this.stale,
      required this.downloadable,
      this.categories})
      : super._();
  @override
  DiscoveryResult rebuild(void Function(DiscoveryResultBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DiscoveryResultBuilder toBuilder() => DiscoveryResultBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DiscoveryResult &&
        id == other.id &&
        title == other.title &&
        sizeBytes == other.sizeBytes &&
        seeders == other.seeders &&
        leechers == other.leechers &&
        peers == other.peers &&
        providerId == other.providerId &&
        providerName == other.providerName &&
        publishedAt == other.publishedAt &&
        fetchedAt == other.fetchedAt &&
        stale == other.stale &&
        downloadable == other.downloadable &&
        categories == other.categories;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, sizeBytes.hashCode);
    _$hash = $jc(_$hash, seeders.hashCode);
    _$hash = $jc(_$hash, leechers.hashCode);
    _$hash = $jc(_$hash, peers.hashCode);
    _$hash = $jc(_$hash, providerId.hashCode);
    _$hash = $jc(_$hash, providerName.hashCode);
    _$hash = $jc(_$hash, publishedAt.hashCode);
    _$hash = $jc(_$hash, fetchedAt.hashCode);
    _$hash = $jc(_$hash, stale.hashCode);
    _$hash = $jc(_$hash, downloadable.hashCode);
    _$hash = $jc(_$hash, categories.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DiscoveryResult')
          ..add('id', id)
          ..add('title', title)
          ..add('sizeBytes', sizeBytes)
          ..add('seeders', seeders)
          ..add('leechers', leechers)
          ..add('peers', peers)
          ..add('providerId', providerId)
          ..add('providerName', providerName)
          ..add('publishedAt', publishedAt)
          ..add('fetchedAt', fetchedAt)
          ..add('stale', stale)
          ..add('downloadable', downloadable)
          ..add('categories', categories))
        .toString();
  }
}

class DiscoveryResultBuilder
    implements Builder<DiscoveryResult, DiscoveryResultBuilder> {
  _$DiscoveryResult? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  int? _sizeBytes;
  int? get sizeBytes => _$this._sizeBytes;
  set sizeBytes(int? sizeBytes) => _$this._sizeBytes = sizeBytes;

  int? _seeders;
  int? get seeders => _$this._seeders;
  set seeders(int? seeders) => _$this._seeders = seeders;

  int? _leechers;
  int? get leechers => _$this._leechers;
  set leechers(int? leechers) => _$this._leechers = leechers;

  int? _peers;
  int? get peers => _$this._peers;
  set peers(int? peers) => _$this._peers = peers;

  String? _providerId;
  String? get providerId => _$this._providerId;
  set providerId(String? providerId) => _$this._providerId = providerId;

  String? _providerName;
  String? get providerName => _$this._providerName;
  set providerName(String? providerName) => _$this._providerName = providerName;

  DateTime? _publishedAt;
  DateTime? get publishedAt => _$this._publishedAt;
  set publishedAt(DateTime? publishedAt) => _$this._publishedAt = publishedAt;

  DateTime? _fetchedAt;
  DateTime? get fetchedAt => _$this._fetchedAt;
  set fetchedAt(DateTime? fetchedAt) => _$this._fetchedAt = fetchedAt;

  bool? _stale;
  bool? get stale => _$this._stale;
  set stale(bool? stale) => _$this._stale = stale;

  bool? _downloadable;
  bool? get downloadable => _$this._downloadable;
  set downloadable(bool? downloadable) => _$this._downloadable = downloadable;

  ListBuilder<int>? _categories;
  ListBuilder<int> get categories => _$this._categories ??= ListBuilder<int>();
  set categories(ListBuilder<int>? categories) =>
      _$this._categories = categories;

  DiscoveryResultBuilder() {
    DiscoveryResult._defaults(this);
  }

  DiscoveryResultBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _title = $v.title;
      _sizeBytes = $v.sizeBytes;
      _seeders = $v.seeders;
      _leechers = $v.leechers;
      _peers = $v.peers;
      _providerId = $v.providerId;
      _providerName = $v.providerName;
      _publishedAt = $v.publishedAt;
      _fetchedAt = $v.fetchedAt;
      _stale = $v.stale;
      _downloadable = $v.downloadable;
      _categories = $v.categories?.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DiscoveryResult other) {
    _$v = other as _$DiscoveryResult;
  }

  @override
  void update(void Function(DiscoveryResultBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DiscoveryResult build() => _build();

  _$DiscoveryResult _build() {
    _$DiscoveryResult _$result;
    try {
      _$result = _$v ??
          _$DiscoveryResult._(
            id: BuiltValueNullFieldError.checkNotNull(
                id, r'DiscoveryResult', 'id'),
            title: BuiltValueNullFieldError.checkNotNull(
                title, r'DiscoveryResult', 'title'),
            sizeBytes: sizeBytes,
            seeders: seeders,
            leechers: leechers,
            peers: peers,
            providerId: BuiltValueNullFieldError.checkNotNull(
                providerId, r'DiscoveryResult', 'providerId'),
            providerName: BuiltValueNullFieldError.checkNotNull(
                providerName, r'DiscoveryResult', 'providerName'),
            publishedAt: publishedAt,
            fetchedAt: BuiltValueNullFieldError.checkNotNull(
                fetchedAt, r'DiscoveryResult', 'fetchedAt'),
            stale: BuiltValueNullFieldError.checkNotNull(
                stale, r'DiscoveryResult', 'stale'),
            downloadable: BuiltValueNullFieldError.checkNotNull(
                downloadable, r'DiscoveryResult', 'downloadable'),
            categories: _categories?.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'categories';
        _categories?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'DiscoveryResult', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

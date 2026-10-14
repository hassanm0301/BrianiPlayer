// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_page.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$MediaPage extends MediaPage {
  @override
  final BuiltList<Media> items;
  @override
  final String? nextCursor;
  @override
  final int? totalKnown;
  @override
  final bool truncated;
  @override
  final BuiltList<String> warnings;

  factory _$MediaPage([void Function(MediaPageBuilder)? updates]) =>
      (MediaPageBuilder()..update(updates))._build();

  _$MediaPage._(
      {required this.items,
      this.nextCursor,
      this.totalKnown,
      required this.truncated,
      required this.warnings})
      : super._();
  @override
  MediaPage rebuild(void Function(MediaPageBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  MediaPageBuilder toBuilder() => MediaPageBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is MediaPage &&
        items == other.items &&
        nextCursor == other.nextCursor &&
        totalKnown == other.totalKnown &&
        truncated == other.truncated &&
        warnings == other.warnings;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, items.hashCode);
    _$hash = $jc(_$hash, nextCursor.hashCode);
    _$hash = $jc(_$hash, totalKnown.hashCode);
    _$hash = $jc(_$hash, truncated.hashCode);
    _$hash = $jc(_$hash, warnings.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'MediaPage')
          ..add('items', items)
          ..add('nextCursor', nextCursor)
          ..add('totalKnown', totalKnown)
          ..add('truncated', truncated)
          ..add('warnings', warnings))
        .toString();
  }
}

class MediaPageBuilder implements Builder<MediaPage, MediaPageBuilder> {
  _$MediaPage? _$v;

  ListBuilder<Media>? _items;
  ListBuilder<Media> get items => _$this._items ??= ListBuilder<Media>();
  set items(ListBuilder<Media>? items) => _$this._items = items;

  String? _nextCursor;
  String? get nextCursor => _$this._nextCursor;
  set nextCursor(String? nextCursor) => _$this._nextCursor = nextCursor;

  int? _totalKnown;
  int? get totalKnown => _$this._totalKnown;
  set totalKnown(int? totalKnown) => _$this._totalKnown = totalKnown;

  bool? _truncated;
  bool? get truncated => _$this._truncated;
  set truncated(bool? truncated) => _$this._truncated = truncated;

  ListBuilder<String>? _warnings;
  ListBuilder<String> get warnings =>
      _$this._warnings ??= ListBuilder<String>();
  set warnings(ListBuilder<String>? warnings) => _$this._warnings = warnings;

  MediaPageBuilder() {
    MediaPage._defaults(this);
  }

  MediaPageBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _items = $v.items.toBuilder();
      _nextCursor = $v.nextCursor;
      _totalKnown = $v.totalKnown;
      _truncated = $v.truncated;
      _warnings = $v.warnings.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(MediaPage other) {
    _$v = other as _$MediaPage;
  }

  @override
  void update(void Function(MediaPageBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  MediaPage build() => _build();

  _$MediaPage _build() {
    _$MediaPage _$result;
    try {
      _$result = _$v ??
          _$MediaPage._(
            items: items.build(),
            nextCursor: nextCursor,
            totalKnown: totalKnown,
            truncated: BuiltValueNullFieldError.checkNotNull(
                truncated, r'MediaPage', 'truncated'),
            warnings: warnings.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'items';
        items.build();

        _$failedField = 'warnings';
        warnings.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'MediaPage', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

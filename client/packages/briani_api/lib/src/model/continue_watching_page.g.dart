// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'continue_watching_page.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$ContinueWatchingPage extends ContinueWatchingPage {
  @override
  final BuiltList<ContinueWatching> items;
  @override
  final String? nextCursor;
  @override
  final int? totalKnown;
  @override
  final bool truncated;
  @override
  final BuiltList<String> warnings;

  factory _$ContinueWatchingPage(
          [void Function(ContinueWatchingPageBuilder)? updates]) =>
      (ContinueWatchingPageBuilder()..update(updates))._build();

  _$ContinueWatchingPage._(
      {required this.items,
      this.nextCursor,
      this.totalKnown,
      required this.truncated,
      required this.warnings})
      : super._();
  @override
  ContinueWatchingPage rebuild(
          void Function(ContinueWatchingPageBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ContinueWatchingPageBuilder toBuilder() =>
      ContinueWatchingPageBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ContinueWatchingPage &&
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
    return (newBuiltValueToStringHelper(r'ContinueWatchingPage')
          ..add('items', items)
          ..add('nextCursor', nextCursor)
          ..add('totalKnown', totalKnown)
          ..add('truncated', truncated)
          ..add('warnings', warnings))
        .toString();
  }
}

class ContinueWatchingPageBuilder
    implements Builder<ContinueWatchingPage, ContinueWatchingPageBuilder> {
  _$ContinueWatchingPage? _$v;

  ListBuilder<ContinueWatching>? _items;
  ListBuilder<ContinueWatching> get items =>
      _$this._items ??= ListBuilder<ContinueWatching>();
  set items(ListBuilder<ContinueWatching>? items) => _$this._items = items;

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

  ContinueWatchingPageBuilder() {
    ContinueWatchingPage._defaults(this);
  }

  ContinueWatchingPageBuilder get _$this {
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
  void replace(ContinueWatchingPage other) {
    _$v = other as _$ContinueWatchingPage;
  }

  @override
  void update(void Function(ContinueWatchingPageBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  ContinueWatchingPage build() => _build();

  _$ContinueWatchingPage _build() {
    _$ContinueWatchingPage _$result;
    try {
      _$result = _$v ??
          _$ContinueWatchingPage._(
            items: items.build(),
            nextCursor: nextCursor,
            totalKnown: totalKnown,
            truncated: BuiltValueNullFieldError.checkNotNull(
                truncated, r'ContinueWatchingPage', 'truncated'),
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
            r'ContinueWatchingPage', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

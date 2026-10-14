// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracker_summary.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$TrackerSummary extends TrackerSummary {
  @override
  final String host;
  @override
  final String state;
  @override
  final int? peers;
  @override
  final String? message;

  factory _$TrackerSummary([void Function(TrackerSummaryBuilder)? updates]) =>
      (TrackerSummaryBuilder()..update(updates))._build();

  _$TrackerSummary._(
      {required this.host, required this.state, this.peers, this.message})
      : super._();
  @override
  TrackerSummary rebuild(void Function(TrackerSummaryBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  TrackerSummaryBuilder toBuilder() => TrackerSummaryBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is TrackerSummary &&
        host == other.host &&
        state == other.state &&
        peers == other.peers &&
        message == other.message;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, host.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, peers.hashCode);
    _$hash = $jc(_$hash, message.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'TrackerSummary')
          ..add('host', host)
          ..add('state', state)
          ..add('peers', peers)
          ..add('message', message))
        .toString();
  }
}

class TrackerSummaryBuilder
    implements Builder<TrackerSummary, TrackerSummaryBuilder> {
  _$TrackerSummary? _$v;

  String? _host;
  String? get host => _$this._host;
  set host(String? host) => _$this._host = host;

  String? _state;
  String? get state => _$this._state;
  set state(String? state) => _$this._state = state;

  int? _peers;
  int? get peers => _$this._peers;
  set peers(int? peers) => _$this._peers = peers;

  String? _message;
  String? get message => _$this._message;
  set message(String? message) => _$this._message = message;

  TrackerSummaryBuilder() {
    TrackerSummary._defaults(this);
  }

  TrackerSummaryBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _host = $v.host;
      _state = $v.state;
      _peers = $v.peers;
      _message = $v.message;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(TrackerSummary other) {
    _$v = other as _$TrackerSummary;
  }

  @override
  void update(void Function(TrackerSummaryBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  TrackerSummary build() => _build();

  _$TrackerSummary _build() {
    final _$result = _$v ??
        _$TrackerSummary._(
          host: BuiltValueNullFieldError.checkNotNull(
              host, r'TrackerSummary', 'host'),
          state: BuiltValueNullFieldError.checkNotNull(
              state, r'TrackerSummary', 'state'),
          peers: peers,
          message: message,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

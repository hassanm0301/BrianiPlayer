// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_create.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const PlaybackCreateModeEnum _$playbackCreateModeEnum_internal =
    const PlaybackCreateModeEnum._('internal');
const PlaybackCreateModeEnum _$playbackCreateModeEnum_external_ =
    const PlaybackCreateModeEnum._('external_');

PlaybackCreateModeEnum _$playbackCreateModeEnumValueOf(String name) {
  switch (name) {
    case 'internal':
      return _$playbackCreateModeEnum_internal;
    case 'external_':
      return _$playbackCreateModeEnum_external_;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<PlaybackCreateModeEnum> _$playbackCreateModeEnumValues =
    BuiltSet<PlaybackCreateModeEnum>(const <PlaybackCreateModeEnum>[
  _$playbackCreateModeEnum_internal,
  _$playbackCreateModeEnum_external_,
]);

Serializer<PlaybackCreateModeEnum> _$playbackCreateModeEnumSerializer =
    _$PlaybackCreateModeEnumSerializer();

class _$PlaybackCreateModeEnumSerializer
    implements PrimitiveSerializer<PlaybackCreateModeEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'internal': 'internal',
    'external_': 'external',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'internal': 'internal',
    'external': 'external_',
  };

  @override
  final Iterable<Type> types = const <Type>[PlaybackCreateModeEnum];
  @override
  final String wireName = 'PlaybackCreateModeEnum';

  @override
  Object serialize(Serializers serializers, PlaybackCreateModeEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  PlaybackCreateModeEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      PlaybackCreateModeEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$PlaybackCreate extends PlaybackCreate {
  @override
  final PlaybackTarget target;
  @override
  final PlaybackCreateModeEnum mode;
  @override
  final int? initialPositionMs;

  factory _$PlaybackCreate([void Function(PlaybackCreateBuilder)? updates]) =>
      (PlaybackCreateBuilder()..update(updates))._build();

  _$PlaybackCreate._(
      {required this.target, required this.mode, this.initialPositionMs})
      : super._();
  @override
  PlaybackCreate rebuild(void Function(PlaybackCreateBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  PlaybackCreateBuilder toBuilder() => PlaybackCreateBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is PlaybackCreate &&
        target == other.target &&
        mode == other.mode &&
        initialPositionMs == other.initialPositionMs;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, target.hashCode);
    _$hash = $jc(_$hash, mode.hashCode);
    _$hash = $jc(_$hash, initialPositionMs.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'PlaybackCreate')
          ..add('target', target)
          ..add('mode', mode)
          ..add('initialPositionMs', initialPositionMs))
        .toString();
  }
}

class PlaybackCreateBuilder
    implements Builder<PlaybackCreate, PlaybackCreateBuilder> {
  _$PlaybackCreate? _$v;

  PlaybackTargetBuilder? _target;
  PlaybackTargetBuilder get target =>
      _$this._target ??= PlaybackTargetBuilder();
  set target(PlaybackTargetBuilder? target) => _$this._target = target;

  PlaybackCreateModeEnum? _mode;
  PlaybackCreateModeEnum? get mode => _$this._mode;
  set mode(PlaybackCreateModeEnum? mode) => _$this._mode = mode;

  int? _initialPositionMs;
  int? get initialPositionMs => _$this._initialPositionMs;
  set initialPositionMs(int? initialPositionMs) =>
      _$this._initialPositionMs = initialPositionMs;

  PlaybackCreateBuilder() {
    PlaybackCreate._defaults(this);
  }

  PlaybackCreateBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _target = $v.target.toBuilder();
      _mode = $v.mode;
      _initialPositionMs = $v.initialPositionMs;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(PlaybackCreate other) {
    _$v = other as _$PlaybackCreate;
  }

  @override
  void update(void Function(PlaybackCreateBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  PlaybackCreate build() => _build();

  _$PlaybackCreate _build() {
    _$PlaybackCreate _$result;
    try {
      _$result = _$v ??
          _$PlaybackCreate._(
            target: target.build(),
            mode: BuiltValueNullFieldError.checkNotNull(
                mode, r'PlaybackCreate', 'mode'),
            initialPositionMs: initialPositionMs,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'target';
        target.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'PlaybackCreate', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

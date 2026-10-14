// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_source_one_of1.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DownloadSourceOneOf1KindEnum _$downloadSourceOneOf1KindEnum_magnet =
    const DownloadSourceOneOf1KindEnum._('magnet');

DownloadSourceOneOf1KindEnum _$downloadSourceOneOf1KindEnumValueOf(
    String name) {
  switch (name) {
    case 'magnet':
      return _$downloadSourceOneOf1KindEnum_magnet;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadSourceOneOf1KindEnum>
    _$downloadSourceOneOf1KindEnumValues =
    BuiltSet<DownloadSourceOneOf1KindEnum>(const <DownloadSourceOneOf1KindEnum>[
  _$downloadSourceOneOf1KindEnum_magnet,
]);

Serializer<DownloadSourceOneOf1KindEnum>
    _$downloadSourceOneOf1KindEnumSerializer =
    _$DownloadSourceOneOf1KindEnumSerializer();

class _$DownloadSourceOneOf1KindEnumSerializer
    implements PrimitiveSerializer<DownloadSourceOneOf1KindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'magnet': 'magnet',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'magnet': 'magnet',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadSourceOneOf1KindEnum];
  @override
  final String wireName = 'DownloadSourceOneOf1KindEnum';

  @override
  Object serialize(Serializers serializers, DownloadSourceOneOf1KindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadSourceOneOf1KindEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadSourceOneOf1KindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadSourceOneOf1 extends DownloadSourceOneOf1 {
  @override
  final DownloadSourceOneOf1KindEnum kind;
  @override
  final String value;

  factory _$DownloadSourceOneOf1(
          [void Function(DownloadSourceOneOf1Builder)? updates]) =>
      (DownloadSourceOneOf1Builder()..update(updates))._build();

  _$DownloadSourceOneOf1._({required this.kind, required this.value})
      : super._();
  @override
  DownloadSourceOneOf1 rebuild(
          void Function(DownloadSourceOneOf1Builder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadSourceOneOf1Builder toBuilder() =>
      DownloadSourceOneOf1Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadSourceOneOf1 &&
        kind == other.kind &&
        value == other.value;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, value.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DownloadSourceOneOf1')
          ..add('kind', kind)
          ..add('value', value))
        .toString();
  }
}

class DownloadSourceOneOf1Builder
    implements Builder<DownloadSourceOneOf1, DownloadSourceOneOf1Builder> {
  _$DownloadSourceOneOf1? _$v;

  DownloadSourceOneOf1KindEnum? _kind;
  DownloadSourceOneOf1KindEnum? get kind => _$this._kind;
  set kind(DownloadSourceOneOf1KindEnum? kind) => _$this._kind = kind;

  String? _value;
  String? get value => _$this._value;
  set value(String? value) => _$this._value = value;

  DownloadSourceOneOf1Builder() {
    DownloadSourceOneOf1._defaults(this);
  }

  DownloadSourceOneOf1Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _value = $v.value;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadSourceOneOf1 other) {
    _$v = other as _$DownloadSourceOneOf1;
  }

  @override
  void update(void Function(DownloadSourceOneOf1Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadSourceOneOf1 build() => _build();

  _$DownloadSourceOneOf1 _build() {
    final _$result = _$v ??
        _$DownloadSourceOneOf1._(
          kind: BuiltValueNullFieldError.checkNotNull(
              kind, r'DownloadSourceOneOf1', 'kind'),
          value: BuiltValueNullFieldError.checkNotNull(
              value, r'DownloadSourceOneOf1', 'value'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

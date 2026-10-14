// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_source_one_of.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DownloadSourceOneOfKindEnum
    _$downloadSourceOneOfKindEnum_discoveryResult =
    const DownloadSourceOneOfKindEnum._('discoveryResult');

DownloadSourceOneOfKindEnum _$downloadSourceOneOfKindEnumValueOf(String name) {
  switch (name) {
    case 'discoveryResult':
      return _$downloadSourceOneOfKindEnum_discoveryResult;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadSourceOneOfKindEnum>
    _$downloadSourceOneOfKindEnumValues =
    BuiltSet<DownloadSourceOneOfKindEnum>(const <DownloadSourceOneOfKindEnum>[
  _$downloadSourceOneOfKindEnum_discoveryResult,
]);

Serializer<DownloadSourceOneOfKindEnum>
    _$downloadSourceOneOfKindEnumSerializer =
    _$DownloadSourceOneOfKindEnumSerializer();

class _$DownloadSourceOneOfKindEnumSerializer
    implements PrimitiveSerializer<DownloadSourceOneOfKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'discoveryResult': 'discoveryResult',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'discoveryResult': 'discoveryResult',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadSourceOneOfKindEnum];
  @override
  final String wireName = 'DownloadSourceOneOfKindEnum';

  @override
  Object serialize(Serializers serializers, DownloadSourceOneOfKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadSourceOneOfKindEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadSourceOneOfKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadSourceOneOf extends DownloadSourceOneOf {
  @override
  final DownloadSourceOneOfKindEnum kind;
  @override
  final String value;

  factory _$DownloadSourceOneOf(
          [void Function(DownloadSourceOneOfBuilder)? updates]) =>
      (DownloadSourceOneOfBuilder()..update(updates))._build();

  _$DownloadSourceOneOf._({required this.kind, required this.value})
      : super._();
  @override
  DownloadSourceOneOf rebuild(
          void Function(DownloadSourceOneOfBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadSourceOneOfBuilder toBuilder() =>
      DownloadSourceOneOfBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadSourceOneOf &&
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
    return (newBuiltValueToStringHelper(r'DownloadSourceOneOf')
          ..add('kind', kind)
          ..add('value', value))
        .toString();
  }
}

class DownloadSourceOneOfBuilder
    implements Builder<DownloadSourceOneOf, DownloadSourceOneOfBuilder> {
  _$DownloadSourceOneOf? _$v;

  DownloadSourceOneOfKindEnum? _kind;
  DownloadSourceOneOfKindEnum? get kind => _$this._kind;
  set kind(DownloadSourceOneOfKindEnum? kind) => _$this._kind = kind;

  String? _value;
  String? get value => _$this._value;
  set value(String? value) => _$this._value = value;

  DownloadSourceOneOfBuilder() {
    DownloadSourceOneOf._defaults(this);
  }

  DownloadSourceOneOfBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _value = $v.value;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadSourceOneOf other) {
    _$v = other as _$DownloadSourceOneOf;
  }

  @override
  void update(void Function(DownloadSourceOneOfBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadSourceOneOf build() => _build();

  _$DownloadSourceOneOf _build() {
    final _$result = _$v ??
        _$DownloadSourceOneOf._(
          kind: BuiltValueNullFieldError.checkNotNull(
              kind, r'DownloadSourceOneOf', 'kind'),
          value: BuiltValueNullFieldError.checkNotNull(
              value, r'DownloadSourceOneOf', 'value'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

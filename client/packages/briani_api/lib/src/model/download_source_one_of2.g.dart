// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_source_one_of2.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DownloadSourceOneOf2KindEnum
    _$downloadSourceOneOf2KindEnum_torrentUpload =
    const DownloadSourceOneOf2KindEnum._('torrentUpload');

DownloadSourceOneOf2KindEnum _$downloadSourceOneOf2KindEnumValueOf(
    String name) {
  switch (name) {
    case 'torrentUpload':
      return _$downloadSourceOneOf2KindEnum_torrentUpload;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadSourceOneOf2KindEnum>
    _$downloadSourceOneOf2KindEnumValues =
    BuiltSet<DownloadSourceOneOf2KindEnum>(const <DownloadSourceOneOf2KindEnum>[
  _$downloadSourceOneOf2KindEnum_torrentUpload,
]);

Serializer<DownloadSourceOneOf2KindEnum>
    _$downloadSourceOneOf2KindEnumSerializer =
    _$DownloadSourceOneOf2KindEnumSerializer();

class _$DownloadSourceOneOf2KindEnumSerializer
    implements PrimitiveSerializer<DownloadSourceOneOf2KindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'torrentUpload': 'torrentUpload',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'torrentUpload': 'torrentUpload',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadSourceOneOf2KindEnum];
  @override
  final String wireName = 'DownloadSourceOneOf2KindEnum';

  @override
  Object serialize(Serializers serializers, DownloadSourceOneOf2KindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadSourceOneOf2KindEnum deserialize(
          Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadSourceOneOf2KindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadSourceOneOf2 extends DownloadSourceOneOf2 {
  @override
  final DownloadSourceOneOf2KindEnum kind;
  @override
  final String value;

  factory _$DownloadSourceOneOf2(
          [void Function(DownloadSourceOneOf2Builder)? updates]) =>
      (DownloadSourceOneOf2Builder()..update(updates))._build();

  _$DownloadSourceOneOf2._({required this.kind, required this.value})
      : super._();
  @override
  DownloadSourceOneOf2 rebuild(
          void Function(DownloadSourceOneOf2Builder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadSourceOneOf2Builder toBuilder() =>
      DownloadSourceOneOf2Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadSourceOneOf2 &&
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
    return (newBuiltValueToStringHelper(r'DownloadSourceOneOf2')
          ..add('kind', kind)
          ..add('value', value))
        .toString();
  }
}

class DownloadSourceOneOf2Builder
    implements Builder<DownloadSourceOneOf2, DownloadSourceOneOf2Builder> {
  _$DownloadSourceOneOf2? _$v;

  DownloadSourceOneOf2KindEnum? _kind;
  DownloadSourceOneOf2KindEnum? get kind => _$this._kind;
  set kind(DownloadSourceOneOf2KindEnum? kind) => _$this._kind = kind;

  String? _value;
  String? get value => _$this._value;
  set value(String? value) => _$this._value = value;

  DownloadSourceOneOf2Builder() {
    DownloadSourceOneOf2._defaults(this);
  }

  DownloadSourceOneOf2Builder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _value = $v.value;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadSourceOneOf2 other) {
    _$v = other as _$DownloadSourceOneOf2;
  }

  @override
  void update(void Function(DownloadSourceOneOf2Builder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadSourceOneOf2 build() => _build();

  _$DownloadSourceOneOf2 _build() {
    final _$result = _$v ??
        _$DownloadSourceOneOf2._(
          kind: BuiltValueNullFieldError.checkNotNull(
              kind, r'DownloadSourceOneOf2', 'kind'),
          value: BuiltValueNullFieldError.checkNotNull(
              value, r'DownloadSourceOneOf2', 'value'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

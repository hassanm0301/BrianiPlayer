// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_source.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const DownloadSourceKindEnum _$downloadSourceKindEnum_torrentUpload =
    const DownloadSourceKindEnum._('torrentUpload');

DownloadSourceKindEnum _$downloadSourceKindEnumValueOf(String name) {
  switch (name) {
    case 'torrentUpload':
      return _$downloadSourceKindEnum_torrentUpload;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<DownloadSourceKindEnum> _$downloadSourceKindEnumValues =
    BuiltSet<DownloadSourceKindEnum>(const <DownloadSourceKindEnum>[
  _$downloadSourceKindEnum_torrentUpload,
]);

Serializer<DownloadSourceKindEnum> _$downloadSourceKindEnumSerializer =
    _$DownloadSourceKindEnumSerializer();

class _$DownloadSourceKindEnumSerializer
    implements PrimitiveSerializer<DownloadSourceKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'torrentUpload': 'torrentUpload',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'torrentUpload': 'torrentUpload',
  };

  @override
  final Iterable<Type> types = const <Type>[DownloadSourceKindEnum];
  @override
  final String wireName = 'DownloadSourceKindEnum';

  @override
  Object serialize(Serializers serializers, DownloadSourceKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  DownloadSourceKindEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      DownloadSourceKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$DownloadSource extends DownloadSource {
  @override
  final OneOf oneOf;

  factory _$DownloadSource([void Function(DownloadSourceBuilder)? updates]) =>
      (DownloadSourceBuilder()..update(updates))._build();

  _$DownloadSource._({required this.oneOf}) : super._();
  @override
  DownloadSource rebuild(void Function(DownloadSourceBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  DownloadSourceBuilder toBuilder() => DownloadSourceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is DownloadSource && oneOf == other.oneOf;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, oneOf.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'DownloadSource')..add('oneOf', oneOf))
        .toString();
  }
}

class DownloadSourceBuilder
    implements Builder<DownloadSource, DownloadSourceBuilder> {
  _$DownloadSource? _$v;

  OneOf? _oneOf;
  OneOf? get oneOf => _$this._oneOf;
  set oneOf(OneOf? oneOf) => _$this._oneOf = oneOf;

  DownloadSourceBuilder() {
    DownloadSource._defaults(this);
  }

  DownloadSourceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _oneOf = $v.oneOf;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(DownloadSource other) {
    _$v = other as _$DownloadSource;
  }

  @override
  void update(void Function(DownloadSourceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  DownloadSource build() => _build();

  _$DownloadSource _build() {
    final _$result = _$v ??
        _$DownloadSource._(
          oneOf: BuiltValueNullFieldError.checkNotNull(
              oneOf, r'DownloadSource', 'oneOf'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

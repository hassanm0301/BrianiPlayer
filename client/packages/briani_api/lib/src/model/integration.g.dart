// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'integration.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const IntegrationKindEnum _$integrationKindEnum_prowlarr =
    const IntegrationKindEnum._('prowlarr');
const IntegrationKindEnum _$integrationKindEnum_qbittorrent =
    const IntegrationKindEnum._('qbittorrent');

IntegrationKindEnum _$integrationKindEnumValueOf(String name) {
  switch (name) {
    case 'prowlarr':
      return _$integrationKindEnum_prowlarr;
    case 'qbittorrent':
      return _$integrationKindEnum_qbittorrent;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<IntegrationKindEnum> _$integrationKindEnumValues =
    BuiltSet<IntegrationKindEnum>(const <IntegrationKindEnum>[
  _$integrationKindEnum_prowlarr,
  _$integrationKindEnum_qbittorrent,
]);

Serializer<IntegrationKindEnum> _$integrationKindEnumSerializer =
    _$IntegrationKindEnumSerializer();

class _$IntegrationKindEnumSerializer
    implements PrimitiveSerializer<IntegrationKindEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'prowlarr': 'prowlarr',
    'qbittorrent': 'qbittorrent',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'prowlarr': 'prowlarr',
    'qbittorrent': 'qbittorrent',
  };

  @override
  final Iterable<Type> types = const <Type>[IntegrationKindEnum];
  @override
  final String wireName = 'IntegrationKindEnum';

  @override
  Object serialize(Serializers serializers, IntegrationKindEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  IntegrationKindEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      IntegrationKindEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Integration extends Integration {
  @override
  final IntegrationKindEnum kind;
  @override
  final String baseUrl;
  @override
  final bool credentialConfigured;
  @override
  final ServiceHealth health;
  @override
  final int version;

  factory _$Integration([void Function(IntegrationBuilder)? updates]) =>
      (IntegrationBuilder()..update(updates))._build();

  _$Integration._(
      {required this.kind,
      required this.baseUrl,
      required this.credentialConfigured,
      required this.health,
      required this.version})
      : super._();
  @override
  Integration rebuild(void Function(IntegrationBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  IntegrationBuilder toBuilder() => IntegrationBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Integration &&
        kind == other.kind &&
        baseUrl == other.baseUrl &&
        credentialConfigured == other.credentialConfigured &&
        health == other.health &&
        version == other.version;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, baseUrl.hashCode);
    _$hash = $jc(_$hash, credentialConfigured.hashCode);
    _$hash = $jc(_$hash, health.hashCode);
    _$hash = $jc(_$hash, version.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Integration')
          ..add('kind', kind)
          ..add('baseUrl', baseUrl)
          ..add('credentialConfigured', credentialConfigured)
          ..add('health', health)
          ..add('version', version))
        .toString();
  }
}

class IntegrationBuilder implements Builder<Integration, IntegrationBuilder> {
  _$Integration? _$v;

  IntegrationKindEnum? _kind;
  IntegrationKindEnum? get kind => _$this._kind;
  set kind(IntegrationKindEnum? kind) => _$this._kind = kind;

  String? _baseUrl;
  String? get baseUrl => _$this._baseUrl;
  set baseUrl(String? baseUrl) => _$this._baseUrl = baseUrl;

  bool? _credentialConfigured;
  bool? get credentialConfigured => _$this._credentialConfigured;
  set credentialConfigured(bool? credentialConfigured) =>
      _$this._credentialConfigured = credentialConfigured;

  ServiceHealthBuilder? _health;
  ServiceHealthBuilder get health => _$this._health ??= ServiceHealthBuilder();
  set health(ServiceHealthBuilder? health) => _$this._health = health;

  int? _version;
  int? get version => _$this._version;
  set version(int? version) => _$this._version = version;

  IntegrationBuilder() {
    Integration._defaults(this);
  }

  IntegrationBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _kind = $v.kind;
      _baseUrl = $v.baseUrl;
      _credentialConfigured = $v.credentialConfigured;
      _health = $v.health.toBuilder();
      _version = $v.version;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Integration other) {
    _$v = other as _$Integration;
  }

  @override
  void update(void Function(IntegrationBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Integration build() => _build();

  _$Integration _build() {
    _$Integration _$result;
    try {
      _$result = _$v ??
          _$Integration._(
            kind: BuiltValueNullFieldError.checkNotNull(
                kind, r'Integration', 'kind'),
            baseUrl: BuiltValueNullFieldError.checkNotNull(
                baseUrl, r'Integration', 'baseUrl'),
            credentialConfigured: BuiltValueNullFieldError.checkNotNull(
                credentialConfigured, r'Integration', 'credentialConfigured'),
            health: health.build(),
            version: BuiltValueNullFieldError.checkNotNull(
                version, r'Integration', 'version'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'health';
        health.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'Integration', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

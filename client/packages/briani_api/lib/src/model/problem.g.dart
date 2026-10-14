// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Problem extends Problem {
  @override
  final String? type;
  @override
  final String title;
  @override
  final int status;
  @override
  final String code;
  @override
  final String? detail;
  @override
  final String? traceId;
  @override
  final BuiltMap<String, BuiltList<String>>? fieldErrors;
  @override
  final int? retryAfterSeconds;

  factory _$Problem([void Function(ProblemBuilder)? updates]) =>
      (ProblemBuilder()..update(updates))._build();

  _$Problem._(
      {this.type,
      required this.title,
      required this.status,
      required this.code,
      this.detail,
      this.traceId,
      this.fieldErrors,
      this.retryAfterSeconds})
      : super._();
  @override
  Problem rebuild(void Function(ProblemBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ProblemBuilder toBuilder() => ProblemBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Problem &&
        type == other.type &&
        title == other.title &&
        status == other.status &&
        code == other.code &&
        detail == other.detail &&
        traceId == other.traceId &&
        fieldErrors == other.fieldErrors &&
        retryAfterSeconds == other.retryAfterSeconds;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, type.hashCode);
    _$hash = $jc(_$hash, title.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, code.hashCode);
    _$hash = $jc(_$hash, detail.hashCode);
    _$hash = $jc(_$hash, traceId.hashCode);
    _$hash = $jc(_$hash, fieldErrors.hashCode);
    _$hash = $jc(_$hash, retryAfterSeconds.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Problem')
          ..add('type', type)
          ..add('title', title)
          ..add('status', status)
          ..add('code', code)
          ..add('detail', detail)
          ..add('traceId', traceId)
          ..add('fieldErrors', fieldErrors)
          ..add('retryAfterSeconds', retryAfterSeconds))
        .toString();
  }
}

class ProblemBuilder implements Builder<Problem, ProblemBuilder> {
  _$Problem? _$v;

  String? _type;
  String? get type => _$this._type;
  set type(String? type) => _$this._type = type;

  String? _title;
  String? get title => _$this._title;
  set title(String? title) => _$this._title = title;

  int? _status;
  int? get status => _$this._status;
  set status(int? status) => _$this._status = status;

  String? _code;
  String? get code => _$this._code;
  set code(String? code) => _$this._code = code;

  String? _detail;
  String? get detail => _$this._detail;
  set detail(String? detail) => _$this._detail = detail;

  String? _traceId;
  String? get traceId => _$this._traceId;
  set traceId(String? traceId) => _$this._traceId = traceId;

  MapBuilder<String, BuiltList<String>>? _fieldErrors;
  MapBuilder<String, BuiltList<String>> get fieldErrors =>
      _$this._fieldErrors ??= MapBuilder<String, BuiltList<String>>();
  set fieldErrors(MapBuilder<String, BuiltList<String>>? fieldErrors) =>
      _$this._fieldErrors = fieldErrors;

  int? _retryAfterSeconds;
  int? get retryAfterSeconds => _$this._retryAfterSeconds;
  set retryAfterSeconds(int? retryAfterSeconds) =>
      _$this._retryAfterSeconds = retryAfterSeconds;

  ProblemBuilder() {
    Problem._defaults(this);
  }

  ProblemBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _type = $v.type;
      _title = $v.title;
      _status = $v.status;
      _code = $v.code;
      _detail = $v.detail;
      _traceId = $v.traceId;
      _fieldErrors = $v.fieldErrors?.toBuilder();
      _retryAfterSeconds = $v.retryAfterSeconds;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Problem other) {
    _$v = other as _$Problem;
  }

  @override
  void update(void Function(ProblemBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Problem build() => _build();

  _$Problem _build() {
    _$Problem _$result;
    try {
      _$result = _$v ??
          _$Problem._(
            type: type,
            title: BuiltValueNullFieldError.checkNotNull(
                title, r'Problem', 'title'),
            status: BuiltValueNullFieldError.checkNotNull(
                status, r'Problem', 'status'),
            code:
                BuiltValueNullFieldError.checkNotNull(code, r'Problem', 'code'),
            detail: detail,
            traceId: traceId,
            fieldErrors: _fieldErrors?.build(),
            retryAfterSeconds: retryAfterSeconds,
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'fieldErrors';
        _fieldErrors?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'Problem', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

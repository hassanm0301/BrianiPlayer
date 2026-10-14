// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const JobStateEnum _$jobStateEnum_queued = const JobStateEnum._('queued');
const JobStateEnum _$jobStateEnum_running = const JobStateEnum._('running');
const JobStateEnum _$jobStateEnum_completed = const JobStateEnum._('completed');
const JobStateEnum _$jobStateEnum_failed = const JobStateEnum._('failed');
const JobStateEnum _$jobStateEnum_cancelled = const JobStateEnum._('cancelled');

JobStateEnum _$jobStateEnumValueOf(String name) {
  switch (name) {
    case 'queued':
      return _$jobStateEnum_queued;
    case 'running':
      return _$jobStateEnum_running;
    case 'completed':
      return _$jobStateEnum_completed;
    case 'failed':
      return _$jobStateEnum_failed;
    case 'cancelled':
      return _$jobStateEnum_cancelled;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<JobStateEnum> _$jobStateEnumValues =
    BuiltSet<JobStateEnum>(const <JobStateEnum>[
  _$jobStateEnum_queued,
  _$jobStateEnum_running,
  _$jobStateEnum_completed,
  _$jobStateEnum_failed,
  _$jobStateEnum_cancelled,
]);

Serializer<JobStateEnum> _$jobStateEnumSerializer = _$JobStateEnumSerializer();

class _$JobStateEnumSerializer implements PrimitiveSerializer<JobStateEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'queued': 'queued',
    'running': 'running',
    'completed': 'completed',
    'failed': 'failed',
    'cancelled': 'cancelled',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'queued': 'queued',
    'running': 'running',
    'completed': 'completed',
    'failed': 'failed',
    'cancelled': 'cancelled',
  };

  @override
  final Iterable<Type> types = const <Type>[JobStateEnum];
  @override
  final String wireName = 'JobStateEnum';

  @override
  Object serialize(Serializers serializers, JobStateEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  JobStateEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      JobStateEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$Job extends Job {
  @override
  final String id;
  @override
  final String kind;
  @override
  final JobStateEnum state;
  @override
  final double? progress;
  @override
  final Problem? error;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  factory _$Job([void Function(JobBuilder)? updates]) =>
      (JobBuilder()..update(updates))._build();

  _$Job._(
      {required this.id,
      required this.kind,
      required this.state,
      this.progress,
      this.error,
      required this.createdAt,
      required this.updatedAt})
      : super._();
  @override
  Job rebuild(void Function(JobBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  JobBuilder toBuilder() => JobBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Job &&
        id == other.id &&
        kind == other.kind &&
        state == other.state &&
        progress == other.progress &&
        error == other.error &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, id.hashCode);
    _$hash = $jc(_$hash, kind.hashCode);
    _$hash = $jc(_$hash, state.hashCode);
    _$hash = $jc(_$hash, progress.hashCode);
    _$hash = $jc(_$hash, error.hashCode);
    _$hash = $jc(_$hash, createdAt.hashCode);
    _$hash = $jc(_$hash, updatedAt.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'Job')
          ..add('id', id)
          ..add('kind', kind)
          ..add('state', state)
          ..add('progress', progress)
          ..add('error', error)
          ..add('createdAt', createdAt)
          ..add('updatedAt', updatedAt))
        .toString();
  }
}

class JobBuilder implements Builder<Job, JobBuilder> {
  _$Job? _$v;

  String? _id;
  String? get id => _$this._id;
  set id(String? id) => _$this._id = id;

  String? _kind;
  String? get kind => _$this._kind;
  set kind(String? kind) => _$this._kind = kind;

  JobStateEnum? _state;
  JobStateEnum? get state => _$this._state;
  set state(JobStateEnum? state) => _$this._state = state;

  double? _progress;
  double? get progress => _$this._progress;
  set progress(double? progress) => _$this._progress = progress;

  ProblemBuilder? _error;
  ProblemBuilder get error => _$this._error ??= ProblemBuilder();
  set error(ProblemBuilder? error) => _$this._error = error;

  DateTime? _createdAt;
  DateTime? get createdAt => _$this._createdAt;
  set createdAt(DateTime? createdAt) => _$this._createdAt = createdAt;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _$this._updatedAt;
  set updatedAt(DateTime? updatedAt) => _$this._updatedAt = updatedAt;

  JobBuilder() {
    Job._defaults(this);
  }

  JobBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _id = $v.id;
      _kind = $v.kind;
      _state = $v.state;
      _progress = $v.progress;
      _error = $v.error?.toBuilder();
      _createdAt = $v.createdAt;
      _updatedAt = $v.updatedAt;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Job other) {
    _$v = other as _$Job;
  }

  @override
  void update(void Function(JobBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  Job build() => _build();

  _$Job _build() {
    _$Job _$result;
    try {
      _$result = _$v ??
          _$Job._(
            id: BuiltValueNullFieldError.checkNotNull(id, r'Job', 'id'),
            kind: BuiltValueNullFieldError.checkNotNull(kind, r'Job', 'kind'),
            state:
                BuiltValueNullFieldError.checkNotNull(state, r'Job', 'state'),
            progress: progress,
            error: _error?.build(),
            createdAt: BuiltValueNullFieldError.checkNotNull(
                createdAt, r'Job', 'createdAt'),
            updatedAt: BuiltValueNullFieldError.checkNotNull(
                updatedAt, r'Job', 'updatedAt'),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'error';
        _error?.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(r'Job', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

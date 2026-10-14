// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_choice.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const FileChoicePriorityEnum _$fileChoicePriorityEnum_normal =
    const FileChoicePriorityEnum._('normal');
const FileChoicePriorityEnum _$fileChoicePriorityEnum_high =
    const FileChoicePriorityEnum._('high');
const FileChoicePriorityEnum _$fileChoicePriorityEnum_maximum =
    const FileChoicePriorityEnum._('maximum');

FileChoicePriorityEnum _$fileChoicePriorityEnumValueOf(String name) {
  switch (name) {
    case 'normal':
      return _$fileChoicePriorityEnum_normal;
    case 'high':
      return _$fileChoicePriorityEnum_high;
    case 'maximum':
      return _$fileChoicePriorityEnum_maximum;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<FileChoicePriorityEnum> _$fileChoicePriorityEnumValues =
    BuiltSet<FileChoicePriorityEnum>(const <FileChoicePriorityEnum>[
  _$fileChoicePriorityEnum_normal,
  _$fileChoicePriorityEnum_high,
  _$fileChoicePriorityEnum_maximum,
]);

Serializer<FileChoicePriorityEnum> _$fileChoicePriorityEnumSerializer =
    _$FileChoicePriorityEnumSerializer();

class _$FileChoicePriorityEnumSerializer
    implements PrimitiveSerializer<FileChoicePriorityEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'normal': 'normal',
    'high': 'high',
    'maximum': 'maximum',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'normal': 'normal',
    'high': 'high',
    'maximum': 'maximum',
  };

  @override
  final Iterable<Type> types = const <Type>[FileChoicePriorityEnum];
  @override
  final String wireName = 'FileChoicePriorityEnum';

  @override
  Object serialize(Serializers serializers, FileChoicePriorityEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  FileChoicePriorityEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      FileChoicePriorityEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

class _$FileChoice extends FileChoice {
  @override
  final String fileId;
  @override
  final bool selected;
  @override
  final FileChoicePriorityEnum priority;

  factory _$FileChoice([void Function(FileChoiceBuilder)? updates]) =>
      (FileChoiceBuilder()..update(updates))._build();

  _$FileChoice._(
      {required this.fileId, required this.selected, required this.priority})
      : super._();
  @override
  FileChoice rebuild(void Function(FileChoiceBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  FileChoiceBuilder toBuilder() => FileChoiceBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is FileChoice &&
        fileId == other.fileId &&
        selected == other.selected &&
        priority == other.priority;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, fileId.hashCode);
    _$hash = $jc(_$hash, selected.hashCode);
    _$hash = $jc(_$hash, priority.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'FileChoice')
          ..add('fileId', fileId)
          ..add('selected', selected)
          ..add('priority', priority))
        .toString();
  }
}

class FileChoiceBuilder implements Builder<FileChoice, FileChoiceBuilder> {
  _$FileChoice? _$v;

  String? _fileId;
  String? get fileId => _$this._fileId;
  set fileId(String? fileId) => _$this._fileId = fileId;

  bool? _selected;
  bool? get selected => _$this._selected;
  set selected(bool? selected) => _$this._selected = selected;

  FileChoicePriorityEnum? _priority;
  FileChoicePriorityEnum? get priority => _$this._priority;
  set priority(FileChoicePriorityEnum? priority) => _$this._priority = priority;

  FileChoiceBuilder() {
    FileChoice._defaults(this);
  }

  FileChoiceBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _fileId = $v.fileId;
      _selected = $v.selected;
      _priority = $v.priority;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(FileChoice other) {
    _$v = other as _$FileChoice;
  }

  @override
  void update(void Function(FileChoiceBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  FileChoice build() => _build();

  _$FileChoice _build() {
    final _$result = _$v ??
        _$FileChoice._(
          fileId: BuiltValueNullFieldError.checkNotNull(
              fileId, r'FileChoice', 'fileId'),
          selected: BuiltValueNullFieldError.checkNotNull(
              selected, r'FileChoice', 'selected'),
          priority: BuiltValueNullFieldError.checkNotNull(
              priority, r'FileChoice', 'priority'),
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

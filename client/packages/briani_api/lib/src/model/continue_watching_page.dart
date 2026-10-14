// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_collection/built_collection.dart';
import 'package:briani_api/src/model/continue_watching.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'continue_watching_page.g.dart';

/// ContinueWatchingPage
///
/// Properties:
/// * [items] 
/// * [nextCursor] 
/// * [totalKnown] 
/// * [truncated] 
/// * [warnings] 
@BuiltValue()
abstract class ContinueWatchingPage implements Built<ContinueWatchingPage, ContinueWatchingPageBuilder> {
  @BuiltValueField(wireName: r'items')
  BuiltList<ContinueWatching> get items;

  @BuiltValueField(wireName: r'nextCursor')
  String? get nextCursor;

  @BuiltValueField(wireName: r'totalKnown')
  int? get totalKnown;

  @BuiltValueField(wireName: r'truncated')
  bool get truncated;

  @BuiltValueField(wireName: r'warnings')
  BuiltList<String> get warnings;

  ContinueWatchingPage._();

  factory ContinueWatchingPage([void updates(ContinueWatchingPageBuilder b)]) = _$ContinueWatchingPage;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(ContinueWatchingPageBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<ContinueWatchingPage> get serializer => _$ContinueWatchingPageSerializer();
}

class _$ContinueWatchingPageSerializer implements PrimitiveSerializer<ContinueWatchingPage> {
  @override
  final Iterable<Type> types = const [ContinueWatchingPage, _$ContinueWatchingPage];

  @override
  final String wireName = r'ContinueWatchingPage';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    ContinueWatchingPage object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'items';
    yield serializers.serialize(
      object.items,
      specifiedType: const FullType(BuiltList, [FullType(ContinueWatching)]),
    );
    yield r'nextCursor';
    yield object.nextCursor == null ? null : serializers.serialize(
      object.nextCursor,
      specifiedType: const FullType.nullable(String),
    );
    yield r'totalKnown';
    yield object.totalKnown == null ? null : serializers.serialize(
      object.totalKnown,
      specifiedType: const FullType.nullable(int),
    );
    yield r'truncated';
    yield serializers.serialize(
      object.truncated,
      specifiedType: const FullType(bool),
    );
    yield r'warnings';
    yield serializers.serialize(
      object.warnings,
      specifiedType: const FullType(BuiltList, [FullType(String)]),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    ContinueWatchingPage object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required ContinueWatchingPageBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'items':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(ContinueWatching)]),
          ) as BuiltList<ContinueWatching>;
          result.items.replace(valueDes);
          break;
        case r'nextCursor':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.nextCursor = valueDes;
          break;
        case r'totalKnown':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.totalKnown = valueDes;
          break;
        case r'truncated':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.truncated = valueDes;
          break;
        case r'warnings':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(BuiltList, [FullType(String)]),
          ) as BuiltList<String>;
          result.warnings.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  ContinueWatchingPage deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = ContinueWatchingPageBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}



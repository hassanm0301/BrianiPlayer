// ignore_for_file: unused_import, unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:briani_api/src/model/user_preferences_folder_preferences_inner.dart';
import 'package:built_collection/built_collection.dart';
import 'package:briani_api/src/model/user_preferences_discovery_views_inner.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'user_preferences.g.dart';

/// UserPreferences
///
/// Properties:
/// * [version] 
/// * [theme] 
/// * [density] 
/// * [libraryLayout] 
/// * [showFilenameExtensions] 
/// * [showContinueWatching] 
/// * [rememberFolderSort] 
/// * [torrentColumns] 
/// * [defaultSort] 
/// * [defaultSortOrder] 
/// * [resumePolicy] 
/// * [defaultPlaybackSpeed] 
/// * [subtitleScale] 
/// * [preferredAudioLanguage] 
/// * [preferredSubtitleLanguage] 
/// * [slideshowSeconds] 
/// * [locale] 
/// * [accentPreset] 
/// * [playbackMode] 
/// * [pinnedLibraryIds] 
/// * [keyboardShortcutPreset] 
/// * [folderPreferences] 
/// * [discoveryViews] - User-synced per-mode discovery filters and sort; search text is not retained.
@BuiltValue()
abstract class UserPreferences implements Built<UserPreferences, UserPreferencesBuilder> {
  @BuiltValueField(wireName: r'version')
  int get version;

  @BuiltValueField(wireName: r'theme')
  UserPreferencesThemeEnum? get theme;
  // enum themeEnum {  system,  light,  dark,  };

  @BuiltValueField(wireName: r'density')
  UserPreferencesDensityEnum? get density;
  // enum densityEnum {  comfortable,  compact,  };

  @BuiltValueField(wireName: r'libraryLayout')
  UserPreferencesLibraryLayoutEnum? get libraryLayout;
  // enum libraryLayoutEnum {  grid,  list,  };

  @BuiltValueField(wireName: r'showFilenameExtensions')
  bool? get showFilenameExtensions;

  @BuiltValueField(wireName: r'showContinueWatching')
  bool? get showContinueWatching;

  @BuiltValueField(wireName: r'rememberFolderSort')
  bool? get rememberFolderSort;

  @BuiltValueField(wireName: r'torrentColumns')
  BuiltList<UserPreferencesTorrentColumnsEnum>? get torrentColumns;
  // enum torrentColumnsEnum {  title,  size,  seeders,  leechers,  peers,  provider,  publishedAt,  };

  @BuiltValueField(wireName: r'defaultSort')
  UserPreferencesDefaultSortEnum? get defaultSort;
  // enum defaultSortEnum {  name,  date,  size,  };

  @BuiltValueField(wireName: r'defaultSortOrder')
  UserPreferencesDefaultSortOrderEnum? get defaultSortOrder;
  // enum defaultSortOrderEnum {  asc,  desc,  };

  @BuiltValueField(wireName: r'resumePolicy')
  UserPreferencesResumePolicyEnum? get resumePolicy;
  // enum resumePolicyEnum {  ask,  always,  never,  };

  @BuiltValueField(wireName: r'defaultPlaybackSpeed')
  double? get defaultPlaybackSpeed;

  @BuiltValueField(wireName: r'subtitleScale')
  double? get subtitleScale;

  @BuiltValueField(wireName: r'preferredAudioLanguage')
  String? get preferredAudioLanguage;

  @BuiltValueField(wireName: r'preferredSubtitleLanguage')
  String? get preferredSubtitleLanguage;

  @BuiltValueField(wireName: r'slideshowSeconds')
  int? get slideshowSeconds;

  @BuiltValueField(wireName: r'locale')
  String? get locale;

  @BuiltValueField(wireName: r'accentPreset')
  UserPreferencesAccentPresetEnum? get accentPreset;
  // enum accentPresetEnum {  blue,  teal,  green,  purple,  orange,  red,  };

  @BuiltValueField(wireName: r'playbackMode')
  UserPreferencesPlaybackModeEnum? get playbackMode;
  // enum playbackModeEnum {  internal,  ask,  external,  };

  @BuiltValueField(wireName: r'pinnedLibraryIds')
  BuiltList<String>? get pinnedLibraryIds;

  @BuiltValueField(wireName: r'keyboardShortcutPreset')
  UserPreferencesKeyboardShortcutPresetEnum? get keyboardShortcutPreset;
  // enum keyboardShortcutPresetEnum {  standard,  minimal,  };

  @BuiltValueField(wireName: r'folderPreferences')
  BuiltList<UserPreferencesFolderPreferencesInner>? get folderPreferences;

  /// User-synced per-mode discovery filters and sort; search text is not retained.
  @BuiltValueField(wireName: r'discoveryViews')
  BuiltList<UserPreferencesDiscoveryViewsInner>? get discoveryViews;

  UserPreferences._();

  factory UserPreferences([void updates(UserPreferencesBuilder b)]) = _$UserPreferences;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(UserPreferencesBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<UserPreferences> get serializer => _$UserPreferencesSerializer();
}

class _$UserPreferencesSerializer implements PrimitiveSerializer<UserPreferences> {
  @override
  final Iterable<Type> types = const [UserPreferences, _$UserPreferences];

  @override
  final String wireName = r'UserPreferences';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    UserPreferences object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'version';
    yield serializers.serialize(
      object.version,
      specifiedType: const FullType(int),
    );
    if (object.theme != null) {
      yield r'theme';
      yield serializers.serialize(
        object.theme,
        specifiedType: const FullType(UserPreferencesThemeEnum),
      );
    }
    if (object.density != null) {
      yield r'density';
      yield serializers.serialize(
        object.density,
        specifiedType: const FullType(UserPreferencesDensityEnum),
      );
    }
    if (object.libraryLayout != null) {
      yield r'libraryLayout';
      yield serializers.serialize(
        object.libraryLayout,
        specifiedType: const FullType(UserPreferencesLibraryLayoutEnum),
      );
    }
    if (object.showFilenameExtensions != null) {
      yield r'showFilenameExtensions';
      yield serializers.serialize(
        object.showFilenameExtensions,
        specifiedType: const FullType(bool),
      );
    }
    if (object.showContinueWatching != null) {
      yield r'showContinueWatching';
      yield serializers.serialize(
        object.showContinueWatching,
        specifiedType: const FullType(bool),
      );
    }
    if (object.rememberFolderSort != null) {
      yield r'rememberFolderSort';
      yield serializers.serialize(
        object.rememberFolderSort,
        specifiedType: const FullType(bool),
      );
    }
    if (object.torrentColumns != null) {
      yield r'torrentColumns';
      yield serializers.serialize(
        object.torrentColumns,
        specifiedType: const FullType(BuiltList, [FullType(UserPreferencesTorrentColumnsEnum)]),
      );
    }
    if (object.defaultSort != null) {
      yield r'defaultSort';
      yield serializers.serialize(
        object.defaultSort,
        specifiedType: const FullType(UserPreferencesDefaultSortEnum),
      );
    }
    if (object.defaultSortOrder != null) {
      yield r'defaultSortOrder';
      yield serializers.serialize(
        object.defaultSortOrder,
        specifiedType: const FullType(UserPreferencesDefaultSortOrderEnum),
      );
    }
    if (object.resumePolicy != null) {
      yield r'resumePolicy';
      yield serializers.serialize(
        object.resumePolicy,
        specifiedType: const FullType(UserPreferencesResumePolicyEnum),
      );
    }
    if (object.defaultPlaybackSpeed != null) {
      yield r'defaultPlaybackSpeed';
      yield serializers.serialize(
        object.defaultPlaybackSpeed,
        specifiedType: const FullType(double),
      );
    }
    if (object.subtitleScale != null) {
      yield r'subtitleScale';
      yield serializers.serialize(
        object.subtitleScale,
        specifiedType: const FullType(double),
      );
    }
    if (object.preferredAudioLanguage != null) {
      yield r'preferredAudioLanguage';
      yield serializers.serialize(
        object.preferredAudioLanguage,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.preferredSubtitleLanguage != null) {
      yield r'preferredSubtitleLanguage';
      yield serializers.serialize(
        object.preferredSubtitleLanguage,
        specifiedType: const FullType.nullable(String),
      );
    }
    if (object.slideshowSeconds != null) {
      yield r'slideshowSeconds';
      yield serializers.serialize(
        object.slideshowSeconds,
        specifiedType: const FullType(int),
      );
    }
    if (object.locale != null) {
      yield r'locale';
      yield serializers.serialize(
        object.locale,
        specifiedType: const FullType(String),
      );
    }
    if (object.accentPreset != null) {
      yield r'accentPreset';
      yield serializers.serialize(
        object.accentPreset,
        specifiedType: const FullType(UserPreferencesAccentPresetEnum),
      );
    }
    if (object.playbackMode != null) {
      yield r'playbackMode';
      yield serializers.serialize(
        object.playbackMode,
        specifiedType: const FullType(UserPreferencesPlaybackModeEnum),
      );
    }
    if (object.pinnedLibraryIds != null) {
      yield r'pinnedLibraryIds';
      yield serializers.serialize(
        object.pinnedLibraryIds,
        specifiedType: const FullType(BuiltList, [FullType(String)]),
      );
    }
    if (object.keyboardShortcutPreset != null) {
      yield r'keyboardShortcutPreset';
      yield serializers.serialize(
        object.keyboardShortcutPreset,
        specifiedType: const FullType(UserPreferencesKeyboardShortcutPresetEnum),
      );
    }
    if (object.folderPreferences != null) {
      yield r'folderPreferences';
      yield serializers.serialize(
        object.folderPreferences,
        specifiedType: const FullType(BuiltList, [FullType(UserPreferencesFolderPreferencesInner)]),
      );
    }
    if (object.discoveryViews != null) {
      yield r'discoveryViews';
      yield serializers.serialize(
        object.discoveryViews,
        specifiedType: const FullType(BuiltList, [FullType(UserPreferencesDiscoveryViewsInner)]),
      );
    }
  }

  @override
  Object serialize(
    Serializers serializers,
    UserPreferences object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required UserPreferencesBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'version':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(int),
          ) as int;
          result.version = valueDes;
          break;
        case r'theme':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(UserPreferencesThemeEnum),
          ) as UserPreferencesThemeEnum?;
          if (valueDes == null) continue;
          result.theme = valueDes;
          break;
        case r'density':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(UserPreferencesDensityEnum),
          ) as UserPreferencesDensityEnum?;
          if (valueDes == null) continue;
          result.density = valueDes;
          break;
        case r'libraryLayout':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(UserPreferencesLibraryLayoutEnum),
          ) as UserPreferencesLibraryLayoutEnum?;
          if (valueDes == null) continue;
          result.libraryLayout = valueDes;
          break;
        case r'showFilenameExtensions':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.showFilenameExtensions = valueDes;
          break;
        case r'showContinueWatching':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.showContinueWatching = valueDes;
          break;
        case r'rememberFolderSort':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(bool),
          ) as bool?;
          if (valueDes == null) continue;
          result.rememberFolderSort = valueDes;
          break;
        case r'torrentColumns':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(UserPreferencesTorrentColumnsEnum)]),
          ) as BuiltList<UserPreferencesTorrentColumnsEnum>?;
          if (valueDes == null) continue;
          result.torrentColumns.replace(valueDes);
          break;
        case r'defaultSort':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(UserPreferencesDefaultSortEnum),
          ) as UserPreferencesDefaultSortEnum?;
          if (valueDes == null) continue;
          result.defaultSort = valueDes;
          break;
        case r'defaultSortOrder':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(UserPreferencesDefaultSortOrderEnum),
          ) as UserPreferencesDefaultSortOrderEnum?;
          if (valueDes == null) continue;
          result.defaultSortOrder = valueDes;
          break;
        case r'resumePolicy':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(UserPreferencesResumePolicyEnum),
          ) as UserPreferencesResumePolicyEnum?;
          if (valueDes == null) continue;
          result.resumePolicy = valueDes;
          break;
        case r'defaultPlaybackSpeed':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(double),
          ) as double?;
          if (valueDes == null) continue;
          result.defaultPlaybackSpeed = valueDes;
          break;
        case r'subtitleScale':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(double),
          ) as double?;
          if (valueDes == null) continue;
          result.subtitleScale = valueDes;
          break;
        case r'preferredAudioLanguage':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.preferredAudioLanguage = valueDes;
          break;
        case r'preferredSubtitleLanguage':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.preferredSubtitleLanguage = valueDes;
          break;
        case r'slideshowSeconds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(int),
          ) as int?;
          if (valueDes == null) continue;
          result.slideshowSeconds = valueDes;
          break;
        case r'locale':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(String),
          ) as String?;
          if (valueDes == null) continue;
          result.locale = valueDes;
          break;
        case r'accentPreset':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(UserPreferencesAccentPresetEnum),
          ) as UserPreferencesAccentPresetEnum?;
          if (valueDes == null) continue;
          result.accentPreset = valueDes;
          break;
        case r'playbackMode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(UserPreferencesPlaybackModeEnum),
          ) as UserPreferencesPlaybackModeEnum?;
          if (valueDes == null) continue;
          result.playbackMode = valueDes;
          break;
        case r'pinnedLibraryIds':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(String)]),
          ) as BuiltList<String>?;
          if (valueDes == null) continue;
          result.pinnedLibraryIds.replace(valueDes);
          break;
        case r'keyboardShortcutPreset':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(UserPreferencesKeyboardShortcutPresetEnum),
          ) as UserPreferencesKeyboardShortcutPresetEnum?;
          if (valueDes == null) continue;
          result.keyboardShortcutPreset = valueDes;
          break;
        case r'folderPreferences':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(UserPreferencesFolderPreferencesInner)]),
          ) as BuiltList<UserPreferencesFolderPreferencesInner>?;
          if (valueDes == null) continue;
          result.folderPreferences.replace(valueDes);
          break;
        case r'discoveryViews':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType.nullable(BuiltList, [FullType(UserPreferencesDiscoveryViewsInner)]),
          ) as BuiltList<UserPreferencesDiscoveryViewsInner>?;
          if (valueDes == null) continue;
          result.discoveryViews.replace(valueDes);
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  UserPreferences deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = UserPreferencesBuilder();
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


class UserPreferencesThemeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'system')
  static const UserPreferencesThemeEnum system = _$userPreferencesThemeEnum_system;
  @BuiltValueEnumConst(wireName: r'light')
  static const UserPreferencesThemeEnum light = _$userPreferencesThemeEnum_light;
  @BuiltValueEnumConst(wireName: r'dark')
  static const UserPreferencesThemeEnum dark = _$userPreferencesThemeEnum_dark;

  static Serializer<UserPreferencesThemeEnum> get serializer => _$userPreferencesThemeEnumSerializer;

  const UserPreferencesThemeEnum._(String name): super(name);

  static BuiltSet<UserPreferencesThemeEnum> get values => _$userPreferencesThemeEnumValues;
  static UserPreferencesThemeEnum valueOf(String name) => _$userPreferencesThemeEnumValueOf(name);
}

class UserPreferencesDensityEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'comfortable')
  static const UserPreferencesDensityEnum comfortable = _$userPreferencesDensityEnum_comfortable;
  @BuiltValueEnumConst(wireName: r'compact')
  static const UserPreferencesDensityEnum compact = _$userPreferencesDensityEnum_compact;

  static Serializer<UserPreferencesDensityEnum> get serializer => _$userPreferencesDensityEnumSerializer;

  const UserPreferencesDensityEnum._(String name): super(name);

  static BuiltSet<UserPreferencesDensityEnum> get values => _$userPreferencesDensityEnumValues;
  static UserPreferencesDensityEnum valueOf(String name) => _$userPreferencesDensityEnumValueOf(name);
}

class UserPreferencesLibraryLayoutEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'grid')
  static const UserPreferencesLibraryLayoutEnum grid = _$userPreferencesLibraryLayoutEnum_grid;
  @BuiltValueEnumConst(wireName: r'list')
  static const UserPreferencesLibraryLayoutEnum list = _$userPreferencesLibraryLayoutEnum_list;

  static Serializer<UserPreferencesLibraryLayoutEnum> get serializer => _$userPreferencesLibraryLayoutEnumSerializer;

  const UserPreferencesLibraryLayoutEnum._(String name): super(name);

  static BuiltSet<UserPreferencesLibraryLayoutEnum> get values => _$userPreferencesLibraryLayoutEnumValues;
  static UserPreferencesLibraryLayoutEnum valueOf(String name) => _$userPreferencesLibraryLayoutEnumValueOf(name);
}

class UserPreferencesTorrentColumnsEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'title')
  static const UserPreferencesTorrentColumnsEnum title = _$userPreferencesTorrentColumnsEnum_title;
  @BuiltValueEnumConst(wireName: r'size')
  static const UserPreferencesTorrentColumnsEnum size = _$userPreferencesTorrentColumnsEnum_size;
  @BuiltValueEnumConst(wireName: r'seeders')
  static const UserPreferencesTorrentColumnsEnum seeders = _$userPreferencesTorrentColumnsEnum_seeders;
  @BuiltValueEnumConst(wireName: r'leechers')
  static const UserPreferencesTorrentColumnsEnum leechers = _$userPreferencesTorrentColumnsEnum_leechers;
  @BuiltValueEnumConst(wireName: r'peers')
  static const UserPreferencesTorrentColumnsEnum peers = _$userPreferencesTorrentColumnsEnum_peers;
  @BuiltValueEnumConst(wireName: r'provider')
  static const UserPreferencesTorrentColumnsEnum provider = _$userPreferencesTorrentColumnsEnum_provider;
  @BuiltValueEnumConst(wireName: r'publishedAt')
  static const UserPreferencesTorrentColumnsEnum publishedAt = _$userPreferencesTorrentColumnsEnum_publishedAt;

  static Serializer<UserPreferencesTorrentColumnsEnum> get serializer => _$userPreferencesTorrentColumnsEnumSerializer;

  const UserPreferencesTorrentColumnsEnum._(String name): super(name);

  static BuiltSet<UserPreferencesTorrentColumnsEnum> get values => _$userPreferencesTorrentColumnsEnumValues;
  static UserPreferencesTorrentColumnsEnum valueOf(String name) => _$userPreferencesTorrentColumnsEnumValueOf(name);
}

class UserPreferencesDefaultSortEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'name')
  static const UserPreferencesDefaultSortEnum byName = _$userPreferencesDefaultSortEnum_byName;
  @BuiltValueEnumConst(wireName: r'date')
  static const UserPreferencesDefaultSortEnum date = _$userPreferencesDefaultSortEnum_date;
  @BuiltValueEnumConst(wireName: r'size')
  static const UserPreferencesDefaultSortEnum size = _$userPreferencesDefaultSortEnum_size;

  static Serializer<UserPreferencesDefaultSortEnum> get serializer => _$userPreferencesDefaultSortEnumSerializer;

  const UserPreferencesDefaultSortEnum._(String name): super(name);

  static BuiltSet<UserPreferencesDefaultSortEnum> get values => _$userPreferencesDefaultSortEnumValues;
  static UserPreferencesDefaultSortEnum valueOf(String name) => _$userPreferencesDefaultSortEnumValueOf(name);
}

class UserPreferencesDefaultSortOrderEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'asc')
  static const UserPreferencesDefaultSortOrderEnum asc = _$userPreferencesDefaultSortOrderEnum_asc;
  @BuiltValueEnumConst(wireName: r'desc')
  static const UserPreferencesDefaultSortOrderEnum desc = _$userPreferencesDefaultSortOrderEnum_desc;

  static Serializer<UserPreferencesDefaultSortOrderEnum> get serializer => _$userPreferencesDefaultSortOrderEnumSerializer;

  const UserPreferencesDefaultSortOrderEnum._(String name): super(name);

  static BuiltSet<UserPreferencesDefaultSortOrderEnum> get values => _$userPreferencesDefaultSortOrderEnumValues;
  static UserPreferencesDefaultSortOrderEnum valueOf(String name) => _$userPreferencesDefaultSortOrderEnumValueOf(name);
}

class UserPreferencesResumePolicyEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'ask')
  static const UserPreferencesResumePolicyEnum ask = _$userPreferencesResumePolicyEnum_ask;
  @BuiltValueEnumConst(wireName: r'always')
  static const UserPreferencesResumePolicyEnum always = _$userPreferencesResumePolicyEnum_always;
  @BuiltValueEnumConst(wireName: r'never')
  static const UserPreferencesResumePolicyEnum never = _$userPreferencesResumePolicyEnum_never;

  static Serializer<UserPreferencesResumePolicyEnum> get serializer => _$userPreferencesResumePolicyEnumSerializer;

  const UserPreferencesResumePolicyEnum._(String name): super(name);

  static BuiltSet<UserPreferencesResumePolicyEnum> get values => _$userPreferencesResumePolicyEnumValues;
  static UserPreferencesResumePolicyEnum valueOf(String name) => _$userPreferencesResumePolicyEnumValueOf(name);
}

class UserPreferencesAccentPresetEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'blue')
  static const UserPreferencesAccentPresetEnum blue = _$userPreferencesAccentPresetEnum_blue;
  @BuiltValueEnumConst(wireName: r'teal')
  static const UserPreferencesAccentPresetEnum teal = _$userPreferencesAccentPresetEnum_teal;
  @BuiltValueEnumConst(wireName: r'green')
  static const UserPreferencesAccentPresetEnum green = _$userPreferencesAccentPresetEnum_green;
  @BuiltValueEnumConst(wireName: r'purple')
  static const UserPreferencesAccentPresetEnum purple = _$userPreferencesAccentPresetEnum_purple;
  @BuiltValueEnumConst(wireName: r'orange')
  static const UserPreferencesAccentPresetEnum orange = _$userPreferencesAccentPresetEnum_orange;
  @BuiltValueEnumConst(wireName: r'red')
  static const UserPreferencesAccentPresetEnum red = _$userPreferencesAccentPresetEnum_red;

  static Serializer<UserPreferencesAccentPresetEnum> get serializer => _$userPreferencesAccentPresetEnumSerializer;

  const UserPreferencesAccentPresetEnum._(String name): super(name);

  static BuiltSet<UserPreferencesAccentPresetEnum> get values => _$userPreferencesAccentPresetEnumValues;
  static UserPreferencesAccentPresetEnum valueOf(String name) => _$userPreferencesAccentPresetEnumValueOf(name);
}

class UserPreferencesPlaybackModeEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'internal')
  static const UserPreferencesPlaybackModeEnum internal = _$userPreferencesPlaybackModeEnum_internal;
  @BuiltValueEnumConst(wireName: r'ask')
  static const UserPreferencesPlaybackModeEnum ask = _$userPreferencesPlaybackModeEnum_ask;
  @BuiltValueEnumConst(wireName: r'external')
  static const UserPreferencesPlaybackModeEnum external_ = _$userPreferencesPlaybackModeEnum_external_;

  static Serializer<UserPreferencesPlaybackModeEnum> get serializer => _$userPreferencesPlaybackModeEnumSerializer;

  const UserPreferencesPlaybackModeEnum._(String name): super(name);

  static BuiltSet<UserPreferencesPlaybackModeEnum> get values => _$userPreferencesPlaybackModeEnumValues;
  static UserPreferencesPlaybackModeEnum valueOf(String name) => _$userPreferencesPlaybackModeEnumValueOf(name);
}

class UserPreferencesKeyboardShortcutPresetEnum extends EnumClass {

  @BuiltValueEnumConst(wireName: r'standard')
  static const UserPreferencesKeyboardShortcutPresetEnum standard = _$userPreferencesKeyboardShortcutPresetEnum_standard;
  @BuiltValueEnumConst(wireName: r'minimal')
  static const UserPreferencesKeyboardShortcutPresetEnum minimal = _$userPreferencesKeyboardShortcutPresetEnum_minimal;

  static Serializer<UserPreferencesKeyboardShortcutPresetEnum> get serializer => _$userPreferencesKeyboardShortcutPresetEnumSerializer;

  const UserPreferencesKeyboardShortcutPresetEnum._(String name): super(name);

  static BuiltSet<UserPreferencesKeyboardShortcutPresetEnum> get values => _$userPreferencesKeyboardShortcutPresetEnumValues;
  static UserPreferencesKeyboardShortcutPresetEnum valueOf(String name) => _$userPreferencesKeyboardShortcutPresetEnumValueOf(name);
}


// ignore_for_file: unused_field, unused_element_parameter
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_import

import 'package:one_of_serializer/any_of_serializer.dart';
import 'package:one_of_serializer/one_of_serializer.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:built_value/serializer.dart';
import 'package:built_value/standard_json_plugin.dart';
import 'package:built_value/iso_8601_date_time_serializer.dart';
import 'package:briani_api/src/date_serializer.dart';
import 'package:briani_api/src/model/date.dart';

import 'package:briani_api/src/model/admin_settings.dart';
import 'package:briani_api/src/model/audit_entry.dart';
import 'package:briani_api/src/model/audit_page.dart';
import 'package:briani_api/src/model/auth_session.dart';
import 'package:briani_api/src/model/auth_tokens.dart';
import 'package:briani_api/src/model/bootstrap_request.dart';
import 'package:briani_api/src/model/continue_watching.dart';
import 'package:briani_api/src/model/continue_watching_page.dart';
import 'package:briani_api/src/model/create_user.dart';
import 'package:briani_api/src/model/device_code.dart';
import 'package:briani_api/src/model/device_code_approve.dart';
import 'package:briani_api/src/model/device_code_poll.dart';
import 'package:briani_api/src/model/device_code_preview.dart';
import 'package:briani_api/src/model/device_code_request.dart';
import 'package:briani_api/src/model/device_pending.dart';
import 'package:briani_api/src/model/discovery_query.dart';
import 'package:briani_api/src/model/discovery_result.dart';
import 'package:briani_api/src/model/discovery_snapshot.dart';
import 'package:briani_api/src/model/download.dart';
import 'package:briani_api/src/model/download_action.dart';
import 'package:briani_api/src/model/download_create.dart';
import 'package:briani_api/src/model/download_diagnostics.dart';
import 'package:briani_api/src/model/download_file.dart';
import 'package:briani_api/src/model/download_page.dart';
import 'package:briani_api/src/model/download_selection.dart';
import 'package:briani_api/src/model/download_settings.dart';
import 'package:briani_api/src/model/download_source.dart';
import 'package:briani_api/src/model/download_source_one_of.dart';
import 'package:briani_api/src/model/download_source_one_of1.dart';
import 'package:briani_api/src/model/download_source_one_of2.dart';
import 'package:briani_api/src/model/entry.dart';
import 'package:briani_api/src/model/entry_page.dart';
import 'package:briani_api/src/model/event.dart';
import 'package:briani_api/src/model/file_choice.dart';
import 'package:briani_api/src/model/get_library_grants200_response.dart';
import 'package:briani_api/src/model/grant_update.dart';
import 'package:briani_api/src/model/integration.dart';
import 'package:briani_api/src/model/integration_update.dart';
import 'package:briani_api/src/model/job.dart';
import 'package:briani_api/src/model/library_capabilities.dart';
import 'package:briani_api/src/model/library_create.dart';
import 'package:briani_api/src/model/library_grant.dart';
import 'package:briani_api/src/model/library_patch.dart';
import 'package:briani_api/src/model/liveness200_response.dart';
import 'package:briani_api/src/model/login_request.dart';
import 'package:briani_api/src/model/maintenance_request.dart';
import 'package:briani_api/src/model/media.dart';
import 'package:briani_api/src/model/media_page.dart';
import 'package:briani_api/src/model/media_track.dart';
import 'package:briani_api/src/model/model_library.dart';
import 'package:briani_api/src/model/move_request.dart';
import 'package:briani_api/src/model/operation.dart';
import 'package:briani_api/src/model/password_change.dart';
import 'package:briani_api/src/model/password_reset.dart';
import 'package:briani_api/src/model/patch_user.dart';
import 'package:briani_api/src/model/playback_create.dart';
import 'package:briani_api/src/model/playback_progress.dart';
import 'package:briani_api/src/model/playback_session.dart';
import 'package:briani_api/src/model/playback_sidecar.dart';
import 'package:briani_api/src/model/playback_target.dart';
import 'package:briani_api/src/model/problem.dart';
import 'package:briani_api/src/model/progress_update.dart';
import 'package:briani_api/src/model/provider.dart';
import 'package:briani_api/src/model/refresh_request.dart';
import 'package:briani_api/src/model/rename_request.dart';
import 'package:briani_api/src/model/server_info.dart';
import 'package:briani_api/src/model/service_health.dart';
import 'package:briani_api/src/model/storage_directory.dart';
import 'package:briani_api/src/model/storage_root.dart';
import 'package:briani_api/src/model/torrent_upload.dart';
import 'package:briani_api/src/model/tracker_summary.dart';
import 'package:briani_api/src/model/user.dart';
import 'package:briani_api/src/model/user_preferences.dart';
import 'package:briani_api/src/model/user_preferences_discovery_views_inner.dart';
import 'package:briani_api/src/model/user_preferences_folder_preferences_inner.dart';
import 'package:briani_api/src/model/version_request.dart';

part 'serializers.g.dart';

@SerializersFor([
  AdminSettings,
  AuditEntry,
  AuditPage,
  AuthSession,
  AuthTokens,
  BootstrapRequest,
  ContinueWatching,
  ContinueWatchingPage,
  CreateUser,
  DeviceCode,
  DeviceCodeApprove,
  DeviceCodePoll,
  DeviceCodePreview,
  DeviceCodeRequest,
  DevicePending,
  DiscoveryQuery,
  DiscoveryResult,
  DiscoverySnapshot,
  Download,
  DownloadAction,
  DownloadCreate,
  DownloadDiagnostics,
  DownloadFile,
  DownloadPage,
  DownloadSelection,
  DownloadSettings,
  DownloadSource,
  DownloadSourceOneOf,
  DownloadSourceOneOf1,
  DownloadSourceOneOf2,
  Entry,
  EntryPage,
  Event,
  FileChoice,
  GetLibraryGrants200Response,
  GrantUpdate,
  Integration,
  IntegrationUpdate,
  Job,
  LibraryCapabilities,
  LibraryCreate,
  LibraryGrant,
  LibraryPatch,
  Liveness200Response,
  LoginRequest,
  MaintenanceRequest,
  Media,
  MediaPage,
  MediaTrack,
  ModelLibrary,
  MoveRequest,
  Operation,
  PasswordChange,
  PasswordReset,
  PatchUser,
  PlaybackCreate,
  PlaybackProgress,
  PlaybackSession,
  PlaybackSidecar,
  PlaybackTarget,
  Problem,
  ProgressUpdate,
  Provider,
  RefreshRequest,
  RenameRequest,
  ServerInfo,
  ServiceHealth,
  StorageDirectory,
  StorageRoot,
  TorrentUpload,
  TrackerSummary,
  User,
  UserPreferences,
  UserPreferencesDiscoveryViewsInner,
  UserPreferencesFolderPreferencesInner,
  VersionRequest,
])
Serializers serializers = (_$serializers.toBuilder()
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(DownloadFile)]),
        () => ListBuilder<DownloadFile>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(PlaybackSidecar)]),
        () => ListBuilder<PlaybackSidecar>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(FileChoice)]),
        () => ListBuilder<FileChoice>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Provider)]),
        () => ListBuilder<Provider>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(MediaTrack)]),
        () => ListBuilder<MediaTrack>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(TrackerSummary)]),
        () => ListBuilder<TrackerSummary>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(LibraryGrant)]),
        () => ListBuilder<LibraryGrant>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Entry)]),
        () => ListBuilder<Entry>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Integration)]),
        () => ListBuilder<Integration>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(UserPreferencesDiscoveryViewsInner)]),
        () => ListBuilder<UserPreferencesDiscoveryViewsInner>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(User)]),
        () => ListBuilder<User>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(AuthSession)]),
        () => ListBuilder<AuthSession>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(StorageRoot)]),
        () => ListBuilder<StorageRoot>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(UserPreferencesFolderPreferencesInner)]),
        () => ListBuilder<UserPreferencesFolderPreferencesInner>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltMap, [FullType(String), FullType(BuiltList, [FullType(String)])]),
        () => MapBuilder<String, BuiltList<String>>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(AuditEntry)]),
        () => ListBuilder<AuditEntry>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(ModelLibrary)]),
        () => ListBuilder<ModelLibrary>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(ContinueWatching)]),
        () => ListBuilder<ContinueWatching>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Download)]),
        () => ListBuilder<Download>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(Media)]),
        () => ListBuilder<Media>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(int)]),
        () => ListBuilder<int>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltMap, [FullType(String), FullType.nullable(JsonObject)]),
        () => MapBuilder<String, JsonObject?>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(String)]),
        () => ListBuilder<String>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(StorageDirectory)]),
        () => ListBuilder<StorageDirectory>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(DiscoveryResult)]),
        () => ListBuilder<DiscoveryResult>(),
      )
      ..addBuilderFactory(
        const FullType(BuiltList, [FullType(ServiceHealth)]),
        () => ListBuilder<ServiceHealth>(),
      )
      ..add(const OneOfSerializer())
      ..add(const AnyOfSerializer())
      ..add(const DateSerializer())
      ..add(Iso8601DateTimeSerializer())
    ).build();

Serializers standardSerializers =
    (serializers.toBuilder()..addPlugin(StandardJsonPlugin())).build();

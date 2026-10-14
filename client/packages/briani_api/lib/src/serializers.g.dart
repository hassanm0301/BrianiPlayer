// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serializers.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializers _$serializers = (Serializers().toBuilder()
      ..add(AdminSettings.serializer)
      ..add(AuditEntry.serializer)
      ..add(AuditPage.serializer)
      ..add(AuthSession.serializer)
      ..add(AuthTokens.serializer)
      ..add(BootstrapRequest.serializer)
      ..add(ContinueWatching.serializer)
      ..add(ContinueWatchingPage.serializer)
      ..add(CreateUser.serializer)
      ..add(CreateUserRoleEnum.serializer)
      ..add(DeviceCode.serializer)
      ..add(DeviceCodeApprove.serializer)
      ..add(DeviceCodePoll.serializer)
      ..add(DeviceCodePreview.serializer)
      ..add(DeviceCodeRequest.serializer)
      ..add(DevicePending.serializer)
      ..add(DevicePendingStateEnum.serializer)
      ..add(DiscoveryQuery.serializer)
      ..add(DiscoveryQueryModeEnum.serializer)
      ..add(DiscoveryQueryOrderEnum.serializer)
      ..add(DiscoveryQuerySortEnum.serializer)
      ..add(DiscoveryResult.serializer)
      ..add(DiscoverySnapshot.serializer)
      ..add(DiscoverySnapshotStateEnum.serializer)
      ..add(Download.serializer)
      ..add(DownloadAction.serializer)
      ..add(DownloadActionActionEnum.serializer)
      ..add(DownloadCreate.serializer)
      ..add(DownloadDiagnostics.serializer)
      ..add(DownloadFile.serializer)
      ..add(DownloadFileKindEnum.serializer)
      ..add(DownloadFilePlaybackStateEnum.serializer)
      ..add(DownloadFilePriorityEnum.serializer)
      ..add(DownloadImportStateEnum.serializer)
      ..add(DownloadPage.serializer)
      ..add(DownloadSelection.serializer)
      ..add(DownloadSettings.serializer)
      ..add(DownloadSource.serializer)
      ..add(DownloadSourceOneOf.serializer)
      ..add(DownloadSourceOneOf1.serializer)
      ..add(DownloadSourceOneOf1KindEnum.serializer)
      ..add(DownloadSourceOneOf2.serializer)
      ..add(DownloadSourceOneOf2KindEnum.serializer)
      ..add(DownloadSourceOneOfKindEnum.serializer)
      ..add(DownloadSourceStateEnum.serializer)
      ..add(DownloadStateEnum.serializer)
      ..add(DownloadTransferStateEnum.serializer)
      ..add(Entry.serializer)
      ..add(EntryKindEnum.serializer)
      ..add(EntryPage.serializer)
      ..add(Event.serializer)
      ..add(EventTypeEnum.serializer)
      ..add(FileChoice.serializer)
      ..add(FileChoicePriorityEnum.serializer)
      ..add(GetLibraryGrants200Response.serializer)
      ..add(GrantUpdate.serializer)
      ..add(Integration.serializer)
      ..add(IntegrationKindEnum.serializer)
      ..add(IntegrationUpdate.serializer)
      ..add(Job.serializer)
      ..add(JobStateEnum.serializer)
      ..add(LibraryCapabilities.serializer)
      ..add(LibraryCreate.serializer)
      ..add(LibraryGrant.serializer)
      ..add(LibraryPatch.serializer)
      ..add(Liveness200Response.serializer)
      ..add(Liveness200ResponseStatusEnum.serializer)
      ..add(LoginRequest.serializer)
      ..add(MaintenanceRequest.serializer)
      ..add(MaintenanceRequestActionEnum.serializer)
      ..add(Media.serializer)
      ..add(MediaKindEnum.serializer)
      ..add(MediaPage.serializer)
      ..add(MediaProbeStateEnum.serializer)
      ..add(MediaTrack.serializer)
      ..add(MediaTrackKindEnum.serializer)
      ..add(ModelLibrary.serializer)
      ..add(MoveRequest.serializer)
      ..add(Operation.serializer)
      ..add(OperationStateEnum.serializer)
      ..add(PasswordChange.serializer)
      ..add(PasswordReset.serializer)
      ..add(PatchUser.serializer)
      ..add(PatchUserRoleEnum.serializer)
      ..add(PlaybackCreate.serializer)
      ..add(PlaybackCreateModeEnum.serializer)
      ..add(PlaybackProgress.serializer)
      ..add(PlaybackSession.serializer)
      ..add(PlaybackSessionStateEnum.serializer)
      ..add(PlaybackSidecar.serializer)
      ..add(PlaybackTarget.serializer)
      ..add(PlaybackTargetKindEnum.serializer)
      ..add(Problem.serializer)
      ..add(ProgressUpdate.serializer)
      ..add(Provider.serializer)
      ..add(ProviderStateEnum.serializer)
      ..add(RefreshRequest.serializer)
      ..add(RenameRequest.serializer)
      ..add(ServerInfo.serializer)
      ..add(ServiceHealth.serializer)
      ..add(ServiceHealthStateEnum.serializer)
      ..add(StorageDirectory.serializer)
      ..add(StorageRoot.serializer)
      ..add(TorrentUpload.serializer)
      ..add(TrackerSummary.serializer)
      ..add(User.serializer)
      ..add(UserPreferences.serializer)
      ..add(UserPreferencesAccentPresetEnum.serializer)
      ..add(UserPreferencesDefaultSortEnum.serializer)
      ..add(UserPreferencesDefaultSortOrderEnum.serializer)
      ..add(UserPreferencesDensityEnum.serializer)
      ..add(UserPreferencesDiscoveryViewsInner.serializer)
      ..add(UserPreferencesDiscoveryViewsInnerModeEnum.serializer)
      ..add(UserPreferencesDiscoveryViewsInnerOrderEnum.serializer)
      ..add(UserPreferencesDiscoveryViewsInnerSortEnum.serializer)
      ..add(UserPreferencesFolderPreferencesInner.serializer)
      ..add(UserPreferencesFolderPreferencesInnerLayoutEnum.serializer)
      ..add(UserPreferencesFolderPreferencesInnerOrderEnum.serializer)
      ..add(UserPreferencesFolderPreferencesInnerSortEnum.serializer)
      ..add(UserPreferencesKeyboardShortcutPresetEnum.serializer)
      ..add(UserPreferencesLibraryLayoutEnum.serializer)
      ..add(UserPreferencesPlaybackModeEnum.serializer)
      ..add(UserPreferencesResumePolicyEnum.serializer)
      ..add(UserPreferencesThemeEnum.serializer)
      ..add(UserPreferencesTorrentColumnsEnum.serializer)
      ..add(UserRoleEnum.serializer)
      ..add(VersionRequest.serializer)
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(AuditEntry)]),
          () => ListBuilder<AuditEntry>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(ContinueWatching)]),
          () => ListBuilder<ContinueWatching>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(DiscoveryResult)]),
          () => ListBuilder<DiscoveryResult>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(Download)]),
          () => ListBuilder<Download>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(Entry)]),
          () => ListBuilder<Entry>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(FileChoice)]),
          () => ListBuilder<FileChoice>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(LibraryGrant)]),
          () => ListBuilder<LibraryGrant>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(LibraryGrant)]),
          () => ListBuilder<LibraryGrant>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(Media)]),
          () => ListBuilder<Media>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(MediaTrack)]),
          () => ListBuilder<MediaTrack>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(PlaybackSidecar)]),
          () => ListBuilder<PlaybackSidecar>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(int)]),
          () => ListBuilder<int>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(int)]),
          () => ListBuilder<int>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(int)]),
          () => ListBuilder<int>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(TrackerSummary)]),
          () => ListBuilder<TrackerSummary>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList,
              const [const FullType(UserPreferencesTorrentColumnsEnum)]),
          () => ListBuilder<UserPreferencesTorrentColumnsEnum>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(String)]),
          () => ListBuilder<String>())
      ..addBuilderFactory(
          const FullType(BuiltList,
              const [const FullType(UserPreferencesFolderPreferencesInner)]),
          () => ListBuilder<UserPreferencesFolderPreferencesInner>())
      ..addBuilderFactory(
          const FullType(BuiltList,
              const [const FullType(UserPreferencesDiscoveryViewsInner)]),
          () => ListBuilder<UserPreferencesDiscoveryViewsInner>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(int)]),
          () => ListBuilder<int>())
      ..addBuilderFactory(
          const FullType(BuiltList, const [const FullType(int)]),
          () => ListBuilder<int>())
      ..addBuilderFactory(
          const FullType(BuiltMap, const [
            const FullType(String),
            const FullType(BuiltList, const [const FullType(String)])
          ]),
          () => MapBuilder<String, BuiltList<String>>())
      ..addBuilderFactory(
          const FullType(BuiltMap, const [
            const FullType(String),
            const FullType.nullable(JsonObject)
          ]),
          () => MapBuilder<String, JsonObject?>()))
    .build();

// ignore_for_file: deprecated_member_use_from_same_package,type=lint

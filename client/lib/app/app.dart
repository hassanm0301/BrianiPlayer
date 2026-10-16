import 'dart:io';

import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:briani_api/briani_api.dart' hide Provider;

import '../core/preferences/preferences_providers.dart';
import '../core/server_profiles/providers.dart';
import '../features/settings/settings_screen.dart';
import '../features/administration/administration_screen.dart';
import '../features/session/account_screen.dart';
import '../core/session/client_session.dart';
import '../core/input/remote_navigation.dart';
import '../core/input/preference_text_scaler.dart';
import '../core/input/shell_navigation_page.dart';
import '../core/platform/platform_capabilities.dart';
import '../features/server_profiles/server_profiles_screen.dart';
import '../features/session/sign_in_screen.dart';
import '../features/session/device_pairing.dart';
import 'shell.dart';
import 'theme.dart';
import '../features/libraries/libraries_screen.dart';
import '../features/libraries/folder_screen.dart';
import '../features/photos/photo_viewer_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/playback/player_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final changes = ValueNotifier<int>(0);
  ref.listen(clientSessionProvider, (previous, next) {
    if ((previous == null) != (next == null) ||
        previous?.tokens.user.mustChangePassword !=
            next?.tokens.user.mustChangePassword) {
      changes.value++;
    }
  });
  final router = GoRouter(
    initialLocation: '/servers',
    refreshListenable: changes,
    redirect: (context, state) {
      final session = ref.read(clientSessionProvider);
      final signedIn = session != null;
      if (session?.tokens.user.mustChangePassword == true &&
          state.uri.path != '/account') {
        return '/account';
      }
      final connecting =
          state.uri.path == '/servers' ||
          state.uri.path.startsWith('/signin/') ||
          state.uri.path.startsWith('/link/');
      if (!signedIn && !connecting) return '/servers';
      if (signedIn && connecting) return '/libraries';
      return null;
    },
    routes: [
      GoRoute(
        path: '/servers',
        builder: (context, state) => const ServerProfilesScreen(),
      ),
      GoRoute(
        path: '/signin/:id',
        builder: (context, state) {
          final profiles = ref.read(serverProfileRepositoryProvider).load();
          final profile = profiles
              .where((p) => p.id == state.pathParameters['id'])
              .firstOrNull;
          return profile == null
              ? const ServerProfilesScreen()
              : SignInScreen(profile: profile);
        },
      ),
      GoRoute(
        path: '/link/:id',
        builder: (context, state) {
          final profile = ref
              .read(serverProfileRepositoryProvider)
              .load()
              .where((p) => p.id == state.pathParameters['id'])
              .firstOrNull;
          return profile == null
              ? const ServerProfilesScreen()
              : DeviceLinkScreen(profile: profile);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/libraries',
                pageBuilder: (context, state) =>
                    _shellPage(context, state, const LibrariesScreen()),
              ),
              GoRoute(
                path: '/libraries/:id',
                pageBuilder: (context, state) => _shellPage(
                  context,
                  state,
                  FolderScreen(libraryId: state.pathParameters['id']!),
                ),
              ),
              GoRoute(
                path: '/libraries/:id/folders/:folderId',
                pageBuilder: (context, state) => _shellPage(
                  context,
                  state,
                  FolderScreen(
                    libraryId: state.pathParameters['id']!,
                    folderId: state.pathParameters['folderId']!,
                    folderName: state.extra is String
                        ? state.extra as String
                        : null,
                    breadcrumbs: state.extra is List<FolderBreadcrumb>
                        ? state.extra as List<FolderBreadcrumb>
                        : const [],
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                pageBuilder: (context, state) =>
                    _shellPage(context, state, const DiscoverScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/downloads',
                pageBuilder: (context, state) =>
                    _shellPage(context, state, const DownloadsScreen()),
              ),
              GoRoute(
                path: '/downloads/:id',
                pageBuilder: (context, state) => _shellPage(
                  context,
                  state,
                  DownloadDetailsScreen(requestId: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdministrationScreen(),
      ),
      GoRoute(
        path: '/photos/:id',
        builder: (context, state) => PhotoViewerScreen(
          mediaId: state.pathParameters['id']!,
          adjacentMediaIds: state.extra is List<String>
              ? state.extra as List<String>
              : const [],
        ),
      ),
      GoRoute(
        path: '/play/:kind/:id',
        builder: (context, state) => PlayerScreen(
          kind: state.pathParameters['kind']!,
          targetId: state.pathParameters['id']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/servers'),
          child: const Text('Return to servers'),
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    changes.dispose();
  });
  return router;
});

Page<void> _shellPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => MediaQuery.maybeOf(context)?.navigationMode == NavigationMode.directional
    ? TvShellPage(key: state.pageKey, child: child)
    : MaterialPage<void>(key: state.pageKey, child: child);

class BrianiApp extends ConsumerWidget {
  const BrianiApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(userPreferencesProvider).asData?.value ??
        defaultUserPreferences();
    final device = ref.watch(devicePreferencesProvider);
    ref.listen(devicePreferencesProvider, (previous, next) {
      if (!Platform.isAndroid &&
          (previous?.windowWidth != next.windowWidth ||
              previous?.windowHeight != next.windowHeight)) {
        // Only explicit dimensions change the native window. Missing desktop
        // plugins in widget tests are handled without breaking application UI.
        windowManager
            .setSize(
              Size(next.windowWidth.toDouble(), next.windowHeight.toDouble()),
            )
            .ignore();
      }
    });
    final accent = accentSeed(preferences.accentPreset);
    final density = preferences.density == UserPreferencesDensityEnum.compact
        ? VisualDensity.compact
        : VisualDensity.standard;
    final television =
        ref.watch(deviceCapabilitiesProvider).value?.television == true;
    return MaterialApp.router(
      title: 'Briani Player',
      debugShowCheckedModeBanner: false,
      themeMode: preferences.theme == UserPreferencesThemeEnum.dark
          ? ThemeMode.dark
          : preferences.theme == UserPreferencesThemeEnum.light
          ? ThemeMode.light
          : ThemeMode.system,
      theme: buildAppTheme(
        seed: accent,
        brightness: Brightness.light,
        density: density,
        television: television,
      ),
      darkTheme: buildAppTheme(
        seed: accent,
        brightness: Brightness.dark,
        density: density,
        television: television,
      ),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        return RemoteNavigationScope(
          television: television,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: PreferenceTextScaler(
                MediaQuery.textScalerOf(context),
                device.displayScale,
              ),
              navigationMode: television
                  ? NavigationMode.directional
                  : NavigationMode.traditional,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

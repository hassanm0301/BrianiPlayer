import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../core/input/shell_navigation_page.dart';
import '../core/platform/platform_capabilities.dart';
import '../features/server_profiles/server_profiles_screen.dart';
import '../features/session/sign_in_screen.dart';
import '../features/session/device_pairing.dart';
import '../features/libraries/libraries_screen.dart';
import '../features/libraries/folder_screen.dart';
import '../features/photos/photo_viewer_screen.dart';
import '../features/discover/discover_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/playback/player_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final changes = ValueNotifier<int>(0);
  ref.listen(clientSessionProvider, (previous, next) {
    if ((previous == null) != (next == null) || previous?.tokens.user.mustChangePassword != next?.tokens.user.mustChangePassword) changes.value++;
  });
  final router = GoRouter(
    initialLocation: '/servers',
    refreshListenable: changes,
    redirect: (context, state) {
      final session = ref.read(clientSessionProvider);
      final signedIn = session != null;
      if (session?.tokens.user.mustChangePassword == true && state.uri.path != '/account') return '/account';
      final connecting = state.uri.path == '/servers' || state.uri.path.startsWith('/signin/') || state.uri.path.startsWith('/link/');
      if (!signedIn && !connecting) return '/servers';
      if (signedIn && connecting) return '/libraries';
      return null;
    },
    routes: [
      GoRoute(path: '/servers', builder: (context, state) => const ServerProfilesScreen()),
      GoRoute(path: '/signin/:id', builder: (context, state) {
        final profiles = ref.read(serverProfileRepositoryProvider).load();
        final profile = profiles.where((p) => p.id == state.pathParameters['id']).firstOrNull;
        return profile == null ? const ServerProfilesScreen() : SignInScreen(profile: profile);
      }),
      GoRoute(path: '/link/:id', builder: (context, state) {
        final profile = ref.read(serverProfileRepositoryProvider).load().where((p) => p.id == state.pathParameters['id']).firstOrNull;
        return profile == null ? const ServerProfilesScreen() : DeviceLinkScreen(profile: profile);
      }),
      ShellRoute(builder: (context, state, child) => _NavigationShell(location: state.uri.path, child: child), routes: [
        GoRoute(path: '/libraries', pageBuilder: (context, state) => _shellPage(context, state, const LibrariesScreen())),
        GoRoute(path: '/libraries/:id', pageBuilder: (context, state) => _shellPage(context, state, FolderScreen(libraryId: state.pathParameters['id']!))),
        GoRoute(path: '/libraries/:id/folders/:folderId', pageBuilder: (context, state) => _shellPage(context, state, FolderScreen(
          libraryId: state.pathParameters['id']!, folderId: state.pathParameters['folderId']!,
          folderName: state.extra is String ? state.extra as String : null,
          breadcrumbs: state.extra is List<FolderBreadcrumb> ? state.extra as List<FolderBreadcrumb> : const []))),
        GoRoute(path: '/discover', pageBuilder: (context, state) => _shellPage(context, state, const DiscoverScreen())),
        GoRoute(path: '/downloads', pageBuilder: (context, state) => _shellPage(context, state, const DownloadsScreen())),
        GoRoute(path: '/downloads/:id', pageBuilder: (context, state) => _shellPage(context, state, DownloadDetailsScreen(requestId: state.pathParameters['id']!))),
      ]),
      GoRoute(path: '/account', builder: (context, state) => const AccountScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdministrationScreen()),
      GoRoute(path: '/photos/:id', builder: (context, state) => PhotoViewerScreen(
        mediaId: state.pathParameters['id']!, adjacentMediaIds: state.extra is List<String> ? state.extra as List<String> : const [])),
      GoRoute(path: '/play/:kind/:id', builder: (context, state) => PlayerScreen(
        kind: state.pathParameters['kind']!, targetId: state.pathParameters['id']!)),
    ],
    errorBuilder: (context, state) => Scaffold(appBar: AppBar(title: const Text('Page unavailable')),
      body: Center(child: FilledButton(onPressed: () => context.go('/servers'), child: const Text('Return to servers')))),
  );
  ref.onDispose(() { router.dispose(); changes.dispose(); });
  return router;
});

Page<void> _shellPage(BuildContext context, GoRouterState state, Widget child) =>
    MediaQuery.maybeOf(context)?.navigationMode == NavigationMode.directional
        ? TvShellPage(key: state.pageKey, child: child)
        : MaterialPage<void>(key: state.pageKey, child: child);

class _NavigationShell extends ConsumerWidget {
  const _NavigationShell({required this.location, required this.child});
  final String location;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(clientSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final index = location.startsWith('/discover') ? 1 : location.startsWith('/downloads') ? 2 : 0;
    void navigate(int selected) => context.go(['/libraries', '/discover', '/downloads'][selected]);
    final shortcuts = ref.watch(userPreferencesProvider).asData?.value.keyboardShortcutPreset != UserPreferencesKeyboardShortcutPresetEnum.minimal;
    return CallbackShortcuts(bindings: shortcuts ? {
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => navigate(0),
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => navigate(1),
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => navigate(2),
    } : {}, child: LayoutBuilder(builder: (context, constraints) {
      final television = ref.watch(deviceCapabilitiesProvider).value?.television == true;
      final wide = constraints.maxWidth >= 800;
      if (television) { return TvNavigationScaffold(index: index, onSelected: navigate,
        profile: Text(session.profile.label), account: PopupMenuButton<String>(tooltip: 'Account',
          onSelected: (action) => _accountAction(context, ref, action),
          itemBuilder: (_) => _accountItems(session.administrator)),
        child: Column(children: [
          if (session.sessionOnly) const Padding(padding: EdgeInsets.all(12), child: Text('Session-only login: secure credential storage is unavailable.')),
          Expanded(child: child)])); }
      return Scaffold(
        appBar: AppBar(title: Text(session.profile.label), actions: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Center(child: Text(session.tokens.user.displayName))),
          PopupMenuButton<String>(tooltip: 'Account', onSelected: (action) => _accountAction(context, ref, action), itemBuilder: (_) => _accountItems(session.administrator), icon: const Icon(Icons.account_circle_outlined)),
        ]),
        body: Column(children: [
          if (session.sessionOnly) const MaterialBanner(content: Text('Secure credential storage is unavailable. This login lasts for this app session.'), actions: [SizedBox.shrink()]),
          Expanded(child: Row(children: [
            if (wide) NavigationRail(selectedIndex: index, onDestinationSelected: navigate,
              labelType: NavigationRailLabelType.all, destinations: const [
                NavigationRailDestination(icon: Icon(Icons.folder_outlined), label: Text('Libraries')),
                NavigationRailDestination(icon: Icon(Icons.search), label: Text('Discover')),
                NavigationRailDestination(icon: Icon(Icons.download_outlined), label: Text('Downloads'))]),
            Expanded(child: child),
          ])),
        ]),
        bottomNavigationBar: wide ? null : NavigationBar(selectedIndex: index, onDestinationSelected: navigate,
          destinations: const [NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Libraries'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Discover'),
            NavigationDestination(icon: Icon(Icons.download_outlined), label: 'Downloads')]),
      );
    }));
  }
}

List<PopupMenuEntry<String>> _accountItems(bool administrator) => [
  const PopupMenuItem(value: 'account', child: Text('Account and devices')),
  const PopupMenuItem(value: 'settings', child: Text('Settings')),
  if (administrator) const PopupMenuItem(value: 'admin', child: Text('Administration')),
  const PopupMenuItem(value: 'pair', child: Text('Link a device')),
  const PopupMenuItem(value: 'disconnect', child: Text('Switch server')),
  const PopupMenuItem(value: 'logout', child: Text('Sign out')),
];
Future<void> _accountAction(BuildContext context, WidgetRef ref, String action) async {
  if (const {'account', 'settings', 'admin'}.contains(action)) { context.push('/$action'); }
  else if (action == 'pair') { await ApproveDeviceDialog.show(context); }
  else { await ref.read(clientSessionProvider.notifier).disconnect(logout: action == 'logout'); }
}

class BrianiApp extends ConsumerWidget {
  const BrianiApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(userPreferencesProvider).asData?.value ?? defaultUserPreferences();
    final device = ref.watch(devicePreferencesProvider);
    ref.listen(devicePreferencesProvider, (previous, next) {
      if (!Platform.isAndroid && (previous?.windowWidth != next.windowWidth || previous?.windowHeight != next.windowHeight)) {
        // Only explicit dimensions change the native window. Missing desktop
        // plugins in widget tests are handled without breaking application UI.
        windowManager.setSize(Size(next.windowWidth.toDouble(), next.windowHeight.toDouble())).ignore();
      }
    });
    final accent = switch (preferences.accentPreset) {
      UserPreferencesAccentPresetEnum.teal => const Color(0xff008577),
      UserPreferencesAccentPresetEnum.green => const Color(0xff348348),
      UserPreferencesAccentPresetEnum.orange => const Color(0xffb35a00),
      UserPreferencesAccentPresetEnum.purple => const Color(0xff7954b3),
      UserPreferencesAccentPresetEnum.red => const Color(0xffb33232),
      _ => const Color(0xff476f9c),
    };
    final density = preferences.density == UserPreferencesDensityEnum.compact ? VisualDensity.compact : VisualDensity.standard;
    return MaterialApp.router(
      title: 'Briani Player', debugShowCheckedModeBanner: false,
      themeMode: preferences.theme == UserPreferencesThemeEnum.dark ? ThemeMode.dark : preferences.theme == UserPreferencesThemeEnum.light ? ThemeMode.light : ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: accent, visualDensity: density, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: accent, brightness: Brightness.dark, visualDensity: density, useMaterial3: true),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final television = ref.watch(deviceCapabilitiesProvider).value?.television == true;
        return RemoteNavigationScope(television: television,
          child: MediaQuery(data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(device.displayScale),
            navigationMode: television ? NavigationMode.directional : NavigationMode.traditional),
            child: child ?? const SizedBox.shrink()));
      },
    );
  }
}

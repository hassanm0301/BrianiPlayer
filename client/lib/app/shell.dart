import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/input/remote_navigation.dart';
import '../core/input/route_activity.dart';
import '../core/platform/platform_capabilities.dart';
import '../core/preferences/preferences_providers.dart';
import '../core/session/client_session.dart';
import '../core/widgets/adaptive.dart';
import '../core/widgets/states.dart';
import '../features/session/device_pairing.dart';
import 'theme.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon, selectedIcon;
}

const _destinations = [
  _Destination('Libraries', Icons.video_library_outlined, Icons.video_library),
  _Destination('Discover', Icons.travel_explore_outlined, Icons.travel_explore),
  _Destination('Downloads', Icons.download_outlined, Icons.download),
];

/// The signed-in navigation frame: a sidebar rail with a rounded content
/// panel on medium and larger windows, a bottom navigation bar on phones and
/// compact top tabs on TV.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(clientSessionProvider);
    if (session == null) return const SizedBox.shrink();
    final index = shell.currentIndex;
    void navigate(int selected) => shell.goBranch(selected);
    final shortcuts =
        ref
            .watch(userPreferencesProvider)
            .asData
            ?.value
            .keyboardShortcutPreset !=
        UserPreferencesKeyboardShortcutPresetEnum.minimal;
    final television =
        ref.watch(deviceCapabilitiesProvider).value?.television == true;
    final content = RouteActivity(
      visible: ModalRoute.of(context)?.isCurrent ?? true,
      child: shell,
    );
    final sessionNotice = session.sessionOnly
        ? const NoticeBanner(
            tone: NoticeTone.warning,
            icon: Icons.lock_open_outlined,
            message: 'Secure credential storage is unavailable. This login lasts for this app session.',
            margin: EdgeInsets.fromLTRB(12, 8, 12, 4),
          )
        : null;
    return CallbackShortcuts(
      bindings: shortcuts
          ? {
              const SingleActivator(
                LogicalKeyboardKey.digit1,
                control: true,
              ): () =>
                  navigate(0),
              const SingleActivator(
                LogicalKeyboardKey.digit2,
                control: true,
              ): () =>
                  navigate(1),
              const SingleActivator(
                LogicalKeyboardKey.digit3,
                control: true,
              ): () =>
                  navigate(2),
            }
          : {},
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (television) {
            return TvNavigationScaffold(
              index: index,
              onSelected: navigate,
              profile: Text(session.profile.label),
              account: AccountMenuButton(session: session),
              child: Column(
                children: [
                  ?sessionNotice,
                  Expanded(child: content),
                ],
              ),
            );
          }
          final size = WindowSize.ofWidth(constraints.maxWidth);
          final scheme = Theme.of(context).colorScheme;
          if (size.isCompact) {
            return ShellLayout(
              accountInPageHeader: true,
              accountButton: AccountMenuButton(
                key: ValueKey(session),
                session: session,
              ),
              child: Scaffold(
                body: Column(
                  children: [
                    if (sessionNotice != null)
                      SafeArea(bottom: false, child: sessionNotice),
                    Expanded(child: content),
                  ],
                ),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: navigate,
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: d.label,
                      ),
                  ],
                ),
              ),
            );
          }
          return ShellLayout(
            accountInPageHeader: false,
            accountButton: AccountMenuButton(
              key: ValueKey(session),
              session: session,
            ),
            child: Scaffold(
              backgroundColor: chromeSurfaceOf(scheme),
              body: SafeArea(
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: index,
                      onDestinationSelected: navigate,
                      labelType: NavigationRailLabelType.all,
                      // Short windows (phones in landscape) scroll the
                      // destinations instead of overflowing.
                      scrollable: true,
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 20),
                        child: _AppMark(serverLabel: session.profile.label),
                      ),
                      trailingAtBottom: true,
                      trailing: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Settings',
                              onPressed: () => context.push('/settings'),
                              icon: const Icon(Icons.settings_outlined),
                            ),
                            const SizedBox(height: 8),
                            AccountMenuButton(session: session),
                          ],
                        ),
                      ),
                      destinations: [
                        for (final d in _destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
                            label: Text(d.label),
                            padding: const EdgeInsets.only(bottom: 4),
                          ),
                      ],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: ColoredBox(
                            color: contentSurfaceOf(scheme),
                            child: Column(
                              children: [
                                ?sessionNotice,
                                Expanded(child: content),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark({required this.serverLabel});
  final String serverLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Briani Player · $serverLabel',
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: scheme.onPrimary,
          size: 30,
        ),
      ),
    );
  }
}

/// The signed-in account's avatar. Opens account, settings, administration,
/// device linking, server switching and sign-out actions.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key, required this.session});
  final ClientSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final name = session.tokens.user.displayName.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    PopupMenuItem<String> item(String value, IconData icon, String label) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
        );
    final button = PopupMenuButton<String>(
      tooltip: 'Account · ${session.profile.label}',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 260),
      onSelected: (action) => _accountAction(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _Avatar(initial: initial),
            title: Text(name, style: Theme.of(context).textTheme.titleSmall),
            subtitle: Text(
              '${session.profile.label} · ${session.administrator ? 'Administrator' : 'Member'}',
            ),
          ),
        ),
        const PopupMenuDivider(),
        item('account', Icons.manage_accounts_outlined, 'Account and devices'),
        item('settings', Icons.settings_outlined, 'Settings'),
        if (session.administrator)
          item('admin', Icons.admin_panel_settings_outlined, 'Administration'),
        item('pair', Icons.devices_other_outlined, 'Link a device'),
        const PopupMenuDivider(),
        item('disconnect', Icons.swap_horiz, 'Switch server'),
        item('logout', Icons.logout, 'Sign out'),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: _Avatar(initial: initial),
      ),
    );
    // The avatar is a bare ink surface; the outline makes keyboard and D-pad
    // focus visible by shape, not only by the overlay color.
    return FocusOutline(borderRadius: BorderRadius.circular(24), child: button);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String initial;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 18,
      backgroundColor: scheme.tertiaryContainer,
      foregroundColor: scheme.onTertiaryContainer,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: scheme.onTertiaryContainer),
      ),
    );
  }
}

Future<void> _accountAction(
  BuildContext context,
  WidgetRef ref,
  String action,
) async {
  if (const {'account', 'settings', 'admin'}.contains(action)) {
    context.push('/$action');
  } else if (action == 'pair') {
    await ApproveDeviceDialog.show(context);
  } else {
    await ref
        .read(clientSessionProvider.notifier)
        .disconnect(logout: action == 'logout');
  }
}

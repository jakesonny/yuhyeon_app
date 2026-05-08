import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../alarms/application/alarm_count_provider.dart';
import '../../auth/application/auth_controller.dart';
import '../../sensors/data/sensor_api.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.body,
    this.showBottomNav = true,
  });

  final String title;
  final Widget body;
  final bool showBottomNav;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    // 새 순서: 대시보드(0), 현장(1), 센서(2), 알람(3), 파일(4)
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/sites')) return 1;
    if (location.startsWith('/sensors')) return 2;
    if (location.startsWith('/alarms')) return 3;
    if (location.startsWith('/files')) return 4;
    return 0;
  }

  void _navTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
      case 1:
        context.go('/sites');
      case 2:
        context.go('/sensors');
      case 3:
        context.go('/alarms');
      case 4:
        context.go('/files');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unackedAlarms = ref.watch(unackedAlarmCountProvider);
    final destinations = <NavigationDestination>[
      const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
      const NavigationDestination(
          icon: Icon(Icons.map_outlined), label: '현장'),
      const NavigationDestination(
          icon: Icon(Icons.sensors_outlined), label: '센서'),
      NavigationDestination(
        icon: _AlarmBellIcon(count: unackedAlarms),
        selectedIcon: _AlarmBellIcon(count: unackedAlarms, selected: true),
        label: '알람',
      ),
      const NavigationDestination(
          icon: Icon(Icons.folder_outlined), label: '파일'),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Text(
              '실시간 계측 모니터링',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.3,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.line, height: 1),
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () => _openNavMenu(ctx),
              icon: const Icon(Icons.menu, size: 20),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              tooltip: '메뉴',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: body,
        ),
      ),
      bottomNavigationBar: showBottomNav
          ? NavigationBar(
              backgroundColor: AppColors.surfaceCard,
              indicatorColor: AppColors.brand.withValues(alpha: 0.12),
              selectedIndex: _selectedIndex(context),
              onDestinationSelected: (index) => _navTo(context, index),
              destinations: destinations,
            )
          : null,
    );
  }

  Future<void> _openNavMenu(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (renderBox == null || overlay == null) return;
    final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final size = renderBox.size;
    final top = offset.dy + size.height - 8;
    final right = overlay.size.width - (offset.dx + size.width) + 4;

    // showGeneralDialog는 GoRouter 라우트 외부에서 빌드되므로
    // 현재 위치는 미리 캡처해서 전달한다.
    final currentLocation = GoRouterState.of(context).uri.toString();
    final router = GoRouter.of(context);

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: '메뉴 닫기',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (ctx, anim, secondaryAnim) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return Stack(
          children: [
            Positioned(
              top: top,
              right: right,
              child: FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  alignment: Alignment.topRight,
                  scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
                  child: _NavMenuPanel(
                    currentLocation: currentLocation,
                    router: router,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NavMenuPanel extends ConsumerStatefulWidget {
  const _NavMenuPanel({required this.currentLocation, required this.router});
  final String currentLocation;
  final GoRouter router;

  @override
  ConsumerState<_NavMenuPanel> createState() => _NavMenuPanelState();
}

class _NavMenuPanelState extends ConsumerState<_NavMenuPanel> {
  bool _sitesOpen = false;
  Future<List<SiteListItem>>? _sitesFuture;

  void _toggleSites() {
    setState(() {
      _sitesOpen = !_sitesOpen;
      if (_sitesOpen && _sitesFuture == null) {
        _sitesFuture = ref.read(sensorApiProvider).fetchSites();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final canManage = session.canManage;
    final email = session.email ?? '';
    final username = session.username ?? '';
    final initial = (username.isNotEmpty
            ? username[0]
            : (email.isNotEmpty ? email[0] : '?'))
        .toUpperCase();

    final maxHeight = MediaQuery.of(context).size.height * 0.72;
    final loc = widget.currentLocation;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 248,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _GroupLabel('모니터링'),
                    _NavItem(
                      icon: '◈',
                      label: '대시보드',
                      active: loc.startsWith('/dashboard'),
                      onTap: () => _go(context, '/dashboard'),
                    ),
                    _NavItem(
                      icon: '⊕',
                      label: '센서 관리',
                      active: loc.startsWith('/sensors'),
                      onTap: () => _go(context, '/sensors'),
                    ),
                    _NavItem(
                      icon: '△',
                      label: '알람',
                      active: loc.startsWith('/alarms'),
                      onTap: () => _go(context, '/alarms'),
                    ),
                    _SitesToggle(
                      open: _sitesOpen,
                      active: loc.startsWith('/sites'),
                      onToggle: _toggleSites,
                    ),
                    if (_sitesOpen)
                      _SitesList(
                        future: _sitesFuture,
                        onTap: () => Navigator.of(context).pop(),
                        router: widget.router,
                      ),
                    if (canManage) ...[
                      const SizedBox(height: 4),
                      const _GroupLabel('기타'),
                      _NavItem(
                        icon: '◎',
                        label: '사용자 관리',
                        active: loc.startsWith('/users'),
                        onTap: () => _go(context, '/users'),
                      ),
                      _NavItem(
                        icon: '□',
                        label: '파일 관리',
                        active: loc.startsWith('/files'),
                        onTap: () => _go(context, '/files'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // 하단 사용자 영역
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.brand.withValues(alpha: 0.1),
                          border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username.isEmpty
                                  ? (email.isEmpty ? '사용자' : email)
                                  : username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(authProvider.notifier).logout();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkMuted,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(28),
                    ),
                    icon: const Icon(Icons.logout, size: 14),
                    label: const Text('로그아웃',
                        style: TextStyle(fontSize: 11)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'v1.0.0',
                      style:
                          TextStyle(fontSize: 9, color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String path) {
    Navigator.of(context).pop();
    widget.router.go(path);
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppColors.brand.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppColors.brand.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: Text(
                  icon,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? AppColors.brand : AppColors.inkSub,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? AppColors.brand : AppColors.inkSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SitesToggle extends StatelessWidget {
  const _SitesToggle({
    required this.open,
    required this.active,
    required this.onToggle,
  });
  final bool open;
  final bool active;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppColors.brand.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? AppColors.brand.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: Text(
                  '⊞',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: active ? AppColors.brand : AppColors.inkSub,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '현장 관리',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppColors.brand : AppColors.inkSub,
                  ),
                ),
              ),
              Text(
                open ? '▲' : '▼',
                style: const TextStyle(
                    fontSize: 9, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SitesList extends StatelessWidget {
  const _SitesList({
    required this.future,
    required this.onTap,
    required this.router,
  });
  final Future<List<SiteListItem>>? future;
  final VoidCallback onTap;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12, top: 1, bottom: 1),
      padding: const EdgeInsets.only(left: 8),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: FutureBuilder<List<SiteListItem>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text('불러오는 중...',
                  style:
                      TextStyle(fontSize: 10, color: AppColors.inkMuted)),
            );
          }
          final sites = snap.data ?? const <SiteListItem>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sites.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('등록된 현장 없음',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.inkMuted)),
                )
              else
                ...sites.map(
                  (s) => InkWell(
                    onTap: () {
                      onTap();
                      router.go('/sites');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Row(
                        children: [
                          const Text('•',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.inkMuted)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.inkSub,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              InkWell(
                onTap: () {
                  onTap();
                  router.go('/sites');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      Text('＋',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.inkMuted)),
                      SizedBox(width: 6),
                      Text(
                        '추가 및 편집',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AlarmBellIcon extends StatelessWidget {
  const _AlarmBellIcon({required this.count, this.selected = false});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final hasBadge = count > 0;
    final clamped = count > 99 ? 99 : count;
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            selected ? Icons.notifications : Icons.notifications_outlined,
          ),
          if (hasBadge)
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: AppColors.surfaceCard, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33C0392B),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  '+$clamped',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

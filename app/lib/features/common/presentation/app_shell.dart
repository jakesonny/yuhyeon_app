import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';

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
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/sensors')) return 1;
    if (location.startsWith('/alarms')) return 2;
    if (location.startsWith('/sites')) return 3;
    if (location.startsWith('/files')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Text(
              '실시간 계측 모니터링',
              style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.line, height: 1),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
          ),
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
              onDestinationSelected: (index) {
                switch (index) {
                  case 0:
                    context.go('/dashboard');
                  case 1:
                    context.go('/sensors');
                  case 2:
                    context.go('/alarms');
                  case 3:
                    context.go('/sites');
                  case 4:
                    context.go('/files');
                }
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '대시보드'),
                NavigationDestination(icon: Icon(Icons.sensors_outlined), label: '센서'),
                NavigationDestination(icon: Icon(Icons.notification_add_outlined), label: '알람'),
                NavigationDestination(icon: Icon(Icons.map_outlined), label: '현장'),
                NavigationDestination(icon: Icon(Icons.folder_outlined), label: '파일'),
              ],
            )
          : null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/alarms/presentation/alarms_page.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/files/presentation/files_page.dart';
import 'features/qr/presentation/qr_page.dart';
import 'features/sensors/presentation/sensor_detail_page.dart';
import 'features/sensors/presentation/sensors_page.dart';
import 'features/sites/presentation/sites_page.dart';
import 'features/users/presentation/users_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authProvider);
  final isLoggedIn = session.isLoggedIn;
  NoTransitionPage<void> noTransition(Widget child, GoRouterState state) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final onLoginPage = state.matchedLocation == '/login';
      final onPublicQrPage = state.matchedLocation.startsWith('/qr/');
      // 웹 동등: MultiMonitor는 사용자 관리만 막고, 현장은 읽기 전용으로 허용한다.
      final isRestrictedForMultiMonitor =
          state.matchedLocation.startsWith('/users');
      if (!isLoggedIn && !onLoginPage && !onPublicQrPage) return '/login';
      if (isLoggedIn && onLoginPage) return '/dashboard';
      if (isLoggedIn && !session.canManage && isRestrictedForMultiMonitor) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => noTransition(const LoginPage(), state),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => noTransition(const DashboardPage(), state),
      ),
      GoRoute(
        path: '/sensors',
        pageBuilder: (context, state) => noTransition(const SensorsPage(), state),
      ),
      GoRoute(
        path: '/sensors/:id',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return noTransition(
            SensorDetailPage(
              sensorId: state.pathParameters['id']!,
              initialRangeDays: int.tryParse(q['range'] ?? ''),
              initialChartMode: q['mode'],
              initialSelectedHour: int.tryParse(q['hour'] ?? ''),
              initialDepthLabel: q['depth'],
            ),
            state,
          );
        },
      ),
      GoRoute(
        path: '/alarms',
        pageBuilder: (context, state) => noTransition(const AlarmsPage(), state),
      ),
      if (session.canManage)
        GoRoute(
          path: '/users',
          pageBuilder: (context, state) => noTransition(const UsersPage(), state),
        ),
      GoRoute(
        path: '/files',
        pageBuilder: (context, state) => noTransition(const FilesPage(), state),
      ),
      GoRoute(
        path: '/sites',
        pageBuilder: (context, state) => noTransition(const SitesPage(), state),
      ),
      GoRoute(
        path: '/qr/:id',
        pageBuilder: (context, state) =>
            noTransition(QrPage(sensorId: state.pathParameters['id']!), state),
      ),
    ],
  );
});

class YuhyunMobileApp extends ConsumerStatefulWidget {
  const YuhyunMobileApp({super.key});

  @override
  ConsumerState<YuhyunMobileApp> createState() => _YuhyunMobileAppState();
}

class _YuhyunMobileAppState extends ConsumerState<YuhyunMobileApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Yuhyun Mobile',
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();

        return ColoredBox(
          color: AppColors.surfacePage,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ClipRect(child: child),
            ),
          ),
        );
      },
    );
  }
}

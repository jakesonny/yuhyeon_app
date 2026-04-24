import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/presentation/geo_widgets.dart';
import '../application/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController(text: 'admin@geomonitor.com');
  final _passwordController = TextEditingController(text: 'admin1234');
  String _error = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfacePage,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'GM',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'GEOMONITOR',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '계측 모니터링 시스템',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 24),
                  GeoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.dangerBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.dangerBorder),
                            ),
                            child: Text(
                              _error,
                              style: const TextStyle(fontSize: 12, color: AppColors.dangerText),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const Text('이메일', style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(hintText: 'email@example.com'),
                        ),
                        const SizedBox(height: 12),
                        const Text('비밀번호', style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(hintText: '비밀번호 입력'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              if (_emailController.text.trim().isEmpty ||
                                  _passwordController.text.trim().isEmpty) {
                                setState(() => _error = '이메일과 비밀번호를 입력해 주세요.');
                                return;
                              }
                              setState(() => _error = '');
                              ref.read(authProvider.notifier).login();
                            },
                            child: const Text('로그인'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '테스트 계정: admin@geomonitor.com / admin1234',
                            style: TextStyle(fontSize: 11, color: AppColors.inkSub),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '© 2026 GeoMonitor. 계측 모니터링 시스템',
                    style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

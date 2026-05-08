import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/presentation/geo_widgets.dart';
import '../application/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static const _testEmail = 'qwer4321@qwer4321.com';
  static const _testPassword = 'qwer4321';

  String _mode = 'login';
  final _userIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _error = '';
  String _success = '';
  bool _loading = false;
  bool _expiredHandled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_expiredHandled) return;
    final expired =
        GoRouterState.of(context).uri.queryParameters['expired'] == 'true';
    if (expired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _error = '세션이 만료되었습니다. 다시 로그인해 주세요.');
      });
    }
    _expiredHandled = true;
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchMode(String mode) {
    setState(() {
      _mode = mode;
      _error = '';
      _success = '';
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_mode == 'login') {
      if (email.isEmpty || password.isEmpty) {
        setState(() => _error = '이메일과 비밀번호를 입력해 주세요.');
        return;
      }
      setState(() {
        _error = '';
        _success = '';
        _loading = true;
      });
      final err = await ref.read(authProvider.notifier).login(
            email: email,
            password: password,
          );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err ?? '';
      });
      return;
    }

    // signup
    final userId = _userIdController.text.trim();
    final name = _nameController.text.trim();
    final confirm = _confirmController.text;
    if (userId.isEmpty || name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = '필수 항목을 모두 입력해 주세요.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = '비밀번호가 일치하지 않습니다.');
      return;
    }
    setState(() {
      _error = '';
      _success = '';
      _loading = true;
    });
    final err = await ref.read(authProvider.notifier).register(
          username: userId,
          email: email,
          password: password,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err == null) {
        _success = '회원가입이 완료되었습니다. 로그인해 주세요.';
        _mode = 'login';
        _passwordController.clear();
        _confirmController.clear();
        _nameController.clear();
        _userIdController.clear();
      } else {
        _error = err;
      }
    });
  }

  void _fillTestAccount() {
    setState(() {
      _emailController.text = _testEmail;
      _passwordController.text = _testPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 380;
    return Scaffold(
      backgroundColor: AppColors.surfacePage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'GM',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'GEOMONITOR',
                    style: TextStyle(
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '계측 모니터링 시스템',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 20),
                  _ModeTabs(mode: _mode, onChanged: _switchMode),
                  const SizedBox(height: 14),
                  GeoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_success.isNotEmpty) ...[
                          _Alert(
                            text: _success,
                            color: AppColors.normalText,
                            bg: AppColors.normalBg,
                            border: AppColors.normalBorder,
                            prefix: '✓ ',
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_error.isNotEmpty) ...[
                          _Alert(
                            text: _error,
                            color: AppColors.dangerText,
                            bg: AppColors.dangerBg,
                            border: AppColors.dangerBorder,
                            prefix: '⚠ ',
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_mode == 'signup') ...[
                          const _FieldLabel('사용자 ID *'),
                          TextField(
                            controller: _userIdController,
                            decoration:
                                const InputDecoration(hintText: 'login_id'),
                          ),
                          const SizedBox(height: 12),
                          const _FieldLabel('사용자명 *'),
                          TextField(
                            controller: _nameController,
                            decoration:
                                const InputDecoration(hintText: '홍길동'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const _FieldLabel('이메일 *'),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: _mode == 'login'
                              ? TextInputAction.next
                              : TextInputAction.next,
                          decoration: const InputDecoration(
                              hintText: 'email@example.com'),
                        ),
                        const SizedBox(height: 12),
                        const _FieldLabel('비밀번호 *'),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: _mode == 'login'
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onSubmitted:
                              _mode == 'login' ? (_) => _submit() : null,
                          decoration:
                              const InputDecoration(hintText: '비밀번호 입력'),
                        ),
                        if (_mode == 'signup') ...[
                          const SizedBox(height: 12),
                          const _FieldLabel('비밀번호 확인 *'),
                          TextField(
                            controller: _confirmController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration:
                                const InputDecoration(hintText: '비밀번호 재입력'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _loading ? null : _submit,
                            child: Text(
                              _loading
                                  ? '처리 중...'
                                  : (_mode == 'login' ? '로그인' : '회원가입'),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        if (_mode == 'login') ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '테스트 계정 (터치 시 자동 입력)',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.inkMuted),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: _fillTestAccount,
                                  child: const Text(
                                    'qwer4321@qwer4321.com / qwer4321 (MultiMonitor)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '© 2026 GeoMonitor. 계측 모니터링 시스템',
                    style:
                        TextStyle(fontSize: 10, color: AppColors.inkMuted),
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

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});
  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(child: _ModeTab(label: '로그인', active: mode == 'login', onTap: () => onChanged('login'))),
          Expanded(child: _ModeTab(label: '회원가입', active: mode == 'signup', onTap: () => onChanged('signup'))),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.brand : AppColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.inkMuted,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.text,
    required this.color,
    required this.bg,
    required this.border,
    required this.prefix,
  });
  final String text;
  final Color color;
  final Color bg;
  final Color border;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        '$prefix$text',
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

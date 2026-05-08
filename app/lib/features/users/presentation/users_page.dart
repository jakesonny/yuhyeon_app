import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';
import '../../sensors/data/sensor_api.dart';

enum _UserFilter { all, active, inactive, deleted }

const List<String> _kRoles = [
  'admin',
  'Administrator',
  'Manager',
  'Operator',
  'Monitor',
  'MultiMonitor',
];

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  late Future<List<UserListItem>> _future;
  _UserFilter _filter = _UserFilter.active;
  int? _workingUserId;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _future = _loadUsers(ref);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadUsers(ref));
    await _future;
  }

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _toast = msg);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      setState(() => _toast = null);
    });
  }

  Future<void> _openAdd() async {
    final form = await showDialog<_UserForm>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _UserDialog(mode: _DialogMode.add),
    );
    if (form == null) return;
    try {
      setState(() => _workingUserId = -1);
      final err = await ref.read(authProvider.notifier).register(
            username: form.username,
            email: form.email,
            password: form.password,
            role: form.role,
            phone: form.phone,
          );
      if (err != null) {
        _showToast(err);
        return;
      }
      _showToast("'${form.username}' 사용자가 추가되었습니다.");
      await _refresh();
    } catch (e) {
      _showToast('추가 실패: $e');
    } finally {
      if (mounted) setState(() => _workingUserId = null);
    }
  }

  Future<void> _openEdit(UserListItem user, {required bool isSelf}) async {
    final form = await showDialog<_UserForm>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _UserDialog(
        mode: _DialogMode.edit,
        initial: user,
        roleLocked: isSelf,
      ),
    );
    if (form == null) return;
    try {
      setState(() => _workingUserId = user.id);
      await ref.read(sensorApiProvider).editUser(
            id: user.id,
            username: form.username,
            email: form.email,
            role: form.role,
            phone: form.phone.isEmpty ? null : form.phone,
          );
      _showToast("'${form.username}' 정보가 수정되었습니다.");
      await _refresh();
    } catch (e) {
      _showToast('수정 실패: $e');
    } finally {
      if (mounted) setState(() => _workingUserId = null);
    }
  }

  Future<void> _confirmAction(UserListItem user, _UserAction action) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ConfirmActionDialog(user: user, action: action),
    );
    if (ok != true) return;
    try {
      setState(() => _workingUserId = user.id);
      final api = ref.read(sensorApiProvider);
      switch (action) {
        case _UserAction.delete:
          await api.deleteUser(user.id);
        case _UserAction.deactivate:
          await api.deactivateUser(user.id);
        case _UserAction.activate:
          await api.activateUser(user.id);
      }
      _showToast(
        "'${user.username}' 계정이 ${switch (action) {
          _UserAction.delete => '삭제',
          _UserAction.deactivate => '비활성화',
          _UserAction.activate => '활성화',
        }}되었습니다.",
      );
      await _refresh();
    } catch (e) {
      _showToast('처리 실패: $e');
    } finally {
      if (mounted) setState(() => _workingUserId = null);
    }
  }

  Future<void> _changePassword(UserListItem user) async {
    final result = await showDialog<({String current, String next})>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _PasswordDialog(),
    );
    if (result == null) return;
    try {
      setState(() => _workingUserId = user.id);
      await ref.read(sensorApiProvider).changeUserPassword(
            id: user.id,
            currentPassword: result.current,
            newPassword: result.next,
          );
      _showToast('비밀번호가 변경되었습니다.');
    } catch (e) {
      _showToast('비밀번호 변경 실패: $e');
    } finally {
      if (mounted) setState(() => _workingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final canManage = session.canManage;
    final myEmail = session.email ?? '';
    final compact = MediaQuery.of(context).size.width < 380;

    return AppShell(
      title: '사용자',
      body: Stack(
        children: [
          FutureBuilder<List<UserListItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    GeoCard(
                      child: Text(
                        '사용자 조회 실패: ${snapshot.error}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                );
              }
              final users = snapshot.data ?? const <UserListItem>[];
              final total = users.length;
              final activeN = users
                  .where((u) => u.isActive && !u.isDeleted)
                  .length;
              final inactiveN = users
                  .where((u) => !u.isActive && !u.isDeleted)
                  .length;
              final deletedN = users.where((u) => u.isDeleted).length;

              final filtered = users.where((u) {
                switch (_filter) {
                  case _UserFilter.all:
                    return true;
                  case _UserFilter.active:
                    return u.isActive && !u.isDeleted;
                  case _UserFilter.inactive:
                    return !u.isActive && !u.isDeleted;
                  case _UserFilter.deleted:
                    return u.isDeleted;
                }
              }).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  children: [
                    _UsersHeader(
                      total: total,
                      active: activeN,
                      inactive: inactiveN,
                      deleted: deletedN,
                      canManage: canManage,
                      onAdd: _openAdd,
                      compact: compact,
                    ),
                    const SizedBox(height: 8),
                    _UserFilterTabs(
                      filter: _filter,
                      total: total,
                      active: activeN,
                      inactive: inactiveN,
                      deleted: deletedN,
                      onSelect: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const _EmptyState()
                    else
                      ...filtered.map(
                        (user) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _UserCard(
                            user: user,
                            isSelf: myEmail.isNotEmpty &&
                                user.email == myEmail,
                            canManage: canManage,
                            busy: _workingUserId == user.id,
                            compact: compact,
                            onEdit: () => _openEdit(user,
                                isSelf: myEmail.isNotEmpty &&
                                    user.email == myEmail),
                            onToggleActive: () => _confirmAction(
                              user,
                              user.isActive
                                  ? _UserAction.deactivate
                                  : _UserAction.activate,
                            ),
                            onDelete: () => _confirmAction(
                                user, _UserAction.delete),
                            onChangePassword: () => _changePassword(user),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (_toast != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(child: _ToastPill(message: _toast!)),
            ),
        ],
      ),
    );
  }
}

Future<List<UserListItem>> _loadUsers(WidgetRef ref) async {
  if (AppConfig.demoMode) {
    return DemoMockData.users
        .asMap()
        .entries
        .map((e) => UserListItem(
              id: e.key + 1,
              username: e.value.email.split('@').first,
              email: e.value.email,
              role: e.value.role,
              phone: e.value.phone,
              isActive: e.value.active,
            ))
        .toList();
  }
  return ref.read(sensorApiProvider).fetchUsers();
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({
    required this.total,
    required this.active,
    required this.inactive,
    required this.deleted,
    required this.canManage,
    required this.onAdd,
    required this.compact,
  });
  final int total;
  final int active;
  final int inactive;
  final int deleted;
  final bool canManage;
  final VoidCallback onAdd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사용자 관리',
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatBit(
                      label: '전체 ',
                      count: total,
                      color: AppColors.ink,
                    ),
                    _StatBit(
                      label: '활성 ',
                      count: active,
                      color: AppColors.normalText,
                    ),
                    if (inactive > 0)
                      _StatBit(
                        label: '비활성화 ',
                        count: inactive,
                        color: AppColors.warningText,
                      ),
                    if (deleted > 0)
                      _StatBit(
                        label: '삭제 ',
                        count: deleted,
                        color: AppColors.dangerText,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canManage)
            FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('+ 사용자 추가'),
            ),
        ],
      ),
    );
  }
}

class _StatBit extends StatelessWidget {
  const _StatBit({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
        Text(
          '$count',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
        const Text('명',
            style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter tabs
// ─────────────────────────────────────────────────────────────────────────────

class _UserFilterTabs extends StatelessWidget {
  const _UserFilterTabs({
    required this.filter,
    required this.total,
    required this.active,
    required this.inactive,
    required this.deleted,
    required this.onSelect,
  });
  final _UserFilter filter;
  final int total;
  final int active;
  final int inactive;
  final int deleted;
  final ValueChanged<_UserFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterPill(
            label: '전체',
            count: total,
            active: filter == _UserFilter.all,
            style: _PillStyle.neutral,
            onTap: () => onSelect(_UserFilter.all),
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label: '현재',
            count: active,
            active: filter == _UserFilter.active,
            style: _PillStyle.normal,
            onTap: () => onSelect(_UserFilter.active),
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label: '비활성화',
            count: inactive,
            active: filter == _UserFilter.inactive,
            style: _PillStyle.warning,
            onTap: () => onSelect(_UserFilter.inactive),
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label: '삭제',
            count: deleted,
            active: filter == _UserFilter.deleted,
            style: _PillStyle.danger,
            onTap: () => onSelect(_UserFilter.deleted),
          ),
        ],
      ),
    );
  }
}

enum _PillStyle { neutral, normal, warning, danger }

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.active,
    required this.style,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool active;
  final _PillStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.line;
    Color text = AppColors.inkMuted;
    Color bg = Colors.transparent;
    if (active) {
      switch (style) {
        case _PillStyle.neutral:
          border = AppColors.lineStrong;
          text = AppColors.ink;
          bg = AppColors.surfaceSubtle;
        case _PillStyle.normal:
          border = AppColors.normalBorder;
          text = AppColors.normalText;
          bg = AppColors.normalBg;
        case _PillStyle.warning:
          border = AppColors.warningBorder;
          text = AppColors.warningText;
          bg = AppColors.warningBg;
        case _PillStyle.danger:
          border = AppColors.dangerBorder;
          text = AppColors.dangerText;
          bg = AppColors.dangerBg;
      }
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: text,
                )),
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: text.withValues(alpha: 0.7),
                )),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return GeoCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: const Center(
        child: Text(
          '해당하는 사용자가 없습니다.',
          style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User card
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.canManage,
    required this.busy,
    required this.compact,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onChangePassword,
  });
  final UserListItem user;
  final bool isSelf;
  final bool canManage;
  final bool busy;
  final bool compact;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final initials = (user.username.isNotEmpty
            ? user.username[0]
            : (user.email.isNotEmpty ? user.email[0] : '?'))
        .toUpperCase();

    return Opacity(
      opacity: user.isDeleted ? 0.5 : 1,
      child: GeoCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brand.withValues(alpha: 0.10),
                    border: Border.all(
                        color: AppColors.brand.withValues(alpha: 0.30)),
                  ),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.username.isEmpty ? '—' : user.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 12 : 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                    color: AppColors.brand
                                        .withValues(alpha: 0.30)),
                              ),
                              child: const Text(
                                '나',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 10 : 11,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _UserStatusBadge(
                  isActive: user.isActive,
                  isDeleted: user.isDeleted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _RoleBadge(role: user.role),
                if (user.phone.isNotEmpty)
                  _MetaChip(
                    icon: Icons.phone_outlined,
                    text: user.phone,
                  ),
                if (user.createdAt != null)
                  _MetaChip(
                    icon: Icons.calendar_today_outlined,
                    text: '가입 ${_formatDate(user.createdAt)}',
                  ),
                if (user.lastLogin != null)
                  _MetaChip(
                    icon: Icons.login_outlined,
                    text: '최근 ${_formatDateTime(user.lastLogin)}',
                  ),
              ],
            ),
            if (!user.isDeleted) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  if (canManage && !isSelf) ...[
                    _ActionButton(
                      label: busy ? '처리 중...' : '수정',
                      color: AppColors.brand,
                      onTap: busy ? null : onEdit,
                    ),
                    _ActionButton(
                      label: user.isActive ? '비활성화' : '활성화',
                      color: user.isActive
                          ? AppColors.warningText
                          : AppColors.normalText,
                      onTap: busy ? null : onToggleActive,
                    ),
                    _ActionButton(
                      label: '삭제',
                      color: AppColors.dangerText,
                      onTap: busy ? null : onDelete,
                    ),
                  ],
                  if (isSelf)
                    _ActionButton(
                      label: '비밀번호 변경',
                      color: AppColors.brand,
                      onTap: busy ? null : onChangePassword,
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 6),
              const Text(
                '삭제된 계정입니다.',
                style:
                    TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.toLowerCase() == 'admin';
    final label = isAdmin ? 'Administrator' : (role.isEmpty ? '—' : role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.brand.withValues(alpha: 0.10)
            : AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isAdmin
              ? AppColors.brand.withValues(alpha: 0.30)
              : AppColors.line,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isAdmin ? AppColors.brand : AppColors.inkSub,
        ),
      ),
    );
  }
}

class _UserStatusBadge extends StatelessWidget {
  const _UserStatusBadge({
    required this.isActive,
    required this.isDeleted,
  });
  final bool isActive;
  final bool isDeleted;

  @override
  Widget build(BuildContext context) {
    final cfg = isDeleted
        ? (
            AppColors.dangerBg,
            AppColors.dangerBorder,
            AppColors.dangerText,
            AppColors.danger,
            '삭제'
          )
        : !isActive
            ? (
                AppColors.warningBg,
                AppColors.warningBorder,
                AppColors.warningText,
                AppColors.warning,
                '비활성화'
              )
            : (
                AppColors.normalBg,
                AppColors.normalBorder,
                AppColors.normalText,
                AppColors.normal,
                '활성'
              );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cfg.$1,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: cfg.$2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: cfg.$4, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            cfg.$5,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cfg.$3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.inkSub,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: color,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit dialog
// ─────────────────────────────────────────────────────────────────────────────

enum _DialogMode { add, edit }

class _UserForm {
  _UserForm({
    required this.username,
    required this.email,
    required this.password,
    required this.role,
    required this.phone,
  });
  final String username;
  final String email;
  final String password;
  final String role;
  final String phone;
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({
    required this.mode,
    this.initial,
    this.roleLocked = false,
  });
  final _DialogMode mode;
  final UserListItem? initial;
  final bool roleLocked;

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  late final TextEditingController _username =
      TextEditingController(text: widget.initial?.username ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.initial?.email ?? '');
  final TextEditingController _password = TextEditingController();
  late final TextEditingController _phone =
      TextEditingController(text: widget.initial?.phone ?? '');
  late String _role = widget.initial?.role.isNotEmpty == true
      ? widget.initial!.role
      : 'MultiMonitor';

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _isValid {
    final base =
        _username.text.trim().isNotEmpty && _email.text.trim().isNotEmpty;
    if (widget.mode == _DialogMode.add) {
      return base && _password.text.trim().isNotEmpty;
    }
    return base;
  }

  void _submit() {
    if (!_isValid) return;
    Navigator.of(context).pop(_UserForm(
      username: _username.text.trim(),
      email: _email.text.trim(),
      password: _password.text.trim(),
      role: _role,
      phone: _phone.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isAdd = widget.mode == _DialogMode.add;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isAdd ? '사용자 추가' : '사용자 수정',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    splashRadius: 16,
                    iconSize: 18,
                    color: AppColors.inkMuted,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('사용자 ID (username) *'),
                    _Input(
                      controller: _username,
                      hint: 'login_id',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    _Label('이메일 *'),
                    _Input(
                      controller: _email,
                      hint: 'email@example.com',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (isAdd) ...[
                      const SizedBox(height: 12),
                      _Label('비밀번호 *'),
                      _Input(
                        controller: _password,
                        hint: '비밀번호 입력',
                        obscure: true,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _Label('핸드폰번호'),
                    _Input(
                      controller: _phone,
                      hint: '010-0000-0000',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _Label('권한'),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 2.6,
                      children: [
                        for (final r in _kRoles)
                          _RoleChoice(
                            label: r == 'admin' ? 'Admin' : r,
                            active: _role == r,
                            disabled: widget.roleLocked,
                            onTap: () => setState(() => _role = r),
                          ),
                      ],
                    ),
                    if (widget.roleLocked)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '본인 계정의 권한은 변경할 수 없습니다.',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.inkMuted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        side: const BorderSide(color: AppColors.line),
                        foregroundColor: AppColors.inkSub,
                      ),
                      child: const Text('취소',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isValid ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(isAdd ? '추가' : '저장'),
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
}

class _Label extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: InputBorder.none,
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      ),
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({
    required this.label,
    required this.active,
    required this.disabled,
    required this.onTap,
  });
  final String label;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.brand.withValues(alpha: 0.10)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? AppColors.brand.withValues(alpha: 0.40)
                : AppColors.line,
          ),
        ),
        child: Opacity(
          opacity: disabled && !active ? 0.4 : 1,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.brand : AppColors.inkSub,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm action dialog
// ─────────────────────────────────────────────────────────────────────────────

enum _UserAction { delete, deactivate, activate }

class _ConfirmActionDialog extends StatelessWidget {
  const _ConfirmActionDialog({required this.user, required this.action});
  final UserListItem user;
  final _UserAction action;

  @override
  Widget build(BuildContext context) {
    final cfg = switch (action) {
      _UserAction.delete => (
          '⚠',
          AppColors.dangerBg,
          AppColors.danger,
          AppColors.danger,
          '삭제',
          '삭제된 계정은 복구할 수 없습니다.',
        ),
      _UserAction.deactivate => (
          '⚠',
          AppColors.warningBg,
          AppColors.warning,
          AppColors.warning,
          '비활성화',
          '비활성화 시 해당 사용자는 로그인할 수 없습니다.',
        ),
      _UserAction.activate => (
          '✓',
          AppColors.normalBg,
          AppColors.normal,
          AppColors.normal,
          '활성화',
          '활성화 시 해당 사용자가 다시 로그인할 수 있습니다.',
        ),
    };
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cfg.$2,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  cfg.$1,
                  style: TextStyle(fontSize: 22, color: cfg.$3),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${user.username} 계정을 ${cfg.$5}하시겠습니까?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cfg.$6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        side: const BorderSide(color: AppColors.line),
                        foregroundColor: AppColors.inkSub,
                      ),
                      child: const Text('취소',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: cfg.$4,
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(cfg.$5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password change dialog (self only)
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _current.text.isNotEmpty &&
      _next.text.isNotEmpty &&
      _confirm.text.isNotEmpty;

  void _submit() {
    if (_next.text != _confirm.text) {
      setState(() => _err = '새 비밀번호와 확인이 일치하지 않습니다.');
      return;
    }
    Navigator.of(context).pop((current: _current.text, next: _next.text));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '비밀번호 변경',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    splashRadius: 16,
                    iconSize: 18,
                    color: AppColors.inkMuted,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 12, color: AppColors.line),
              const SizedBox(height: 4),
              _Label('현재 비밀번호'),
              _Input(
                controller: _current,
                hint: '현재 비밀번호',
                obscure: true,
                onChanged: (_) => setState(() => _err = null),
              ),
              const SizedBox(height: 12),
              _Label('새 비밀번호'),
              _Input(
                controller: _next,
                hint: '새 비밀번호',
                obscure: true,
                onChanged: (_) => setState(() => _err = null),
              ),
              const SizedBox(height: 12),
              _Label('새 비밀번호 확인'),
              _Input(
                controller: _confirm,
                hint: '한 번 더 입력',
                obscure: true,
                onChanged: (_) => setState(() => _err = null),
              ),
              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(
                  _err!,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.dangerText),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        side: const BorderSide(color: AppColors.line),
                        foregroundColor: AppColors.inkSub,
                      ),
                      child: const Text('취소',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isValid ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('변경'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastPill extends StatelessWidget {
  const _ToastPill({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33212233),
              blurRadius: 14,
              offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}.${two(l.month)}.${two(l.day)}';
}

String _formatDateTime(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.month)}.${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

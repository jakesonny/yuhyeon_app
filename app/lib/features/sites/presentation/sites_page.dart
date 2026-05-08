import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../common/presentation/app_shell.dart';
import '../../../mock/mock_data.dart';
import '../../sensors/data/sensor_api.dart';

enum _SiteStatus { normal, warning, danger }
enum _ViewFilter { all, danger, warning, normal }

class _SiteWithStatus {
  _SiteWithStatus({
    required this.site,
    required this.status,
    required this.danger,
    required this.warning,
    required this.normal,
    required this.offline,
    required this.total,
  });

  final SiteListItem site;
  final _SiteStatus status;
  final int danger;
  final int warning;
  final int normal;
  final int offline;
  final int total;
}

class SitesPage extends ConsumerStatefulWidget {
  const SitesPage({super.key});

  @override
  ConsumerState<SitesPage> createState() => _SitesPageState();
}

class _SitesPageState extends ConsumerState<SitesPage> {
  late Future<_PageData> _future;
  _ViewFilter _filter = _ViewFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _load(ref);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load(ref);
    });
    await _future;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      ),
    );
  }

  Future<void> _openSiteDialog({SiteListItem? site, required List<UserListItem> users}) async {
    final isEdit = site != null;
    final name = TextEditingController(text: site?.name ?? '');
    final location = TextEditingController(text: site?.location ?? '');
    final description = TextEditingController(text: site?.description ?? '');
    final managers = <String>{...?site?.managers};

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          title: Text(isEdit ? '현장 편집' : '현장 추가',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DialogLabel('현장명 *'),
                  _DialogTextField(controller: name, hint: '현장 A'),
                  const SizedBox(height: 10),
                  _DialogLabel('위치 *'),
                  _DialogTextField(controller: location, hint: '서울특별시 마포구'),
                  const SizedBox(height: 10),
                  _DialogLabel('설명'),
                  _DialogTextField(
                    controller: description,
                    hint: '현장에 대한 설명을 입력하세요.',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _DialogLabel('담당자  '),
                      const Text('(복수 선택 가능)',
                          style: TextStyle(fontSize: 10, color: AppColors.inkMuted)),
                      const Spacer(),
                      if (managers.isNotEmpty)
                        TextButton(
                          onPressed: () => setDialog(managers.clear),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            minimumSize: const Size(0, 24),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: AppColors.dangerText,
                          ),
                          child: const Text('전체 해제',
                              style: TextStyle(fontSize: 10)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (users.isEmpty)
                    const Text('사용자 정보를 불러올 수 없습니다.',
                        style: TextStyle(fontSize: 11, color: AppColors.inkMuted))
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: users
                            .where((u) => u.username.isNotEmpty)
                            .toList()
                            .asMap()
                            .entries
                            .map((entry) {
                          final u = entry.value;
                          final isSelected = managers.contains(u.username);
                          return InkWell(
                            onTap: () {
                              setDialog(() {
                                if (isSelected) {
                                  managers.remove(u.username);
                                } else {
                                  managers.add(u.username);
                                }
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brand.withValues(alpha: 0.08)
                                    : null,
                                border: entry.key == 0
                                    ? null
                                    : const Border(
                                        top: BorderSide(color: AppColors.line),
                                      ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.brand
                                          : AppColors.surfaceCard,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.brand
                                            : AppColors.lineStrong,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    alignment: Alignment.center,
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            size: 10, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.brand.withValues(alpha: 0.15)
                                          : AppColors.surfaceSubtle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      (u.username.isNotEmpty ? u.username[0] : '?')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? AppColors.brand
                                            : AppColors.inkSub,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      u.username,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.brand
                                            : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    u.role,
                                    style: const TextStyle(
                                        fontSize: 9, color: AppColors.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  if (managers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        '담당자를 선택하지 않으면 미배정으로 등록됩니다.',
                        style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty || location.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(isEdit ? '저장' : '추가'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (name.text.trim().isEmpty || location.text.trim().isEmpty) return;

    try {
      final api = ref.read(sensorApiProvider);
      if (isEdit) {
        await api.updateSite(
          id: site.id,
          name: name.text.trim(),
          location: location.text.trim(),
          description: description.text.trim(),
          managers: managers.toList(),
        );
        _toast('${name.text.trim()} 현장 정보가 수정되었습니다.');
      } else {
        await api.createSite(
          name: name.text.trim(),
          location: location.text.trim(),
          description: description.text.trim(),
          managers: managers.toList(),
        );
        _toast('${name.text.trim()} 현장이 추가되었습니다.');
      }
      await _refresh();
    } catch (e) {
      _toast('처리 실패: $e');
    }
  }

  Future<void> _confirmDeleteSite(SiteListItem site) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dangerBg,
              ),
              alignment: Alignment.center,
              child: const Text('⚠',
                  style: TextStyle(
                      fontSize: 22, color: AppColors.dangerText)),
            ),
            const SizedBox(height: 12),
            Text(
              '${site.name}을(를) 삭제하시겠습니까?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '삭제된 현장 정보는 복구할 수 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
                  child: const Text('삭제'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(sensorApiProvider).deleteSite(site.id);
      _toast('${site.name} 현장이 삭제되었습니다.');
      await _refresh();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _toast('삭제 실패: $e');
    }
  }

  Future<void> _uploadSiteFloorPlan(SiteListItem site) async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    final bytes = f.bytes;
    if (bytes == null || f.name.isEmpty) {
      _toast('파일을 읽을 수 없습니다.');
      return;
    }
    try {
      await ref.read(sensorApiProvider).uploadSiteFloorPlan(
            id: site.id,
            bytes: bytes,
            filename: f.name,
          );
      _toast('${site.name} 평면도가 업로드되었습니다.');
      await _refresh();
    } catch (e) {
      _toast('업로드 실패: $e');
    }
  }

  Future<void> _showSiteDetailModal({
    required _SiteWithStatus item,
    required List<UserListItem> users,
    required List<SensorListItem> sensors,
    required bool canManage,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height;
        final w = MediaQuery.of(ctx).size.width;
        final maxW = (w - 32).clamp(280.0, 400.0);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.92, maxWidth: maxW),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '현장 상세',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close,
                              size: 18, color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SiteCardBody(
                          item: item,
                          users: users,
                          onManagerTap: (name) =>
                              _showUserInfo(name, users),
                          compact: w < 380,
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.line),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _showSiteSensors(item.site, sensors),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.sensors, size: 18),
                            label: const Text('센서 보기'),
                          ),
                        ),
                        if (canManage) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _assignSensorsToSite(item.site, sensors),
                              icon: const Icon(Icons.assignment_outlined, size: 18),
                              label: const Text('센서 배정'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _uploadSiteFloorPlan(item.site),
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: Text(
                                item.site.hasFloorPlan
                                    ? '평면도 변경'
                                    : '평면도 업로드',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openSiteDialog(
                                      site: item.site, users: users),
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('편집'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _confirmDeleteSite(item.site),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.dangerText,
                                    side: const BorderSide(
                                        color: AppColors.dangerBorder),
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  label: const Text('삭제'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSiteSensors(SiteListItem site, List<SensorListItem> all) async {
    final list = all.where((s) => s.siteCode == site.siteCode).toList();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height;
        final dialogW = (MediaQuery.of(ctx).size.width - 32).clamp(280.0, 380.0);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogW,
              maxHeight: h * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.line)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${site.name} 센서 목록',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('총 ${list.length}개',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.inkMuted)),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close,
                            size: 16, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: list.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text('등록된 센서가 없습니다.',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.inkMuted)),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: AppColors.line),
                          itemBuilder: (_, i) {
                            final s = list[i];
                            return InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                context.push('/sensors/${s.id}');
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.name.isEmpty ? s.sensorCode : s.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.brand,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      s.status == '오프라인' ||
                                              s.currentValue == null
                                          ? '—'
                                          : '${s.currentValue!.toStringAsFixed(1)} ${s.unit}',
                                      style: const TextStyle(
                                          fontSize: 11, color: AppColors.ink),
                                    ),
                                    const SizedBox(width: 8),
                                    _StatusPill(s.status),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right,
                                        size: 14, color: AppColors.inkMuted),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showUserInfo(String username, List<UserListItem> users) async {
    final user = users.where((u) => u.username == username).firstOrNull;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('담당자 정보',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close,
                        size: 16, color: AppColors.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brand.withValues(alpha: 0.1),
                      border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(user?.role ?? '—',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.inkMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (user == null)
                const Text('상세 정보를 불러올 수 없습니다.',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.inkMuted))
              else ...[
                _InfoRow(label: '이메일', value: user.email.isEmpty ? '—' : user.email),
                _InfoRow(
                  label: '핸드폰',
                  value: user.phone.isEmpty ? '—' : user.phone,
                ),
                _InfoRow(
                  label: '계정 상태',
                  value: user.isActive ? '활성' : '비활성화',
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final canManage = session.canManage;
    final compact = MediaQuery.of(context).size.width < 380;

    return AppShell(
      title: '현장',
      body: FutureBuilder<_PageData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('현장 조회 실패: ${snap.error}'),
                ),
              ],
            );
          }
          final data = snap.data!;
          final sitesWithStatus = data.sites
              .map((site) => _annotate(site, data.sensors))
              .toList();
          final total = sitesWithStatus.length;
          final dangerN = sitesWithStatus.where((s) => s.status == _SiteStatus.danger).length;
          final warningN = sitesWithStatus.where((s) => s.status == _SiteStatus.warning).length;
          final normalN = sitesWithStatus.where((s) => s.status == _SiteStatus.normal).length;

          final filtered = switch (_filter) {
            _ViewFilter.all => sitesWithStatus,
            _ViewFilter.danger => sitesWithStatus.where((s) => s.status == _SiteStatus.danger).toList(),
            _ViewFilter.warning => sitesWithStatus.where((s) => s.status == _SiteStatus.warning).toList(),
            _ViewFilter.normal => sitesWithStatus.where((s) => s.status == _SiteStatus.normal).toList(),
          };

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                _SitesHeader(
                  total: total,
                  danger: dangerN,
                  warning: warningN,
                  normal: normalN,
                  canManage: canManage,
                  onAdd: () => _openSiteDialog(users: data.users),
                  compact: compact,
                ),
                const SizedBox(height: 8),
                _FilterTabs(
                  filter: _filter,
                  total: total,
                  danger: dangerN,
                  warning: warningN,
                  normal: normalN,
                  onSelect: (f) => setState(() => _filter = f),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  _EmptyState(
                    canManage: canManage,
                    onAdd: () => _openSiteDialog(users: data.users),
                  )
                else
                  ...filtered.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SiteCard(
                        item: item,
                        canManage: canManage,
                        users: data.users,
                        onOpenDetail: () => _showSiteDetailModal(
                          item: item,
                          users: data.users,
                          sensors: data.sensors,
                          canManage: canManage,
                        ),
                        onLongPressEdit: canManage
                            ? () => _openSiteDialog(
                                site: item.site, users: data.users)
                            : null,
                        onManagerTap: (name) =>
                            _showUserInfo(name, data.users),
                        compact: compact,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _assignSensorsToSite(
    SiteListItem site,
    List<SensorListItem> allSensors,
  ) async {
    final selected = allSensors
        .where((s) => s.siteCode == site.siteCode)
        .map((s) => s.id)
        .toSet();
    final targetSensors = allSensors
        .where((s) => s.siteCode.isEmpty || s.siteCode == site.siteCode)
        .toList();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${site.name} 센서 배정',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          content: SizedBox(
            width: 360,
            child: targetSensors.isEmpty
                ? const Text('배정 가능한 센서가 없습니다.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted))
                : SizedBox(
                    height: 320,
                    child: ListView.builder(
                      itemCount: targetSensors.length,
                      itemBuilder: (context, i) {
                        final s = targetSensors[i];
                        return CheckboxListTile(
                          value: selected.contains(s.id),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            s.name.isEmpty ? s.sensorCode : s.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onChanged: (v) {
                            setDialogState(() {
                              if (v == true) {
                                selected.add(s.id);
                              } else {
                                selected.remove(s.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('저장')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      final api = ref.read(sensorApiProvider);
      final currentIds =
          allSensors.where((s) => s.siteCode == site.siteCode).map((s) => s.id).toSet();
      final toAdd = selected.difference(currentIds);
      final toRemove = currentIds.difference(selected);

      for (final id in toAdd) {
        await api.updateSensorSite(sensorId: id, siteCode: site.siteCode);
      }
      for (final id in toRemove) {
        await api.updateSensorSite(sensorId: id, siteCode: '');
      }
      _toast('센서 배정이 저장되었습니다.');
      await _refresh();
    } catch (e) {
      _toast('센서 배정 실패: $e');
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _PageData {
  _PageData({required this.sites, required this.sensors, required this.users});
  final List<SiteListItem> sites;
  final List<SensorListItem> sensors;
  final List<UserListItem> users;
}

_SiteWithStatus _annotate(SiteListItem site, List<SensorListItem> sensors) {
  final mine = sensors.where((s) => s.siteCode == site.siteCode).toList();
  final danger = mine.where((s) => s.status == '위험').length;
  final warning = mine.where((s) => s.status == '주의').length;
  final normal = mine.where((s) => s.status == '정상').length;
  final offline = mine.where((s) => s.status == '오프라인').length;
  final status = danger > 0
      ? _SiteStatus.danger
      : warning > 0
          ? _SiteStatus.warning
          : _SiteStatus.normal;
  return _SiteWithStatus(
    site: site,
    status: status,
    danger: danger,
    warning: warning,
    normal: normal,
    offline: offline,
    total: mine.length,
  );
}

Future<_PageData> _load(WidgetRef ref) async {
  if (AppConfig.demoMode) {
    final sites = DemoMockData.sites
        .map(
          (s) => SiteListItem(
            id: 0,
            siteCode: '',
            name: s.name,
            location: s.location,
            managers: [s.manager],
          ),
        )
        .toList();
    final sensors = DemoMockData.sensors
        .map(
          (s) => SensorListItem(
            id: int.tryParse(s.id) ?? 0,
            name: s.name,
            sensorCode: s.name,
            siteCode: '',
            siteName: '—',
            status: s.status,
            lastReceived: null,
            currentValue: null,
            unit: '',
          ),
        )
        .toList();
    return _PageData(sites: sites, sensors: sensors, users: const []);
  }
  final api = ref.read(sensorApiProvider);
  final results = await Future.wait([
    api.fetchSites(),
    api.fetchSensors(),
    api.fetchUsers().catchError((_) => <UserListItem>[]),
  ]);
  return _PageData(
    sites: results[0] as List<SiteListItem>,
    sensors: results[1] as List<SensorListItem>,
    users: results[2] as List<UserListItem>,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// UI components
// ─────────────────────────────────────────────────────────────────────────────

class _SitesHeader extends StatelessWidget {
  const _SitesHeader({
    required this.total,
    required this.danger,
    required this.warning,
    required this.normal,
    required this.canManage,
    required this.onAdd,
    required this.compact,
  });

  final int total;
  final int danger;
  final int warning;
  final int normal;
  final bool canManage;
  final VoidCallback onAdd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현장 추가 및 편집',
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
                        _StatBit(text: '전체 ', count: total, countColor: AppColors.ink),
                        if (danger > 0)
                          _StatBit(
                            text: '위험 ',
                            count: danger,
                            countColor: AppColors.dangerText,
                            leadingDot: AppColors.danger,
                          ),
                        if (warning > 0)
                          _StatBit(
                            text: '주의 ',
                            count: warning,
                            countColor: AppColors.warningText,
                          ),
                        _StatBit(
                          text: '정상 ',
                          count: normal,
                          countColor: AppColors.normalText,
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
                  child: const Text('+ 현장 추가'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBit extends StatelessWidget {
  const _StatBit({
    required this.text,
    required this.count,
    required this.countColor,
    this.leadingDot,
  });
  final String text;
  final int count;
  final Color countColor;
  final Color? leadingDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingDot != null) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: leadingDot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
        Text(
          '$count',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: countColor),
        ),
        const Text('개',
            style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
      ],
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({
    required this.filter,
    required this.total,
    required this.danger,
    required this.warning,
    required this.normal,
    required this.onSelect,
  });

  final _ViewFilter filter;
  final int total;
  final int danger;
  final int warning;
  final int normal;
  final ValueChanged<_ViewFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Tab(
            label: '전체',
            count: total,
            active: filter == _ViewFilter.all,
            activeStyle: _TabStyle.neutral,
            onTap: () => onSelect(_ViewFilter.all),
          ),
          const SizedBox(width: 6),
          _Tab(
            label: '위험',
            count: danger,
            active: filter == _ViewFilter.danger,
            activeStyle: _TabStyle.danger,
            onTap: () => onSelect(_ViewFilter.danger),
          ),
          const SizedBox(width: 6),
          _Tab(
            label: '주의',
            count: warning,
            active: filter == _ViewFilter.warning,
            activeStyle: _TabStyle.warning,
            onTap: () => onSelect(_ViewFilter.warning),
          ),
          const SizedBox(width: 6),
          _Tab(
            label: '정상',
            count: normal,
            active: filter == _ViewFilter.normal,
            activeStyle: _TabStyle.normal,
            onTap: () => onSelect(_ViewFilter.normal),
          ),
        ],
      ),
    );
  }
}

enum _TabStyle { neutral, danger, warning, normal }

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.active,
    required this.activeStyle,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final _TabStyle activeStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.line;
    Color text = AppColors.inkMuted;
    Color bg = Colors.transparent;
    if (active) {
      switch (activeStyle) {
        case _TabStyle.neutral:
          border = AppColors.lineStrong;
          text = AppColors.ink;
          bg = AppColors.surfaceSubtle;
        case _TabStyle.danger:
          border = AppColors.dangerBorder;
          text = AppColors.dangerText;
          bg = AppColors.dangerBg;
        case _TabStyle.warning:
          border = AppColors.warningBorder;
          text = AppColors.warningText;
          bg = AppColors.warningBg;
        case _TabStyle.normal:
          border = AppColors.normalBorder;
          text = AppColors.normalText;
          bg = AppColors.normalBg;
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
                    color: text)),
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

class _SiteCardBody extends StatelessWidget {
  const _SiteCardBody({
    required this.item,
    required this.users,
    required this.onManagerTap,
    required this.compact,
  });

  final _SiteWithStatus item;
  final List<UserListItem> users;
  final ValueChanged<String> onManagerTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final site = item.site;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.name,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    site.location.isEmpty ? '—' : site.location,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SiteStatusBadge(item.status),
          ],
        ),
        if (site.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            site.description,
            style: const TextStyle(fontSize: 11, color: AppColors.inkSub),
          ),
        ],
        const SizedBox(height: 10),
        _StatusBar(
          normal: item.normal,
          warning: item.warning,
          danger: item.danger,
          total: item.total,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _CountChip(label: '전체', value: item.total, color: AppColors.ink),
            _CountChip(
              label: '정상',
              value: item.normal,
              color: AppColors.normalText,
            ),
            if (item.warning > 0)
              _CountChip(
                label: '주의',
                value: item.warning,
                color: AppColors.warningText,
              ),
            if (item.danger > 0)
              _CountChip(
                label: '위험',
                value: item.danger,
                color: AppColors.dangerText,
              ),
            if (item.offline > 0)
              _CountChip(
                label: '오프라인',
                value: item.offline,
                color: AppColors.inkMuted,
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.line),
        const SizedBox(height: 8),
        const Text(
          '담당자',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.inkMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        if (site.managers.isEmpty)
          const Text(
            '미배정',
            style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: site.managers.map((name) {
              final user = users.where((u) => u.username == name).firstOrNull;
              final active = user?.isActive ?? false;
              return GestureDetector(
                onTap: () => onManagerTap(name),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: active
                        ? AppColors.brand.withValues(alpha: 0.08)
                        : AppColors.surfaceSubtle,
                    border: Border.all(
                      color: active
                          ? AppColors.brand.withValues(alpha: 0.3)
                          : AppColors.line,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? AppColors.brand.withValues(alpha: 0.18)
                              : AppColors.surfaceSubtle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: active ? AppColors.brand : AppColors.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 10,
                          color: active ? AppColors.brand : AppColors.inkSub,
                        ),
                      ),
                      if (user != null) ...[
                        const SizedBox(width: 2),
                        Text(
                          '↗',
                          style: TextStyle(
                            fontSize: 9,
                            color: active
                                ? AppColors.brand.withValues(alpha: 0.6)
                                : AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.item,
    required this.canManage,
    required this.users,
    required this.onOpenDetail,
    required this.onManagerTap,
    this.onLongPressEdit,
    required this.compact,
  });

  final _SiteWithStatus item;
  final bool canManage;
  final List<UserListItem> users;
  final VoidCallback onOpenDetail;
  final ValueChanged<String> onManagerTap;
  final VoidCallback? onLongPressEdit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        onLongPress: onLongPressEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SiteCardBody(
                item: item,
                users: users,
                onManagerTap: onManagerTap,
                compact: compact,
              ),
              const SizedBox(height: 10),
              Text(
                canManage
                    ? '탭하여 상세 및 작업 · 길게 눌러 편집'
                    : '탭하여 상세',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteStatusBadge extends StatelessWidget {
  const _SiteStatusBadge(this.status);
  final _SiteStatus status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;
    String label;
    switch (status) {
      case _SiteStatus.danger:
        bg = AppColors.dangerBg;
        border = AppColors.dangerBorder;
        text = AppColors.dangerText;
        label = '위험';
      case _SiteStatus.warning:
        bg = AppColors.warningBg;
        border = AppColors.warningBorder;
        text = AppColors.warningText;
        label = '주의';
      case _SiteStatus.normal:
        bg = AppColors.normalBg;
        border = AppColors.normalBorder;
        text = AppColors.normalText;
        label = '정상';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == _SiteStatus.danger) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: text)),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.normal,
    required this.warning,
    required this.danger,
    required this.total,
  });

  final int normal;
  final int warning;
  final int danger;
  final int total;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (total == 0) {
          return Container(
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(99),
            ),
            alignment: Alignment.center,
            child: const Text(
              '센서 미배정',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
            ),
          );
        }
        final segments = <_BarSeg>[
          if (normal > 0)
            _BarSeg(value: normal, color: AppColors.normal, label: '정상'),
          if (warning > 0)
            _BarSeg(value: warning, color: AppColors.warning, label: '주의'),
          if (danger > 0)
            _BarSeg(value: danger, color: AppColors.danger, label: '위험'),
        ];
        return ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 16,
            width: double.infinity,
            child: Row(
              children: segments.map((seg) {
                final segWidth = (seg.value / total) * w;
                final showFull = segWidth >= 56;
                final showCountOnly = !showFull && segWidth >= 20;
                return Container(
                  width: segWidth,
                  color: seg.color,
                  alignment: Alignment.center,
                  child: showFull
                      ? Text(
                          '${seg.value} ${seg.label}',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        )
                      : showCountOnly
                          ? Text(
                              '${seg.value}',
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            )
                          : null,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _BarSeg {
  const _BarSeg({
    required this.value,
    required this.color,
    required this.label,
  });
  final int value;
  final Color color;
  final String label;
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted)),
        Text(
          '$value',
          style:
              TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    Color text;
    Color bg;
    Color border;
    switch (status) {
      case '위험':
        text = AppColors.dangerText;
        bg = AppColors.dangerBg;
        border = AppColors.dangerBorder;
      case '주의':
        text = AppColors.warningText;
        bg = AppColors.warningBg;
        border = AppColors.warningBorder;
      case '오프라인':
        text = AppColors.offlineText;
        bg = AppColors.offlineBg;
        border = AppColors.offlineBorder;
      default:
        text = AppColors.normalText;
        bg = AppColors.normalBg;
        border = AppColors.normalBorder;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canManage, required this.onAdd});
  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Text('등록된 현장이 없습니다.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
          if (canManage) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onAdd,
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: const Text('+ 첫 번째 현장 추가하기',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    this.hint,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        filled: true,
        fillColor: AppColors.surfaceSubtle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: AppColors.brand.withValues(alpha: 0.5), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

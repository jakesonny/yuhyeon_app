import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../mock/mock_data.dart';
import '../../auth/application/auth_controller.dart';
import '../../common/presentation/app_shell.dart';
import '../data/sensor_api.dart';

enum _SensorTab { monitor, define, formula, recollect }

const _tabLabels = <_SensorTab, String>{
  _SensorTab.monitor: '모니터링',
  _SensorTab.define: '센서 정의',
  _SensorTab.formula: '계산식',
  _SensorTab.recollect: '재수집',
};

class SensorsPage extends ConsumerStatefulWidget {
  const SensorsPage({super.key});

  @override
  ConsumerState<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends ConsumerState<SensorsPage> {
  _SensorTab _tab = _SensorTab.monitor;
  String? _statusFilter;
  String _siteFilter = 'all';
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();

  late Future<_PageData> _future;
  late Future<List<FormulaItem>> _formulasFuture;
  late Future<List<RecollectItem>> _recollectFuture;
  late Future<AgentStatusItem> _agentFuture;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _formulasFuture = _loadFormulas();
    _recollectFuture = _loadRecollects();
    _agentFuture = _loadAgentStatus();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_PageData> _load() async {
    if (AppConfig.demoMode) {
      final mock = DemoMockData.sensors
          .map(
            (e) => SensorListItem(
              id: int.tryParse(e.id) ?? 0,
              name: e.name,
              sensorCode: e.name,
              siteCode: '',
              siteName: '—',
              status: e.status,
              lastReceived: null,
              currentValue: null,
              unit: '',
            ),
          )
          .toList();
      return _PageData(sensors: mock, sites: const []);
    }
    final api = ref.read(sensorApiProvider);
    final results = await Future.wait([
      api.fetchSensors(),
      api.fetchSites(),
    ]);
    return _PageData(
      sensors: results[0] as List<SensorListItem>,
      sites: results[1] as List<SiteListItem>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<List<FormulaItem>> _loadFormulas() async {
    if (AppConfig.demoMode) return const [];
    return ref.read(sensorApiProvider).fetchFormulas();
  }

  Future<List<RecollectItem>> _loadRecollects() async {
    if (AppConfig.demoMode) return const [];
    return ref.read(sensorApiProvider).fetchRecollects();
  }

  Future<AgentStatusItem> _loadAgentStatus() async {
    if (AppConfig.demoMode) {
      return const AgentStatusItem(isOnline: true, lastSeenAt: null);
    }
    return ref.read(sensorApiProvider).fetchAgentStatus();
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

  // ── 계산식 / 재수집 액션 (기존 로직 유지, 톤만 정리) ────────────────────────
  Future<void> _addFormula() async {
    final name = TextEditingController();
    final expr = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('계산식 추가',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '이름')),
              TextField(
                  controller: expr,
                  decoration: const InputDecoration(labelText: '수식')),
              TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: '설명')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('추가')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || expr.text.trim().isEmpty) {
      return;
    }
    try {
      await ref.read(sensorApiProvider).createFormula(
            name: name.text.trim(),
            expression: expr.text.trim(),
            description: desc.text.trim(),
          );
      _toast('계산식이 추가되었습니다.');
      setState(() {
        _formulasFuture = _loadFormulas();
      });
    } catch (e) {
      _toast('추가 실패: $e');
    }
  }

  Future<void> _editFormula(FormulaItem item) async {
    final name = TextEditingController(text: item.name);
    final expr = TextEditingController(text: item.expression);
    final desc = TextEditingController(text: item.description);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('계산식 수정',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '이름')),
              TextField(
                  controller: expr,
                  decoration: const InputDecoration(labelText: '수식')),
              TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: '설명')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(sensorApiProvider).updateFormula(
            id: item.id,
            name: name.text.trim(),
            expression: expr.text.trim(),
            description: desc.text.trim(),
          );
      _toast('계산식이 수정되었습니다.');
      setState(() {
        _formulasFuture = _loadFormulas();
      });
    } catch (e) {
      _toast('수정 실패: $e');
    }
  }

  Future<void> _deleteFormula(FormulaItem item) async {
    final ok = await _confirmDelete('${item.name} 계산식을 삭제하시겠습니까?');
    if (!ok) return;
    try {
      await ref.read(sensorApiProvider).deleteFormula(item.id);
      _toast('계산식이 삭제되었습니다.');
      setState(() {
        _formulasFuture = _loadFormulas();
      });
    } catch (e) {
      _toast('삭제 실패: $e');
    }
  }

  Future<void> _requestRecollect() async {
    final today = DateTime.now();
    final fromCtl = TextEditingController(
      text:
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
    );
    int? sensorId;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('재수집 요청',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<_PageData>(
                    future: _future,
                    builder: (_, snap) {
                      final list = snap.data?.sensors ?? const [];
                      return DropdownButtonFormField<int>(
                        initialValue: sensorId,
                        decoration:
                            const InputDecoration(labelText: '센서 선택'),
                        items: list
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(
                                  '${s.name.isEmpty ? s.sensorCode : s.name}'
                                  ' · ${s.siteName}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setLocal(() => sensorId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: fromCtl,
                    decoration: const InputDecoration(
                      labelText: '시작일 (YYYY-MM-DD)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('요청')),
            ],
          ),
        );
      },
    );
    if (ok != true || sensorId == null) return;
    try {
      await ref.read(sensorApiProvider).createRecollect(
            sensorId: sensorId!,
            dateFrom: fromCtl.text.trim().isEmpty ? null : fromCtl.text.trim(),
          );
      _toast('재수집 요청이 등록되었습니다.');
      setState(() {
        _recollectFuture = _loadRecollects();
      });
    } catch (e) {
      _toast('요청 실패: $e');
    }
  }

  Future<void> _deleteRecollect(RecollectItem item) async {
    final ok = await _confirmDelete('재수집 요청 #${item.id}을(를) 취소하시겠습니까?');
    if (!ok) return;
    try {
      await ref.read(sensorApiProvider).deleteRecollect(item.id);
      _toast('재수집 요청이 취소되었습니다.');
      setState(() {
        _recollectFuture = _loadRecollects();
      });
    } catch (e) {
      _toast('취소 실패: $e');
    }
  }

  Future<bool> _confirmDelete(String message) async {
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
              decoration: const BoxDecoration(
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
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
    return ok == true;
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final canManage = ref.watch(authProvider).canManage;
    final compact = MediaQuery.of(context).size.width < 380;

    return AppShell(
      title: '센서 관리',
      body: FutureBuilder<_PageData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? _PageData(sensors: const [], sites: const []);
          final sensors = data.sensors;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
              children: [
                _SensorsHeader(
                  total: sensors.length,
                  tab: _tab,
                  canManage: canManage,
                  onAdd: () {
                    if (_tab == _SensorTab.formula) {
                      _addFormula();
                    } else if (_tab == _SensorTab.recollect) {
                      _requestRecollect();
                    } else {
                      _toast('센서 추가는 PC에서 이용해 주세요.');
                    }
                  },
                  compact: compact,
                ),
                _TabBarSegmented(
                  tab: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
                if (_tab == _SensorTab.monitor) ...[
                  _MonitorBody(
                    sensors: sensors,
                    sites: data.sites,
                    statusFilter: _statusFilter,
                    siteFilter: _siteFilter,
                    query: _query,
                    searchCtrl: _searchCtrl,
                    onStatusChange: (s) =>
                        setState(() => _statusFilter = s),
                    onSiteChange: (s) => setState(() => _siteFilter = s),
                    onQueryChange: (q) => setState(() => _query = q),
                    compact: compact,
                  ),
                ] else if (_tab == _SensorTab.define) ...[
                  _DefineBody(
                    sensors: sensors,
                    canManage: canManage,
                    compact: compact,
                  ),
                ] else if (_tab == _SensorTab.formula) ...[
                  _FormulaBody(
                    future: _formulasFuture,
                    canManage: canManage,
                    onEdit: _editFormula,
                    onDelete: _deleteFormula,
                  ),
                ] else ...[
                  _RecollectBody(
                    agentFuture: _agentFuture,
                    recollectFuture: _recollectFuture,
                    canManage: canManage,
                    onDelete: _deleteRecollect,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── 데이터 모델 ───────────────────────────────────────────────────────────────
class _PageData {
  _PageData({required this.sensors, required this.sites});
  final List<SensorListItem> sensors;
  final List<SiteListItem> sites;
}

bool _isDelayed(DateTime? last) {
  if (last == null) return true;
  return DateTime.now().difference(last.toLocal()).inHours >= 2;
}

String _timeAgo(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}

// ── 헤더 ─────────────────────────────────────────────────────────────────────
class _SensorsHeader extends StatelessWidget {
  const _SensorsHeader({
    required this.total,
    required this.tab,
    required this.canManage,
    required this.onAdd,
    required this.compact,
  });

  final int total;
  final _SensorTab tab;
  final bool canManage;
  final VoidCallback onAdd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    String? actionLabel;
    if (canManage) {
      switch (tab) {
        case _SensorTab.formula:
          actionLabel = '+ 계산식 추가';
        case _SensorTab.recollect:
          actionLabel = '+ 재수집 요청';
        default:
          actionLabel = null;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '센서 관리',
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '등록된 센서 $total개',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}

// ── 탭 ───────────────────────────────────────────────────────────────────────
class _TabBarSegmented extends StatelessWidget {
  const _TabBarSegmented({required this.tab, required this.onChanged});

  final _SensorTab tab;
  final ValueChanged<_SensorTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: _SensorTab.values.map((t) {
            final active = t == tab;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  padding: const EdgeInsets.symmetric(vertical: 7),
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
                    _tabLabels[t]!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.brand : AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── 모니터링 탭 ──────────────────────────────────────────────────────────────
class _MonitorBody extends StatelessWidget {
  const _MonitorBody({
    required this.sensors,
    required this.sites,
    required this.statusFilter,
    required this.siteFilter,
    required this.query,
    required this.searchCtrl,
    required this.onStatusChange,
    required this.onSiteChange,
    required this.onQueryChange,
    required this.compact,
  });

  final List<SensorListItem> sensors;
  final List<SiteListItem> sites;
  final String? statusFilter;
  final String siteFilter;
  final String query;
  final TextEditingController searchCtrl;
  final ValueChanged<String?> onStatusChange;
  final ValueChanged<String> onSiteChange;
  final ValueChanged<String> onQueryChange;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final delayed = sensors.where((s) => _isDelayed(s.lastReceived)).toList();
    final byStatus = <String, int>{
      '정상': sensors.where((s) => s.status == '정상').length,
      '주의': sensors.where((s) => s.status == '주의').length,
      '위험': sensors.where((s) => s.status == '위험').length,
      '오프라인': sensors.where((s) => s.status == '오프라인').length,
    };
    final filtered = sensors.where((s) {
      final q = query.trim().toLowerCase();
      final matchQ = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.sensorCode.toLowerCase().contains(q) ||
          s.siteName.toLowerCase().contains(q);
      final matchStatus = statusFilter == null || s.status == statusFilter;
      final matchSite = siteFilter == 'all' || s.siteCode == siteFilter;
      return matchQ && matchStatus && matchSite;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (delayed.isNotEmpty)
          _DelayedBanner(delayed: delayed),
        const SizedBox(height: 8),
        _SearchAndSite(
          searchCtrl: searchCtrl,
          query: query,
          siteFilter: siteFilter,
          sites: sites,
          onQueryChange: onQueryChange,
          onSiteChange: onSiteChange,
        ),
        const SizedBox(height: 10),
        _StatusFilterTabs(
          total: sensors.length,
          counts: byStatus,
          status: statusFilter,
          onChange: onStatusChange,
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          _EmptyCard(message: '조건에 맞는 센서가 없습니다.')
        else
          ...filtered.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MonitorSensorCard(sensor: s, compact: compact),
            ),
          ),
      ],
    );
  }
}

class _DelayedBanner extends StatelessWidget {
  const _DelayedBanner({required this.delayed});
  final List<SensorListItem> delayed;

  @override
  Widget build(BuildContext context) {
    final names = delayed
        .map((s) => s.name.isEmpty ? s.sensorCode : s.name)
        .where((s) => s.isNotEmpty)
        .join(', ');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚠',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningText,
                  )),
              const SizedBox(width: 6),
              const Text('데이터 수신 지연 감지',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningText,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$names 센서에서 2시간 이상 데이터가 수신되지 않고 있습니다.',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.warningText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndSite extends StatelessWidget {
  const _SearchAndSite({
    required this.searchCtrl,
    required this.query,
    required this.siteFilter,
    required this.sites,
    required this.onQueryChange,
    required this.onSiteChange,
  });

  final TextEditingController searchCtrl;
  final String query;
  final String siteFilter;
  final List<SiteListItem> sites;
  final ValueChanged<String> onQueryChange;
  final ValueChanged<String> onSiteChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: searchCtrl,
            onChanged: onQueryChange,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: '센서명·현장 검색',
              hintStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.inkMuted,
              ),
              prefixIcon:
                  const Icon(Icons.search, size: 16, color: AppColors.inkMuted),
              prefixIconConstraints: const BoxConstraints(
                  minWidth: 30, minHeight: 30),
              suffixIcon: query.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () {
                        searchCtrl.clear();
                        onQueryChange('');
                      },
                      child: const Icon(Icons.close,
                          size: 14, color: AppColors.inkMuted),
                    ),
              suffixIconConstraints: const BoxConstraints(
                  minWidth: 30, minHeight: 30),
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceCard,
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
                  color: AppColors.brand.withValues(alpha: 0.5),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 9),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _SiteFilterDropdown(
            value: siteFilter,
            sites: sites,
            onChange: onSiteChange,
          ),
        ),
      ],
    );
  }
}

class _SiteFilterDropdown extends StatelessWidget {
  const _SiteFilterDropdown({
    required this.value,
    required this.sites,
    required this.onChange,
  });

  final String value;
  final List<SiteListItem> sites;
  final ValueChanged<String> onChange;

  String _label() {
    if (value == 'all') return '모든 현장';
    for (final s in sites) {
      if (s.siteCode == value) return s.name;
    }
    return '모든 현장';
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = box.size;

    final selected = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              left: anchor.dx,
              top: anchor.dy + size.height + 4,
              width: size.width,
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.line),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        _menuItem(ctx, value: 'all', label: '모든 현장'),
                        ...sites.map(
                          (s) => _menuItem(
                            ctx,
                            value: s.siteCode,
                            label: s.name,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (selected != null) onChange(selected);
  }

  Widget _menuItem(BuildContext ctx,
      {required String value, required String label}) {
    final selected = value == this.value;
    return InkWell(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        color: selected ? AppColors.surfaceSubtle : null,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: selected ? AppColors.brand : AppColors.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (innerCtx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(innerCtx),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _label(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.expand_more,
                  size: 16, color: AppColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusFilterTabs extends StatelessWidget {
  const _StatusFilterTabs({
    required this.total,
    required this.counts,
    required this.status,
    required this.onChange,
  });

  final int total;
  final Map<String, int> counts;
  final String? status;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _StatusPill(
            label: '전체',
            count: total,
            active: status == null,
            color: AppColors.ink,
            border: AppColors.lineStrong,
            bg: AppColors.surfaceSubtle,
            onTap: () => onChange(null),
          ),
          const SizedBox(width: 6),
          _StatusPill(
            label: '정상',
            count: counts['정상'] ?? 0,
            active: status == '정상',
            color: AppColors.normalText,
            border: AppColors.normalBorder,
            bg: AppColors.normalBg,
            onTap: () => onChange('정상'),
          ),
          const SizedBox(width: 6),
          _StatusPill(
            label: '주의',
            count: counts['주의'] ?? 0,
            active: status == '주의',
            color: AppColors.warningText,
            border: AppColors.warningBorder,
            bg: AppColors.warningBg,
            onTap: () => onChange('주의'),
          ),
          const SizedBox(width: 6),
          _StatusPill(
            label: '위험',
            count: counts['위험'] ?? 0,
            active: status == '위험',
            color: AppColors.dangerText,
            border: AppColors.dangerBorder,
            bg: AppColors.dangerBg,
            onTap: () => onChange('위험'),
          ),
          const SizedBox(width: 6),
          _StatusPill(
            label: '오프라인',
            count: counts['오프라인'] ?? 0,
            active: status == '오프라인',
            color: AppColors.offlineText,
            border: AppColors.offlineBorder,
            bg: AppColors.offlineBg,
            onTap: () => onChange('오프라인'),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.count,
    required this.active,
    required this.color,
    required this.border,
    required this.bg,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final Color color;
  final Color border;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? bg : Colors.transparent,
          border: Border.all(color: active ? border : AppColors.line),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? color : AppColors.inkMuted)),
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (active ? color : AppColors.inkMuted)
                      .withValues(alpha: 0.7),
                )),
          ],
        ),
      ),
    );
  }
}

class _MonitorSensorCard extends StatelessWidget {
  const _MonitorSensorCard({required this.sensor, required this.compact});
  final SensorListItem sensor;
  final bool compact;

  Color get _accent {
    switch (sensor.status) {
      case '위험':
        return AppColors.danger;
      case '주의':
        return AppColors.warning;
      case '오프라인':
        return AppColors.offline;
      default:
        return AppColors.normal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final delayed = _isDelayed(sensor.lastReceived);
    return Material(
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/sensors/${sensor.id}'),
        child: Column(
          children: [
            Container(height: 3, color: _accent),
            Padding(
              padding: EdgeInsets.all(compact ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          sensor.name.isEmpty ? sensor.sensorCode : sensor.name,
                          style: TextStyle(
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(sensor.status),
                    ],
                  ),
                  if (sensor.siteName.isNotEmpty &&
                      sensor.siteName != '—') ...[
                    const SizedBox(height: 2),
                    Text(
                      sensor.siteName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _FieldChip(field: sensor.field),
                      const Spacer(),
                      _ValueText(sensor: sensor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        delayed ? Icons.warning_amber_rounded : Icons.schedule,
                        size: 13,
                        color: delayed
                            ? AppColors.warningText
                            : AppColors.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '마지막 수신 ${_timeAgo(sensor.lastReceived)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: delayed
                              ? AppColors.warningText
                              : AppColors.inkSub,
                          fontWeight: delayed
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      _ThresholdHint(sensor: sensor),
                      const SizedBox(width: 6),
                      _QrIconButton(sensorId: sensor.id),
                    ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(status,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: text,
          )),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({required this.field});
  final String field;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        field.isEmpty ? '공통' : field,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.brand,
        ),
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText({required this.sensor});
  final SensorListItem sensor;

  @override
  Widget build(BuildContext context) {
    if (sensor.status == '오프라인' || sensor.currentValue == null) {
      return const Text('—',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.inkMuted,
            fontWeight: FontWeight.w700,
          ));
    }
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: sensor.currentValue!.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (sensor.unit.isNotEmpty)
            TextSpan(
              text: ' ${sensor.unit}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _ThresholdHint extends StatelessWidget {
  const _ThresholdHint({required this.sensor});
  final SensorListItem sensor;

  @override
  Widget build(BuildContext context) {
    final w = sensor.thresholdWarningMax;
    final d = sensor.thresholdDangerMin;
    if (w == null && d == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (w != null)
          Text(
            'W ${w.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.warningText,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (w != null && d != null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 3),
            child: Text('/',
                style:
                    TextStyle(fontSize: 9, color: AppColors.inkMuted)),
          ),
        if (d != null)
          Text(
            'D ${d.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.dangerText,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _QrIconButton extends StatelessWidget {
  const _QrIconButton({required this.sensorId});
  final int sensorId;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/qr/$sensorId'),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.qr_code_2,
            size: 14, color: AppColors.inkMuted),
      ),
    );
  }
}

// ── 센서 정의 탭 ─────────────────────────────────────────────────────────────
class _DefineBody extends StatelessWidget {
  const _DefineBody({
    required this.sensors,
    required this.canManage,
    required this.compact,
  });
  final List<SensorListItem> sensors;
  final bool canManage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (sensors.isEmpty) {
      return _EmptyCard(message: '등록된 센서가 없습니다.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '센서의 임계값·관리기준·계산식 같은 정의 항목은 PC 웹에서 편집할 수 있습니다.',
            style: TextStyle(fontSize: 11, color: AppColors.inkSub),
          ),
        ),
        const SizedBox(height: 10),
        ...sensors.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DefineRow(sensor: s, compact: compact),
          ),
        ),
      ],
    );
  }
}

class _DefineRow extends StatelessWidget {
  const _DefineRow({required this.sensor, required this.compact});
  final SensorListItem sensor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/sensors/${sensor.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sensor.name.isEmpty ? sensor.sensorCode : sensor.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  _FieldChip(field: sensor.field),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${sensor.siteName} · ${sensor.unit.isEmpty ? '단위 미설정' : sensor.unit}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (sensor.thresholdNormalMax != null)
                    _ThresholdBadge(
                      label: '정상 ≤${sensor.thresholdNormalMax!.toStringAsFixed(1)}',
                      bg: AppColors.normalBg,
                      border: AppColors.normalBorder,
                      color: AppColors.normalText,
                    ),
                  if (sensor.thresholdWarningMax != null)
                    _ThresholdBadge(
                      label: '주의 ≤${sensor.thresholdWarningMax!.toStringAsFixed(1)}',
                      bg: AppColors.warningBg,
                      border: AppColors.warningBorder,
                      color: AppColors.warningText,
                    ),
                  if (sensor.thresholdDangerMin != null)
                    _ThresholdBadge(
                      label: '위험 ≥${sensor.thresholdDangerMin!.toStringAsFixed(1)}',
                      bg: AppColors.dangerBg,
                      border: AppColors.dangerBorder,
                      color: AppColors.dangerText,
                    ),
                  if (sensor.thresholdNormalMax == null &&
                      sensor.thresholdWarningMax == null &&
                      sensor.thresholdDangerMin == null)
                    const _ThresholdBadge(
                      label: '임계값 미설정',
                      bg: AppColors.surfaceSubtle,
                      border: AppColors.line,
                      color: AppColors.inkMuted,
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

class _ThresholdBadge extends StatelessWidget {
  const _ThresholdBadge({
    required this.label,
    required this.bg,
    required this.border,
    required this.color,
  });
  final String label;
  final Color bg;
  final Color border;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── 계산식 탭 ────────────────────────────────────────────────────────────────
class _FormulaBody extends StatelessWidget {
  const _FormulaBody({
    required this.future,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });
  final Future<List<FormulaItem>> future;
  final bool canManage;
  final ValueChanged<FormulaItem> onEdit;
  final ValueChanged<FormulaItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FormulaItem>>(
      future: future,
      builder: (_, snap) {
        final list = snap.data ?? const <FormulaItem>[];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (list.isEmpty) {
          return _EmptyCard(message: '등록된 계산식이 없습니다.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: list
              .map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                f.expression,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (f.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  f.description,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (canManage) ...[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onEdit(f),
                            icon: const Icon(Icons.edit_outlined,
                                size: 16, color: AppColors.inkMuted),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onDelete(f),
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: AppColors.dangerText),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ── 재수집 탭 ────────────────────────────────────────────────────────────────
class _RecollectBody extends StatelessWidget {
  const _RecollectBody({
    required this.agentFuture,
    required this.recollectFuture,
    required this.canManage,
    required this.onDelete,
  });
  final Future<AgentStatusItem> agentFuture;
  final Future<List<RecollectItem>> recollectFuture;
  final bool canManage;
  final ValueChanged<RecollectItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FutureBuilder<AgentStatusItem>(
          future: agentFuture,
          builder: (_, snap) {
            final s = snap.data;
            final online = s?.isOnline == true;
            return Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('에이전트 상태',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      )),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: online
                          ? AppColors.normalBg
                          : AppColors.dangerBg,
                      border: Border.all(
                        color: online
                            ? AppColors.normalBorder
                            : AppColors.dangerBorder,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online
                                ? AppColors.normal
                                : AppColors.danger,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          online ? '온라인' : '오프라인',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: online
                                ? AppColors.normalText
                                : AppColors.dangerText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<RecollectItem>>(
          future: recollectFuture,
          builder: (_, snap) {
            final list = snap.data ?? const <RecollectItem>[];
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (list.isEmpty) {
              return _EmptyCard(message: '재수집 요청 내역이 없습니다.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: list
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'sensor #${r.sensorId} · ${r.dateFrom ?? '—'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '상태: ${r.status}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canManage &&
                                r.status != 'done' &&
                                r.status != '완료')
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () => onDelete(r),
                                icon: const Icon(Icons.delete_outline,
                                    size: 16,
                                    color: AppColors.dangerText),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// ── 공통 ─────────────────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
      ),
    );
  }
}

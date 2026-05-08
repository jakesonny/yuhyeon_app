import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';
import '../../sensors/data/sensor_api.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  static const _statusPrefKey = 'dashboard_status_filter';
  String? _selected;
  bool _refreshing = false;
  late Future<({DashboardSummary summary, List<SensorListItem> sensors, List<AlarmListItem> alarms})> _future;
  Timer? _refreshTimer;
  bool _queryInitialized = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _restoreStatusFilter();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;
        setState(() {
          _future = _load();
        });
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queryInitialized) return;
    _queryInitialized = true;
    final q = GoRouterState.of(context).uri.queryParameters['status'];
    if (q == '정상' || q == '주의' || q == '위험' || q == '오프라인') {
      _selected = q;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreStatusFilter() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_statusPrefKey);
    if (!mounted) return;
    if (v == '정상' || v == '주의' || v == '위험' || v == '오프라인') {
      setState(() => _selected = v);
    }
  }

  Future<void> _persistStatusFilter() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selected == null) {
      await prefs.remove(_statusPrefKey);
    } else {
      await prefs.setString(_statusPrefKey, _selected!);
    }
  }

  void _toggleStatus(String? status) {
    setState(() {
      _selected = (_selected == status) ? null : status;
      _syncDashboardQuery();
    });
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _future = _load();
    });
    try {
      await _future;
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _syncDashboardQuery() {
    final uri = Uri(
      path: '/dashboard',
      queryParameters: _selected == null ? null : {'status': _selected!},
    );
    final target = uri.toString();
    final current = GoRouterState.of(context).uri.toString();
    if (current != target) context.replace(target);
    _persistStatusFilter();
  }

  Future<({DashboardSummary summary, List<SensorListItem> sensors, List<AlarmListItem> alarms})> _load() async {
    if (AppConfig.demoMode) {
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
      final alarms = DemoMockData.recentAlarms
          .asMap()
          .entries
          .map(
            (e) => AlarmListItem(
              id: e.key + 1,
              sensorId: 0,
              sensorCode: e.value.sensorCode,
              sensorName: e.value.sensorName,
              siteName: '—',
              severity: e.value.severity,
              message: e.value.message,
              triggeredAt: null,
              isAcknowledged: false,
              acknowledgedBy: null,
              acknowledgedAt: null,
            ),
          )
          .toList();
      final summary = DashboardSummary(
        totalSensors: sensors.length,
        normalCount: sensors.where((s) => s.status == '정상').length,
        warningCount: sensors.where((s) => s.status == '주의').length,
        dangerCount: sensors.where((s) => s.status == '위험').length,
        offlineCount: sensors.where((s) => s.status == '오프라인').length,
        activeAlarms: alarms.length,
      );
      return (summary: summary, sensors: sensors, alarms: alarms);
    }
    final api = ref.read(sensorApiProvider);
    final results = await Future.wait([
      api.fetchDashboard(),
      api.fetchSensors(),
      api.fetchAlarms(limit: 20),
    ]);
    return (
      summary: results[0] as DashboardSummary,
      sensors: results[1] as List<SensorListItem>,
      alarms: results[2] as List<AlarmListItem>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '대시보드',
      body: FutureBuilder<({DashboardSummary summary, List<SensorListItem> sensors, List<AlarmListItem> alarms})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: Text('데이터 불러오는 중...', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return ListView(children: [GeoCard(child: Text('대시보드 조회 실패: ${snapshot.error}'))]);
          }
          final sensors = snapshot.data!.sensors;
          final summary = snapshot.data!.summary;
          final alarms = snapshot.data!.alarms;
          final dangerSensors = sensors.where((s) => s.status == '위험').toList();
          final filtered = _selected == null ? sensors : sensors.where((s) => s.status == _selected).toList();
          final delayedSensors = sensors.where((s) {
            final t = s.lastReceived;
            if (t == null) return true;
            return DateTime.now().difference(t.toLocal()) > const Duration(hours: 2);
          }).toList();

          return ListView(
            children: [
              _DashboardHeader(
                dangerCount: summary.dangerCount,
                refreshing: _refreshing,
                onRefresh: _manualRefresh,
              ),
              const SizedBox(height: 12),
              if (delayedSensors.isNotEmpty) ...[
                _DelayedBanner(delayedSensors: delayedSensors),
                const SizedBox(height: 12),
              ],
              const _SectionTitleWithHint(
                title: '시스템 현황',
                hint: '— 카드를 탭하면 해당 센서 목록을 볼 수 있어요',
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                children: [
                  _KpiCard(
                    label: '전체 센서',
                    sub: '전체',
                    value: summary.totalSensors,
                    barColor: AppColors.brand,
                    valueColor: AppColors.brand,
                    active: _selected == null,
                    onTap: () => _toggleStatus(null),
                  ),
                  _KpiCard(
                    label: '정상',
                    sub: '정상 운영',
                    value: summary.normalCount,
                    barColor: AppColors.normal,
                    valueColor: AppColors.normalText,
                    active: _selected == '정상',
                    onTap: () => _toggleStatus('정상'),
                  ),
                  _KpiCard(
                    label: '주의',
                    sub: '확인 필요',
                    value: summary.warningCount,
                    barColor: AppColors.warning,
                    valueColor: AppColors.warningText,
                    active: _selected == '주의',
                    onTap: () => _toggleStatus('주의'),
                  ),
                  _KpiCard(
                    label: '위험',
                    sub: '즉시 조치',
                    value: summary.dangerCount,
                    barColor: AppColors.danger,
                    valueColor: AppColors.dangerText,
                    active: _selected == '위험',
                    onTap: () => _toggleStatus('위험'),
                  ),
                  _KpiCard(
                    label: '오프라인',
                    sub: '점검 필요',
                    value: summary.offlineCount,
                    barColor: AppColors.inkMuted,
                    valueColor: AppColors.inkMuted,
                    active: _selected == '오프라인',
                    onTap: () => _toggleStatus('오프라인'),
                  ),
                ],
              ),
              if (_selected != null) ...[
                const SizedBox(height: 14),
                _KpiFilterPanel(
                  status: _selected!,
                  filtered: filtered,
                  onClose: () => _toggleStatus(_selected),
                ),
              ],
              const SizedBox(height: 16),
              SectionTitle(
                '최근 알람',
                trailing: TextButton(
                  onPressed: () => context.go('/alarms'),
                  child: const Text('전체 보기 →', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(height: 8),
              GeoCard(
                padding: EdgeInsets.zero,
                child: alarms.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('알람이 없습니다.',
                              style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                        ),
                      )
                    : Column(
                        children: alarms.take(5).map((alarm) {
                          return InkWell(
                            onTap: () => context.go('/alarms'),
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.line)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    StatusBadge(status: alarm.severity),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                alarm.sensorCode,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.brand,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  alarm.sensorName,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.ink,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            alarm.message,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11, color: AppColors.inkSub),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _timeAgo(alarm.triggeredAt),
                                      style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 16, color: AppColors.inkMuted),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              if (dangerSensors.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DangerSensorBanner(sensors: dangerSensors),
              ],
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.dangerCount,
    required this.refreshing,
    required this.onRefresh,
  });
  final int dangerCount;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '실시간 계측 모니터링 현황',
            style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (dangerCount > 0)
                _Pill(
                  text: '위험 센서 $dangerCount개 감지',
                  textColor: AppColors.dangerText,
                  bg: AppColors.dangerBg,
                  border: AppColors.dangerBorder,
                ),
              const _Pill(
                text: 'LIVE',
                textColor: AppColors.normalText,
                bg: AppColors.normalBg,
                border: AppColors.normalBorder,
                leadingDotColor: AppColors.normal,
              ),
              GestureDetector(
                onTap: refreshing ? null : onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    refreshing ? '⟳ 갱신 중...' : '↻ 새로고침',
                    style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DelayedBanner extends StatelessWidget {
  const _DelayedBanner({required this.delayedSensors});
  final List<SensorListItem> delayedSensors;

  @override
  Widget build(BuildContext context) {
    final names = delayedSensors
        .take(8)
        .map((s) => s.name.isEmpty ? s.sensorCode : s.name)
        .join(', ');
    final extra =
        delayedSensors.length > 8 ? ' 외 ${delayedSensors.length - 8}개' : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠ 데이터 수신 지연 감지',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.warningText),
          ),
          const SizedBox(height: 4),
          Text(
            '$names$extra 센서에서 2시간 이상 데이터가 수신되지 않고 있습니다.',
            style: TextStyle(
                fontSize: 12, color: AppColors.warningText.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitleWithHint extends StatelessWidget {
  const _SectionTitleWithHint({required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hint,
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.sub,
    required this.value,
    required this.barColor,
    required this.valueColor,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String sub;
  final int value;
  final Color barColor;
  final Color valueColor;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.brand : AppColors.line,
            width: active ? 1.5 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 3, color: barColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: AppColors.inkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 28,
                        color: valueColor,
                        fontWeight: FontWeight.w300,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.line)),
                      ),
                      child: Text(
                        sub,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiFilterPanel extends StatelessWidget {
  const _KpiFilterPanel({
    required this.status,
    required this.filtered,
    required this.onClose,
  });
  final String status;
  final List<SensorListItem> filtered;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$status 센서',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text('${filtered.length}개 센서',
                          style: const TextStyle(fontSize: 10, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/sensors'),
                  child: const Text('센서 관리 →', style: TextStyle(fontSize: 11)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 16, color: AppColors.inkMuted),
                  tooltip: '닫기',
                ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('해당하는 센서가 없습니다.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length.clamp(0, 8),
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.line),
              itemBuilder: (context, index) {
                final s = filtered[index];
                final lastTxt = s.lastReceived == null
                    ? '미수신'
                    : _timeAgo(s.lastReceived);
                final delayed = s.lastReceived == null ||
                    DateTime.now().difference(s.lastReceived!.toLocal()) >
                        const Duration(hours: 2);
                return InkWell(
                  onTap: () => context.push('/sensors/${s.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name.isEmpty ? s.sensorCode : s.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.siteName.isEmpty ? '—' : s.siteName,
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.currentValue == null
                              ? '—'
                              : '${s.currentValue!.toStringAsFixed(2)} ${s.unit}',
                          style: const TextStyle(fontSize: 11, color: AppColors.ink),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: s.status),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 64,
                          child: Text(
                            (delayed ? '⚠ ' : '') + lastTxt,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10,
                              color: delayed
                                  ? AppColors.warningText
                                  : AppColors.inkMuted,
                              fontWeight:
                                  delayed ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (filtered.length > 8)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton(
                  onPressed: () => context.go('/sensors'),
                  child: Text('외 ${filtered.length - 8}개 더 보기 →',
                      style: const TextStyle(fontSize: 11)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DangerSensorBanner extends StatelessWidget {
  const _DangerSensorBanner({required this.sensors});
  final List<SensorListItem> sensors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '위험 센서 즉시 확인 필요',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.dangerText),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sensors.map((s) {
              final value = s.currentValue == null
                  ? ''
                  : ' → ${s.currentValue!.toStringAsFixed(2)} ${s.unit}';
              return GestureDetector(
                onTap: () => context.push('/sensors/${s.id}'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.dangerBorder),
                  ),
                  child: Text(
                    '${s.sensorCode} ${s.name}$value',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.dangerText,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.textColor,
    required this.bg,
    required this.border,
    this.leadingDotColor,
  });
  final String text;
  final Color textColor;
  final Color bg;
  final Color border;
  final Color? leadingDotColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingDotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: leadingDotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
                fontSize: 11,
                color: textColor,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime? date) {
  if (date == null) return '-';
  final diff = DateTime.now().difference(date.toLocal());
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}

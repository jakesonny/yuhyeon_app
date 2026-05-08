import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';
import '../../sensors/data/sensor_api.dart';
import '../application/alarm_count_provider.dart';

enum _AlarmFilter { all, danger, warning }

extension _AlarmFilterX on _AlarmFilter {
  String get queryValue => switch (this) {
        _AlarmFilter.all => '전체',
        _AlarmFilter.danger => '위험',
        _AlarmFilter.warning => '주의',
      };
  String get severityKey => switch (this) {
        _AlarmFilter.all => '',
        _AlarmFilter.danger => '위험',
        _AlarmFilter.warning => '주의',
      };
}

class AlarmsPage extends ConsumerStatefulWidget {
  const AlarmsPage({super.key});

  @override
  ConsumerState<AlarmsPage> createState() => _AlarmsPageState();
}

class _AlarmsPageState extends ConsumerState<AlarmsPage> {
  _AlarmFilter _filter = _AlarmFilter.all;
  List<AlarmListItem> _alarms = const [];
  bool _loading = true;
  bool _refreshing = false;
  Timer? _refreshTimer;
  int _page = 1;
  bool _queryInitialized = false;
  String? _toast;
  Timer? _toastTimer;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _fetchAlarms();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchAlarms(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_queryInitialized) return;
    _queryInitialized = true;
    final q = GoRouterState.of(context).uri.queryParameters;
    final severity = q['severity'];
    _filter = switch (severity) {
      '위험' => _AlarmFilter.danger,
      '주의' => _AlarmFilter.warning,
      _ => _AlarmFilter.all,
    };
    final p = int.tryParse(q['page'] ?? '');
    if (p != null && p > 0) _page = p;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<List<AlarmListItem>> _loadAlarms() async {
    if (AppConfig.demoMode) {
      return DemoMockData.recentAlarms
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
    }
    return ref.read(sensorApiProvider).fetchAlarms();
  }

  Future<void> _fetchAlarms() async {
    try {
      if (!_loading && mounted) {
        setState(() => _refreshing = true);
      }
      final rows = await _loadAlarms();
      if (!mounted) return;
      setState(() {
        _alarms = rows;
        _loading = false;
        _refreshing = false;
        final maxP = _maxPage(rows);
        if (_page > maxP) _page = maxP;
      });
      _syncBadgeCount();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _syncBadgeCount() {
    final n = _alarms.where((a) => !a.isAcknowledged).length;
    ref.read(unackedAlarmCountProvider.notifier).setCount(n);
  }

  int _maxPage(List<AlarmListItem> source) {
    final filtered = _filter == _AlarmFilter.all
        ? source
        : source.where((a) => a.severity == _filter.severityKey).toList();
    if (filtered.isEmpty) return 1;
    return ((filtered.length - 1) ~/ _pageSize) + 1;
  }

  void _syncAlarmQuery() {
    final q = <String, String>{
      if (_filter != _AlarmFilter.all) 'severity': _filter.queryValue,
      if (_page > 1) 'page': '$_page',
    };
    final uri = Uri(path: '/alarms', queryParameters: q.isEmpty ? null : q);
    final target = uri.toString();
    final current = GoRouterState.of(context).uri.toString();
    if (current != target) context.replace(target);
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

  AlarmListItem _ackedClone(AlarmListItem a, String by) => AlarmListItem(
        id: a.id,
        sensorId: a.sensorId,
        sensorCode: a.sensorCode,
        sensorName: a.sensorName,
        siteName: a.siteName,
        severity: a.severity,
        message: a.message,
        triggeredAt: a.triggeredAt,
        isAcknowledged: true,
        acknowledgedBy: by,
        acknowledgedAt: DateTime.now(),
        triggeredValue: a.triggeredValue,
        thresholdValue: a.thresholdValue,
        unit: a.unit,
        manageNo: a.manageNo,
      );

  Future<void> _ackOne(AlarmListItem alarm) async {
    final me = ref.read(authProvider);
    final myName = me.username ?? '';
    final prev = _alarms;
    setState(() {
      _alarms =
          _alarms.map((a) => a.id == alarm.id ? _ackedClone(a, myName) : a).toList();
    });
    _syncBadgeCount();
    try {
      await ref.read(sensorApiProvider).acknowledgeAlarm(
            alarm.id,
            acknowledgedBy: myName,
          );
      _showToast('알람 확인 완료');
      await _fetchAlarms();
    } catch (e) {
      if (!mounted) return;
      setState(() => _alarms = prev);
      _syncBadgeCount();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('알람 확인 실패: $e')),
      );
    }
  }

  Future<void> _ackAll() async {
    final me = ref.read(authProvider);
    final myName = me.username ?? '';
    final api = ref.read(sensorApiProvider);
    final target = _alarms.where((a) => !a.isAcknowledged).toList();
    if (target.isEmpty) return;
    final prev = _alarms;
    setState(() {
      _alarms = _alarms
          .map((a) => target.any((t) => t.id == a.id) ? _ackedClone(a, myName) : a)
          .toList();
    });
    _syncBadgeCount();
    try {
      for (final a in target) {
        await api.acknowledgeAlarm(a.id, acknowledgedBy: myName);
      }
      _showToast('미처리 알람 ${target.length}건 모두 확인 완료');
      await _fetchAlarms();
    } catch (e) {
      if (!mounted) return;
      setState(() => _alarms = prev);
      _syncBadgeCount();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('전체 확인 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);
    final canManage = session.canManage;
    final compact = MediaQuery.of(context).size.width < 380;

    final dangerN = _alarms.where((a) => a.severity == '위험').length;
    final warningN = _alarms.where((a) => a.severity == '주의').length;
    final unackedN = _alarms.where((a) => !a.isAcknowledged).length;

    final filtered = _filter == _AlarmFilter.all
        ? _alarms
        : _alarms.where((a) => a.severity == _filter.severityKey).toList();
    final totalPages =
        filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ _pageSize) + 1;
    final safePage = _page.clamp(1, totalPages);
    final start = (safePage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pageRows = filtered.isEmpty ? <AlarmListItem>[] : filtered.sublist(start, end);

    return AppShell(
      title: '알람',
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _fetchAlarms,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              children: [
                _AlarmsHeader(
                  total: _alarms.length,
                  unacked: unackedN,
                  refreshing: _refreshing,
                  canManage: canManage,
                  onAckAll: () => _ackAll(),
                  compact: compact,
                ),
                const SizedBox(height: 8),
                _AlarmFilterTabs(
                  filter: _filter,
                  total: _alarms.length,
                  danger: dangerN,
                  warning: warningN,
                  onSelect: (f) => setState(() {
                    _filter = f;
                    _page = 1;
                    _syncAlarmQuery();
                  }),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filtered.isEmpty)
                  GeoCard(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    child: Center(
                      child: Text(
                        _alarms.isEmpty ? '발생한 알람이 없습니다.' : '조건에 맞는 알람이 없습니다.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  )
                else ...[
                  ...pageRows.map(
                    (alarm) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlarmCard(
                        alarm: alarm,
                        canManage: canManage,
                        compact: compact,
                        onAck: () => _ackOne(alarm),
                        onOpenSensor: () => context.push(
                          '/sensors/${alarm.sensorId}?range=1&mode=hourly',
                        ),
                      ),
                    ),
                  ),
                  if (totalPages > 1)
                    _PagerBar(
                      page: safePage,
                      totalPages: totalPages,
                      onPrev: safePage > 1
                          ? () => setState(() {
                                _page = safePage - 1;
                                _syncAlarmQuery();
                              })
                          : null,
                      onNext: safePage < totalPages
                          ? () => setState(() {
                                _page = safePage + 1;
                                _syncAlarmQuery();
                              })
                          : null,
                    ),
                ],
              ],
            ),
          ),
          if (_toast != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: _ToastPill(message: _toast!),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _AlarmsHeader extends StatelessWidget {
  const _AlarmsHeader({
    required this.total,
    required this.unacked,
    required this.refreshing,
    required this.canManage,
    required this.onAckAll,
    required this.compact,
  });

  final int total;
  final int unacked;
  final bool refreshing;
  final bool canManage;
  final VoidCallback onAckAll;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '알람 관리',
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (unacked > 0)
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '미처리 $unacked건',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dangerText,
                            ),
                          ),
                        ]),
                      )
                    else
                      const Text(
                        '✓ 미처리 없음',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.normalText,
                        ),
                      ),
                    Text(
                      ' · 전체 $total건',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (canManage && unacked > 0)
            FilledButton.tonal(
              onPressed: onAckAll,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand.withValues(alpha: 0.10),
                foregroundColor: AppColors.brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: AppColors.brand.withValues(alpha: 0.30)),
                ),
              ),
              child: Text('✓ 전체 확인 ($unacked)'),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter tabs
// ─────────────────────────────────────────────────────────────────────────────

class _AlarmFilterTabs extends StatelessWidget {
  const _AlarmFilterTabs({
    required this.filter,
    required this.total,
    required this.danger,
    required this.warning,
    required this.onSelect,
  });

  final _AlarmFilter filter;
  final int total;
  final int danger;
  final int warning;
  final ValueChanged<_AlarmFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterPill(
            label: '전체',
            count: total,
            active: filter == _AlarmFilter.all,
            style: _PillStyle.neutral,
            onTap: () => onSelect(_AlarmFilter.all),
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label: '위험',
            count: danger,
            active: filter == _AlarmFilter.danger,
            style: _PillStyle.danger,
            onTap: () => onSelect(_AlarmFilter.danger),
          ),
          const SizedBox(width: 6),
          _FilterPill(
            label: '주의',
            count: warning,
            active: filter == _AlarmFilter.warning,
            style: _PillStyle.warning,
            onTap: () => onSelect(_AlarmFilter.warning),
          ),
        ],
      ),
    );
  }
}

enum _PillStyle { neutral, danger, warning }

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
        case _PillStyle.danger:
          border = AppColors.dangerBorder;
          text = AppColors.dangerText;
          bg = AppColors.dangerBg;
        case _PillStyle.warning:
          border = AppColors.warningBorder;
          text = AppColors.warningText;
          bg = AppColors.warningBg;
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
            if (label != '전체' || active) ...[
              const SizedBox(width: 4),
              Text('$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: text.withValues(alpha: 0.7),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alarm card
// ─────────────────────────────────────────────────────────────────────────────

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({
    required this.alarm,
    required this.canManage,
    required this.compact,
    required this.onAck,
    required this.onOpenSensor,
  });

  final AlarmListItem alarm;
  final bool canManage;
  final bool compact;
  final VoidCallback onAck;
  final VoidCallback onOpenSensor;

  @override
  Widget build(BuildContext context) {
    final isDanger = alarm.severity == '위험';
    final isWarning = alarm.severity == '주의';
    final accent = isDanger
        ? AppColors.danger
        : isWarning
            ? AppColors.warning
            : AppColors.line;
    final tintBg = isDanger
        ? AppColors.dangerBg.withValues(alpha: 0.30)
        : isWarning
            ? AppColors.warningBg.withValues(alpha: 0.30)
            : AppColors.surfaceCard;

    return Opacity(
      opacity: alarm.isAcknowledged ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpenSensor,
          child: Container(
            decoration: BoxDecoration(
              color: tintBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x14212233),
                    blurRadius: 10,
                    offset: Offset(0, 2)),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StatusBadge(status: alarm.severity),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 2,
                                      children: [
                                        Text(
                                          alarm.sensorCode,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.brand,
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ],
                                          ),
                                        ),
                                        Text(
                                          alarm.sensorName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '— ${alarm.siteName}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (alarm.isAcknowledged)
                                _AckedBadge(by: alarm.acknowledgedBy)
                              else if (canManage)
                                _AckButton(onTap: onAck),
                            ],
                          ),
                          if (alarm.message.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              alarm.message,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.inkSub,
                                height: 1.35,
                              ),
                            ),
                          ],
                          if (alarm.triggeredValue != null) ...[
                            const SizedBox(height: 4),
                            _ValueLine(
                              value: alarm.triggeredValue!,
                              threshold: alarm.thresholdValue,
                              unit: alarm.unit,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                '발생: ${_formatDateTime(alarm.triggeredAt)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.inkMuted,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (alarm.acknowledgedBy != null &&
                                  alarm.acknowledgedBy!.isNotEmpty)
                                Text(
                                  '확인자: ${alarm.acknowledgedBy}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.inkMuted,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: onOpenSensor,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.inkSub,
                                side: const BorderSide(color: AppColors.line),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 28),
                                textStyle: const TextStyle(fontSize: 11),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('센서 보기'),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _ValueLine extends StatelessWidget {
  const _ValueLine({
    required this.value,
    required this.threshold,
    required this.unit,
  });
  final double value;
  final double? threshold;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final unitSuffix = unit.isEmpty ? '' : ' $unit';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          '측정값 ',
          style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
        ),
        Text(
          '${_fmt(value)}$unitSuffix',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (threshold != null) ...[
          const Text(' / 기준 ',
              style: TextStyle(fontSize: 11, color: AppColors.inkMuted)),
          Text(
            '${_fmt(threshold!)}$unitSuffix',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.inkSub,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble() && v.abs() < 1e9) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}

class _AckButton extends StatefulWidget {
  const _AckButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AckButton> createState() => _AckButtonState();
}

class _AckButtonState extends State<_AckButton> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      widget.onTap();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: FilledButton.tonal(
        onPressed: _busy ? null : _onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand.withValues(alpha: 0.10),
          foregroundColor: AppColors.brand,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(64, 28),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AppColors.brand.withValues(alpha: 0.30)),
          ),
        ),
        child: _busy
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('✓ ', style: TextStyle(fontSize: 11)),
                  Text('처리중', style: TextStyle(fontSize: 11)),
                ],
              )
            : const Text('확인'),
      ),
    );
  }
}

class _AckedBadge extends StatelessWidget {
  const _AckedBadge({required this.by});
  final String? by;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.normalBg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.normalBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✓ ',
              style: TextStyle(fontSize: 10, color: AppColors.normal)),
          Flexible(
            child: Text(
              by == null || by!.isEmpty ? '확인됨' : '확인됨 · $by',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.normalText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PagerBar extends StatelessWidget {
  const _PagerBar({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Text(
            '페이지 $page / $totalPages',
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
          const Spacer(),
          TextButton(
            onPressed: onPrev,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('이전', style: TextStyle(fontSize: 11)),
          ),
          TextButton(
            onPressed: onNext,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('다음', style: TextStyle(fontSize: 11)),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.normalBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.normalBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22212233), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        '✓ $message',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.normalText,
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime? dt) {
  if (dt == null) return '-';
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

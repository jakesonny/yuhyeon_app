import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '대시보드',
      body: ListView(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.normalBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.normalBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.normal),
                    SizedBox(width: 6),
                    Text('LIVE', style: TextStyle(fontSize: 11, color: AppColors.normalText)),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Text('↻ 새로고침', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SectionTitle('시스템 현황'),
          const SizedBox(height: 10),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: DemoMockData.dashboardMetrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) {
              final metric = DemoMockData.dashboardMetrics[index];
              return _MetricCard(
                title: metric.title,
                value: metric.value,
                index: index,
                statusKey: _statusKeyByIndex(index),
              );
            },
          ),
          const SizedBox(height: 12),
          _KpiFilteredSensorPanel(initialStatus: null),
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
            child: Column(
              children: [
                for (final alarm in DemoMockData.recentAlarms)
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.line)),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        '${alarm.sensorCode} / ${alarm.severity} / ${alarm.timeAgo}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.index,
    required this.statusKey,
  });

  final String title;
  final String value;
  final int index;
  final String? statusKey;

  @override
  Widget build(BuildContext context) {
    final topBar = [
      AppColors.brand,
      AppColors.normal,
      AppColors.warning,
      AppColors.danger,
    ][index % 4];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        _KpiFilterStore.status.value = statusKey;
      },
      child: GeoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, decoration: BoxDecoration(color: topBar, borderRadius: const BorderRadius.vertical(top: Radius.circular(12)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                const SizedBox(height: 8),
                Text(value.padLeft(2, '0'), style: const TextStyle(fontSize: 30, color: AppColors.ink, fontWeight: FontWeight.w300)),
              ],
            ),
          ),
        ],
      ),
    ));
  }
}

String? _statusKeyByIndex(int index) {
  if (index == 0) return null;
  if (index == 1) return '정상';
  if (index == 2) return '주의';
  if (index == 3) return '위험';
  return null;
}

class _KpiFilterStore {
  static final ValueNotifier<String?> status = ValueNotifier<String?>(null);
}

class _KpiFilteredSensorPanel extends StatelessWidget {
  const _KpiFilteredSensorPanel({required this.initialStatus});
  final String? initialStatus;

  @override
  Widget build(BuildContext context) {
    if (_KpiFilterStore.status.value == null && initialStatus != null) {
      _KpiFilterStore.status.value = initialStatus;
    }
    return ValueListenableBuilder<String?>(
      valueListenable: _KpiFilterStore.status,
      builder: (context, selected, _) {
        final sensors = selected == null
            ? DemoMockData.sensors
            : DemoMockData.sensors.where((s) => s.status == selected).toList();

        return GeoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    selected == null ? '전체 센서' : '$selected 센서',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _KpiFilterStore.status.value = null,
                    child: const Text('필터 해제', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final sensor in sensors.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(sensor.name, style: const TextStyle(fontSize: 12, color: AppColors.brand)),
                      const Spacer(),
                      StatusBadge(status: sensor.status),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';

class SensorDetailPage extends StatelessWidget {
  const SensorDetailPage({super.key, required this.sensorId});

  final String sensorId;

  @override
  Widget build(BuildContext context) {
    final sensor = DemoMockData.sensors.firstWhere(
      (item) => item.id == sensorId,
      orElse: () => const SensorSummary(
        id: '0',
        name: '알 수 없는 센서',
        status: '오프라인',
        lastReceived: '-',
      ),
    );
    return AppShell(
      title: '${sensor.name} 상세',
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const TabBar(
                indicator: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                dividerColor: Colors.transparent,
                labelColor: AppColors.brand,
                unselectedLabelColor: AppColors.inkMuted,
                tabs: [
                  Tab(text: '정보'),
                  Tab(text: '트렌드'),
                  Tab(text: '로그'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                children: [
                  _InfoTab(sensor: sensor),
                  _TrendTab(),
                  _LogTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.sensor});
  final SensorSummary sensor;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle('센서 정보'),
        const SizedBox(height: 8),
        GeoCard(
          child: Column(
            children: [
              Row(
                children: [
                  const Text('상태', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                  const Spacer(),
                  StatusBadge(status: sensor.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('마지막 수신', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                  const Spacer(),
                  Text(sensor.lastReceived, style: const TextStyle(fontSize: 13, color: AppColors.inkSub)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle('측정값'),
        const SizedBox(height: 8),
        const GeoCard(
          child: Column(
            children: [
              _ValueRow(label: '현재값', value: '12.34 m'),
              SizedBox(height: 10),
              _ValueRow(label: '초기측정값', value: '11.80 m'),
              SizedBox(height: 10),
              _ValueRow(label: '최솟값 / 최댓값', value: '11.72 m / 12.38 m'),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrendTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle('트렌드'),
        const SizedBox(height: 8),
        GeoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RangeButton(label: '오늘', active: true),
                  const SizedBox(width: 6),
                  _RangeButton(label: '7일'),
                  const SizedBox(width: 6),
                  _RangeButton(label: '30일'),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text('차트 영역 (목업)', style: TextStyle(color: AppColors.inkMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SectionTitle('측정 로그'),
        const SizedBox(height: 8),
        GeoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(
              15,
              (i) => Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: ListTile(
                  dense: true,
                  title: Text('2026-04-23 ${i.toString().padLeft(2, '0')}:00'),
                  trailing: Text('${(12.2 + i * 0.01).toStringAsFixed(2)} m'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({required this.label, this.active = false});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppColors.brand.withValues(alpha: 0.1) : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? AppColors.brand : AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: active ? AppColors.brand : AppColors.inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';

class SensorsPage extends StatelessWidget {
  const SensorsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '센서 목록',
      body: ListView(
        children: [
          const SectionTitle('모니터링'),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _FilterChip(label: '전체', active: true),
                _FilterChip(label: '정상'),
                _FilterChip(label: '주의'),
                _FilterChip(label: '위험'),
                _FilterChip(label: '오프라인'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...DemoMockData.sensors.map((sensor) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/sensors/${sensor.id}'),
                child: GeoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            sensor.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                          const Spacer(),
                          StatusBadge(status: sensor.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: AppColors.inkMuted),
                          const SizedBox(width: 6),
                          Text(
                            '마지막 수신 ${sensor.lastReceived}',
                            style: const TextStyle(fontSize: 12, color: AppColors.inkSub),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? AppColors.surfaceSubtle : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppColors.lineStrong : AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: active ? AppColors.ink : AppColors.inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

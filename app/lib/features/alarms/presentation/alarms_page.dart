import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';

class AlarmsPage extends StatelessWidget {
  const AlarmsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '알람',
      body: ListView(
        children: [
          const SectionTitle('최근 알람'),
          const SizedBox(height: 8),
          ...DemoMockData.recentAlarms.map((alarm) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GeoCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(status: alarm.severity),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${alarm.sensorCode}  ${alarm.sensorName}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brand,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alarm.message,
                              style: const TextStyle(fontSize: 12, color: AppColors.inkSub),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        alarm.timeAgo,
                        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

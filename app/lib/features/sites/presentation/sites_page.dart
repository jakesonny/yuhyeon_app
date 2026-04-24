import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';

class SitesPage extends StatelessWidget {
  const SitesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '현장',
      body: ListView(
        children: [
          const SectionTitle('현장 관리'),
          const SizedBox(height: 8),
          ...DemoMockData.sites.map((site) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GeoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            site.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: site.warningCount > 0 ? AppColors.warningBg : AppColors.normalBg,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: site.warningCount > 0 ? AppColors.warningBorder : AppColors.normalBorder,
                              ),
                            ),
                            child: Text(
                              '주의 ${site.warningCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: site.warningCount > 0 ? AppColors.warningText : AppColors.normalText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('위치: ${site.location}', style: const TextStyle(fontSize: 12, color: AppColors.inkSub)),
                      const SizedBox(height: 4),
                      Text('담당자: ${site.manager}', style: const TextStyle(fontSize: 12, color: AppColors.inkSub)),
                      const SizedBox(height: 4),
                      Text('센서 ${site.sensorCount}개', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

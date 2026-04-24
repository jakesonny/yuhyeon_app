import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';

class FilesPage extends StatelessWidget {
  const FilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '파일',
      body: ListView(
        children: [
          const SectionTitle('파일 관리'),
          const SizedBox(height: 8),
          ...DemoMockData.files.map((file) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GeoCard(
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.inkSub),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(
                              '${file.size} · ${file.uploadedBy} · ${file.uploadedAt}',
                              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.download_rounded, color: AppColors.inkMuted, size: 18),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

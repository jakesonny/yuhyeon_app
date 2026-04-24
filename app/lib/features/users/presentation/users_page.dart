import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../../../mock/mock_data.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '사용자',
      body: ListView(
        children: [
          const SectionTitle('사용자 관리'),
          const SizedBox(height: 8),
          ...DemoMockData.users.map((user) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GeoCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.surfaceSubtle,
                        child: Text(
                          user.email.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: AppColors.inkSub),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.email, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${user.role} · ${user.phone}', style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                          ],
                        ),
                      ),
                      StatusBadge(status: user.active ? '정상' : '오프라인'),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

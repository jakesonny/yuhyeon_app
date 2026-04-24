import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class GeoCard extends StatelessWidget {
  const GeoCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(color: Color(0x14212233), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.inkMuted,
          ),
        ),
        const Spacer(),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cfg = switch (status) {
      '정상' => (AppColors.normalBg, AppColors.normalBorder, AppColors.normalText, AppColors.normal),
      '주의' => (AppColors.warningBg, AppColors.warningBorder, AppColors.warningText, AppColors.warning),
      '위험' => (AppColors.dangerBg, AppColors.dangerBorder, AppColors.dangerText, AppColors.danger),
      _ => (AppColors.offlineBg, AppColors.offlineBorder, AppColors.offlineText, AppColors.offline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.$1,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: cfg.$2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: cfg.$4, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(fontSize: 11, color: cfg.$3, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

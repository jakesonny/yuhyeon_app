import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../sensors/data/sensor_api.dart';

class QrPage extends ConsumerWidget {
  const QrPage({super.key, required this.sensorId});

  final String sensorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<SensorDetailItem>(
      future: AppConfig.demoMode
          ? Future.value(
              const SensorDetailItem(
                id: 0,
                name: '데모 센서',
                sensorCode: '80053',
                status: '정상',
                lastReceived: null,
                currentValue: 0,
                unit: 'm',
                siteName: '데모 현장',
                level1Upper: null,
                level1Lower: null,
                installDate: null,
                locationDesc: null,
                correctionParams: <String, double>{},
                siteDbId: null,
                sensorPositions: <String, Map<String, dynamic>>{},
              ),
            )
          : ref.read(sensorApiProvider).fetchSensorById(sensorId),
      builder: (context, sensorSnap) {
        if (sensorSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (sensorSnap.hasError || sensorSnap.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('QR 조회')),
            body: Center(child: Text('센서 조회 실패: ${sensorSnap.error}')),
          );
        }
        final sensor = sensorSnap.data!;
        final is80053 = sensor.sensorCode == '80053';

        return Scaffold(
          appBar: AppBar(title: Text('${sensor.name} QR 조회')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sensor.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${sensor.siteName} · ${sensor.sensorCode}',
                        style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('상태', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                          const Spacer(),
                          _StatusPill(sensor.status),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (is80053)
                  _DepthBlock(sensorId: sensorId, depth: '1', label: 'WL-01')
                else
                  _SingleValueBlock(sensorId: sensorId),
                if (is80053) const SizedBox(height: 8),
                if (is80053) _DepthBlock(sensorId: sensorId, depth: '2', label: 'WL-02'),
                if (is80053) const SizedBox(height: 8),
                if (is80053) _DepthBlock(sensorId: sensorId, depth: '3', label: 'WL-03'),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => context.push('/sensors/$sensorId?range=1&mode=hourly'),
                  child: const Text('상세 정보 보기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DepthBlock extends ConsumerWidget {
  const _DepthBlock({
    required this.sensorId,
    required this.depth,
    required this.label,
  });

  final String sensorId;
  final String depth;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<SensorMeasurement>>(
      future: AppConfig.demoMode
          ? Future.value(const [])
          : ref.read(sensorApiProvider).fetchMeasurements(
                sensorId,
                depthLabel: depth,
                limit: 2000,
              ),
      builder: (context, snap) {
        final rows = snap.data ?? const <SensorMeasurement>[];
        final last = rows.isEmpty ? null : rows.last;
        final linear = last?.linearValue;
        final poly = last?.value;
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 8),
              _ValueRow('Linear', linear == null ? '—' : linear.toStringAsFixed(4)),
              const SizedBox(height: 4),
              _ValueRow('Polynomial', poly == null ? '—' : poly.toStringAsFixed(4)),
            ],
          ),
        );
      },
    );
  }
}

class _SingleValueBlock extends ConsumerWidget {
  const _SingleValueBlock({required this.sensorId});
  final String sensorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<SensorMeasurement>>(
      future: AppConfig.demoMode
          ? Future.value(const [])
          : ref.read(sensorApiProvider).fetchMeasurements(sensorId, limit: 2000),
      builder: (context, snap) {
        final rows = snap.data ?? const <SensorMeasurement>[];
        final last = rows.isEmpty ? null : rows.last;
        return _Card(
          child: _ValueRow('현재 측정값', last == null ? '—' : last.value.toStringAsFixed(4)),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == '위험'
        ? AppColors.dangerText
        : status == '주의'
            ? AppColors.warningText
            : AppColors.normalText;
    final bg = status == '위험'
        ? AppColors.dangerBg
        : status == '주의'
            ? AppColors.warningBg
            : AppColors.normalBg;
    final border = status == '위험'
        ? AppColors.dangerBorder
        : status == '주의'
            ? AppColors.warningBorder
            : AppColors.normalBorder;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

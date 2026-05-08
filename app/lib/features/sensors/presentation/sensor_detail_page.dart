import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/json_parse.dart';
import '../../auth/application/auth_controller.dart';
import '../../common/presentation/app_shell.dart';
import '../../common/presentation/geo_widgets.dart';
import '../data/sensor_api.dart';
import '../../../mock/mock_data.dart';

class SensorDetailPage extends ConsumerStatefulWidget {
  const SensorDetailPage({
    super.key,
    required this.sensorId,
    this.initialRangeDays,
    this.initialChartMode,
    this.initialSelectedHour,
    this.initialDepthLabel,
  });

  final String sensorId;
  final int? initialRangeDays;
  final String? initialChartMode;
  final int? initialSelectedHour;
  final String? initialDepthLabel;

  @override
  ConsumerState<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends ConsumerState<SensorDetailPage> {
  static const _prefKey = 'sensor_detail_query_state';
  int _rangeDays = 1;
  String _chartMode = 'hourly';
  int _selectedHour = 12;
  String _depthLabel = '';
  int _queryRangeDays = 1;
  String _queryChartMode = 'hourly';
  int _querySelectedHour = 12;
  String _queryDepthLabel = '';
  bool _syncScheduled = false;
  late Future<SensorDetailItem> _sensorFuture;

  Future<SensorDetailItem> _buildSensorFuture() {
    if (AppConfig.demoMode) {
      return Future.value(_mockSensor(widget.sensorId));
    }
    return ref.read(sensorApiProvider).fetchSensorById(widget.sensorId);
  }

  @override
  void initState() {
    super.initState();
    _sensorFuture = _buildSensorFuture();
    if (widget.initialRangeDays != null && [1, 7, 30].contains(widget.initialRangeDays)) {
      _rangeDays = widget.initialRangeDays!;
    }
    if (widget.initialChartMode == 'hourly' || widget.initialChartMode == 'daily') {
      _chartMode = widget.initialChartMode!;
    }
    if (widget.initialSelectedHour != null &&
        widget.initialSelectedHour! >= 0 &&
        widget.initialSelectedHour! <= 23) {
      _selectedHour = widget.initialSelectedHour!;
    }
    if (widget.initialDepthLabel != null && ['1', '2', '3'].contains(widget.initialDepthLabel)) {
      _depthLabel = widget.initialDepthLabel!;
    }
    _queryRangeDays = _rangeDays;
    _queryChartMode = _chartMode;
    _querySelectedHour = _selectedHour;
    _queryDepthLabel = _depthLabel;
    _restoreQueryState();
  }

  Future<void> _restoreQueryState() async {
    // URL 파라미터가 있으면 URL 우선
    if (widget.initialRangeDays != null ||
        widget.initialChartMode != null ||
        widget.initialSelectedHour != null ||
        widget.initialDepthLabel != null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null || !mounted) return;
    final parts = raw.split('|');
    if (parts.length != 4) return;
    final m = parts[1];
    final h = int.tryParse(parts[2]) ?? 12;
    final d = parts[3];
    if (!(m == 'hourly' || m == 'daily')) return;
    if (h < 0 || h > 23) return;
    if (!(d.isEmpty || d == '1' || d == '2' || d == '3')) return;
    setState(() {
      // 트렌드 진입 시 기본 "오늘"로 시작하도록 기간(_rangeDays)은 복원하지 않음
      _chartMode = m;
      _selectedHour = h;
      _depthLabel = d;
      _queryChartMode = m;
      _querySelectedHour = h;
      _queryDepthLabel = d;
    });
  }

  Future<void> _persistQueryState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = '$_rangeDays|$_chartMode|$_selectedHour|$_depthLabel';
    await prefs.setString(_prefKey, raw);
  }

  String get _from {
    final today = DateTime.now();
    final from = today.subtract(Duration(days: _rangeDays - 1));
    return _dateOnly(from);
  }

  String get _to => _dateOnly(DateTime.now());

  void _syncRouteQuery() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncScheduled = false;
      _doSyncRouteQuery();
    });
  }

  void _doSyncRouteQuery() {
    final q = <String, String>{
      'range': '$_rangeDays',
      'mode': _chartMode,
      if (_chartMode == 'daily') 'hour': '$_selectedHour',
      if (_depthLabel.isNotEmpty) 'depth': _depthLabel,
    };
    final uri = Uri(path: '/sensors/${widget.sensorId}', queryParameters: q);
    final target = uri.toString();
    final current = GoRouterState.of(context).uri.toString();
    if (current != target) context.replace(target);
    _persistQueryState();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '센서 상세',
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(1),
                labelPadding: EdgeInsets.zero,
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                labelColor: AppColors.brand,
                unselectedLabelColor: AppColors.inkMuted,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: '정보', height: 32),
                  Tab(text: '트렌드', height: 32),
                  Tab(text: '로그', height: 32),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<SensorDetailItem>(
                future: _sensorFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return GeoCard(
                      child: Text('상세 조회 실패: ${snapshot.error ?? '데이터 없음'}'),
                    );
                  }
                  final sensor = snapshot.data!;
                  return TabBarView(
                    children: [
                      _InfoTab(
                        sensor: sensor,
                        sensorId: widget.sensorId,
                        depthLabel: _depthLabel.isEmpty ? '1' : _depthLabel,
                        onDepthChanged: (v) => setState(() {
                          _depthLabel = v;
                          _queryDepthLabel = v;
                          _syncRouteQuery();
                        }),
                        onUpdated: () => setState(() {
                          _sensorFuture = _buildSensorFuture();
                        }),
                      ),
                      _TrendTab(
                        sensorId: widget.sensorId,
                        from: _from,
                        to: _to,
                        chartMode: _chartMode,
                        selectedHour: _selectedHour,
                        depthLabel: _depthLabel,
                        preferLinear: sensor.sensorCode == '80053',
                        level1Upper: sensor.level1Upper,
                        level1Lower: sensor.level1Lower,
                        rangeDays: _queryRangeDays,
                        onRangeChanged: (v) => setState(() => _queryRangeDays = v),
                        onChartModeChanged: (v) => setState(() => _queryChartMode = v),
                        onSelectedHourChanged: (v) => setState(() => _querySelectedHour = v),
                        onDepthLabelChanged: (v) => setState(() => _queryDepthLabel = v),
                        onApplyQuery: () => setState(() {
                          _rangeDays = _queryRangeDays;
                          _chartMode = _queryChartMode;
                          _selectedHour = _querySelectedHour;
                          _depthLabel = _queryDepthLabel;
                          _syncRouteQuery();
                        }),
                      ),
                      _LogTab(
                        sensorId: widget.sensorId,
                        from: _from,
                        to: _to,
                        chartMode: _chartMode,
                        selectedHour: _selectedHour,
                        depthLabel: _depthLabel,
                        preferLinear: sensor.sensorCode == '80053',
                        level1Upper: sensor.level1Upper,
                        level1Lower: sensor.level1Lower,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends ConsumerWidget {
  const _InfoTab({
    required this.sensor,
    required this.sensorId,
    required this.depthLabel,
    required this.onDepthChanged,
    required this.onUpdated,
  });
  final SensorDetailItem sensor;
  final String sensorId;
  final String depthLabel;
  final ValueChanged<String> onDepthChanged;
  final VoidCallback onUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(authProvider).canManage;
    final compact = MediaQuery.of(context).size.width < 380;
    return ListView(
      children: [
        SectionTitle(
          '센서 정보',
          trailing: canManage
              ? PopupMenuButton<String>(
                  tooltip: '관리 작업',
                  position: PopupMenuPosition.under,
                  icon: const Icon(Icons.more_horiz,
                      size: 18, color: AppColors.inkSub),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditSensorDialog(
                          context,
                          ref,
                          sensor: sensor,
                          sensorId: sensorId,
                          depthLabel: depthLabel,
                          onUpdated: onUpdated,
                        );
                      case 'threshold':
                        _showThresholdDialog(
                          context,
                          ref,
                          sensor: sensor,
                          sensorId: sensorId,
                          onUpdated: onUpdated,
                        );
                      case 'formula':
                        _showFormulaDialog(
                          context,
                          ref,
                          sensor: sensor,
                          sensorId: sensorId,
                          depthLabel: depthLabel,
                          onUpdated: onUpdated,
                        );
                      case 'correction':
                        _showCorrectionDialog(
                          context,
                          ref,
                          sensor: sensor,
                          sensorId: sensorId,
                          initialDepth: depthLabel,
                          onUpdated: onUpdated,
                        );
                      case 'icon':
                        _showIconPositionDialog(
                          context,
                          ref,
                          sensor: sensor,
                          depthLabel: depthLabel,
                          onUpdated: onUpdated,
                        );
                      case 'upload':
                        _showFloorPlanUploadDialog(
                          context,
                          ref,
                          sensorId: sensorId,
                          onUpdated: onUpdated,
                        );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('센서 정보 수정',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const PopupMenuItem(
                      value: 'threshold',
                      child:
                          Text('임계치 편집', style: TextStyle(fontSize: 12)),
                    ),
                    const PopupMenuItem(
                      value: 'formula',
                      child: Text('계산식 / 파라미터',
                          style: TextStyle(fontSize: 12)),
                    ),
                    if (sensor.sensorCode == '80053')
                      const PopupMenuItem(
                        value: 'correction',
                        child: Text('보정값',
                            style: TextStyle(fontSize: 12)),
                      ),
                    if (sensor.siteDbId != null)
                      const PopupMenuItem(
                        value: 'icon',
                        child: Text('아이콘 위치',
                            style: TextStyle(fontSize: 12)),
                      ),
                    const PopupMenuItem(
                      value: 'upload',
                      child: Text('평면도 업로드',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                )
              : null,
        ),
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
                  Text(_timeAgo(sensor.lastReceived), style: const TextStyle(fontSize: 13, color: AppColors.inkSub)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('현장', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                  const Spacer(),
                  Text(sensor.siteName, style: const TextStyle(fontSize: 13, color: AppColors.inkSub)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('1차 기준',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.inkMuted)),
                  const Spacer(),
                  Text(
                    _formatLevel1(sensor, depthLabel),
                    style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: AppColors.inkSub),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('임계치 (정상/주의/위험)',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.inkMuted)),
                  const Spacer(),
                  Text(
                    _formatThreshold(sensor),
                    style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: AppColors.inkSub),
                  ),
                ],
              ),
              if (sensor.sensorCode == '80053') ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('현재 Depth', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                    const Spacer(),
                    _DepthChip(
                      label: '1',
                      active: depthLabel == '1',
                      onTap: () => onDepthChanged('1'),
                    ),
                    const SizedBox(width: 6),
                    _DepthChip(
                      label: '2',
                      active: depthLabel == '2',
                      onTap: () => onDepthChanged('2'),
                    ),
                    const SizedBox(width: 6),
                    _DepthChip(
                      label: '3',
                      active: depthLabel == '3',
                      onTap: () => onDepthChanged('3'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('설치일', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                  const Spacer(),
                  Text(
                    (sensor.installDate == null || sensor.installDate!.isEmpty)
                        ? '—'
                        : sensor.installDate!.split('T').first,
                    style: TextStyle(fontSize: compact ? 12 : 13, color: AppColors.inkSub),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('설치위치', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      (sensor.locationDesc == null || sensor.locationDesc!.isEmpty)
                          ? '—'
                          : sensor.locationDesc!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: compact ? 12 : 13, color: AppColors.inkSub),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle('계측계획 평면도'),
        const SizedBox(height: 8),
        GeoCard(
          padding: EdgeInsets.zero,
          child: _FloorPlanSection(
            sensor: sensor,
            sensorId: sensorId,
            depthLabel: depthLabel,
            canManage: canManage,
            onDepthChanged: onDepthChanged,
            onUpdated: onUpdated,
          ),
        ),
        const SizedBox(height: 8),
        const SectionTitle('측정값'),
        const SizedBox(height: 8),
        GeoCard(
          child: Column(
            children: [
              _ValueRow(
                label: '현재값',
                value: sensor.currentValue == null
                    ? '—'
                    : '${sensor.currentValue!.toStringAsFixed(2)} ${sensor.unit}',
              ),
              const SizedBox(height: 10),
              _ValueRow(label: '센서 코드', value: sensor.sensorCode),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloorPlanSection extends ConsumerStatefulWidget {
  const _FloorPlanSection({
    required this.sensor,
    required this.sensorId,
    required this.depthLabel,
    required this.canManage,
    required this.onDepthChanged,
    required this.onUpdated,
  });

  final SensorDetailItem sensor;
  final String sensorId;
  final String depthLabel;
  final bool canManage;
  final ValueChanged<String> onDepthChanged;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_FloorPlanSection> createState() => _FloorPlanSectionState();
}

class _FloorPlanSectionState extends ConsumerState<_FloorPlanSection> {
  late List<_FloorIcon> _icons;
  String? _dragKey;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _icons = const <_FloorIcon>[];
  }

  @override
  void didUpdateWidget(covariant _FloorPlanSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sensor.sensorPositions != widget.sensor.sensorPositions ||
        oldWidget.depthLabel != widget.depthLabel) {
      // 상태 정보는 build 시 다시 주입됨
      _icons = const <_FloorIcon>[];
    }
  }

  Future<void> _savePositions() async {
    if (!widget.canManage || widget.sensor.siteDbId == null) return;
    final positions = <String, dynamic>{...widget.sensor.sensorPositions};
    for (final icon in _icons) {
      positions[icon.key] = {'label': icon.label, 'x': icon.x, 'y': icon.y};
    }
    try {
      setState(() => _saving = true);
      await ref.read(sensorApiProvider).updateSiteSensorPositions(
            siteId: widget.sensor.siteDbId!,
            positions: positions,
          );
      if (!mounted) return;
      widget.onUpdated();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아이콘 위치 저장에 실패했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addIcon() async {
    String depth = ['1', '2', '3'].contains(widget.depthLabel) ? widget.depthLabel : '1';
    final label = TextEditingController(
      text: widget.sensor.sensorCode == '80053' ? 'WL-0$depth' : widget.sensor.name,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('센서 아이콘 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.sensor.sensorCode == '80053')
                DropdownButton<String>(
                  value: depth,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('Depth 1')),
                    DropdownMenuItem(value: '2', child: Text('Depth 2')),
                    DropdownMenuItem(value: '3', child: Text('Depth 3')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => depth = v);
                  },
                ),
              TextField(controller: label, decoration: const InputDecoration(labelText: '아이콘 라벨')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('추가')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final key = widget.sensor.sensorCode == '80053' ? '${widget.sensor.id}:$depth' : '${widget.sensor.id}';
    if (_icons.any((e) => e.key == key)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 존재하는 아이콘 키입니다.')),
      );
      return;
    }
    setState(() {
      _icons = [
        ..._icons,
        _FloorIcon(
          key: key,
          label: label.text.trim().isEmpty ? key : label.text.trim(),
          x: 0.5,
          y: 0.5,
          active: true,
          status: '오프라인',
        ),
      ];
    });
    await _savePositions();
  }

  Future<void> _renameIcon() async {
    final active = _icons.where((e) => e.active).toList();
    if (active.isEmpty) return;
    var selectedKey = active.first.key;
    final label = TextEditingController(text: active.first.label);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('센서 아이콘 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedKey,
                isExpanded: true,
                items: _icons
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.key)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final icon = _icons.firstWhere((e) => e.key == v);
                  setState(() {
                    selectedKey = v;
                    label.text = icon.label;
                  });
                },
              ),
              TextField(controller: label, decoration: const InputDecoration(labelText: '아이콘 라벨')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      _icons = _icons
          .map((e) => e.key == selectedKey
              ? e.copyWith(label: label.text.trim().isEmpty ? e.key : label.text.trim())
              : e)
          .toList();
    });
    await _savePositions();
  }

  Future<void> _deleteIcon() async {
    if (_icons.isEmpty) return;
    String selectedKey = _icons.where((e) => e.active).map((e) => e.key).firstOrNull ?? _icons.first.key;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('센서 아이콘 삭제'),
          content: DropdownButton<String>(
            value: selectedKey,
            isExpanded: true,
            items: _icons
                .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.label} (${e.key})')))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => selectedKey = v);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      _icons = _icons.where((e) => e.key != selectedKey).toList();
    });
    await _savePositions();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SensorListItem>>(
      future: ref.read(sensorApiProvider).fetchSensors(),
      builder: (context, snapshot) {
        final statusBySensorId = <String, String>{
          for (final s in snapshot.data ?? const <SensorListItem>[]) '${s.id}': s.status,
        };
        final serverIcons = _buildFloorIcons(widget.sensor, widget.depthLabel, statusBySensorId);
        if (_icons.isEmpty) _icons = serverIcons;
        final normalCount = _icons.where((e) => e.status == '정상').length;
        final warningCount = _icons.where((e) => e.status == '주의').length;
        final dangerCount = _icons.where((e) => e.status == '위험').length;
        return Column(
          children: [
            if (widget.canManage)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _saving ? null : _addIcon,
                        child: const Text('+ 추가', style: TextStyle(fontSize: 11)),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _renameIcon,
                        child: const Text('✏️ 수정', style: TextStyle(fontSize: 11)),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _deleteIcon,
                        child: const Text('🗑️ 삭제', style: TextStyle(fontSize: 11, color: AppColors.dangerText)),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              height: 220,
              child: LayoutBuilder(
                builder: (context, constraints) => ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        '${AppConfig.apiBaseUrl}/api/sensors/${widget.sensorId}/floor-plan-image',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.surfaceSubtle,
                          alignment: Alignment.center,
                          child: const Text(
                            '평면도 이미지가 없습니다.',
                            style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
                          ),
                        ),
                      ),
                      ..._icons.map(
                        (icon) => Positioned(
                          left: (icon.x * constraints.maxWidth).clamp(0, constraints.maxWidth).toDouble(),
                          top: (icon.y * constraints.maxHeight).clamp(0, constraints.maxHeight).toDouble(),
                          child: Transform.translate(
                            offset: const Offset(-12, -12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _icons = _icons.map((e) => e.copyWith(active: e.key == icon.key)).toList();
                                });
                                if (widget.sensor.sensorCode == '80053') {
                                  final depth = icon.key.split(':').length > 1 ? icon.key.split(':')[1] : '1';
                                  widget.onDepthChanged(depth);
                                }
                              },
                              onPanStart: widget.canManage ? (_) => _dragKey = icon.key : null,
                              onPanUpdate: widget.canManage
                                  ? (details) {
                                      if (_dragKey != icon.key) return;
                                      final dx = details.delta.dx / constraints.maxWidth;
                                      final dy = details.delta.dy / constraints.maxHeight;
                                      setState(() {
                                        _icons = _icons
                                            .map((e) => e.key == icon.key
                                                ? e.copyWith(
                                                    x: (e.x + dx).clamp(0.0, 1.0),
                                                    y: (e.y + dy).clamp(0.0, 1.0),
                                                  )
                                                : e)
                                            .toList();
                                      });
                                    }
                                  : null,
                              onPanEnd: widget.canManage
                                  ? (_) async {
                                      _dragKey = null;
                                      await _savePositions();
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                decoration: BoxDecoration(
                                  color: icon.active ? AppColors.brand : _statusFillColor(icon.status),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: icon.active ? AppColors.brand : _statusBorderColor(icon.status),
                                  ),
                                ),
                                child: Text(
                                  icon.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: icon.active ? Colors.white : _statusTextColor(icon.status),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_icons.isNotEmpty)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (normalCount > 0) ...[
                                  _LegendDot(color: AppColors.normal),
                                  Text('정상 $normalCount', style: const TextStyle(fontSize: 10)),
                                  const SizedBox(width: 8),
                                ],
                                if (warningCount > 0) ...[
                                  _LegendDot(color: AppColors.warning),
                                  Text('주의 $warningCount', style: const TextStyle(fontSize: 10)),
                                  const SizedBox(width: 8),
                                ],
                                if (dangerCount > 0) ...[
                                  _LegendDot(color: AppColors.danger),
                                  Text('위험 $dangerCount', style: const TextStyle(fontSize: 10)),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                _saving
                    ? '아이콘 위치 저장 중...'
                    : (widget.sensor.sensorCode == '80053'
                        ? '아이콘 탭: Depth 전환 · 드래그: 위치 이동'
                        : '아이콘 드래그로 위치 이동 후 자동 저장됩니다.'),
                style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
            ),
          ],
        );
      },
    );
  }
}

List<_FloorIcon> _buildFloorIcons(
  SensorDetailItem sensor,
  String depthLabel,
  Map<String, String> statusBySensorId,
) {
  final out = <_FloorIcon>[];
  sensor.sensorPositions.forEach((key, value) {
    final x = asDouble(value['x']);
    final y = asDouble(value['y']);
    if (x == null || y == null) return;
    final label = (value['label'] ?? key).toString();
    final isActive = sensor.sensorCode == '80053'
        ? key == '${sensor.id}:$depthLabel'
        : key == sensor.id.toString();
    final sensorKey = key.split(':').first;
    final status = statusBySensorId[sensorKey] ?? '오프라인';
    out.add(_FloorIcon(key: key, label: label, x: x, y: y, active: isActive, status: status));
  });
  return out;
}

class _FloorIcon {
  const _FloorIcon({
    required this.key,
    required this.label,
    required this.x,
    required this.y,
    required this.active,
    required this.status,
  });
  final String key;
  final String label;
  final double x;
  final double y;
  final bool active;
  final String status;

  _FloorIcon copyWith({
    String? key,
    String? label,
    double? x,
    double? y,
    bool? active,
    String? status,
  }) {
    return _FloorIcon(
      key: key ?? this.key,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
      active: active ?? this.active,
      status: status ?? this.status,
    );
  }
}

extension on Iterable<String> {
  String? get firstOrNull => isEmpty ? null : first;
}

Color _statusFillColor(String status) {
  switch (status) {
    case '정상':
      return AppColors.normalBg;
    case '주의':
      return AppColors.warningBg;
    case '위험':
      return AppColors.dangerBg;
    default:
      return AppColors.offlineBg;
  }
}

Color _statusBorderColor(String status) {
  switch (status) {
    case '정상':
      return AppColors.normalBorder;
    case '주의':
      return AppColors.warningBorder;
    case '위험':
      return AppColors.dangerBorder;
    default:
      return AppColors.offlineBorder;
  }
}

Color _statusTextColor(String status) {
  switch (status) {
    case '정상':
      return AppColors.normalText;
    case '주의':
      return AppColors.warningText;
    case '위험':
      return AppColors.dangerText;
    default:
      return AppColors.offlineText;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

String _formatLevel1(SensorDetailItem sensor, String depthLabel) {
  if (sensor.sensorCode == '80053') {
    final dc = sensor.depthCriteria[depthLabel.isEmpty ? '1' : depthLabel];
    final upper = dc?['upper'];
    final lower = dc?['lower'];
    return '${lower?.toStringAsFixed(2) ?? '—'} / ${upper?.toStringAsFixed(2) ?? '—'}';
  }
  return '${sensor.level1Lower?.toStringAsFixed(2) ?? '—'} / ${sensor.level1Upper?.toStringAsFixed(2) ?? '—'}';
}

String _formatThreshold(SensorDetailItem sensor) {
  String fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);
  return '${fmt(sensor.thresholdNormalMax)} / ${fmt(sensor.thresholdWarningMax)} / ${fmt(sensor.thresholdDangerMin)}';
}

Future<void> _showEditSensorDialog(
  BuildContext context,
  WidgetRef ref, {
  required SensorDetailItem sensor,
  required String sensorId,
  required String depthLabel,
  required VoidCallback onUpdated,
}) async {
  final is80053 = sensor.sensorCode == '80053';
  final activeDepth = is80053
      ? (depthLabel.isEmpty ? '1' : depthLabel)
      : '';
  final Map<String, double?> dcEntry = is80053
      ? (sensor.depthCriteria[activeDepth] ?? const <String, double?>{})
      : const <String, double?>{};
  final double? initialUpper =
      is80053 ? dcEntry['upper'] : sensor.level1Upper;
  final double? initialLower =
      is80053 ? dcEntry['lower'] : sensor.level1Lower;

  final name = TextEditingController(text: sensor.name);
  final manageNo = TextEditingController(text: sensor.manageNo);
  final upper = TextEditingController(
    text: initialUpper == null ? '' : initialUpper.toString(),
  );
  final lower = TextEditingController(
    text: initialLower == null ? '' : initialLower.toString(),
  );
  final install = TextEditingController(
    text: (sensor.installDate == null || sensor.installDate!.isEmpty)
        ? ''
        : sensor.installDate!.split('T').first,
  );
  final location = TextEditingController(text: sensor.locationDesc ?? '');

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => AlertDialog(
      title: Text(is80053
          ? '센서 정보 수정 (Depth $activeDepth)'
          : '센서 정보 수정'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '센서명'),
              ),
              TextField(
                controller: manageNo,
                decoration: const InputDecoration(labelText: '관리번호'),
              ),
              TextField(
                controller: lower,
                decoration: InputDecoration(
                  labelText: is80053
                      ? '1차 하한 (Depth $activeDepth)'
                      : '1차 하한',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
              TextField(
                controller: upper,
                decoration: InputDecoration(
                  labelText: is80053
                      ? '1차 상한 (Depth $activeDepth)'
                      : '1차 상한',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
              ),
              TextField(
                controller: install,
                decoration: const InputDecoration(
                    labelText: '설치일 (YYYY-MM-DD)'),
              ),
              TextField(
                controller: location,
                decoration: const InputDecoration(labelText: '설치위치 설명'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('저장'),
        ),
      ],
    ),
  );
  if (ok != true || name.text.trim().isEmpty) return;
  final id = int.tryParse(sensorId);
  if (id == null) return;
  final lowerV = double.tryParse(lower.text.trim());
  final upperV = double.tryParse(upper.text.trim());

  try {
    final api = ref.read(sensorApiProvider);
    if (is80053) {
      final next = <String, dynamic>{};
      sensor.depthCriteria.forEach((k, v) {
        next[k] = {
          'upper': v['upper'],
          'lower': v['lower'],
        };
      });
      next[activeDepth] = {
        'upper': upperV,
        'lower': lowerV,
      };
      await api.updateSensorInfo(
        id: id,
        name: name.text.trim(),
        manageNo: manageNo.text.trim(),
        depthCriteria: next,
        installDate:
            install.text.trim().isEmpty ? null : install.text.trim(),
        locationDesc:
            location.text.trim().isEmpty ? null : location.text.trim(),
      );
    } else {
      await api.updateSensorInfo(
        id: id,
        name: name.text.trim(),
        manageNo: manageNo.text.trim(),
        level1Lower: lowerV ?? SensorApi.kClearValue,
        level1Upper: upperV ?? SensorApi.kClearValue,
        installDate:
            install.text.trim().isEmpty ? null : install.text.trim(),
        locationDesc:
            location.text.trim().isEmpty ? null : location.text.trim(),
      );
    }
    if (!context.mounted) return;
    onUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('센서 정보가 저장되었습니다.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('저장 실패: $e')),
    );
  }
}

Future<void> _showThresholdDialog(
  BuildContext context,
  WidgetRef ref, {
  required SensorDetailItem sensor,
  required String sensorId,
  required VoidCallback onUpdated,
}) async {
  final normal = TextEditingController(
      text: sensor.thresholdNormalMax?.toString() ?? '');
  final warning = TextEditingController(
      text: sensor.thresholdWarningMax?.toString() ?? '');
  final danger = TextEditingController(
      text: sensor.thresholdDangerMin?.toString() ?? '');

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => AlertDialog(
      title: const Text('임계치 편집'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: normal,
              decoration: const InputDecoration(
                  labelText: '정상 최대 (threshold_normal_max)'),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            ),
            TextField(
              controller: warning,
              decoration: const InputDecoration(
                  labelText: '주의 최대 (threshold_warning_max)'),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            ),
            TextField(
              controller: danger,
              decoration: const InputDecoration(
                  labelText: '위험 최소 (threshold_danger_min)'),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '* 빈 값은 기준 미설정으로 저장됩니다.',
                style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장')),
      ],
    ),
  );
  if (ok != true) return;
  final id = int.tryParse(sensorId);
  if (id == null) return;
  double? parse(String s) =>
      s.trim().isEmpty ? null : double.tryParse(s.trim());
  try {
    await ref.read(sensorApiProvider).updateSensorThreshold(
          id: id,
          thresholdNormalMax: parse(normal.text),
          thresholdWarningMax: parse(warning.text),
          thresholdDangerMin: parse(danger.text),
        );
    if (!context.mounted) return;
    onUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('임계치가 저장되었습니다.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('저장 실패: $e')),
    );
  }
}

Future<void> _showFormulaDialog(
  BuildContext context,
  WidgetRef ref, {
  required SensorDetailItem sensor,
  required String sensorId,
  required String depthLabel,
  required VoidCallback onUpdated,
}) async {
  final api = ref.read(sensorApiProvider);
  List<FormulaItem> formulas = const [];
  try {
    formulas = await api.fetchFormulas();
  } catch (_) {}
  if (!context.mounted) return;

  int? selectedFormulaId = sensor.formulaId;
  final params = <String, TextEditingController>{};
  final initialParams = sensor.formulaParams;
  // 80053 depth별 키(예: G_1, A_1, B_1, C_1) 또는 단일 키 (G, A, B, C, I)
  final keys = <String>{
    ...initialParams.keys,
    if (sensor.sensorCode == '80053') ...[
      'G',
      'A',
      'B',
      'C',
      'I',
    ],
  }.toList()
    ..sort();
  for (final k in keys) {
    params[k] = TextEditingController(
      text: (initialParams[k] ?? '').toString(),
    );
  }

  final newKeyCtrl = TextEditingController();
  final newValCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('계산식 / 파라미터'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('계산식 선택',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted)),
                const SizedBox(height: 4),
                DropdownButton<int?>(
                  value: selectedFormulaId,
                  isExpanded: true,
                  hint: const Text('— 선택 안함 —',
                      style: TextStyle(fontSize: 12)),
                  items: <DropdownMenuItem<int?>>[
                    const DropdownMenuItem(
                        value: null,
                        child: Text('— 선택 안함 —',
                            style: TextStyle(fontSize: 12))),
                    ...formulas.map(
                      (f) => DropdownMenuItem(
                        value: f.id,
                        child: Text(
                          f.name.isEmpty ? '식 #${f.id}' : f.name,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => selectedFormulaId = v),
                ),
                const SizedBox(height: 12),
                const Text('파라미터 (formula_params)',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkMuted)),
                const SizedBox(height: 4),
                if (params.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '등록된 파라미터가 없습니다. 아래에서 추가해 주세요.',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.inkMuted),
                    ),
                  )
                else
                  ...params.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 64,
                            child: Text(
                              e.key,
                              style:
                                  const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: e.value,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                              style: const TextStyle(fontSize: 12),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                            ),
                          ),
                          IconButton(
                            tooltip: '삭제',
                            iconSize: 16,
                            onPressed: () => setLocal(() {
                              params[e.key]?.dispose();
                              params.remove(e.key);
                            }),
                            icon: const Icon(Icons.close,
                                color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 16),
                const Text('파라미터 추가',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.inkMuted)),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: newKeyCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'KEY',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: newValCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'VALUE',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 12),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                      ),
                    ),
                    IconButton(
                      tooltip: '추가',
                      onPressed: () {
                        final k = newKeyCtrl.text.trim();
                        if (k.isEmpty) return;
                        setLocal(() {
                          params[k] = TextEditingController(
                              text: newValCtrl.text.trim());
                          newKeyCtrl.clear();
                          newValCtrl.clear();
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppColors.brand),
                    ),
                  ],
                ),
                if (sensor.sensorCode == '80053') ...[
                  const SizedBox(height: 8),
                  const Text(
                    '* 80053 센서는 depth별로 _1/_2/_3 접미사를 사용할 수 있습니다.',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.inkMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final id = int.tryParse(sensorId);
  if (id == null) return;

  final fp = <String, dynamic>{};
  params.forEach((k, c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return;
    fp[k] = double.tryParse(raw) ?? raw;
  });

  try {
    await ref.read(sensorApiProvider).updateSensorInfo(
          id: id,
          formulaId: selectedFormulaId ?? SensorApi.kClearValue,
          formulaParams: fp,
        );
    if (!context.mounted) return;
    onUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('계산식/파라미터가 저장되었습니다.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('저장 실패: $e')),
    );
  } finally {
    for (final c in params.values) {
      c.dispose();
    }
    newKeyCtrl.dispose();
    newValCtrl.dispose();
  }
}

Future<void> _showFloorPlanUploadDialog(
  BuildContext context,
  WidgetRef ref, {
  required String sensorId,
  required VoidCallback onUpdated,
}) async {
  final id = int.tryParse(sensorId);
  if (id == null) return;
  final picked = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf'],
  );
  if (picked == null || picked.files.isEmpty) return;
  final f = picked.files.first;
  final bytes = f.bytes;
  if (bytes == null || f.name.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('파일을 읽을 수 없습니다.')),
    );
    return;
  }
  try {
    await ref.read(sensorApiProvider).uploadSensorFloorPlan(
          id: id,
          bytes: bytes,
          filename: f.name,
        );
    if (!context.mounted) return;
    onUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('평면도가 업로드되었습니다: ${f.name}')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('업로드 실패: $e')),
    );
  }
}

Future<void> _showCorrectionDialog(
  BuildContext context,
  WidgetRef ref, {
  required SensorDetailItem sensor,
  required String sensorId,
  required String initialDepth,
  required VoidCallback onUpdated,
}) async {
  String depth = ['1', '2', '3'].contains(initialDepth) ? initialDepth : '1';
  final value = TextEditingController(
    text: (sensor.correctionParams[depth] ?? 0).toString(),
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('초기값(기준점) 보정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: depth,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: '1', child: Text('Depth 1')),
                DropdownMenuItem(value: '2', child: Text('Depth 2')),
                DropdownMenuItem(value: '3', child: Text('Depth 3')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  depth = v;
                  value.text = (sensor.correctionParams[v] ?? 0).toString();
                });
              },
            ),
            TextField(
              controller: value,
              decoration: const InputDecoration(labelText: '보정값 (-100 ~ 100)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('적용')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final sensorNumId = int.tryParse(sensorId);
  final v = double.tryParse(value.text.trim());
  if (sensorNumId == null || v == null || v < -100 || v > 100) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('보정값은 -100 ~ 100 범위의 숫자여야 합니다.')),
    );
    return;
  }
  try {
    final next = <String, dynamic>{...sensor.correctionParams, depth: v};
    await ref.read(sensorApiProvider).updateSensorInfo(
          id: sensorNumId,
          correctionParams: next,
        );
    if (!context.mounted) return;
    onUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('보정값이 저장되었습니다.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('보정값 저장 실패: $e')),
    );
  }
}

Future<void> _showIconPositionDialog(
  BuildContext context,
  WidgetRef ref, {
  required SensorDetailItem sensor,
  required String depthLabel,
  required VoidCallback onUpdated,
}) async {
  if (sensor.siteDbId == null) return;
  final baseKey = sensor.id.toString();
  final initialKey = sensor.sensorCode == '80053'
      ? '$baseKey:${depthLabel.isEmpty ? '1' : depthLabel}'
      : baseKey;
  final current = sensor.sensorPositions[initialKey] ?? const <String, dynamic>{};
  final label = TextEditingController(text: (current['label'] ?? initialKey).toString());
  final x = TextEditingController(text: (asDouble(current['x']) ?? 0.5).toString());
  final y = TextEditingController(text: (asDouble(current['y']) ?? 0.5).toString());
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('평면도 아이콘 위치 저장'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('키: $initialKey', style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
          const SizedBox(height: 8),
          TextField(controller: label, decoration: const InputDecoration(labelText: '아이콘 라벨')),
          TextField(
            controller: x,
            decoration: const InputDecoration(labelText: 'X 좌표(0~1)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          TextField(
            controller: y,
            decoration: const InputDecoration(labelText: 'Y 좌표(0~1)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('저장')),
      ],
    ),
  );
  if (ok != true) return;
  final dx = double.tryParse(x.text.trim());
  final dy = double.tryParse(y.text.trim());
  if (dx == null || dy == null || dx < 0 || dx > 1 || dy < 0 || dy > 1) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('좌표는 0~1 범위의 숫자여야 합니다.')),
    );
    return;
  }
  try {
    final next = <String, dynamic>{...sensor.sensorPositions};
    next[initialKey] = {
      'label': label.text.trim().isEmpty ? initialKey : label.text.trim(),
      'x': dx,
      'y': dy,
    };
    await ref.read(sensorApiProvider).updateSiteSensorPositions(
          siteId: sensor.siteDbId!,
          positions: next,
        );
    if (!context.mounted) return;
    onUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('아이콘 위치가 저장되었습니다.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('아이콘 위치 저장 실패: $e')),
    );
  }
}

class _TrendTab extends StatelessWidget {
  const _TrendTab({
    required this.sensorId,
    required this.from,
    required this.to,
    required this.chartMode,
    required this.selectedHour,
    required this.depthLabel,
    required this.preferLinear,
    required this.level1Upper,
    required this.level1Lower,
    required this.rangeDays,
    required this.onRangeChanged,
    required this.onChartModeChanged,
    required this.onSelectedHourChanged,
    required this.onDepthLabelChanged,
    required this.onApplyQuery,
  });

  final String sensorId;
  final String from;
  final String to;
  final String chartMode;
  final int selectedHour;
  final String depthLabel;
  final bool preferLinear;
  final double? level1Upper;
  final double? level1Lower;
  final int rangeDays;
  final ValueChanged<int> onRangeChanged;
  final ValueChanged<String> onChartModeChanged;
  final ValueChanged<int> onSelectedHourChanged;
  final ValueChanged<String> onDepthLabelChanged;
  final VoidCallback onApplyQuery;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return ListView(
          children: [
            const SectionTitle('트렌드'),
            const SizedBox(height: 8),
            GeoCard(
              child: FutureBuilder<List<SensorMeasurement>>(
                future: AppConfig.demoMode
                    ? Future.value(const [])
                    : _loadMeasurements(
                        ref,
                        sensorId: sensorId,
                        from: from,
                        to: to,
                        depthLabel: depthLabel,
                        preferLinear: preferLinear,
                      ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final rawRows = snapshot.data ?? const <SensorMeasurement>[];
                  final rows = _buildDisplayPoints(
                    rawRows,
                    chartMode: chartMode,
                    selectedHour: selectedHour,
                    from: from,
                    to: to,
                    preferLinear: preferLinear,
                  );
                  final values = rows.where((e) => e.value != null).map((e) => e.value!).toList();
                  final count = rows.length;
                  final minV = values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b);
                  final maxV = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
                  final latest = values.isEmpty ? null : values.last;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _RangeButton(label: '오늘', active: rangeDays == 1, onTap: () => onRangeChanged(1)),
                          const SizedBox(width: 6),
                          _RangeButton(label: '7일', active: rangeDays == 7, onTap: () => onRangeChanged(7)),
                          const SizedBox(width: 6),
                          _RangeButton(label: '30일', active: rangeDays == 30, onTap: () => onRangeChanged(30)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: chartMode,
                            items: const [
                              DropdownMenuItem(value: 'hourly', child: Text('시간별')),
                              DropdownMenuItem(value: 'daily', child: Text('일별')),
                            ],
                            onChanged: (v) => onChartModeChanged(v ?? 'hourly'),
                          ),
                          const SizedBox(width: 10),
                          if (chartMode == 'daily')
                            DropdownButton<int>(
                              value: selectedHour,
                              items: List.generate(
                                24,
                                (i) => DropdownMenuItem(value: i, child: Text('${i.toString().padLeft(2, '0')}시')),
                              ),
                              onChanged: (v) => onSelectedHourChanged(v ?? 12),
                            ),
                          const Spacer(),
                          DropdownButton<String>(
                            value: depthLabel.isEmpty ? 'all' : depthLabel,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Depth 전체')),
                              DropdownMenuItem(value: '1', child: Text('Depth 1')),
                              DropdownMenuItem(value: '2', child: Text('Depth 2')),
                              DropdownMenuItem(value: '3', child: Text('Depth 3')),
                            ],
                            onChanged: (v) => onDepthLabelChanged(v == 'all' ? '' : (v ?? '')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: onApplyQuery,
                          child: const Text('조회'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: rows.isEmpty
                            ? const Center(
                                child: Text('차트 데이터 없음', style: TextStyle(color: AppColors.inkMuted)),
                              )
                            : CustomPaint(
                                painter: _SparklinePainter(
                                  points: rows,
                                  upper: level1Upper,
                                  lower: level1Lower,
                                ),
                                child: const SizedBox.expand(),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('건수 $count', style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                          const SizedBox(width: 10),
                          Text('최소 ${minV.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                          const SizedBox(width: 10),
                          Text('최대 ${maxV.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                          const Spacer(),
                          Text(
                            latest == null ? '-' : '현재 ${latest.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.ink),
                          ),
                        ],
                      ),
                      if (level1Lower != null || level1Upper != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (level1Lower != null)
                              _LegendChip(
                                color: AppColors.danger,
                                label: '1차 하한 ${level1Lower!.toStringAsFixed(2)}',
                              ),
                            if (level1Upper != null)
                              _LegendChip(
                                color: AppColors.warning,
                                label: '1차 상한 ${level1Upper!.toStringAsFixed(2)}',
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LogTab extends StatefulWidget {
  const _LogTab({
    required this.sensorId,
    required this.from,
    required this.to,
    required this.chartMode,
    required this.selectedHour,
    required this.depthLabel,
    required this.preferLinear,
    required this.level1Upper,
    required this.level1Lower,
  });

  final String sensorId;
  final String from;
  final String to;
  final String chartMode;
  final int selectedHour;
  final String depthLabel;
  final bool preferLinear;
  final double? level1Upper;
  final double? level1Lower;

  @override
  State<_LogTab> createState() => _LogTabState();
}

class _LogTabState extends State<_LogTab> {
  int _page = 1;

  @override
  void didUpdateWidget(covariant _LogTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final queryChanged = oldWidget.from != widget.from ||
        oldWidget.to != widget.to ||
        oldWidget.chartMode != widget.chartMode ||
        oldWidget.selectedHour != widget.selectedHour ||
        oldWidget.depthLabel != widget.depthLabel;
    if (queryChanged) _page = 1;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return ListView(
          children: [
            const SectionTitle('측정 로그'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _InfoChip('기간 ${_rangeLabel(widget.from, widget.to)}'),
                _InfoChip('모드 ${widget.chartMode == 'hourly' ? '시간별' : '일별'}'),
                if (widget.chartMode == 'daily') _InfoChip('시각 ${widget.selectedHour}시'),
                _InfoChip('Depth ${widget.depthLabel.isEmpty ? '전체' : widget.depthLabel}'),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.chartMode == 'hourly')
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '미래 시간 슬롯은 자동으로 숨김 처리됩니다.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
              ),
            FutureBuilder<List<SensorMeasurement>>(
              future: AppConfig.demoMode
                  ? Future.value(const [])
                  : _loadMeasurements(
                      ref,
                      sensorId: widget.sensorId,
                      from: widget.from,
                      to: widget.to,
                      depthLabel: widget.depthLabel,
                      preferLinear: widget.preferLinear,
                    ),
              builder: (context, snapshot) {
                final baseRows = snapshot.data ?? const <SensorMeasurement>[];
                final rows = _buildDisplayPoints(
                  baseRows,
                  chartMode: widget.chartMode,
                  selectedHour: widget.selectedHour,
                  from: widget.from,
                  to: widget.to,
                  preferLinear: widget.preferLinear,
                );
                const pageSize = 15;
                final totalPages = rows.isEmpty ? 1 : ((rows.length - 1) ~/ pageSize) + 1;
                final safePage = _page.clamp(1, totalPages);
                final start = (safePage - 1) * pageSize;
                final end = (start + pageSize).clamp(0, rows.length);
                final pageRows = rows.sublist(start, end);
                return GeoCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      if (rows.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '로그 데이터가 없습니다.',
                            style: TextStyle(color: AppColors.inkMuted),
                          ),
                        )
                      else
                        ...pageRows.map(
                          (m) => Container(
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.line),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(_timestampLabel(m.timestamp.toLocal())),
                              subtitle: Row(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: m.received
                                          ? AppColors.normalBg
                                          : AppColors.offlineBg,
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: m.received
                                            ? AppColors.normalBorder
                                            : AppColors.offlineBorder,
                                      ),
                                    ),
                                    child: Text(
                                      m.received ? '수신' : '미수신',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: m.received
                                            ? AppColors.normalText
                                            : AppColors.offlineText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                m.value == null
                                    ? '—'
                                    : m.value!.toStringAsFixed(2),
                                style: TextStyle(
                                  color: _valueColor(
                                    m.value,
                                    upper: widget.level1Upper,
                                    lower: widget.level1Lower,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Text(
                              '페이지 $safePage / $totalPages',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.inkMuted),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: safePage > 1
                                  ? () => setState(() => _page = safePage - 1)
                                  : null,
                              child: const Text('이전',
                                  style: TextStyle(fontSize: 11)),
                            ),
                            TextButton(
                              onPressed: safePage < totalPages
                                  ? () => setState(() => _page = safePage + 1)
                                  : null,
                              child: const Text('다음',
                                  style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

String _timeAgo(DateTime? date) {
  if (date == null) return '-';
  final now = DateTime.now();
  final diff = now.difference(date.toLocal());
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}

String _timestampLabel(DateTime t) {
  final mm = t.month.toString().padLeft(2, '0');
  final dd = t.day.toString().padLeft(2, '0');
  final hh = t.hour.toString().padLeft(2, '0');
  final min = t.minute.toString().padLeft(2, '0');
  return '${t.year}-$mm-$dd $hh:$min';
}

SensorDetailItem _mockSensor(String id) {
  final sensor = DemoMockData.sensors.firstWhere(
    (item) => item.id == id,
    orElse: () => const SensorSummary(
      id: '0',
      name: '알 수 없는 센서',
      status: '오프라인',
      lastReceived: '-',
    ),
  );
  return SensorDetailItem(
    id: int.tryParse(sensor.id) ?? 0,
    name: sensor.name,
    sensorCode: sensor.name,
    status: sensor.status,
    lastReceived: null,
    currentValue: null,
    unit: '',
    siteName: '—',
    level1Upper: null,
    level1Lower: null,
    installDate: null,
    locationDesc: null,
    correctionParams: const {},
    siteDbId: null,
    sensorPositions: const {},
  );
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({required this.label, required this.onTap, this.active = false});
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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

class _DepthChip extends StatelessWidget {
  const _DepthChip({
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.brand.withValues(alpha: 0.12) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.brand : AppColors.line),
        ),
        child: Text(
          'D$label',
          style: TextStyle(
            fontSize: 10,
            color: active ? AppColors.brand : AppColors.inkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    this.upper,
    this.lower,
  });

  final List<_DisplayPoint> points;
  final double? upper;
  final double? lower;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.where((p) => p.value != null).map((p) => p.value!).toList();
    if (values.length < 2) return;
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if (upper != null) maxV = maxV > upper! ? maxV : upper!;
    if (lower != null) minV = minV < lower! ? minV : lower!;
    final span = (maxV - minV).abs() < 0.000001 ? 1.0 : (maxV - minV);

    void drawBaseline(double value, Color color) {
      final yNorm = (value - minV) / span;
      final y = size.height - (yNorm * size.height);
      final p = Paint()
        ..color = color
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      const dash = 5.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width), y), p);
        x += dash * 2;
      }
    }

    if (upper != null) drawBaseline(upper!, AppColors.warning);
    if (lower != null) drawBaseline(lower!, AppColors.danger);

    final neutralLinePaint = Paint()
      ..color = AppColors.brand.withValues(alpha: 0.9)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final warningLinePaint = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dangerLinePaint = Paint()
      ..color = AppColors.danger
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final gapPaint = Paint()
      ..color = AppColors.inkMuted.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    Path? path;
    var hasStarted = false;
    for (var i = 0; i < points.length; i++) {
      final v = points[i].value;
      final x = points.length <= 1 ? 0.0 : (i / (points.length - 1) * size.width);
      if (v == null) {
        canvas.drawCircle(Offset(x, size.height - 4), 1.8, gapPaint);
        if (path != null) {
          canvas.drawPath(path, neutralLinePaint);
          path = null;
          hasStarted = false;
        }
        continue;
      }
      final yNorm = (v - minV) / span;
      final y = size.height - (yNorm * size.height);
      path ??= Path();
      if (!hasStarted) {
        path.moveTo(x, y);
        hasStarted = true;
      } else {
        path.lineTo(x, y);
      }
    }
    if (path != null) canvas.drawPath(path, neutralLinePaint);

    // 상태 구간선 오버레이: 웹 톤과 유사하게 위험/주의 구간 강조
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1].value;
      final cur = points[i].value;
      if (prev == null || cur == null) continue;
      final x1 = points.length <= 1 ? 0.0 : ((i - 1) / (points.length - 1) * size.width);
      final x2 = points.length <= 1 ? 0.0 : (i / (points.length - 1) * size.width);
      final y1 = size.height - (((prev - minV) / span) * size.height);
      final y2 = size.height - (((cur - minV) / span) * size.height);
      final stateColor = _segmentPaint(prev, cur, upper: upper, lower: lower, warning: warningLinePaint, danger: dangerLinePaint);
      if (stateColor != null) {
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stateColor);
      }
    }

    // 포인트 상태색 표시 (정상/주의/위험)
    for (var i = 0; i < points.length; i++) {
      final v = points[i].value;
      if (v == null) continue;
      final x = points.length <= 1 ? 0.0 : (i / (points.length - 1) * size.width);
      final yNorm = (v - minV) / span;
      final y = size.height - (yNorm * size.height);
      final pointPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = _pointColor(v, upper: upper, lower: lower);
      canvas.drawCircle(Offset(x, y), 2.4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.upper != upper ||
        oldDelegate.lower != lower;
  }
}

Color _pointColor(double value, {double? upper, double? lower}) {
  if (lower != null && value < lower) return AppColors.danger;
  if (upper != null && value > upper) return AppColors.warning;
  return AppColors.normal;
}

Paint? _segmentPaint(
  double a,
  double b, {
  required double? upper,
  required double? lower,
  required Paint warning,
  required Paint danger,
}) {
  final overUpper = upper != null && (a > upper || b > upper);
  final underLower = lower != null && (a < lower || b < lower);
  if (underLower) return danger;
  if (overUpper) return warning;
  return null;
}

class _DisplayPoint {
  const _DisplayPoint({
    required this.timestamp,
    required this.value,
    required this.received,
  });

  final DateTime timestamp;
  final double? value;
  final bool received;
}

List<_DisplayPoint> _buildDisplayPoints(
  List<SensorMeasurement> input, {
  required String chartMode,
  required int selectedHour,
  required String from,
  required String to,
  required bool preferLinear,
}) {
  double? pickValue(SensorMeasurement m) => preferLinear ? (m.linearValue ?? m.value) : m.value;

  if (chartMode == 'daily') {
    final map = <String, _DisplayPoint>{};
    for (final m in input) {
      final t = m.timestamp.toLocal();
      if (t.hour != selectedHour) continue;
      final k = _dateOnly(t);
      map.putIfAbsent(
        k,
        () => _DisplayPoint(timestamp: t, value: pickValue(m), received: true),
      );
    }
    final list = map.values.toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  final map = <String, SensorMeasurement>{};
  for (final m in input) {
    final t = m.timestamp.toLocal();
    final key = '${_dateOnly(t)}T${t.hour.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => m);
  }
  final fromDt = DateTime.parse('${from}T00:00:00');
  final toDt = DateTime.parse('${to}T23:00:00');
  final now = DateTime.now();
  final end = toDt.isAfter(now) ? DateTime(now.year, now.month, now.day, now.hour) : toDt;
  final list = <_DisplayPoint>[];
  for (var t = fromDt; !t.isAfter(end); t = t.add(const Duration(hours: 1))) {
    final key = '${_dateOnly(t)}T${t.hour.toString().padLeft(2, '0')}';
    final m = map[key];
    if (m == null) {
      list.add(_DisplayPoint(timestamp: t, value: null, received: false));
    } else {
      list.add(_DisplayPoint(timestamp: t, value: pickValue(m), received: true));
    }
  }
  list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return list;
}

String _dateOnly(DateTime d) {
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

String _rangeLabel(String from, String to) {
  if (from == to) return from;
  return '$from ~ $to';
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

Color _valueColor(double? v, {double? upper, double? lower}) {
  if (v == null) return AppColors.inkMuted;
  if (upper != null && v > upper) return AppColors.warningText;
  if (lower != null && v < lower) return AppColors.dangerText;
  return AppColors.ink;
}

Future<List<SensorMeasurement>> _loadMeasurements(
  WidgetRef ref, {
  required String sensorId,
  required String from,
  required String to,
  required String depthLabel,
  required bool preferLinear,
}) {
  final api = ref.read(sensorApiProvider);
  // 웹 프론트와 동일: 80053 depth 2는 depth1/3 동시간 평균으로 표시
  if (preferLinear && depthLabel == '2') {
    return api.fetchDepth2AveragedMeasurements(sensorId, from: from, to: to, limit: 2000);
  }
  return api.fetchMeasurements(
    sensorId,
    from: from,
    to: to,
    depthLabel: depthLabel.isEmpty ? null : depthLabel,
    limit: 2000,
  );
}

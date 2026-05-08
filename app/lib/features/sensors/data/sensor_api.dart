import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/json_parse.dart';

class SensorListItem {
  const SensorListItem({
    required this.id,
    required this.name,
    required this.sensorCode,
    required this.siteCode,
    required this.siteName,
    required this.status,
    required this.lastReceived,
    required this.currentValue,
    required this.unit,
    this.manageNo = '',
    this.field = '공통',
    this.thresholdNormalMax,
    this.thresholdWarningMax,
    this.thresholdDangerMin,
  });

  final int id;
  final String name;
  final String sensorCode;
  final String siteCode;
  final String siteName;
  final String status;
  final DateTime? lastReceived;
  final double? currentValue;
  final String unit;
  final String manageNo;
  final String field;
  final double? thresholdNormalMax;
  final double? thresholdWarningMax;
  final double? thresholdDangerMin;
}

class SensorDetailItem {
  const SensorDetailItem({
    required this.id,
    required this.name,
    required this.sensorCode,
    required this.status,
    required this.lastReceived,
    required this.currentValue,
    required this.unit,
    required this.siteName,
    required this.level1Upper,
    required this.level1Lower,
    required this.installDate,
    required this.locationDesc,
    required this.correctionParams,
    required this.siteDbId,
    required this.sensorPositions,
    this.thresholdNormalMax,
    this.thresholdWarningMax,
    this.thresholdDangerMin,
    this.formulaId,
    this.formulaParams = const <String, dynamic>{},
    this.depthCriteria = const <String, Map<String, double?>>{},
    this.field = '공통',
    this.manageNo = '',
    this.hasFloorPlan = false,
  });

  final int id;
  final String name;
  final String sensorCode;
  final String status;
  final DateTime? lastReceived;
  final double? currentValue;
  final String unit;
  final String siteName;
  final double? level1Upper;
  final double? level1Lower;
  final String? installDate;
  final String? locationDesc;
  final Map<String, double> correctionParams;
  final int? siteDbId;
  final Map<String, Map<String, dynamic>> sensorPositions;
  final double? thresholdNormalMax;
  final double? thresholdWarningMax;
  final double? thresholdDangerMin;
  final int? formulaId;
  final Map<String, dynamic> formulaParams;
  final Map<String, Map<String, double?>> depthCriteria;
  final String field;
  final String manageNo;
  final bool hasFloorPlan;
}

class SensorMeasurement {
  const SensorMeasurement({
    required this.timestamp,
    required this.value,
    required this.linearValue,
    required this.rawValue,
    required this.depthLabel,
  });

  final DateTime timestamp;
  final double value;
  final double? linearValue;
  final double? rawValue;
  final String? depthLabel;
}

class AlarmListItem {
  const AlarmListItem({
    required this.id,
    required this.sensorId,
    required this.sensorCode,
    required this.sensorName,
    required this.siteName,
    required this.severity,
    required this.message,
    required this.triggeredAt,
    required this.isAcknowledged,
    required this.acknowledgedBy,
    required this.acknowledgedAt,
    this.triggeredValue,
    this.thresholdValue,
    this.unit = '',
    this.manageNo = '',
  });

  final int id;
  final int sensorId;
  final String sensorCode;
  final String sensorName;
  final String siteName;
  final String severity;
  final String message;
  final DateTime? triggeredAt;
  final bool isAcknowledged;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final double? triggeredValue;
  final double? thresholdValue;
  final String unit;
  final String manageNo;
}

class SiteListItem {
  const SiteListItem({
    required this.id,
    required this.siteCode,
    required this.name,
    required this.location,
    required this.managers,
    this.description = '',
    this.hasFloorPlan = false,
  });

  final int id;
  final String siteCode;
  final String name;
  final String location;
  final List<String> managers;
  final String description;
  final bool hasFloorPlan;
}

class UserListItem {
  const UserListItem({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.phone,
    required this.isActive,
    this.isDeleted = false,
    this.createdAt,
    this.lastLogin,
  });

  final int id;
  final String username;
  final String email;
  final String role;
  final String phone;
  final bool isActive;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? lastLogin;
}

class FileListItem {
  const FileListItem({
    required this.id,
    required this.originalName,
    required this.fileSize,
    required this.uploadedByName,
    required this.createdAt,
  });

  final int id;
  final String originalName;
  final int fileSize;
  final String uploadedByName;
  final DateTime? createdAt;
}

class DownloadedFile {
  const DownloadedFile({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final List<int> bytes;
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalSensors,
    required this.normalCount,
    required this.warningCount,
    required this.dangerCount,
    required this.offlineCount,
    required this.activeAlarms,
  });

  final int totalSensors;
  final int normalCount;
  final int warningCount;
  final int dangerCount;
  final int offlineCount;
  final int activeAlarms;
}

class FormulaItem {
  const FormulaItem({
    required this.id,
    required this.name,
    required this.expression,
    required this.description,
  });

  final int id;
  final String name;
  final String expression;
  final String description;
}

class RecollectItem {
  const RecollectItem({
    required this.id,
    required this.sensorId,
    required this.status,
    required this.dateFrom,
    required this.dateTo,
    required this.reason,
    required this.createdAt,
  });

  final int id;
  final int sensorId;
  final String status;
  final String? dateFrom;
  final String? dateTo;
  final String reason;
  final DateTime? createdAt;
}

class AgentStatusItem {
  const AgentStatusItem({
    required this.isOnline,
    required this.lastSeenAt,
  });

  final bool isOnline;
  final DateTime? lastSeenAt;
}

class SensorApi {
  const SensorApi(this._dio);
  final Dio _dio;

  Future<List<SensorListItem>> fetchSensors({String? status}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/sensors',
      queryParameters: status == null ? null : {'status': status},
    );
    final data = res.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => SensorListItem(
              id: asInt(e['id']) ?? 0,
              name: (e['name'] ?? '').toString(),
              sensorCode: (e['sensor_code'] ?? '').toString(),
              siteCode: (e['site_code'] ?? '').toString(),
              siteName: (e['site_name'] ?? '—').toString(),
              status: _toKoreanStatus((e['status'] ?? '').toString()),
              lastReceived: DateTime.tryParse((e['last_measured'] ?? '').toString()),
              currentValue: asDouble(e['current_value']),
              unit: (e['unit'] ?? '').toString(),
              manageNo: (e['manage_no'] ?? '').toString(),
              field: (e['field'] ?? '공통').toString(),
              thresholdNormalMax: asDouble(e['threshold_normal_max']),
              thresholdWarningMax: asDouble(e['threshold_warning_max']),
              thresholdDangerMin: asDouble(e['threshold_danger_min']),
            ))
        .toList();
  }

  Future<SensorDetailItem> fetchSensorById(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/sensors/$id');
    final e = res.data ?? <String, dynamic>{};
    final rawDc = (e['depth_criteria'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final depthCriteria = rawDc.map<String, Map<String, double?>>((k, v) {
      final m = (v as Map<String, dynamic>? ?? const <String, dynamic>{});
      return MapEntry(k, {
        'upper': asDouble(m['upper']),
        'lower': asDouble(m['lower']),
      });
    });
    return SensorDetailItem(
      id: asInt(e['id']) ?? 0,
      name: (e['name'] ?? '').toString(),
      sensorCode: (e['sensor_code'] ?? '').toString(),
      status: _toKoreanStatus((e['status'] ?? '').toString()),
      lastReceived: DateTime.tryParse((e['last_measured'] ?? '').toString()),
      currentValue: asDouble(e['current_value']),
      unit: (e['unit'] ?? '').toString(),
      siteName: (e['site_name'] ?? '—').toString(),
      level1Upper: asDouble(e['level1_upper']),
      level1Lower: asDouble(e['level1_lower']),
      installDate: e['install_date']?.toString(),
      locationDesc: e['location_desc']?.toString(),
      correctionParams: ((e['correction_params'] as Map<String, dynamic>?) ?? const <String, dynamic>{})
          .map((k, v) => MapEntry(k, asDouble(v) ?? 0)),
      siteDbId: asInt(e['site_db_id']),
      sensorPositions: ((e['sensor_positions'] as Map<String, dynamic>?) ?? const <String, dynamic>{})
          .map(
            (k, v) => MapEntry(
              k,
              (v as Map<String, dynamic>? ?? const <String, dynamic>{}),
            ),
          ),
      thresholdNormalMax: asDouble(e['threshold_normal_max']),
      thresholdWarningMax: asDouble(e['threshold_warning_max']),
      thresholdDangerMin: asDouble(e['threshold_danger_min']),
      formulaId: asInt(e['formula_id']),
      formulaParams:
          (e['formula_params'] as Map<String, dynamic>?) ?? const {},
      depthCriteria: depthCriteria,
      field: (e['field'] ?? '공통').toString(),
      manageNo: (e['manage_no'] ?? '').toString(),
      hasFloorPlan: e['has_floor_plan'] == true ||
          e['floor_plan_url'] != null ||
          e['site_floor_plan_url'] != null,
    );
  }

  // ignore: constant_identifier_names
  static const Object kClearValue = '__SENSOR_CLEAR_VALUE__';

  static dynamic _passNullable(Object? v) =>
      identical(v, kClearValue) ? null : v;

  Future<void> updateSensorInfo({
    required int id,
    String? name,
    String? unit,
    String? formula,
    Object? level1Upper,
    Object? level1Lower,
    Map<String, dynamic>? formulaParams,
    Map<String, dynamic>? correctionParams,
    Map<String, dynamic>? depthCriteria,
    Object? formulaId,
    String? installDate,
    String? locationDesc,
    String? field,
    String? manageNo,
  }) async {
    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (unit != null) 'unit': unit,
      if (formula != null) 'formula': formula,
      if (level1Upper != null) 'level1_upper': _passNullable(level1Upper),
      if (level1Lower != null) 'level1_lower': _passNullable(level1Lower),
      if (formulaParams != null) 'formula_params': formulaParams,
      if (correctionParams != null) 'correction_params': correctionParams,
      if (depthCriteria != null) 'depth_criteria': depthCriteria,
      if (formulaId != null) 'formula_id': _passNullable(formulaId),
      if (installDate != null) 'install_date': installDate,
      if (locationDesc != null) 'location_desc': locationDesc,
      if (field != null) 'field': field,
      if (manageNo != null) 'manage_no': manageNo,
    };
    await _dio.patch('/api/sensors/$id', data: payload);
  }

  Future<void> uploadSensorFloorPlan({
    required int id,
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post('/api/sensors/$id/floor-plan', data: form);
  }

  Future<void> uploadSiteFloorPlan({
    required int id,
    required List<int> bytes,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post('/api/sites/$id/floor-plan', data: form);
  }

  Future<void> updateSensorThreshold({
    required int id,
    required double? thresholdNormalMax,
    required double? thresholdWarningMax,
    required double? thresholdDangerMin,
  }) async {
    await _dio.patch(
      '/api/sensors/$id/threshold',
      data: {
        'threshold_normal_max': thresholdNormalMax,
        'threshold_warning_max': thresholdWarningMax,
        'threshold_danger_min': thresholdDangerMin,
      },
    );
  }

  Future<void> updateSiteSensorPositions({
    required int siteId,
    required Map<String, dynamic> positions,
  }) async {
    await _dio.patch(
      '/api/sites/$siteId/sensor-positions',
      data: {'positions': positions},
    );
  }

  Future<List<SensorMeasurement>> fetchMeasurements(
    String id, {
    String? from,
    String? to,
    String? depthLabel,
    int limit = 24,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;
    if (depthLabel != null && depthLabel.isNotEmpty) query['depthLabel'] = depthLabel;
    final res = await _dio.get<List<dynamic>>(
      '/api/sensors/$id/measurements',
      queryParameters: query,
    );
    final data = res.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => SensorMeasurement(
              timestamp: DateTime.tryParse((e['measured_at'] ?? '').toString()) ?? DateTime.now(),
              value: asDouble(e['value']) ?? 0,
              linearValue: asDouble(e['linear_value']),
              rawValue: asDouble(e['raw_value']),
              depthLabel: e['depth_label']?.toString(),
            ))
        .toList();
  }

  Future<List<SensorMeasurement>> fetchDepth2AveragedMeasurements(
    String id, {
    String? from,
    String? to,
    int limit = 2000,
  }) async {
    final depth1 = await fetchMeasurements(id, from: from, to: to, depthLabel: '1', limit: limit);
    final depth3 = await fetchMeasurements(id, from: from, to: to, depthLabel: '3', limit: limit);

    final map1 = <String, SensorMeasurement>{};
    final map3 = <String, SensorMeasurement>{};
    for (final m in depth1) {
      map1[_hourKey(m.timestamp.toLocal())] = m;
    }
    for (final m in depth3) {
      map3[_hourKey(m.timestamp.toLocal())] = m;
    }

    final keys = <String>{...map1.keys, ...map3.keys}.toList()..sort();
    final out = <SensorMeasurement>[];
    for (final k in keys) {
      final m1 = map1[k];
      final m3 = map3[k];
      if (m1 == null && m3 == null) continue;
      final ts = m1?.timestamp ?? m3!.timestamp;
      final values = <double>[
        if (m1 != null) m1.value,
        if (m3 != null) m3.value,
      ];
      final linears = <double>[
        if (m1?.linearValue != null) m1!.linearValue!,
        if (m3?.linearValue != null) m3!.linearValue!,
      ];
      final raws = <double>[
        if (m1?.rawValue != null) m1!.rawValue!,
        if (m3?.rawValue != null) m3!.rawValue!,
      ];

      double avg(List<double> nums) => nums.isEmpty ? 0 : nums.reduce((a, b) => a + b) / nums.length;

      out.add(
        SensorMeasurement(
          timestamp: ts,
          value: avg(values),
          linearValue: linears.isEmpty ? null : avg(linears),
          rawValue: raws.isEmpty ? null : avg(raws),
          depthLabel: '2',
        ),
      );
    }
    out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return out;
  }

  Future<DashboardSummary> fetchDashboard() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/dashboard');
    final e = res.data ?? const <String, dynamic>{};
    return DashboardSummary(
      totalSensors: asInt(e['totalSensors']) ?? 0,
      normalCount: asInt(e['normalCount']) ?? 0,
      warningCount: asInt(e['warningCount']) ?? 0,
      dangerCount: asInt(e['dangerCount']) ?? 0,
      offlineCount: asInt(e['offlineCount']) ?? 0,
      activeAlarms: asInt(e['activeAlarms']) ?? 0,
    );
  }

  Future<List<AlarmListItem>> fetchAlarms({bool? acknowledged, int limit = 50}) async {
    final query = <String, dynamic>{'limit': limit};
    if (acknowledged != null) query['acknowledged'] = acknowledged;
    final res = await _dio.get<List<dynamic>>('/api/alarms', queryParameters: query);
    final data = res.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => AlarmListItem(
              id: asInt(e['id']) ?? 0,
              sensorId: asInt(e['sensor_id']) ?? 0,
              sensorCode: (e['sensor_code'] ?? '').toString(),
              sensorName: (e['sensor_name'] ?? '').toString(),
              siteName: (e['site_name'] ?? '—').toString(),
              severity: _toKoreanSeverity((e['severity'] ?? '').toString()),
              message: (e['message'] ?? '').toString(),
              triggeredAt: DateTime.tryParse((e['triggered_at'] ?? '').toString()),
              isAcknowledged: e['is_acknowledged'] == true,
              acknowledgedBy: e['acknowledged_by']?.toString(),
              acknowledgedAt: DateTime.tryParse((e['acknowledged_at'] ?? '').toString()),
              triggeredValue: asDouble(e['triggered_value']),
              thresholdValue: asDouble(e['threshold_value']),
              unit: (e['unit'] ?? '').toString(),
              manageNo: (e['manage_no'] ?? '').toString(),
            ))
        .toList();
  }

  Future<void> acknowledgeAlarm(int id, {String? acknowledgedBy}) async {
    await _dio.patch(
      '/api/alarms/$id/acknowledge',
      data: acknowledgedBy == null ? const {} : {'acknowledgedBy': acknowledgedBy},
    );
  }

  Future<List<SiteListItem>> fetchSites() async {
    final res = await _dio.get<List<dynamic>>('/api/sites');
    final data = res.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => SiteListItem(
              id: asInt(e['id']) ?? 0,
              siteCode: (e['site_code'] ?? '').toString(),
              name: (e['name'] ?? '').toString(),
              location: (e['location'] ?? '').toString(),
              description: (e['description'] ?? '').toString(),
              hasFloorPlan: e['has_floor_plan'] == true,
              managers: (e['managers'] as List<dynamic>? ?? const [])
                  .map((m) => m.toString())
                  .toList(),
            ))
        .toList();
  }

  Future<SiteListItem> createSite({
    required String name,
    required String location,
    String description = '',
    List<String> managers = const [],
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/sites',
      data: {
        'name': name,
        'location': location,
        'description': description,
        'managers': managers,
      },
    );
    final s = (res.data?['site'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return SiteListItem(
      id: asInt(s['id']) ?? 0,
      siteCode: (s['site_code'] ?? '').toString(),
      name: (s['name'] ?? '').toString(),
      location: (s['location'] ?? '').toString(),
      description: (s['description'] ?? '').toString(),
      hasFloorPlan: s['has_floor_plan'] == true,
      managers: (s['managers'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
    );
  }

  Future<void> updateSite({
    required int id,
    required String name,
    required String location,
    String description = '',
    List<String> managers = const [],
  }) async {
    await _dio.patch(
      '/api/sites/$id',
      data: {
        'name': name,
        'location': location,
        'description': description,
        'managers': managers,
      },
    );
  }

  Future<void> deleteSite(int id) async {
    await _dio.delete('/api/sites/$id');
  }

  Future<void> updateSensorSite({
    required int sensorId,
    required String siteCode,
  }) async {
    await _dio.patch(
      '/api/sensors/$sensorId/site',
      data: {'site_code': siteCode},
    );
  }

  Future<List<UserListItem>> fetchUsers() async {
    final res = await _dio.get<List<dynamic>>('/api/users/list');
    final data = res.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => UserListItem(
              id: asInt(e['id']) ?? 0,
              username: (e['username'] ?? '').toString(),
              email: (e['email'] ?? '').toString(),
              role: (e['role'] ?? '').toString(),
              phone: (e['phone'] ?? '').toString(),
              isActive: e['is_active'] == true,
              isDeleted: e['is_deleted'] == true,
              createdAt:
                  DateTime.tryParse((e['created_at'] ?? '').toString()),
              lastLogin:
                  DateTime.tryParse((e['last_login'] ?? '').toString()),
            ))
        .toList();
  }

  Future<List<FileListItem>> fetchFiles() async {
    final res = await _dio.get<List<dynamic>>('/api/files');
    final data = res.data ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => FileListItem(
              id: asInt(e['id']) ?? 0,
              originalName: (e['original_name'] ?? 'unnamed').toString(),
              fileSize: asInt(e['file_size']) ?? 0,
              uploadedByName: (e['uploaded_by_name'] ?? 'unknown').toString(),
              createdAt: DateTime.tryParse((e['created_at'] ?? '').toString()),
            ))
        .toList();
  }

  Future<void> uploadFile({
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _dio.post('/api/files/upload', data: formData);
  }

  Future<void> deleteFile(int id) async {
    await _dio.delete('/api/files/$id');
  }

  Future<void> editUser({
    required int id,
    required String username,
    required String email,
    required String role,
    String? phone,
  }) async {
    await _dio.patch(
      '/api/users/$id/edit',
      data: {
        'username': username,
        'email': email,
        'role': role,
        'phone': phone,
      }..removeWhere((key, value) => value == null),
    );
  }

  Future<void> changeUserPassword({
    required int id,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.patch(
      '/api/users/$id/password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> deactivateUser(int id) async {
    await _dio.patch('/api/users/$id/deactivate');
  }

  Future<void> activateUser(int id) async {
    await _dio.patch('/api/users/$id/activate');
  }

  Future<void> deleteUser(int id) async {
    await _dio.delete('/api/users/$id');
  }

  Future<List<FormulaItem>> fetchFormulas() async {
    final res = await _dio.get<List<dynamic>>('/api/formulas');
    final data = res.data ?? const <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => FormulaItem(
            id: asInt(e['id']) ?? 0,
            name: (e['name'] ?? '').toString(),
            expression: (e['expression'] ?? '').toString(),
            description: (e['description'] ?? '').toString(),
          ),
        )
        .toList();
  }

  Future<void> createFormula({
    required String name,
    required String expression,
    String description = '',
  }) async {
    await _dio.post(
      '/api/formulas',
      data: {'name': name, 'expression': expression, 'description': description},
    );
  }

  Future<void> updateFormula({
    required int id,
    required String name,
    required String expression,
    String description = '',
  }) async {
    await _dio.patch(
      '/api/formulas/$id',
      data: {'name': name, 'expression': expression, 'description': description},
    );
  }

  Future<void> deleteFormula(int id) async {
    await _dio.delete('/api/formulas/$id');
  }

  Future<List<RecollectItem>> fetchRecollects() async {
    final res = await _dio.get<List<dynamic>>('/api/recollect');
    final data = res.data ?? const <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => RecollectItem(
            id: asInt(e['id']) ?? 0,
            sensorId: asInt(e['sensor_id']) ?? 0,
            status: (e['status'] ?? '').toString(),
            dateFrom: e['date_from']?.toString(),
            dateTo: e['date_to']?.toString(),
            reason: (e['reason'] ?? '').toString(),
            createdAt: DateTime.tryParse((e['created_at'] ?? '').toString()),
          ),
        )
        .toList();
  }

  Future<void> createRecollect({
    required int sensorId,
    String? dateFrom,
    String? dateTo,
    String reason = '',
  }) async {
    final payload = <String, dynamic>{
      'sensor_id': sensorId,
      'date_from': dateFrom,
      'date_to': dateTo,
      if (reason.isNotEmpty) 'reason': reason,
    }..removeWhere((key, value) => value == null);
    await _dio.post(
      '/api/recollect',
      data: payload,
    );
  }

  Future<void> deleteRecollect(int id) async {
    await _dio.delete('/api/recollect/$id');
  }

  Future<AgentStatusItem> fetchAgentStatus() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/agent/status');
    final e = res.data ?? const <String, dynamic>{};
    return AgentStatusItem(
      isOnline: e['is_online'] == true || e['online'] == true,
      lastSeenAt: DateTime.tryParse((e['last_seen_at'] ?? e['last_seen'] ?? '').toString()),
    );
  }

  Future<DownloadedFile> downloadFile(int id) async {
    final res = await _dio.get<List<int>>(
      '/api/files/$id/download',
      options: Options(responseType: ResponseType.bytes),
    );
    final header = (res.headers.map['content-disposition'] ?? const <String>[]).join(';');
    final filenameMatch = RegExp(r'filename="?([^"]+)"?').firstMatch(header);
    final name = filenameMatch?.group(1) ?? 'download_$id.bin';
    return DownloadedFile(fileName: name, bytes: res.data ?? const <int>[]);
  }
}

String _hourKey(DateTime t) {
  final mm = t.month.toString().padLeft(2, '0');
  final dd = t.day.toString().padLeft(2, '0');
  final hh = t.hour.toString().padLeft(2, '0');
  return '${t.year}-$mm-${dd}T$hh';
}

String _toKoreanStatus(String status) {
  switch (status.toLowerCase()) {
    case 'normal':
    case 'ok':
    case '정상':
      return '정상';
    case 'warning':
    case '주의':
      return '주의';
    case 'danger':
    case 'critical':
    case '위험':
      return '위험';
    default:
      return '오프라인';
  }
}

String _toKoreanSeverity(String severity) {
  switch (severity.toLowerCase()) {
    case 'danger':
    case 'critical':
    case '위험':
      return '위험';
    case 'warning':
    case '주의':
      return '주의';
    default:
      return '오프라인';
  }
}

final sensorApiProvider = Provider<SensorApi>((ref) {
  return SensorApi(ref.read(dioProvider));
});

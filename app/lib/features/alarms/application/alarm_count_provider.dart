import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../sensors/data/sensor_api.dart';

final unackedAlarmCountProvider =
    StateNotifierProvider<UnackedAlarmCount, int>((ref) {
  final controller = UnackedAlarmCount(ref);
  ref.onDispose(controller.shutdown);
  ref.listen<AuthSession>(authProvider, (prev, next) {
    if (next.isLoggedIn) {
      controller.start();
    } else {
      controller.stopAndReset();
    }
  });
  final session = ref.read(authProvider);
  if (session.isLoggedIn) {
    controller.start();
  }
  return controller;
});

class UnackedAlarmCount extends StateNotifier<int> {
  UnackedAlarmCount(this._ref) : super(0);

  final Ref _ref;
  Timer? _timer;
  bool _disposed = false;

  void start() {
    _refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void stopAndReset() {
    _timer?.cancel();
    _timer = null;
    if (_disposed) return;
    state = 0;
  }

  Future<void> _refresh() async {
    if (_disposed) return;
    try {
      final session = _ref.read(authProvider);
      if (!session.isLoggedIn) return;
      final api = _ref.read(sensorApiProvider);
      final list = await api.fetchAlarms(acknowledged: false, limit: 200);
      if (_disposed) return;
      state = list.length;
    } catch (_) {
      // 네트워크 오류 시 카운트는 그대로 유지
    }
  }

  void setCount(int n) {
    if (_disposed) return;
    state = n < 0 ? 0 : n;
  }

  Future<void> refreshNow() => _refresh();

  void shutdown() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}

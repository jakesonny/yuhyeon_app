import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/json_parse.dart';

class AuthSession {
  const AuthSession({
    required this.isLoggedIn,
    this.userId,
    this.username,
    this.email,
    this.role,
  });

  final bool isLoggedIn;
  final int? userId;
  final String? username;
  final String? email;
  final String? role;

  bool get canManage => role != null && role != 'MultiMonitor';

  AuthSession copyWith({
    bool? isLoggedIn,
    int? userId,
    String? username,
    String? email,
    String? role,
  }) {
    return AuthSession(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthSession>((ref) {
  return AuthController(
    tokenStorage: ref.read(tokenStorageProvider),
    dio: ref.read(dioProvider),
  );
});

class AuthController extends StateNotifier<AuthSession> {
  AuthController({
    required TokenStorage tokenStorage,
    required Dio dio,
  })  : _tokenStorage = tokenStorage,
        _dio = dio,
        super(const AuthSession(isLoggedIn: false));

  final TokenStorage _tokenStorage;
  final Dio _dio;

  Future<void> restoreSession() async {
    final token = await _tokenStorage.getToken();
    if (token == null || token.isEmpty) {
      state = const AuthSession(isLoggedIn: false);
      return;
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/auth/me');
      final me = res.data ?? const <String, dynamic>{};
      state = AuthSession(
        isLoggedIn: true,
        userId: asInt(me['id']),
        username: me['username']?.toString(),
        email: me['email']?.toString(),
        role: me['role']?.toString(),
      );
    } catch (_) {
      await _tokenStorage.clearToken();
      state = const AuthSession(isLoggedIn: false);
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );
      final token = (res.data?['token'] ?? '').toString();
      if (token.isEmpty) {
        return '토큰 발급에 실패했습니다.';
      }
      await _tokenStorage.saveToken(token);
      final user = (res.data?['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
      state = AuthSession(
        isLoggedIn: true,
        userId: asInt(user['id']),
        username: user['username']?.toString(),
        email: user['email']?.toString(),
        role: user['role']?.toString(),
      );
      return null;
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['error'] ?? e.response?.data['message'] ?? '').toString()
          : '';
      return msg.isEmpty ? '로그인에 실패했습니다.' : msg;
    } catch (_) {
      return '로그인 중 오류가 발생했습니다.';
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout');
    } catch (_) {}
    await _tokenStorage.clearToken();
    state = const AuthSession(isLoggedIn: false);
  }

  Future<String?> register({
    required String username,
    required String email,
    required String password,
    String role = 'MultiMonitor',
    String? phone,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'role': role,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
      return null;
    } on DioException catch (e) {
      final msg = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['error'] ?? e.response?.data['message'] ?? '').toString()
          : '';
      return msg.isEmpty ? '회원가입에 실패했습니다.' : msg;
    } catch (_) {
      return '회원가입 중 오류가 발생했습니다.';
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/config/env.dart';
import '../../../../core/network/auth_api.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  localDevelopmentSession,
}

class LocalDevelopmentSession {
  final String userId;
  final String name;
  final String environment;
  final Set<String> permissions;

  const LocalDevelopmentSession({
    required this.userId,
    required this.name,
    required this.environment,
    required this.permissions,
  });

  static const technician = LocalDevelopmentSession(
    userId: 'local-technician',
    name: 'Técnico local',
    environment: 'development',
    permissions: {
      'usb:serial',
      'catalog:suntech',
      'studio:quick-test',
      'studio:laboratory',
      'agenda:local',
    },
  );
}

typedef AuthLoginRequest = Future<Map<String, dynamic>> Function(
  String email,
  String password,
);

abstract class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> deleteAll();
}

class SecureSessionStore implements SessionStore {
  final FlutterSecureStorage storage;

  const SecureSessionStore({
    this.storage = const FlutterSecureStorage(),
  });

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);

  @override
  Future<void> deleteAll() => storage.deleteAll();
}

class AuthState {
  final AuthStatus status;
  final String? token;
  final String? userEmail;
  final LocalDevelopmentSession? localSession;
  final String? error;

  const AuthState(
      {this.status = AuthStatus.unknown,
      this.token,
      this.userEmail,
      this.localSession,
      this.error});

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLocalDevelopment => status == AuthStatus.localDevelopmentSession;
  bool get canAccessApp => isAuthenticated || isLocalDevelopment;
  bool get isUnknown => status == AuthStatus.unknown;
}

class AuthNotifier extends ChangeNotifier {
  AuthState _state = const AuthState();
  AuthState get state => _state;

  final SessionStore _storage;
  final bool authEnabled;
  final AuthLoginRequest _loginRequest;
  bool _loading = false;
  bool get loading => _loading;
  String? get error => _state.error;
  bool get isAuthenticated => _state.isAuthenticated;

  AuthNotifier({
    SessionStore? storage,
    this.authEnabled = true,
    AuthLoginRequest? loginRequest,
  })  : _storage = storage ?? const SecureSessionStore(),
        _loginRequest = loginRequest ?? authApi.login;

  Future<void> checkAuth() async {
    if (!authEnabled) {
      _activateLocalDevelopmentSession();
      return;
    }

    try {
      final values = await Future.wait([
        _storage.read('auth_token'),
        _storage.read('user_email'),
      ]);
      final token = values[0];
      final email = values[1];
      if (token != null) {
        _state = AuthState(
          status: AuthStatus.authenticated,
          token: token,
          userEmail: email,
        );
      } else {
        _state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      _state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Sessao local indisponivel. Entrando em modo offline.',
      );
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  void forceUnauthenticated() {
    if (!authEnabled) {
      _activateLocalDevelopmentSession();
      return;
    }
    _state = const AuthState(status: AuthStatus.unauthenticated);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    if (!authEnabled) {
      _activateLocalDevelopmentSession();
      return;
    }

    _loading = true;
    _state = const AuthState(status: AuthStatus.unknown);
    notifyListeners();

    try {
      final result = await _loginRequest(email, password);
      final token = result['accessToken'] as String;
      await _storage.write('auth_token', token);
      await _storage.write('user_email', email);
      _state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        userEmail: email,
      );
    } on DioException catch (e) {
      final message = _dioErrorMessage(e);
      _state = AuthState(status: AuthStatus.unauthenticated, error: message);
    } catch (e) {
      _state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Erro inesperado. Tente novamente.');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_state.error != null) {
      _state = AuthState(
          status: _state.status,
          token: _state.token,
          userEmail: _state.userEmail,
          localSession: _state.localSession);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (!authEnabled) {
      _activateLocalDevelopmentSession();
      return;
    }
    await _storage.deleteAll();
    _state = const AuthState(status: AuthStatus.unauthenticated);
    notifyListeners();
  }

  String _dioErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Servidor não respondeu. Verifique sua conexão.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Não foi possível conectar ao servidor.';
    }
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) return 'E-mail ou senha inválidos.';
    if (statusCode == 429) {
      return 'Muitas tentativas. Aguarde e tente novamente.';
    }
    return 'Erro ao entrar. Tente novamente.';
  }

  void _activateLocalDevelopmentSession() {
    _state = const AuthState(
      status: AuthStatus.localDevelopmentSession,
      localSession: LocalDevelopmentSession.technician,
    );
    _loading = false;
    notifyListeners();
  }
}

final authProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier(authEnabled: ref.watch(authEnabledProvider));
});

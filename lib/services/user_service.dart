import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user.dart';

const String userBackendUrlOverride = 'https://gobike-backend.onrender.com';
const String _envUserBackendUrl = String.fromEnvironment(
  'USER_BACKEND_URL',
  defaultValue: '',
);

class UserService {

    /// Intenta restaurar la sesión persistida al iniciar la app.
    /// Prioriza token válido; si no hay red o el perfil no responde pero existe
    /// email guardado, mantiene sesión local para no expulsar al usuario.
    Future<bool> restoreSession() async {
      final token = await getToken();
      final email = await getLoggedEmail();

      if (token != null && token.isNotEmpty) {
        final user = await getProfile(token);
        if (user != null) {
          await setLoggedIn(true, email: user.email);
          return true;
        }
      }

      if (email != null && email.isNotEmpty) {
        setCurrentUser(User(email: email, password: '', name: '', phone: ''));
        await setLoggedIn(true, email: email);
        return true;
      }

      await logout();
      return false;
    }

    // Guardar estado de sesión y email
    Future<void> setLoggedIn(bool value, {String? email}) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logged_in', value);
      if (value && email != null) {
        await prefs.setString('logged_email', email);
      } else {
        await prefs.remove('logged_email');
      }
    }

    // Verificar si el usuario está logueado

    Future<bool> isLoggedIn() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('logged_in') ?? false;
    }

    Future<String?> getLoggedEmail() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('logged_email');
    }

    // Cerrar sesión
    Future<void> logout() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.setBool('logged_in', false);
      await prefs.remove('logged_email');
      setCurrentUser(null);
    }
  // Guardar token JWT
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  // Obtener token JWT
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// Obtener perfil del usuario autenticado desde backend PostgreSQL
  Future<User?> getProfile(String token) async {
    final baseUrl = _resolveBackendUrl();
    final url = Uri.parse('$baseUrl/auth/v1/user');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = User(
        email: data['email'],
        password: '',
        name: data['user_metadata']?['name'] ?? '',
        phone: data['user_metadata']?['phone'] ?? '',
      );
      setCurrentUser(user);
      return user;
    }
    return null;
  }

  /// Registro con backend PostgreSQL
  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final baseUrl = _resolveBackendUrl();
    final url = Uri.parse('$baseUrl/auth/v1/signup');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'data': {
          'name': name,
          'phone': phone,
        },
      }),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      // Registro exitoso
      return true;
    } else {
      // Mostrar el error real del backend
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? error['msg'] ?? error.toString());
    }
  }

    /// Login con backend PostgreSQL
    Future<User?> login(String email, String password) async {
      final baseUrl = _resolveBackendUrl();
      final url = Uri.parse('$baseUrl/auth/v1/token?grant_type=password');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['access_token'] != null) {
          await saveToken(data['access_token']);
          await setLoggedIn(true, email: email);
        }
        final user = User(
          email: email,
          password: '',
          name: '',
          phone: '',
        );
        setCurrentUser(user);
        return user;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? error['msg'] ?? error.toString());
      }
    }

  String _resolveBackendUrl() {
    final configuredUrl = _envUserBackendUrl.isNotEmpty
        ? _envUserBackendUrl
        : userBackendUrlOverride;

    final uri = Uri.tryParse(configuredUrl);
    if (uri == null || uri.host.isEmpty) {
      return configuredUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        return uri.replace(host: '10.0.2.2').toString();
      }
    }

    return configuredUrl;
  }

  String getBackendBaseUrl() {
    return _resolveBackendUrl();
  }

  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final List<User> _users = [];
  // Restaurar usuario local si no hay token válido (solo para pruebas locales, no producción)
  Future<void> restoreUserFromPrefs() async {
    final email = await getLoggedEmail();
    if (email != null) {
      setCurrentUser(User(email: email, password: '', name: '', phone: ''));
    }
  }

  User? _currentUser;

  User? get currentUser => _currentUser;
  void setCurrentUser(User? user) => _currentUser = user;

  void updateCurrentUser({String? name, String? phone, String? email, String? password}) {
    if (_currentUser == null) return;
    final idx = _users.indexWhere((u) => u.email == _currentUser!.email);
    if (idx != -1) {
      _currentUser = User(
        email: email ?? _currentUser!.email,
        password: password ?? _currentUser!.password,
        name: name ?? _currentUser!.name,
        phone: phone ?? _currentUser!.phone,
      );
      _users[idx] = _currentUser!;
    }
  }

  User? authenticate(String email, String password) {
    try {
      final user = _users.firstWhere(
        (u) => u.email == email && u.password == password,
      );
      setCurrentUser(user);
      return user;
    } catch (e) {
      return null;
    }
  }

  bool exists(String email) {
    return _users.any((u) => u.email == email);
  }

  bool register(User user) {
    if (exists(user.email)) return false;
    _users.add(user);
    setCurrentUser(user);
    return true;
  }
}

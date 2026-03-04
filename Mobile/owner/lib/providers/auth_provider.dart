import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;
  final _storage = const FlutterSecureStorage();
  
  User? _user;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._apiService);

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  Future<bool> hasSavedCredentials() async {
    final email = await _storage.read(key: 'saved_email');
    final password = await _storage.read(key: 'saved_password');
    return email != null && password != null;
  }

  Future<bool> loginWithSavedCredentials() async {
    final email = await _storage.read(key: 'saved_email');
    final password = await _storage.read(key: 'saved_password');
    if (email != null && password != null) {
      return login(email, password, saveCredentials: true);
    }
    return false;
  }

  Future<bool> login(String email, String password, {bool saveCredentials = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.client.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.data != null && response.data['access_token'] != null) {
        final token = response.data['access_token'];
        await _storage.write(key: 'auth_token', value: token);
        
        if (saveCredentials) {
          await _storage.write(key: 'saved_email', value: email);
          await _storage.write(key: 'saved_password', value: password);
        }

        // Verify Role by fetching profile
        return await _verifyUserRole();
      }
      _error = 'Invalid response from server';
      return false;
    } on DioException catch (e) {
      _error = e.response?.data['detail'] ?? 'Login failed. Please check your credentials.';
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return false;

    // Verify token validity and role via API
    try {
       final success = await _verifyUserRole();
       if (!success) {
         await logout(); // Invalid role or token
         return false;
       }
       return true;
    } catch (e) {
      await logout();
      return false;
    }
  }

  Future<bool> _verifyUserRole() async {
    try {
        final meResponse = await _apiService.client.get('/auth/me');
        final data = meResponse.data;
        
        // Check Role
        final role = data['role']?.toString().toLowerCase();
        // Allow 'owner' and 'admin' (assuming admin has owner privileges)
        if (role != 'owner' && role != 'admin') {
            await _storage.delete(key: 'auth_token'); // Clear token
            _error = 'Access Denied: Only Owners can access this application.';
            return false;
        }

        _user = User.fromJson(data);
        notifyListeners();
        return true;
    } catch (e) {
        print("Role verification failed: $e");
        await _storage.delete(key: 'auth_token');
        _error = 'Failed to verify user profile.';
        return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    _user = null;
    notifyListeners();
  }
}

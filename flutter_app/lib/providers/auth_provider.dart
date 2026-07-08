/// Auth Provider：用户认证状态管理
import "package:flutter/foundation.dart";
import "../services/api_service.dart";
import "../models/user.dart";

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => ApiService.isLoggedIn && _user != null;

  /// 初始化：尝试恢复会话
  Future<void> init() async {
    if (ApiService.token != null) {
      try {
        _user = await ApiService.getMe();
      } catch (_) {
        // token 过期，忽略
      }
    }
    notifyListeners();
  }

  /// 登录
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final auth = await ApiService.login(email, password);
      _user = auth.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 注册
  Future<bool> register(String email, String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final auth = await ApiService.register(email, username, password);
      _user = auth.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 登出
  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    notifyListeners();
  }

  /// 更新个人资料
  Future<bool updateProfile({String? username}) async {
    try {
      _user = await ApiService.updateProfile(username: username);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 升级会员
  Future<bool upgradePremium() async {
    try {
      _user = await ApiService.upgradePremium();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

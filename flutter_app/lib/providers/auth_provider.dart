/// Auth Provider：用户认证状态管理
import "package:flutter/foundation.dart";
import "../models/user.dart";

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  /// 初始化：尝试恢复会话
  Future<void> init() async {
    _user ??= User(
      id: 0,
      email: "local@iphone",
      username: "本机用户",
      avatarUrl: null,
      isPremium: true,
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    );
    notifyListeners();
  }

  /// 登录
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = User(
        id: 0,
        email: email.trim().isEmpty ? "local@iphone" : email.trim(),
        username: email.trim().isEmpty ? "本机用户" : email.split("@").first,
        avatarUrl: null,
        isPremium: true,
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      );
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
      _user = User(
        id: 0,
        email: email.trim().isEmpty ? "local@iphone" : email.trim(),
        username: username.trim().isEmpty ? "本机用户" : username.trim(),
        avatarUrl: null,
        isPremium: true,
        isActive: true,
        createdAt: DateTime.now().toIso8601String(),
      );
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
    await init();
    notifyListeners();
  }

  /// 更新个人资料
  Future<bool> updateProfile({String? username}) async {
    try {
      final current = _user;
      _user = User(
        id: current?.id ?? 0,
        email: current?.email ?? "local@iphone",
        username: username?.trim().isNotEmpty == true
            ? username!.trim()
            : (current?.username ?? "本机用户"),
        avatarUrl: current?.avatarUrl,
        isPremium: true,
        isActive: true,
        createdAt: current?.createdAt ?? DateTime.now().toIso8601String(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 升级会员
  Future<bool> upgradePremium() async {
    try {
      await init();
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

/// API 服务：封装所有后端 HTTP 请求
import "dart:convert";
import "dart:io";
import "package:http/http.dart as http";
import "package:shared_preferences/shared_preferences.dart";
import "../models/user.dart";
import "../models/book.dart";
import "../models/task.dart";

class ApiService {
  static const String _baseUrlKey = "api_base_url";
  static const String _tokenKey = "auth_token";

  static String _baseUrl = "http://localhost:8000";
  static String? _token;

  /// 初始化：从本地存储读取 baseUrl 和 token
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? "http://localhost:8000";
    _token = prefs.getString(_tokenKey);
  }

  /// 设置后端地址
  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url.replaceAll(RegExp(r"/$"), "");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
  }

  static String get baseUrl => _baseUrl;

  /// 保存/清除 token
  static Future<void> _saveToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_tokenKey, token);
    } else {
      await prefs.remove(_tokenKey);
    }
  }

  static String? get token => _token;
  static bool get isLoggedIn => _token != null;

  /// 通用请求头
  static Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h["Content-Type"] = "application/json";
    if (_token != null) h["Authorization"] = "Bearer $_token";
    return h;
  }

  /// 通用 GET 请求
  static Future<Map<String, dynamic>> _get(String path) async {
    final resp = await http.get(Uri.parse("$_baseUrl$path"), headers: _headers());
    return _handleResponse(resp);
  }

  /// 通用 POST 请求（JSON body）
  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse("$_baseUrl$path"),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(resp);
  }

  /// 通用 PATCH 请求
  static Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    final resp = await http.patch(
      Uri.parse("$_baseUrl$path"),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(resp);
  }

  /// 通用 DELETE 请求
  static Future<void> _delete(String path) async {
    final resp = await http.delete(Uri.parse("$_baseUrl$path"), headers: _headers());
    if (resp.statusCode >= 400) {
      _throwError(resp);
    }
  }

  /// Multipart 上传
  static Future<Map<String, dynamic>> _upload(
    String path,
    File file,
    Map<String, String> fields,
  ) async {
    final req = http.MultipartRequest("POST", Uri.parse("$_baseUrl$path"));
    req.headers.addAll(_headers(json: false));
    req.files.add(await http.MultipartFile.fromPath("file", file.path));
    fields.forEach((k, v) => req.fields[k] = v);
    final streamedResp = await req.send();
    final resp = await http.Response.fromStream(streamedResp);
    return _handleResponse(resp);
  }

  /// 处理响应
  static Map<String, dynamic> _handleResponse(http.Response resp) {
    if (resp.statusCode >= 400) {
      _throwError(resp);
    }
    if (resp.body.isEmpty) return {};
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Never _throwError(http.Response resp) {
    String msg = "请求失败 (${resp.statusCode})";
    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      msg = body["detail"] as String? ?? msg;
    } catch (_) {}
    throw ApiException(resp.statusCode, msg);
  }

  // ========== Auth ==========

  static Future<AuthToken> register(String email, String username, String password) async {
    final json = await _post("/api/auth/register", {
      "email": email,
      "username": username,
      "password": password,
    });
    final auth = AuthToken.fromJson(json);
    await _saveToken(auth.accessToken);
    return auth;
  }

  static Future<AuthToken> login(String email, String password) async {
    final json = await _post("/api/auth/login", {
      "email": email,
      "password": password,
    });
    final auth = AuthToken.fromJson(json);
    await _saveToken(auth.accessToken);
    return auth;
  }

  static Future<void> logout() async {
    await _saveToken(null);
  }

  static Future<User> getMe() async {
    final json = await _get("/api/auth/me");
    return User.fromJson(json);
  }

  // ========== Users ==========

  static Future<User> updateProfile({String? username, String? avatarUrl}) async {
    final body = <String, dynamic>{};
    if (username != null) body["username"] = username;
    if (avatarUrl != null) body["avatar_url"] = avatarUrl;
    final json = await _patch("/api/users/me", body);
    return User.fromJson(json);
  }

  static Future<User> upgradePremium() async {
    final json = await _post("/api/users/me/premium", {});
    return User.fromJson(json);
  }

  // ========== Books ==========

  static Future<Book> uploadBook(File file, String title, {String? author, String? description}) async {
    final fields = <String, String>{"title": title};
    if (author != null) fields["author"] = author;
    if (description != null) fields["description"] = description;
    final json = await _upload("/api/books/upload", file, fields);
    return Book.fromJson(json);
  }

  static Future<List<Book>> listBooks({int page = 1, int pageSize = 20}) async {
    final json = await _get("/api/books?page=$page&page_size=$pageSize");
    final items = json["items"] as List;
    return items.map((e) => Book.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<BookDetail> getBook(int id) async {
    final json = await _get("/api/books/$id");
    return BookDetail.fromJson(json);
  }

  static Future<Book> updateBook(int id, {String? title, String? author, String? description}) async {
    final body = <String, dynamic>{};
    if (title != null) body["title"] = title;
    if (author != null) body["author"] = author;
    if (description != null) body["description"] = description;
    final json = await _patch("/api/books/$id", body);
    return Book.fromJson(json);
  }

  static Future<void> deleteBook(int id) async {
    await _delete("/api/books/$id");
  }

  static String downloadUrl(int id) {
    return "$_baseUrl/api/books/$id/download";
  }

  // ========== Tasks ==========

  static Future<Task> createTask(int bookId, {String taskType = "tts", Map<String, dynamic>? params}) async {
    final body = <String, dynamic>{
      "book_id": bookId,
      "task_type": taskType,
    };
    if (params != null) body["params"] = params;
    final json = await _post("/api/tasks", body);
    return Task.fromJson(json);
  }

  static Future<List<Task>> listTasks({String? statusFilter, int page = 1, int pageSize = 20}) async {
    var path = "/api/tasks?page=$page&page_size=$pageSize";
    if (statusFilter != null) path += "&status_filter=$statusFilter";
    final json = await _get(path);
    final items = json["items"] as List;
    return items.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Task> getTask(int id) async {
    final json = await _get("/api/tasks/$id");
    return Task.fromJson(json);
  }

  static Future<Task> cancelTask(int id) async {
    final json = await _post("/api/tasks/$id/cancel", {});
    return Task.fromJson(json);
  }
}

/// API 异常
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

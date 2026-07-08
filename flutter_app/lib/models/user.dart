/// 用户模型
class User {
  final int id;
  final String email;
  final String username;
  final String? avatarUrl;
  final bool isPremium;
  final bool isActive;
  final String createdAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    required this.isPremium,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json["id"] as int,
      email: json["email"] as String,
      username: json["username"] as String,
      avatarUrl: json["avatar_url"] as String?,
      isPremium: json["is_premium"] as bool? ?? false,
      isActive: json["is_active"] as bool? ?? true,
      createdAt: json["created_at"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "email": email,
      "username": username,
      "avatar_url": avatarUrl,
      "is_premium": isPremium,
      "is_active": isActive,
      "created_at": createdAt,
    };
  }
}

/// 登录响应
class AuthToken {
  final String accessToken;
  final String tokenType;
  final User user;

  AuthToken({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json["access_token"] as String,
      tokenType: json["token_type"] as String? ?? "bearer",
      user: User.fromJson(json["user"] as Map<String, dynamic>),
    );
  }
}

/// 用户与登录会话模型。
library;

/// 登录用户信息，对应后端 `UserInfoResponse`。
class UserInfo {
  const UserInfo({
    required this.userId,
    required this.username,
    required this.email,
    required this.displayName,
    this.description,
    this.avatar,
    required this.createDate,
    this.lastLoginDate,
    this.token,
  });

  final int userId;
  final String username;
  final String email;
  final String displayName;
  final String? description;
  final String? avatar;
  final int createDate;
  final int? lastLoginDate;

  /// 登录令牌，仅登录响应中存在。
  final String? token;

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        userId: (json['userId'] as num?)?.toInt() ?? -1,
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        description: json['description'] as String?,
        avatar: json['avatar'] as String?,
        createDate: (json['createDate'] as num?)?.toInt() ?? 0,
        lastLoginDate: (json['lastLoginDate'] as num?)?.toInt(),
        token: json['token'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'email': email,
        'displayName': displayName,
        'description': description,
        'avatar': avatar,
        'createDate': createDate,
        'lastLoginDate': lastLoginDate,
        if (token != null) 'token': token,
      };

  UserInfo copyWith({
    int? userId,
    String? username,
    String? email,
    String? displayName,
    String? description,
    String? avatar,
    int? createDate,
    int? lastLoginDate,
    String? token,
  }) =>
      UserInfo(
        userId: userId ?? this.userId,
        username: username ?? this.username,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        description: description ?? this.description,
        avatar: avatar ?? this.avatar,
        createDate: createDate ?? this.createDate,
        lastLoginDate: lastLoginDate ?? this.lastLoginDate,
        token: token ?? this.token,
      );
}

/// 修改用户信息请求体，对应后端 `UserInfoRequest`。
class UserInfoRequest {
  const UserInfoRequest({
    required this.username,
    required this.email,
    required this.displayName,
    this.description,
    this.avatar,
  });

  final String username;
  final String email;
  final String displayName;
  final String? description;
  final String? avatar;

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'displayName': displayName,
        'description': description,
        'avatar': avatar,
      };
}

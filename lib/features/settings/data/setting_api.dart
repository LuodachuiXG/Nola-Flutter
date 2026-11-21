import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/blog_models.dart';
import '../../../core/network/api_client.dart';

/// 博客设置 API（博客信息与备案信息）。
class SettingApi {
  SettingApi(this._client);

  final ApiClient _client;

  /// 获取博客信息（管理端）。
  Future<BlogInfo?> blogInfo() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/admin/config/blog',
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    return data == null ? null : BlogInfo.fromJson(data);
  }

  /// 修改博客信息。
  Future<bool> updateBlogInfo({
    required String title,
    String? subtitle,
    String? logo,
    String? favicon,
  }) async {
    return await _client.put<bool>(
          '/admin/config/blog',
          body: BlogInfo.updateJson(
            title: title,
            subtitle: subtitle,
            logo: logo,
            favicon: favicon,
          ),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }

  /// 获取备案信息。
  Future<ICPFiling?> icp() async {
    final data = await _client.get<Map<String, dynamic>>(
      '/admin/config/icp',
      parse: (data) =>
          data == null ? null : Map<String, dynamic>.from(data as Map),
    );
    return data == null ? null : ICPFiling.fromJson(data);
  }

  /// 修改备案信息。
  Future<bool> updateICP(ICPFiling filing) async {
    return await _client.put<bool>(
          '/admin/config/icp',
          body: filing.toJson(),
          parse: (data) => data is bool ? data : false,
        ) ??
        false;
  }
}

/// [SettingApi] 提供者。
final settingApiProvider = Provider<SettingApi>((ref) {
  return SettingApi(ref.watch(apiClientProvider));
});

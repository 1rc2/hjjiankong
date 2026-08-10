import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/version_util.dart';

/// GitHub 更新信息
class UpdateInfo {
  /// 原始 tag，如 v1.0.2
  final String tagName;

  /// 去掉 v 前缀后的版本号，如 1.0.2
  final String latestVersion;

  /// 更新日志（Release body）
  final String releaseNotes;

  /// APK 下载直链（Release 未上传 APK 时为空）
  final String? apkUrl;

  /// APK 文件名
  final String apkFileName;

  UpdateInfo({
    required this.tagName,
    required this.latestVersion,
    required this.releaseNotes,
    required this.apkUrl,
    required this.apkFileName,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String?) ?? '';
    String? apkUrl;
    String apkName = 'hjjiankong.apk';

    // 从 assets 中找第一个 .apk 附件
    final assets = (json['assets'] as List?) ?? const [];
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = (asset['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          apkName = name;
          break;
        }
      }
    }

    return UpdateInfo(
      tagName: tag,
      latestVersion: VersionUtil.normalize(tag),
      releaseNotes: (json['body'] as String?) ?? '暂无更新日志',
      apkUrl: apkUrl,
      apkFileName: apkName,
    );
  }
}

/// GitHub 更新检查异常（携带可直接展示给用户的提示）
class GithubUpdateException implements Exception {
  final String message;

  GithubUpdateException(this.message);

  @override
  String toString() => message;
}

/// GitHub 版本更新服务
class GithubUpdateService {
  /// 公开仓库最新 Release 接口（无需 token，但必须带 User-Agent，否则易触发 403 限流）
  static const String apiUrl =
      'https://api.github.com/repos/1rc2/hjjiankong/releases/latest';

  /// 请求最新 Release 信息
  ///
  /// 失败时抛出 [GithubUpdateException]：
  /// - 403：GitHub API 限流
  /// - 404：仓库无 Release（需先发布 v1.0.0）
  /// - 网络超时 / 连接失败
  static Future<UpdateInfo> checkLatest() async {
    http.Response resp;
    try {
      resp = await http
          .get(
            Uri.parse(apiUrl),
            headers: {
              // 关键：不带 User-Agent 会触发 GitHub API 403（无认证接口有访问频率限制）
              'User-Agent': 'Mozilla/5.0 (Linux; Android 13) GoldMonitor/1.0',
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw GithubUpdateException('请求 GitHub 超时，请检查网络后重试');
    } catch (e) {
      throw GithubUpdateException('网络异常：$e');
    }

    if (resp.statusCode == 403) {
      throw GithubUpdateException('GitHub API 访问受限（限流），请稍后再试，或前往 Release 页面手动下载');
    }
    if (resp.statusCode == 404) {
      throw GithubUpdateException('未找到 Release，请先在 GitHub 发布 v1.0.0');
    }
    if (resp.statusCode != 200) {
      throw GithubUpdateException('GitHub 接口返回异常：HTTP ${resp.statusCode}');
    }

    return UpdateInfo.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }
}

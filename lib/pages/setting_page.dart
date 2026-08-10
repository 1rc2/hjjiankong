import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../service/github_update.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import '../utils/toast_util.dart';
import '../utils/version_util.dart';
import '../widgets/update_dialog.dart';

/// 设置 Tab：版本更新 / 主题切换 / 清除缓存 / 关于我们
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String _version = '1.0.0';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  /// 检查更新：仅用户手动点击时调用（避免频繁触发 GitHub API 限流）
  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      // 1. 拉取 GitHub 最新 Release
      final remote = await GithubUpdateService.checkLatest();
      // 2. 获取本地版本号
      final info = await PackageInfo.fromPlatform();
      final local = info.version;
      if (!mounted) return;

      // 3. 远程版本大于本地版本 → 弹更新框
      if (VersionUtil.isNewer(remote.latestVersion, local)) {
        await showDialog<void>(
          context: context,
          builder: (_) => UpdateDialog(info: remote),
        );
      } else {
        showToast(context, '已是最新版本 v$local');
      }
    } on GithubUpdateException catch (e) {
      // 403 / 404 / 网络失败：弹窗提示，并提供「前往 Release 手动下载」按钮
      if (mounted) await _showUpdateError(e.message);
    } catch (e) {
      if (mounted) await _showUpdateError('检查更新失败：$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// GitHub 接口失败（限流 / 无 Release / 超时等）：提示并提供「前往 Release 手动下载」
  Future<void> _showUpdateError(String message) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('检查更新失败'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openUrl('https://github.com/1rc2/hjjiankong/releases/latest');
            },
            child: const Text('前往 Release 下载'),
          ),
        ],
      ),
    );
  }

  /// 主题模式选择
  Future<void> _selectTheme() async {
    final mode = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择主题模式'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ThemeMode.system),
            child: const Text('跟随系统'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ThemeMode.light),
            child: const Text('浅色'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ThemeMode.dark),
            child: const Text('深色'),
          ),
        ],
      ),
    );
    if (mode != null) {
      await ThemeController.instance.setMode(mode);
    }
  }

  /// 清除缓存（临时文件 + 已下载的 APK 更新包，不影响持仓数据）
  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('将清理临时文件与已下载的 APK 更新包，不影响持仓数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    double freed = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      freed += await _dirSizeMB(tempDir);

      // 清理下载的 APK（应用外部私有目录 /Download）
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final dlDir = Directory('${extDir.path}/Download');
        if (dlDir.existsSync()) {
          freed += await _dirSizeMB(dlDir);
          dlDir.deleteSync(recursive: true);
        }
      }

      for (final e in tempDir.listSync()) {
        if (e is File) {
          e.deleteSync();
        } else if (e is Directory) {
          e.deleteSync(recursive: true);
        }
      }
      showToast(context, '缓存已清除（约 ${freed.toStringAsFixed(1)} MB）');
    } catch (_) {
      showToast(context, '清除缓存失败');
    }
  }

  Future<double> _dirSizeMB(Directory dir) async {
    double mb = 0;
    try {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            mb += await e.length() / 1024 / 1024;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return mb;
  }

  /// 关于我们
  Future<void> _showAbout() async {
    const repo = 'https://github.com/1rc2/hjjiankong';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于黄金监控'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本 v$_version'),
            const SizedBox(height: 8),
            const Text('黄金行情为模拟数据，仅供演示；\n持仓数据仅保存在本机。'),
            const SizedBox(height: 12),
            Text(repo, style: const TextStyle(color: Colors.blue, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _copyText(repo);
            },
            child: const Text('复制链接'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openUrl(repo);
            },
            child: const Text('打开 GitHub'),
          ),
        ],
      ),
    );
  }

  void _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    showToast(context, '链接已复制');
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      showToast(context, '无法打开链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 版本信息
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.gold),
              title: const Text('黄金监控'),
              subtitle: Text('当前版本 v$_version'),
              trailing: _checking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update_alt, color: AppColors.gold),
                  title: const Text('检查更新'),
                  subtitle: const Text('从 GitHub Release 检测最新版本'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _checkUpdate,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined, color: AppColors.gold),
                  title: const Text('主题模式'),
                  subtitle: const Text('跟随系统 / 浅色 / 深色'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectTheme,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined, color: AppColors.gold),
                  title: const Text('清除缓存'),
                  subtitle: const Text('清理临时文件与已下载的更新包'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearCache,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.favorite_outline, color: AppColors.gold),
                  title: const Text('关于我们'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showAbout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '黄金监控 v$_version',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

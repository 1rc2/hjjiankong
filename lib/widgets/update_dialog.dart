import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../service/download_manager.dart';
import '../service/github_update.dart';
import '../theme/app_colors.dart';
import '../utils/toast_util.dart';

/// GitHub 更新弹窗：展示更新日志 → 下载 APK → 引导安装
///
/// 流程：
/// 1. 初始状态：显示新版本 + 更新日志 + 【立即下载】【稍后】
/// 2. 下载中：显示进度条（后台下载，关闭弹窗不中断）
/// 3. 下载完成：显示【立即安装】（未授权"安装未知应用"时先引导去系统设置）
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final DownloadManager _dm = DownloadManager.instance;

  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _dm.status.addListener(_onStatusChanged);
  }

  @override
  void dispose() {
    _dm.status.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    if (!mounted) return;
    setState(() {
      final s = _dm.status.value;
      _downloading =
          s == DownloadTaskStatus.enqueued || s == DownloadTaskStatus.running;
    });
  }

  /// 下载完成且拿到文件路径
  bool get _downloaded =>
      _dm.status.value == DownloadTaskStatus.complete &&
      _dm.downloadedPath.value != null;

  /// 开始下载 APK
  Future<void> _startDownload() async {
    final url = widget.info.apkUrl;
    if (url == null) return;
    // Android 13+ 需要通知权限，否则通知栏不显示下载进度
    await _dm.requestNotificationPermission();
    // 保存到应用外部私有目录（无需存储权限）
    final dir = await getExternalStorageDirectory();
    final savedDir = '${dir!.path}/Download';
    await _dm.startDownload(url, savedDir, widget.info.apkFileName);
    if (mounted) setState(() {});
  }

  /// 安装已下载的 APK（Android 8+ 需先授权"安装未知应用"）
  Future<void> _install() async {
    final path = _dm.downloadedPath.value;
    if (path == null) return;

    final can = await _dm.canRequestInstall();
    if (!can) {
      // 未授权：引导用户去系统设置开启
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要安装权限'),
          content: const Text('系统默认禁止安装未知来源应用。\n请前往系统设置，开启「允许安装此来源的应用」后，再点击「立即安装」。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );
      if (go == true) {
        await _dm.openInstallSettings();
        showToast(context, '开启权限后，请回到 App 重新点击「立即安装」');
      }
      return;
    }

    final ok = await _dm.installApk(path);
    if (!ok) {
      showToast(context, '安装失败，请检查 APK 文件是否完整');
    }
  }

  /// 前往 GitHub Release 页面手动下载
  Future<void> _openReleasePage() async {
    const url = 'https://github.com/1rc2/hjjiankong/releases/latest';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      showToast(context, '无法打开链接，请复制地址到浏览器：$url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update_alt, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(child: Text('发现新版本 v${info.latestVersion}')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Release tag：${info.tagName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              '更新内容：',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: Text(info.releaseNotes, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
            const SizedBox(height: 12),
            if (_downloading) ...[
              ValueListenableBuilder<int>(
                valueListenable: _dm.progress,
                builder: (_, p, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: p / 100, minHeight: 6),
                    const SizedBox(height: 6),
                    Text(
                      '正在下载 $p%',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 下载失败提示
            if (_dm.status.value == DownloadTaskStatus.failed) ...[
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '下载失败，请检查网络后重试，\n或前往 Release 页面手动下载。',
                      style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              '下载采用「直连 + 多个加速镜像自动切换」，国内网络也尽量保证速度；\n若全部失败，可点击「前往 Release」手动下载。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: _buildActions(),
    );
  }

  List<Widget> _buildActions() {
    // 下载失败：提供重试与网页手动下载备选
    if (_dm.status.value == DownloadTaskStatus.failed) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后'),
        ),
        TextButton(
          onPressed: _openReleasePage,
          child: const Text('前往 Release'),
        ),
        FilledButton(
          onPressed: _startDownload,
          child: const Text('重试'),
        ),
      ];
    }

    // 下载中：只能关闭弹窗（下载在后台继续，进度见通知栏）
    if (_downloading) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('后台下载'),
        ),
      ];
    }

    // 已下载：立即安装
    if (_downloaded) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后'),
        ),
        TextButton(
          onPressed: _openReleasePage,
          child: const Text('前往 Release'),
        ),
        FilledButton(
          onPressed: _install,
          child: const Text('立即安装'),
        ),
      ];
    }

    // 初始状态
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('稍后'),
      ),
      if (widget.info.apkUrl == null)
        // Release 未上传 APK：引导手动下载
        TextButton(
          onPressed: _openReleasePage,
          child: const Text('前往 Release 下载'),
        )
      else
        FilledButton(
          onPressed: _startDownload,
          child: const Text('立即下载'),
        ),
    ];
  }
}

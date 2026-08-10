import 'dart:async';
import 'dart:io';
import 'dart:isolate'; // ReceivePort（下载回调跨 isolate 通信）
import 'dart:ui' show IsolateNameServer; // IsolateNameServer 定义在 dart:ui（引擎层）

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

/// 下载与安装管理器（FlutterDownloader + 原生 MethodChannel）
///
/// 说明：
/// - flutter_downloader 的下载回调运行在后台 isolate，
///   通过 IsolateNameServer 把进度回传到主 isolate（见 init / _onEvent）。
/// - 安装 APK 由 MainActivity 中的 MethodChannel「com.example.hjjiankong/install」
///   完成，使用 FileProvider 生成安全的 content:// URI。
class DownloadManager {
  DownloadManager._();

  static final DownloadManager instance = DownloadManager._();

  static const String _portName = 'gold_update_download_port';
  static const MethodChannel _channel =
      MethodChannel('com.example.hjjiankong/install');

  /// 当前下载状态
  final ValueNotifier<DownloadTaskStatus?> status = ValueNotifier(null);

  /// 下载进度 0-100
  final ValueNotifier<int> progress = ValueNotifier(0);

  /// 下载完成后的 APK 绝对路径
  final ValueNotifier<String?> downloadedPath = ValueNotifier(null);

  String? _taskId;
  String _savedDir = '';
  String _fileName = '';
  ReceivePort? _port;

  /// 在 main() 中调用：注册消息端口 + 下载回调
  void init() {
    if (IsolateNameServer.lookupPortByName(_portName) != null) {
      IsolateNameServer.removePortNameMapping(_portName);
    }
    final port = ReceivePort();
    _port = port;
    IsolateNameServer.registerPortWithName(port.sendPort, _portName);
    port.listen(_onEvent);
    FlutterDownloader.registerCallback(downloadCallback);
  }

  /// 后台 isolate 下载回调
  /// 注意：必须是 static + @pragma，否则 release 模式下会被 tree-shaking 掉
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final sendPort = IsolateNameServer.lookupPortByName(_portName);
    sendPort?.send([id, status, progress]);
  }

  /// 主 isolate 接收下载事件
  void _onEvent(dynamic data) {
    if (data is! List || data.length < 3) return;
    final id = data[0] as String;
    if (_taskId != null && id != _taskId) return;
    final st = DownloadTaskStatus.fromInt(data[1] as int);
    final p = data[2] as int;

    status.value = st;
    progress.value = p;
    if (st == DownloadTaskStatus.complete) {
      downloadedPath.value = '$_savedDir/$_fileName';
    }
  }

  /// 开始下载 APK
  Future<void> startDownload(String url, String savedDir, String fileName) async {
    _savedDir = savedDir;
    _fileName = fileName;
    status.value = DownloadTaskStatus.enqueued;
    progress.value = 0;
    downloadedPath.value = null;

    _taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: savedDir,
      fileName: fileName,
      headers: {'User-Agent': 'Mozilla/5.0'},
      showNotification: true,
      openFileFromNotification: false,
    );
  }

  /// 是否已允许「安装未知应用」（Android 8+ 才有此概念，旧版本直接返回 true）
  Future<bool> canRequestInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canRequestInstall') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 跳转系统「允许安装未知应用」设置页
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (_) {}
  }

  /// 调用系统安装器安装 APK
  Future<bool> installApk(String path) async {
    try {
      return await _channel.invokeMethod<bool>('installApk', {'path': path}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Android 13+ 申请通知栏权限（下载进度通知需要，拒绝不影响下载本身）
  Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }
}

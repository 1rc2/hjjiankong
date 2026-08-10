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

  /// 候选下载地址队列（直连优先，失败自动切换镜像），当前尝试下标
  List<String> _urlQueue = [];
  int _urlIndex = 0;

  /// GitHub 加速镜像前缀（第三方服务，可能随时间失效，失效请更换或补充）
  /// 直连 GitHub 在国内较慢，镜像作为兜底自动切换。
  static const List<String> mirrorPrefixes = [
    'https://gh-proxy.com/',
    'https://ghproxy.net/',
    'https://ghfast.top/',
    'https://github.moeyy.xyz/',
    'https://mirror.ghproxy.com/',
  ];

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

    progress.value = p;
    if (st == DownloadTaskStatus.complete) {
      status.value = st;
      downloadedPath.value = '$_savedDir/$_fileName';
    } else if (st == DownloadTaskStatus.failed) {
      // 下载失败：自动切换到下一个候选地址重试（直连 → 各镜像）
      _urlIndex++;
      if (_urlIndex < _urlQueue.length) {
        status.value = DownloadTaskStatus.enqueued;
        progress.value = 0;
        _enqueueCurrent();
      } else {
        status.value = st; // 全部候选都失败，最终上报失败
      }
    } else {
      status.value = st;
    }
  }

  /// 开始下载 APK（直连优先，失败自动切换镜像兜底）
  Future<void> startDownload(String url, String savedDir, String fileName) async {
    _savedDir = savedDir;
    _fileName = fileName;
    status.value = DownloadTaskStatus.enqueued;
    progress.value = 0;
    downloadedPath.value = null;

    // 确保目录存在（flutter_downloader 的 enqueue 会 assert savedDir 存在）
    final dir = Directory(savedDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    _urlQueue = _buildUrlQueue(url);
    _urlIndex = 0;
    await _enqueueCurrent();
  }

  /// 生成候选下载地址：直连优先，镜像逐个兜底
  List<String> _buildUrlQueue(String directUrl) {
    final queue = [directUrl];
    for (final prefix in mirrorPrefixes) {
      queue.add('$prefix$directUrl');
    }
    return queue;
  }

  /// 用当前下标对应的地址发起下载
  Future<void> _enqueueCurrent() async {
    if (_urlIndex >= _urlQueue.length) return;
    final url = _urlQueue[_urlIndex];
    _taskId = await FlutterDownloader.enqueue(
      url: url,
      savedDir: _savedDir,
      fileName: _fileName,
      headers: {'User-Agent': 'Mozilla/5.0'},
      showNotification: true,
      openFileFromNotification: false,
    );
    if (_taskId == null) {
      // 入队失败（如地址不可达），继续尝试下一个候选
      _urlIndex++;
      if (_urlIndex < _urlQueue.length) {
        await _enqueueCurrent();
      } else {
        status.value = DownloadTaskStatus.failed;
      }
    }
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

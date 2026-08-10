import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'pages/main_shell.dart';
import 'service/download_manager.dart';
import 'service/gold_api.dart';
import 'service/holdings_service.dart';
import 'theme/app_colors.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化下载服务（GitHub APK 更新下载，必须在 runApp 前）
  await FlutterDownloader.initialize(debug: false, ignoreSsl: false);
  DownloadManager.instance.init();

  // 2. 启动模拟行情定时器（每 3 秒波动一次）
  GoldService.instance.start();

  // 3. 加载本地持久化数据
  await HoldingsService.instance.load();
  await ThemeController.instance.load();

  runApp(const GoldMonitorApp());
}

/// 黄金监控 App
class GoldMonitorApp extends StatelessWidget {
  const GoldMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: '黄金监控',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: ThemeController.instance.mode,
          home: const MainShell(),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.gold,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}

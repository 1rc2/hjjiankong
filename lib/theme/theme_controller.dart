import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式控制器（跟随系统 / 浅色 / 深色），选择结果本地持久化
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _key = 'theme_mode';

  ThemeMode mode = ThemeMode.system;

  /// 启动时读取本地保存的主题偏好
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode = ThemeMode.values[prefs.getInt(_key) ?? 0];
    notifyListeners();
  }

  /// 切换主题并持久化
  Future<void> setMode(ThemeMode m) async {
    if (mode == m) return;
    mode = m;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, m.index);
  }
}

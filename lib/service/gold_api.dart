import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// 黄金行情服务（模拟数据）
///
/// 真实行情可在此处替换为免费接口，例如新浪财经：
/// GET https://hq.sinajs.cn/list=hf_XAU （需 Referer 头）
/// 返回字段 hf_XAU: 名称,昨收,今开,...,现价,...
class GoldService extends ChangeNotifier {
  GoldService._();

  static final GoldService instance = GoldService._();

  /// 模拟开盘价（元/克）
  static const double _initPrice = 698.50;

  final Random _random = Random();

  late double _prevClose; // 昨收价（涨跌幅基准）
  late double _current; // 当前价
  late DateTime _lastUpdate;
  final List<double> _history = []; // 分时历史价格（用于曲线）

  double get current => _current;
  double get prevClose => _prevClose;
  List<double> get history => List.unmodifiable(_history);
  DateTime get lastUpdate => _lastUpdate;

  /// 涨跌额 = 现价 - 昨收
  double get change => _current - _prevClose;

  /// 涨跌幅（%）
  double get changePercent => _prevClose == 0 ? 0 : (change / _prevClose) * 100;

  Timer? _timer;

  /// 启动模拟行情：每 3 秒随机波动一次
  void start() {
    _prevClose = _initPrice;
    _current = _initPrice;
    _lastUpdate = DateTime.now();
    _history
      ..clear()
      ..add(_current);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  /// 模拟一次价格波动（定时器 / 下拉刷新 / 手动刷新共用）
  void refresh() => _tick();

  void _tick() {
    // 随机游走：每次在 ±0.15% 内波动
    final drift = (_random.nextDouble() - 0.5) * 2 * 0.0015;
    _current = (_current * (1 + drift))
        .clamp(_initPrice * 0.85, _initPrice * 1.3)
        .toDouble();
    _lastUpdate = DateTime.now();
    _history.add(_current);
    if (_history.length > 120) {
      _history.removeAt(0); // 最多保留 120 个点
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

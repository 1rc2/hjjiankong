import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 持仓数据模型
class Holding {
  final String id;
  final String name; // 持仓名称
  final double grams; // 持仓克重(g)
  final double cost; // 买入成本价(元/克)

  Holding({
    required this.id,
    required this.name,
    required this.grams,
    required this.cost,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'grams': grams,
        'cost': cost,
      };

  factory Holding.fromJson(Map<String, dynamic> json) => Holding(
        id: json['id'] as String,
        name: json['name'] as String? ?? '黄金持仓',
        grams: (json['grams'] as num?)?.toDouble() ?? 0,
        cost: (json['cost'] as num?)?.toDouble() ?? 0,
      );
}

/// 持仓管理服务：本地持久化（SharedPreferences 存 JSON）
class HoldingsService extends ChangeNotifier {
  HoldingsService._();

  static final HoldingsService instance = HoldingsService._();

  static const String _key = 'holdings';

  final List<Holding> _items = [];

  List<Holding> get items => List.unmodifiable(_items);

  /// 启动时读取本地持仓
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      _items
        ..clear()
        ..addAll(list.map((e) => Holding.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (_) {
      // 数据损坏时静默丢弃
    }
  }

  /// 新增持仓并持久化
  Future<void> add(Holding holding) async {
    _items.add(holding);
    await _save();
  }

  /// 删除持仓并持久化
  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }
}

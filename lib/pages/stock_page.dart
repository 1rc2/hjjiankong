import 'package:flutter/material.dart';

import '../service/gold_api.dart';
import '../service/holdings_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_util.dart';
import '../utils/toast_util.dart';

/// 持股 Tab：录入持仓（克重 / 成本价），按实时模拟金价计算市值与浮动盈亏
/// 数据通过 SharedPreferences 本地持久化
class StockPage extends StatelessWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的持仓')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新增持仓'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([HoldingsService.instance, GoldService.instance]),
        builder: (context, _) {
          final items = HoldingsService.instance.items;
          final current = GoldService.instance.current;
          if (items.isEmpty) return const _EmptyView();
          return Column(
            children: [
              _SummaryBar(items: items, current: current),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (context, i) =>
                      _HoldingCard(item: items[i], current: current),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 新增持仓表单弹窗
  Future<void> _showAddDialog(BuildContext context) async {
    final nameCtl = TextEditingController();
    final gramsCtl = TextEditingController();
    final costCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增持仓'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: '名称（可选）', hintText: '如：黄金ETF'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: gramsCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '持仓克重 (g)'),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return '请输入有效的克重';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: costCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '买入成本价 (元/克)'),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return '请输入有效的成本价';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (saved == true) {
      await HoldingsService.instance.add(
        Holding(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: nameCtl.text.trim().isEmpty ? '黄金持仓' : nameCtl.text.trim(),
          grams: double.parse(gramsCtl.text),
          cost: double.parse(costCtl.text),
        ),
      );
      if (context.mounted) showToast(context, '持仓已保存');
    }
  }
}

/// 持仓汇总条（总市值 / 浮动盈亏 / 盈亏率）
class _SummaryBar extends StatelessWidget {
  final List<Holding> items;
  final double current;

  const _SummaryBar({required this.items, required this.current});

  @override
  Widget build(BuildContext context) {
    double totalValue = 0, totalCost = 0;
    for (final h in items) {
      totalCost += h.grams * h.cost;
      totalValue += h.grams * current;
    }
    final pl = totalValue - totalCost;
    final plPercent = totalCost == 0 ? 0.0 : pl / totalCost * 100;
    final color = pl >= 0 ? AppColors.up : AppColors.down;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: _summaryItem(context, '总市值', '¥${Fmt.money(totalValue)}', null),
            ),
            Container(width: 1, height: 36, color: Colors.grey.shade300),
            Expanded(
              child: _summaryItem(context, '浮动盈亏', Fmt.signed(pl), color),
            ),
            Container(width: 1, height: 36, color: Colors.grey.shade300),
            Expanded(
              child: _summaryItem(
                context,
                '盈亏率',
                '${pl >= 0 ? '+' : ''}${plPercent.toStringAsFixed(2)}%',
                color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(BuildContext context, String label, String value, Color? color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }
}

/// 单条持仓卡片（左滑删除）
class _HoldingCard extends StatelessWidget {
  final Holding item;
  final double current;

  const _HoldingCard({required this.item, required this.current});

  @override
  Widget build(BuildContext context) {
    final value = item.grams * current; // 总市值
    final cost = item.grams * item.cost; // 总成本
    final pl = value - cost; // 浮动盈亏
    final plPercent = cost == 0 ? 0.0 : pl / cost * 100;
    final color = pl >= 0 ? AppColors.up : AppColors.down;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('删除', style: TextStyle(color: Colors.white)),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => HoldingsService.instance.remove(item.id),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${Fmt.signed(pl)} (${pl >= 0 ? '+' : ''}${plPercent.toStringAsFixed(2)}%)',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _info(context, '克重', '${Fmt.money(item.grams, decimals: 2)} g'),
                  _info(context, '成本价', '${Fmt.money(item.cost)} 元/克'),
                  _info(context, '现价', '${Fmt.money(current)} 元/克'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '总市值 ¥${Fmt.money(value)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除持仓'),
        content: Text('确定删除「${item.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 空状态
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('暂无持仓', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            '点击右下角「新增持仓」开始录入',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

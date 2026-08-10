import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../service/gold_api.dart';
import '../theme/app_colors.dart';
import '../utils/format_util.dart';

/// 黄金首页 Tab：模拟实时价格 + 分时走势曲线
/// - 现价 / 涨跌额 / 涨跌幅，红涨绿跌
/// - 下拉刷新模拟一次行情更新（行情每 3 秒自动波动）
class GoldPage extends StatelessWidget {
  const GoldPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('黄金行情'),
        actions: [
          IconButton(
            tooltip: '刷新行情',
            onPressed: GoldService.instance.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        // 下拉刷新：立即触发一次模拟行情更新
        onRefresh: () async {
          GoldService.instance.refresh();
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: ListenableBuilder(
          listenable: GoldService.instance,
          builder: (context, _) {
            final g = GoldService.instance;
            final isUp = g.change >= 0;
            final color = isUp ? AppColors.up : AppColors.down;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _PriceCard(service: g, color: color, isUp: isUp),
                const SizedBox(height: 12),
                _ChartCard(history: g.history, color: color),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 现价卡片
class _PriceCard extends StatelessWidget {
  final GoldService service;
  final Color color;
  final bool isUp;

  const _PriceCard({required this.service, required this.color, required this.isUp});

  String _time() {
    final t = service.lastUpdate;
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(t.hour)}:${p(t.minute)}:${p(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final sign = isUp ? '▲' : '▼';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('黄金现货', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('模拟行情', style: TextStyle(fontSize: 11, color: color)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${Fmt.money(service.current)} 元/克',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Tag(
                  text: '$sign ${isUp ? '+' : ''}${Fmt.money(service.change)}',
                  color: color,
                ),
                const SizedBox(width: 8),
                _Tag(
                  text: '${isUp ? '+' : ''}${service.changePercent.toStringAsFixed(2)}%',
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '昨收 ${Fmt.money(service.prevClose)}   ·   更新于 $_time()',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// 涨跌标签
class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

/// 分时走势卡片
class _ChartCard extends StatelessWidget {
  final List<double> history;
  final Color color;

  const _ChartCard({required this.history, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('分时走势', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  '每 3 秒自动模拟更新',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: CustomPaint(
                painter: _PriceChartPainter(data: history, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 折线图绘制器（含渐变填充）
class _PriceChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _PriceChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final range = (maxV - minV) == 0 ? 1.0 : maxV - minV;
    final stepX = size.width / (data.length - 1);

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - 6 - ((data[i] - minV) / range) * (size.height - 12);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // 折线
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // 曲线下方渐变填充
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.30), color.withOpacity(0.02)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fill, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _PriceChartPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

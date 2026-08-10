import 'package:flutter/material.dart';

/// 新闻 Tab：黄金资讯列表（静态模拟数据）
class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  static const List<Map<String, String>> _news = [
    {
      'title': '国际金价再创历史新高，避险与降息预期共振',
      'source': '金十数据',
      'time': '10:32',
      'summary': '受地缘局势紧张与主要央行降息预期影响，国际金价再度刷新历史纪录，机构普遍看好黄金中长期配置价值。',
    },
    {
      'title': '全球央行连续增持黄金，金价中枢或进一步抬升',
      'source': '华尔街见闻',
      'time': '09:15',
      'summary': '最新数据显示，多国央行连续多个季度增持黄金储备，分析人士认为央行购金行为为金价提供了坚实支撑。',
    },
    {
      'title': '美联储官员释放鸽派信号，黄金多头获得新动能',
      'source': '财联社',
      'time': '08:47',
      'summary': '多位美联储官员表态支持年内降息，实际利率下行预期升温，推动以美元计价的黄金价格走强。',
    },
    {
      'title': '黄金 ETF 资金流入创近半年新高',
      'source': '东方财富',
      'time': '昨天',
      'summary': '资金流向数据显示，全球黄金 ETF 单周净流入规模创近半年新高，显示市场配置需求明显回暖。',
    },
    {
      'title': '矿业巨头警告：金矿产量增速放缓将支撑金价',
      'source': '第一财经',
      'time': '昨天',
      'summary': '多家大型矿企表示，优质金矿资源开发难度加大，未来几年黄金供给增速有限，供需缺口或进一步扩大。',
    },
    {
      'title': '投行上调金价目标价，称"黄金超级周期"仍在途中',
      'source': '新浪财经',
      'time': '2天前',
      'summary': '多家国际投行在最新研报中上调金价目标价，认为在去美元化背景下，黄金的货币属性将被重新定价。',
    },
    {
      'title': '金饰消费旺季临近，零售金价持续攀升',
      'source': '每日经济新闻',
      'time': '3天前',
      'summary': '随着传统消费旺季临近，国内金饰零售价格持续走高，消费者观望情绪与"追涨"情绪并存。',
    },
    {
      'title': '实物黄金投资升温，金条回购量明显增加',
      'source': '央视财经',
      'time': '5天前',
      'summary': '近期实物黄金投资需求旺盛，多家银行及金店的金条销量与回购量同比均有明显增长。',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('黄金资讯')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _news.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final n = _news[i];
          return Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n['title']!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    n['summary']!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        n['source']!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.primary),
                      ),
                      const Spacer(),
                      Text(
                        n['time']!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

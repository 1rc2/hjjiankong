/// 数字格式化工具
class Fmt {
  /// 千分位金额，如 1234567.891 → 1,234,567.89
  static String money(double v, {int decimals = 2}) {
    final negative = v < 0;
    final s = v.abs().toStringAsFixed(decimals);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    final result = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
    return '${negative ? '-' : ''}$result';
  }

  /// 带符号金额，如 +1,234.50 / -1,234.50
  static String signed(double v, {int decimals = 2}) {
    final s = money(v.abs(), decimals: decimals);
    return v > 0 ? '+$s' : (v < 0 ? '-$s' : s);
  }
}

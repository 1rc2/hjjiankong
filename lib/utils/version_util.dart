/// 版本号工具类（纯 Dart 实现，不依赖第三方包）
///
/// 注意：曾使用 pub.dev 的 version_compare 包，但该包已从 pub.dev 下架，
/// 故改为自实现的逐段数字比较，语义完全一致（1.0.10 > 1.0.9）。
class VersionUtil {
  /// 统一版本格式：去掉 tag 前缀 v / V 以及 +build 后缀
  /// 例如：v1.0.2 → 1.0.2，1.0.2+build5 → 1.0.2
  static String normalize(String version) {
    var v = version.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    final plus = v.indexOf('+');
    if (plus > 0) {
      v = v.substring(0, plus);
    }
    return v;
  }

  /// 判断远程版本是否大于本地版本（有更新返回 true）
  static bool isNewer(String remote, String local) =>
      _segmentCompare(normalize(remote), normalize(local)) > 0;

  /// 逐段数字比较，例如 1.0.10 > 1.0.9
  static int _segmentCompare(String a, String b) {
    final as = a.split('.').map(int.tryParse).toList();
    final bs = b.split('.').map(int.tryParse).toList();
    final len = as.length > bs.length ? as.length : bs.length;
    for (var i = 0; i < len; i++) {
      final x = i < as.length ? (as[i] ?? 0) : 0;
      final y = i < bs.length ? (bs[i] ?? 0) : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}

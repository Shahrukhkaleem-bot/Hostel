/// "just now", "5m ago", "3h ago", "2d ago", or a date for older items.
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.day}/${time.month}/${time.year}';
}

/// 12000 → "12,000"
String formatRs(int amount) {
  final s = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 84000 → "84k", 1250 → "1.3k", 900 → "900"
String compactRs(int amount) {
  if (amount >= 1000000) {
    final m = amount / 1000000;
    return '${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1)}M';
  }
  if (amount >= 1000) {
    final k = amount / 1000;
    return '${k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)}k';
  }
  return '$amount';
}

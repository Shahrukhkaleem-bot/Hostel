import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationRow {
  const NotificationRow({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  factory NotificationRow.fromJson(Map<String, dynamic> j) => NotificationRow(
    id: j['id'].toString(),
    type: (j['type'] ?? 'system').toString(),
    title: (j['title'] ?? '').toString(),
    body: (j['body'] ?? '').toString(),
    isRead: j['is_read'] == true,
    createdAt:
        DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

/// In-app notifications. They are created by database triggers/RPCs; the
/// client can only read them, mark them read, or delete them.
class SupabaseNotificationRepository {
  SupabaseNotificationRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _table = 'notifications';

  Future<List<NotificationRow>> fetch({int limit = 100}) async {
    final rows = await _client
        .from(_table)
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(NotificationRow.fromJson).toList();
  }

  Future<int> unreadCount() async {
    return _client.from(_table).count(CountOption.exact).eq('is_read', false);
  }

  Future<void> markRead(String id) async {
    await _client.from(_table).update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllRead() async {
    await _client.from(_table).update({'is_read': true}).eq('is_read', false);
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}

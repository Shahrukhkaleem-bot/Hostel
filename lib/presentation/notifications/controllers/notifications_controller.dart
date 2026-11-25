import 'package:get/get.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/time_ago.dart';
import '../../../data/repositories/supabase_notification_repository.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type, // bid | offer | system | chat
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final String time;
  final String type;
  bool isRead;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      time: map['time']?.toString() ?? '',
      type: map['type']?.toString() ?? 'system',
      isRead: map['isRead'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'time': time,
      'type': type,
      'isRead': isRead,
    };
  }
}

class NotificationsController extends GetxController {
  final _repo = Get.find<SupabaseNotificationRepository>();
  final notifications = <AppNotification>[].obs;
  final selectedTab = 0.obs; // 0 = All, 1 = Unread
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final rows = await _repo.fetch();
      notifications.assignAll(
        rows.map(
          (r) => AppNotification(
            id: r.id,
            title: r.title,
            body: r.body,
            time: timeAgo(r.createdAt),
            type: r.type,
            isRead: r.isRead,
          ),
        ),
      );
    } catch (error) {
      AppSnackbar.error('Notifications', friendlyError(error));
    } finally {
      isLoading.value = false;
    }
  }

  List<AppNotification> get filtered {
    if (selectedTab.value == 1) {
      return notifications.where((n) => !n.isRead).toList();
    }
    return notifications.toList();
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void onTabChanged(int index) => selectedTab.value = index;

  Future<void> markAsRead(AppNotification item) async {
    final i = notifications.indexWhere((n) => n.id == item.id);
    if (i == -1 || notifications[i].isRead) return;
    notifications[i].isRead = true;
    notifications.refresh();
    try {
      await _repo.markRead(item.id);
    } catch (_) {
      notifications[i].isRead = false;
      notifications.refresh();
    }
  }

  Future<void> markAllRead() async {
    final unread = notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    for (final n in unread) {
      n.isRead = true;
    }
    notifications.refresh();
    try {
      await _repo.markAllRead();
    } catch (error) {
      for (final n in unread) {
        n.isRead = false;
      }
      notifications.refresh();
      AppSnackbar.error('Notifications', friendlyError(error));
    }
  }

  Future<void> deleteNotification(AppNotification item) async {
    final index = notifications.indexWhere((n) => n.id == item.id);
    if (index == -1) return;
    final removed = notifications.removeAt(index);
    try {
      await _repo.delete(item.id);
    } catch (error) {
      notifications.insert(index, removed);
      AppSnackbar.error('Notifications', friendlyError(error));
    }
  }
}

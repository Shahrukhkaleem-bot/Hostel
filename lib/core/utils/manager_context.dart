import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../domain/repositories/i_hostel_repository.dart';

/// Which hostel the manager currently has selected.
///
/// The selection is cached locally (`manager_hostels` + `selected_hostel_index`),
/// but only server-issued UUIDs are trusted; anything else is re-fetched.
class ManagerContext {
  ManagerContext._();

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static String? _cachedId() {
    final box = GetStorage();
    final stored = box.read('manager_hostels');
    if (stored is! List || stored.isEmpty) return null;
    final saved = box.read('selected_hostel_index');
    final index = (saved is int && saved >= 0 && saved < stored.length)
        ? saved
        : stored.length - 1;
    final entry = stored[index];
    final id = entry is Map ? entry['id']?.toString() : null;
    return (id != null && _uuid.hasMatch(id)) ? id : null;
  }

  /// Selected hostel id, falling back to the server when the cache is stale.
  static Future<String?> selectedHostelId() async {
    final cached = _cachedId();
    if (cached != null) return cached;
    final hostels = await Get.find<IHostelRepository>().fetchMyHostels();
    if (hostels.isEmpty) return null;
    return hostels.last.id;
  }
}

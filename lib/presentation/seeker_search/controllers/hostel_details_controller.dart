import 'package:get/get.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_text.dart';
import '../../../data/models/seeker_models.dart';
import '../../../data/repositories/supabase_seeker_repository.dart';
import '../../../routes/app_routes.dart';

/// Loads one hostel's photos, rooms, facilities and reviews.
/// The list card passed as route arguments is shown instantly while loading.
class HostelDetailsController extends GetxController {
  late final Map<String, dynamic> card;
  final detail = Rxn<HostelDetail>();
  final isLoading = true.obs;
  final photoIndex = 0.obs;

  String get name => detail.value?.name ?? card['name']?.toString() ?? 'Hostel';
  String get area => detail.value?.area ?? card['area']?.toString() ?? '';
  String get city => detail.value?.city ?? card['city']?.toString() ?? '';
  String get type => detail.value?.type ?? card['type']?.toString() ?? '';

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    card = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    load();
  }

  Future<void> load() async {
    final id = card['id']?.toString();
    if (id == null) {
      isLoading.value = false;
      return;
    }
    isLoading.value = true;
    try {
      detail.value = await Get.find<SupabaseSeekerRepository>().hostelDetail(id);
    } catch (error) {
      AppSnackbar.error('Hostel', friendlyError(error));
    } finally {
      isLoading.value = false;
    }
  }

  void placeBid() {
    Get.toNamed(AppRoutes.placeBid, arguments: {'type': type, 'city': city});
  }
}

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_text.dart';
import '../../../data/models/seeker_models.dart';
import '../../../data/repositories/supabase_seeker_repository.dart';
import '../../../routes/app_routes.dart';

class SeekerSearchController extends GetxController {
  final selectedNavIndex = 2.obs; // Search tab
  final searchQuery = ''.obs;
  final selectedFilter = 'All'.obs;
  final isLoading = true.obs;

  /// Seater filters understood by the backend.
  final filters = ['All', '1-seater', '2-seater', '3-seater', '4-seater'];

  final hostels = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    search();
    debounce(searchQuery, (_) => search(), time: const Duration(milliseconds: 350));
    ever(selectedFilter, (_) => search());
  }

  Future<void> search() async {
    isLoading.value = true;
    try {
      final f = selectedFilter.value;
      final seater = f == 'All' ? null : int.tryParse(f.split('-').first);
      final city = GetStorage().read('profile_city')?.toString().trim();
      final list = await Get.find<SupabaseSeekerRepository>().browseHostels(
        city: (city == null || city.isEmpty) ? null : city,
        query: searchQuery.value,
        seater: seater,
        limit: 50,
      );
      hostels.assignAll(list.map(listingToCard));
    } catch (error) {
      AppSnackbar.error('Search', friendlyError(error));
    } finally {
      isLoading.value = false;
    }
  }

  /// Already filtered by the server.
  List<Map<String, dynamic>> get filteredHostels => hostels.toList();

  void onNavTap(int index) {
    if (index == selectedNavIndex.value) return;
    selectedNavIndex.value = index;
    switch (index) {
      case 0:
        Get.offAllNamed(AppRoutes.seekerHome);
        break;
      case 1:
        Get.offAllNamed(AppRoutes.seekerBids);
        break;
      case 2:
        break;
      case 3:
        Get.toNamed(AppRoutes.profile);
        selectedNavIndex.value = 2;
        break;
    }
  }

  void onHostelTap(Map<String, dynamic> hostel) {
    Get.toNamed(AppRoutes.hostelDetails, arguments: hostel);
  }
}

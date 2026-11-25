import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_text.dart';
import '../../../data/models/seeker_models.dart';
import '../../../data/repositories/supabase_seeker_repository.dart';
import '../../../routes/app_routes.dart';

class SeekerMapController extends GetxController {
  final selectedFilter = 'All'.obs;
  final searchQuery = ''.obs;
  final selectedHostel = Rxn<Map<String, dynamic>>();
  final isLoading = true.obs;

  final filters = ['All', 'Under 10k', 'Under 15k', 'Under 20k'];

  final hostels = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
    debounce(searchQuery, (_) => load(), time: const Duration(milliseconds: 350));
    ever(selectedFilter, (_) => load());
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final city = GetStorage().read('profile_city')?.toString().trim();
      final f = selectedFilter.value;
      final maxRent = switch (f) {
        'Under 10k' => 10000,
        'Under 15k' => 15000,
        'Under 20k' => 20000,
        _ => null,
      };
      final list = await Get.find<SupabaseSeekerRepository>().browseHostels(
        city: (city == null || city.isEmpty) ? null : city,
        query: searchQuery.value,
        maxRent: maxRent,
        limit: 50,
      );
      hostels.assignAll(list.map(listingToCard));
    } catch (error) {
      AppSnackbar.error('Hostels', friendlyError(error));
    } finally {
      isLoading.value = false;
    }
  }

  List<Map<String, dynamic>> get filtered => hostels.toList();

  void onFilterChanged(String f) => selectedFilter.value = f;

  void onSearchChanged(String q) => searchQuery.value = q;

  void onHostelTap(Map<String, dynamic> h) {
    selectedHostel.value = h;
    Get.toNamed(AppRoutes.hostelDetails, arguments: h);
  }

  void onNavTap(int index) {
    switch (index) {
      case 0:
        Get.offAllNamed(AppRoutes.seekerHome);
        break;
      case 1:
        Get.toNamed(AppRoutes.seekerBids);
        break;
      case 2:
        Get.toNamed(AppRoutes.seekerSearch);
        break;
      case 3:
        Get.toNamed(AppRoutes.profile);
        break;
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../domain/repositories/i_auth_repository.dart';
import '../../../domain/repositories/i_hostel_repository.dart';
import '../../../routes/app_routes.dart';

class SplashController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    debugPrint('===== SPLASH CONTROLLER STARTED =====');
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final user = await Get.find<IAuthRepository>().getCurrentUser();
      if (user == null) {
        Get.offNamed(AppRoutes.auth);
      } else if (user.role == 'manager') {
        Get.offNamed(
          await _hasHostel() ? AppRoutes.managerHome : AppRoutes.hostelSetup,
        );
      } else if (user.role == 'seeker') {
        Get.offNamed(AppRoutes.seekerHome);
      } else {
        Get.offNamed(
          AppRoutes.profileSetup,
          arguments: {'name': user.name, 'phone': user.phone},
        );
      }
    } on Exception catch (error) {
      AppSnackbar.error(
        'Session unavailable',
        'Could not restore your session. ${error.toString()}',
      );
      Get.offNamed(AppRoutes.auth);
    }
  }

  /// A manager without a registered hostel must finish hostel setup first.
  Future<bool> _hasHostel() async {
    final cached = GetStorage().read('manager_hostels');
    if (cached is List && cached.isNotEmpty) return true;
    try {
      return (await Get.find<IHostelRepository>().fetchMyHostels()).isNotEmpty;
    } on Exception {
      return true; // offline: don't trap an existing manager in setup
    }
  }
}

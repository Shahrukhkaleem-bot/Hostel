import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../domain/repositories/i_auth_repository.dart';
import '../../../routes/app_routes.dart';

/// Role selection: seeker or manager — nothing selected until user taps.
class RoleSelectionController extends GetxController {
  /// null until user selects; then AppConstants.roleSeeker | roleManager
  final selectedRole = RxnString();
  final isLoading = false.obs;
  final _box = GetStorage();

  void selectRole(String role) {
    selectedRole.value = role;
  }

  Future<void> continueNext() async {
    if (selectedRole.value == null) {
      AppSnackbar.warning(
        'Select a role',
        'Please choose how you will use HostelBuddy.',
      );
      return;
    }

    isLoading.value = true;
    try {
      final repository = Get.find<IAuthRepository>();
      final user = await repository.getCurrentUser();
      if (user == null) {
        throw Exception('Sign in again before selecting an account role.');
      }
      await repository.setRole(userId: user.id, role: selectedRole.value!);
      await _box.write('user_role', selectedRole.value);
    } on Exception catch (error) {
      AppSnackbar.error('Role not saved', error.toString());
      return;
    } finally {
      isLoading.value = false;
    }

    if (selectedRole.value == AppConstants.roleManager) {
      Get.offNamed(AppRoutes.hostelSetup);
    } else {
      Get.offNamed(AppRoutes.seekerHome);
    }
  }

  void goBack() => Get.back();
}

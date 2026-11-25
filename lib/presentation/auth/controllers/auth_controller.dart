import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../routes/app_routes.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/supabase_auth_repository.dart';
import '../../../domain/repositories/i_auth_repository.dart';

class AuthController extends GetxController {
  final isLogin = true.obs; // start on Login

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  final formKey = GlobalKey<FormState>();
  final isLoading = false.obs;
  final obscurePassword = true.obs;

  void toggleMode() {
    isLogin.value = !isLogin.value;
    nameController.clear();
    emailController.clear();
    phoneController.clear();
    passwordController.clear();
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final repository = Get.find<IAuthRepository>();
      final user = isLogin.value
          ? await repository.login(
              email: emailController.text.trim(),
              password: passwordController.text,
            )
          : await repository.signup(
              name: nameController.text.trim(),
              email: emailController.text.trim(),
              phone: phoneController.text.trim(),
              password: passwordController.text,
            );
      AppSnackbar.success(
        'Success',
        isLogin.value ? 'Logged in successfully' : 'Account created successfully',
      );
      _continueAfterAuthentication(user);
    } on EmailConfirmationRequiredException {
      AppSnackbar.info(
        'Check your email',
        'Confirm your email address before signing in.',
      );
    } on AuthException catch (error) {
      AppSnackbar.error('Sign-in failed', error.message);
    } on Exception catch (error) {
      AppSnackbar.error('Sign-in failed', _errorMessage(error));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> continueWithGoogle() async {
    isLoading.value = true;
    try {
      final user = await Get.find<SupabaseAuthRepository>().signInWithGoogle();
      if (user == null) return;
      AppSnackbar.success(
        'Welcome',
        user.name.isEmpty ? 'Google sign-in successful' : 'Signed in as ${user.name}',
      );
      _continueAfterAuthentication(user);
    } on AuthFlowCancelledException {
      return;
    } on AuthException catch (error) {
      AppSnackbar.error('Google sign-in failed', error.message);
    } on Exception catch (error) {
      AppSnackbar.error('Google sign-in failed', _errorMessage(error));
    } finally {
      isLoading.value = false;
    }
  }

  void _continueAfterAuthentication(UserModel user) {
    if (user.role == 'manager') {
      Get.offAllNamed(AppRoutes.managerHome);
    } else if (user.role == 'seeker') {
      Get.offAllNamed(AppRoutes.seekerHome);
    } else {
      Get.offNamed(
        AppRoutes.profileSetup,
        arguments: {'name': user.name, 'phone': user.phone},
      );
    }
  }

  String _errorMessage(Exception error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Please check your connection and try again.' : message;
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

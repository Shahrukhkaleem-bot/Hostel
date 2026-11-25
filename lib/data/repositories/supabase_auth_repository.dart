import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_config.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../models/user_model.dart';

class AuthFlowCancelledException implements Exception {
  const AuthFlowCancelledException();
}

class EmailConfirmationRequiredException implements Exception {
  const EmailConfirmationRequiredException();
}

class SupabaseAuthRepository implements IAuthRepository {
  SupabaseAuthRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final _box = GetStorage();
  static const _sessionKey = 'session_user_id';

  static Future<void> initializeGoogleSignIn() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: SupabaseConfig.googleWebClientId,
    );
  }

  @override
  Future<UserModel> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, 'phone': phone},
    );
    final user = response.user;
    if (user == null) {
      throw Exception('Supabase did not return a user after sign-up.');
    }
    if (response.session == null) {
      throw const EmailConfirmationRequiredException();
    }
    return _saveSessionUser(user);
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw Exception('Supabase did not return a user after sign-in.');
    }
    return _saveSessionUser(user);
  }

  Future<UserModel?> signInWithGoogle() async {
    if (kIsWeb) {
      final started = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
      if (!started) {
        throw Exception('Could not start Google sign-in in the browser.');
      }
      return null;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw Exception(
            'Google did not return an ID token. Check the OAuth client configuration.',
          );
        }
        final response = await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        );
        final user = response.user;
        if (user == null) {
          throw Exception(
            'Supabase did not return a user after Google sign-in.',
          );
        }
        return _saveSessionUser(user);
      } on GoogleSignInException catch (error) {
        if (error.code == GoogleSignInExceptionCode.canceled) {
          throw const AuthFlowCancelledException();
        }
        rethrow;
      }
    }

    final started = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseConfig.iosAuthCallbackUrl,
    );
    if (!started) {
      throw Exception('Could not start Google sign-in in the browser.');
    }
    return null;
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    required String city,
    required String occupation,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'full_name': name,
          'phone': phone,
          'city': city,
          'occupation': occupation,
        },
      ),
    );
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
    await _box.remove(_sessionKey);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await GoogleSignIn.instance.signOut();
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      await _box.remove(_sessionKey);
      return null;
    }
    return _saveSessionUser(user);
  }

  @override
  Future<UserModel> setRole({
    required String userId,
    required String role,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || user.id != userId) {
      throw Exception('The signed-in user changed before their role was saved.');
    }
    final response = await _client.auth.updateUser(
      UserAttributes(data: {'role': role}),
    );
    final updatedUser = response.user;
    if (updatedUser == null) {
      throw Exception('Supabase did not return the updated user role.');
    }
    return _saveSessionUser(updatedUser);
  }

  Future<UserModel> _saveSessionUser(User user) async {
    final model = _toUserModel(user);
    await _box.write(_sessionKey, model.id);
    await _box.write('profile_name', model.name);
    await _box.write('profile_email', model.email);
    await _box.write('profile_phone', model.phone);
    await _box.write('profile_city', model.city ?? '');
    if (model.profilePicture != null) {
      await _box.write('profile_avatar_url', model.profilePicture);
    }
    if (model.role == null || model.role!.isEmpty) {
      await _box.remove('user_role');
    } else {
      await _box.write('user_role', model.role);
    }
    return model;
  }

  UserModel _toUserModel(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return UserModel(
      id: user.id,
      name: (metadata['full_name'] ?? metadata['name'] ?? '').toString(),
      email: user.email ?? '',
      phone: (metadata['phone'] ?? user.phone ?? '').toString(),
      profilePicture:
          (metadata['avatar_url'] ?? metadata['picture'])?.toString(),
      city: metadata['city']?.toString(),
      role: metadata['role']?.toString(),
    );
  }
}

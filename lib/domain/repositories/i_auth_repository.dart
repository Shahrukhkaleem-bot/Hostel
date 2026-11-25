import '../../data/models/user_model.dart';

/// Contract for authentication providers used by application controllers.
abstract class IAuthRepository {
  Future<UserModel> signup({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  Future<UserModel> login({required String email, required String password});

  Future<void> logout();

  /// Returns the persisted session's user, or null if nobody is logged in.
  Future<UserModel?> getCurrentUser();

  /// Called after Role Selection to persist the chosen role.
  Future<UserModel> setRole({required String userId, required String role});
}

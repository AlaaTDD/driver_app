// lib/features/user/domain/repositories/user_profile_repository.dart
abstract class UserProfileRepository {
  Future<Map<String, dynamic>?> getUserProfile(String userId);
  Future<void> updateProfile(String userId, Map<String, dynamic> data);
}

import 'package:get_storage/get_storage.dart';

/// Local keys that belong to the signed-in user. Must be wiped on logout so
/// the next account on this device never sees the previous user's data.
const _userKeys = [
  'profile_name',
  'profile_email',
  'profile_phone',
  'profile_city',
  'profile_occupation',
  'profile_photo',
  'profile_avatar_url',
  'session_user_id',
  'user_role',
  'manager_hostels',
  'selected_hostel_index',
  'hostel_name',
  'hostel_type',
  'hostel_area',
  'hostel_description',
  'hostel_contact',
  'hostel_rooms',
  'hostel_photos',
  'hostel_facilities',
  'hostel_room_types',
  'seeker_my_bids',
  'app_notifications',
];

Future<void> clearLocalSession() async {
  final box = GetStorage();
  for (final key in _userKeys) {
    await box.remove(key);
  }
}

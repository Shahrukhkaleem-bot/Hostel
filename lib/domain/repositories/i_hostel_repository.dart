import '../../data/models/hostel_model.dart';

/// Contract for persisting hostels owned by the signed-in manager.
abstract class IHostelRepository {
  /// Uploads [photoPaths] (local file paths) and creates the hostel.
  Future<HostelModel> createHostel({
    required String name,
    required String type,
    required String city,
    required String area,
    required String contact,
    required String description,
    required int totalRooms,
    required List<String> roomTypes,
    required List<String> facilities,
    required List<String> photoPaths,
  });

  /// Hostels owned by the signed-in manager, oldest first.
  Future<List<HostelModel>> fetchMyHostels();

  /// Updates the editable listing fields of one of the manager's hostels.
  Future<HostelModel> updateHostel({
    required String id,
    required String name,
    required String type,
    required String city,
    required String area,
    required String contact,
    required String description,
    required int totalRooms,
  });

  /// Deletes a hostel (rooms and offers cascade) and its stored photos.
  Future<void> deleteHostel(String id);
}

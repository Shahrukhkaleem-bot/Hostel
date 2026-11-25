class HostelModel {
  final String id;
  final String ownerId;
  final String name;
  final String type; // 'Boys Hostel' | 'Girls Hostel'
  final String city;
  final String area;
  final String contact;
  final String description;
  final int totalRooms;
  final List<String> roomTypes;
  final List<String> facilities;
  final List<String> photoUrls;
  final double? ratingAvg;
  final int ratingCount;

  const HostelModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.city,
    required this.area,
    required this.contact,
    required this.description,
    required this.totalRooms,
    required this.roomTypes,
    required this.facilities,
    required this.photoUrls,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  /// [contact] is supplied separately because the table column is not
  /// readable by clients (see `my_hostel_contacts` RPC).
  factory HostelModel.fromJson(Map<String, dynamic> json, {String? contact}) {
    List<String> list(String key) =>
        (json[key] as List?)?.map((e) => e.toString()).toList() ?? const [];

    return HostelModel(
      id: json['id'].toString(),
      ownerId: json['owner_id'].toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['hostel_type'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      area: (json['area'] ?? '').toString(),
      contact: contact ?? (json['contact'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      totalRooms: (json['total_rooms'] as num?)?.toInt() ?? 0,
      roomTypes: list('room_types'),
      facilities: list('facilities'),
      photoUrls: list('photo_urls'),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Payload for insert — `id` and `owner_id` are filled in by the database.
  static Map<String, dynamic> toInsertJson({
    required String name,
    required String type,
    required String city,
    required String area,
    required String contact,
    required String description,
    required int totalRooms,
    required List<String> roomTypes,
    required List<String> facilities,
    required List<String> photoUrls,
  }) {
    return {
      'name': name,
      'hostel_type': type,
      'city': city,
      'area': area,
      'contact': contact,
      'description': description,
      'total_rooms': totalRooms,
      'room_types': roomTypes,
      'facilities': facilities,
      'photo_urls': photoUrls,
    };
  }
}

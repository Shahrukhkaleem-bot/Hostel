class RoomModel {
  const RoomModel({
    required this.id,
    required this.hostelId,
    required this.number,
    required this.floor,
    required this.seater,
    required this.rent,
    required this.status,
  });

  final String id;
  final String hostelId;
  final String number;
  final int floor;
  final int seater;
  final int rent;

  /// vacant | occupied | reserved
  final String status;

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'].toString(),
      hostelId: json['hostel_id'].toString(),
      number: (json['room_number'] ?? '').toString(),
      floor: (json['floor'] as num?)?.toInt() ?? 1,
      seater: (json['seater'] as num?)?.toInt() ?? 1,
      rent: (json['rent'] as num?)?.toInt() ?? 0,
      status: (json['status'] ?? 'vacant').toString(),
    );
  }
}

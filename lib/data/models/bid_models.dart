/// Numbers shown on the manager dashboard (one RPC round trip).
class DashboardStats {
  const DashboardStats({
    this.declaredRooms = 0,
    this.totalRooms = 0,
    this.vacantRooms = 0,
    this.occupiedRooms = 0,
    this.reservedRooms = 0,
    this.pendingBids = 0,
    this.offeredBids = 0,
    this.acceptedBids = 0,
    this.monthlyRevenue = 0,
  });

  final int declaredRooms;
  final int totalRooms;
  final int vacantRooms;
  final int occupiedRooms;
  final int reservedRooms;
  final int pendingBids;
  final int offeredBids;
  final int acceptedBids;
  final int monthlyRevenue;

  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return DashboardStats(
      declaredRooms: n('declared_rooms'),
      totalRooms: n('total_rooms'),
      vacantRooms: n('vacant_rooms'),
      occupiedRooms: n('occupied_rooms'),
      reservedRooms: n('reserved_rooms'),
      pendingBids: n('pending_bids'),
      offeredBids: n('offered_bids'),
      acceptedBids: n('accepted_bids'),
      monthlyRevenue: n('monthly_revenue'),
    );
  }
}

/// A seeker bid as seen by one manager's hostel.
class IncomingBidModel {
  const IncomingBidModel({
    required this.bidId,
    required this.seekerName,
    required this.seaterLabel,
    required this.amenities,
    required this.offerAmount,
    required this.createdAt,
    required this.status,
    this.offerId,
    this.offeredPrice,
    this.seekerPhone,
    this.hasMatchingRoom = false,
  });

  final String bidId;
  final String? offerId;
  final String seekerName;
  final String? seekerPhone;
  final String seaterLabel;
  final List<String> amenities;
  final int offerAmount;
  final DateTime createdAt;

  /// pending | offered | accepted
  final String status;
  final int? offeredPrice;
  final bool hasMatchingRoom;

  factory IncomingBidModel.fromJson(Map<String, dynamic> j) {
    return IncomingBidModel(
      bidId: j['bid_id'].toString(),
      offerId: j['offer_id']?.toString(),
      seekerName: (j['seeker_name'] ?? 'Seeker').toString(),
      seekerPhone: j['seeker_phone']?.toString(),
      seaterLabel: (j['seater_label'] ?? '').toString(),
      amenities:
          (j['amenities'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      offerAmount: (j['offer_amount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(j['bid_created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      status: (j['response_status'] ?? 'pending').toString(),
      offeredPrice: (j['offered_price'] as num?)?.toInt(),
      hasMatchingRoom: j['has_matching_room'] == true,
    );
  }
}

/// Parses "2 Seater" / "Single" / "5+ Seater" / "Studio" into a head-count.
/// Returns null when the label has no single fixed capacity.
int? parseSeater(String label) {
  final s = label.toLowerCase();
  if (s.contains('single')) return 1;
  final m = RegExp(r'(\d+)\s*(\+)?').firstMatch(s);
  if (m == null || m.group(2) != null) return null;
  final n = int.tryParse(m.group(1)!);
  return (n != null && n >= 1 && n <= 20) ? n : null;
}

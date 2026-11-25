import '../../core/utils/time_ago.dart';

/// One row of the hostel browse/search list.
class HostelListing {
  const HostelListing({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.area,
    required this.facilities,
    required this.vacantRooms,
    this.photoUrl,
    this.ratingAvg,
    this.ratingCount = 0,
    this.minRent,
  });

  final String id;
  final String name;
  final String type;
  final String city;
  final String area;
  final List<String> facilities;
  final String? photoUrl;
  final double? ratingAvg;
  final int ratingCount;
  final int? minRent;
  final int vacantRooms;

  factory HostelListing.fromJson(Map<String, dynamic> j) => HostelListing(
    id: j['id'].toString(),
    name: (j['name'] ?? '').toString(),
    type: (j['hostel_type'] ?? '').toString(),
    city: (j['city'] ?? '').toString(),
    area: (j['area'] ?? '').toString(),
    facilities:
        (j['facilities'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    photoUrl: j['photo_url']?.toString(),
    ratingAvg: (j['rating_avg'] as num?)?.toDouble(),
    ratingCount: (j['rating_count'] as num?)?.toInt() ?? 0,
    minRent: (j['min_rent'] as num?)?.toInt(),
    vacantRooms: (j['vacant_rooms'] as num?)?.toInt() ?? 0,
  );
}

class RoomSummary {
  const RoomSummary({
    required this.seater,
    required this.vacant,
    required this.total,
    this.minRent,
  });

  final int seater;
  final int vacant;
  final int total;
  final int? minRent;

  factory RoomSummary.fromJson(Map<String, dynamic> j) => RoomSummary(
    seater: (j['seater'] as num?)?.toInt() ?? 1,
    vacant: (j['vacant'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    minRent: (j['min_rent'] as num?)?.toInt(),
  );
}

class HostelReviewItem {
  const HostelReviewItem({
    required this.name,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String name;
  final double rating;
  final String comment;
  final DateTime createdAt;

  factory HostelReviewItem.fromJson(Map<String, dynamic> j) => HostelReviewItem(
    name: (j['name'] ?? 'Guest').toString(),
    rating: (j['rating'] as num?)?.toDouble() ?? 0,
    comment: (j['comment'] ?? '').toString(),
    createdAt:
        DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

class HostelDetail {
  const HostelDetail({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.area,
    required this.description,
    required this.facilities,
    required this.photoUrls,
    required this.rooms,
    required this.reviews,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  final String id;
  final String name;
  final String type;
  final String city;
  final String area;
  final String description;
  final List<String> facilities;
  final List<String> photoUrls;
  final List<RoomSummary> rooms;
  final List<HostelReviewItem> reviews;
  final double? ratingAvg;
  final int ratingCount;

  int? get minRent {
    final rents = rooms.where((r) => r.vacant > 0 && r.minRent != null);
    if (rents.isEmpty) return null;
    return rents.map((r) => r.minRent!).reduce((a, b) => a < b ? a : b);
  }

  int get vacantRooms => rooms.fold(0, (sum, r) => sum + r.vacant);

  factory HostelDetail.fromJson(Map<String, dynamic> j) {
    List<String> strings(String k) =>
        (j[k] as List?)?.map((e) => e.toString()).toList() ?? const [];
    return HostelDetail(
      id: j['id'].toString(),
      name: (j['name'] ?? '').toString(),
      type: (j['hostel_type'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      area: (j['area'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      facilities: strings('facilities'),
      photoUrls: strings('photo_urls'),
      rooms: ((j['rooms'] as List?) ?? const [])
          .map((e) => RoomSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      reviews: ((j['reviews'] as List?) ?? const [])
          .map(
            (e) =>
                HostelReviewItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      ratingAvg: (j['rating_avg'] as num?)?.toDouble(),
      ratingCount: (j['rating_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SeekerStats {
  const SeekerStats({
    this.openBids = 0,
    this.offersReceived = 0,
    this.acceptedDeals = 0,
    this.avgOffer,
    this.coins = 0,
  });

  final int openBids;
  final int offersReceived;
  final int acceptedDeals;
  final int? avgOffer;
  final int coins;

  factory SeekerStats.fromJson(Map<String, dynamic> j) => SeekerStats(
    openBids: (j['open_bids'] as num?)?.toInt() ?? 0,
    offersReceived: (j['offers_received'] as num?)?.toInt() ?? 0,
    acceptedDeals: (j['accepted_deals'] as num?)?.toInt() ?? 0,
    avgOffer: (j['avg_offer'] as num?)?.toInt(),
    coins: (j['coins'] as num?)?.toInt() ?? 0,
  );
}

/// An offer a hostel made on one of the seeker's bids.
class SeekerOffer {
  const SeekerOffer({
    required this.offerId,
    required this.bidId,
    required this.hostelId,
    required this.hostelName,
    required this.area,
    required this.city,
    required this.hostelType,
    required this.seaterLabel,
    required this.bidAmount,
    required this.offeredPrice,
    required this.tab,
    required this.reviewed,
    this.contact,
    this.myRating,
  });

  final String offerId;
  final String bidId;
  final String hostelId;
  final String hostelName;
  final String area;
  final String city;
  final String hostelType;
  final String seaterLabel;
  final int bidAmount;
  final int offeredPrice;

  /// received | pending | closed
  final String tab;
  final String? contact;
  final bool reviewed;
  final double? myRating;

  factory SeekerOffer.fromJson(Map<String, dynamic> j) => SeekerOffer(
    offerId: j['offer_id'].toString(),
    bidId: j['bid_id'].toString(),
    hostelId: j['hostel_id'].toString(),
    hostelName: (j['hostel_name'] ?? '').toString(),
    area: (j['area'] ?? '').toString(),
    city: (j['city'] ?? '').toString(),
    hostelType: (j['hostel_type'] ?? '').toString(),
    seaterLabel: (j['seater_label'] ?? '').toString(),
    bidAmount: (j['bid_amount'] as num?)?.toInt() ?? 0,
    offeredPrice: (j['offered_price'] as num?)?.toInt() ?? 0,
    tab: (j['tab'] ?? 'received').toString(),
    contact: j['contact']?.toString(),
    reviewed: j['reviewed'] == true,
    myRating: (j['my_rating'] as num?)?.toDouble(),
  );
}

/// A bid the seeker placed, with how many offers it attracted.
class MyBidRow {
  const MyBidRow({
    required this.id,
    required this.city,
    required this.hostelType,
    required this.seaterLabel,
    required this.amenities,
    required this.offerAmount,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.offerCount,
  });

  final String id;
  final String city;
  final String hostelType;
  final String seaterLabel;
  final List<String> amenities;
  final int offerAmount;

  /// open | closed
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int offerCount;

  factory MyBidRow.fromJson(Map<String, dynamic> j) => MyBidRow(
    id: j['id'].toString(),
    city: (j['city'] ?? '').toString(),
    hostelType: (j['hostel_type'] ?? 'Boys Hostel').toString(),
    seaterLabel: (j['seater_label'] ?? '').toString(),
    amenities:
        (j['amenities'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    offerAmount: (j['offer_amount'] as num?)?.toInt() ?? 0,
    status: (j['status'] ?? 'open').toString(),
    createdAt:
        DateTime.tryParse(j['created_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    expiresAt:
        DateTime.tryParse(j['expires_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    offerCount: (j['offer_count'] as num?)?.toInt() ?? 0,
  );
}

/// Result of spending coins to unlock an offer.
class UnlockResult {
  const UnlockResult({required this.coins, this.contact});
  final int coins;
  final String? contact;
}

/// Hostel list entry in the shape the existing seeker cards expect.
Map<String, dynamic> listingToCard(HostelListing h) {
  const palette = [0xFF8B1538, 0xFF0D9488, 0xFF5C0E24, 0xFF6B0E24];
  final color = palette[h.name.codeUnits.fold<int>(0, (a, b) => a + b) % 4];
  return {
    'id': h.id,
    'name': h.name,
    'area': h.area,
    'city': h.city,
    'distance': h.vacantRooms > 0 ? '${h.vacantRooms} vacant' : 'No vacancy',
    'price': h.minRent == null ? 'Ask for price' : 'From Rs ${compactRs(h.minRent!)}/mo',
    'rating': h.ratingAvg ?? 0.0,
    'ratingCount': h.ratingCount,
    'type': h.type,
    'seater': '',
    'photo': h.photoUrl,
    'color': color,
  };
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/seeker_models.dart';

/// Everything the seeker app reads/does besides placing a bid
/// (see [SupabaseBidRepository] for bids): browsing hostels, offers,
/// coins, accept/decline and reviews. All rules are enforced server-side.
class SupabaseSeekerRepository {
  SupabaseSeekerRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<HostelListing>> browseHostels({
    String? city,
    String? type,
    String? query,
    int? seater,
    int? maxRent,
    int limit = 30,
    int offset = 0,
  }) async {
    final res = await _client.rpc(
      'browse_hostels',
      params: {
        'p_city': city,
        'p_type': type,
        'p_query': query,
        'p_seater': seater,
        'p_max_rent': maxRent,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return (res as List)
        .map((e) => HostelListing.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<HostelDetail?> hostelDetail(String hostelId) async {
    final res = await _client.rpc(
      'hostel_detail',
      params: {'p_hostel_id': hostelId},
    );
    if (res == null) return null;
    return HostelDetail.fromJson(Map<String, dynamic>.from(res as Map));
  }

  Future<SeekerStats> dashboard() async {
    final res = await _client.rpc('seeker_dashboard');
    final rows = res as List;
    if (rows.isEmpty) return const SeekerStats();
    return SeekerStats.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<List<MyBidRow>> myBids() async {
    final res = await _client.rpc('seeker_my_bids');
    return (res as List)
        .map((e) => MyBidRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<SeekerOffer>> offers() async {
    final res = await _client.rpc('seeker_offers');
    return (res as List)
        .map((e) => SeekerOffer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Spends 100 coins; returns the new balance and the hostel's contact.
  Future<UnlockResult> unlockOffer(String offerId) async {
    final res = await _client.rpc(
      'unlock_offer',
      params: {'p_offer_id': offerId},
    );
    final row = Map<String, dynamic>.from((res as List).first as Map);
    return UnlockResult(
      coins: (row['coins'] as num?)?.toInt() ?? 0,
      contact: row['contact']?.toString(),
    );
  }

  Future<void> acceptOffer(String offerId) async {
    await _client.rpc('accept_offer', params: {'p_offer_id': offerId});
  }

  Future<void> declineOffer(String offerId, {String? reason}) async {
    await _client.rpc(
      'decline_offer',
      params: {'p_offer_id': offerId, 'p_reason': reason},
    );
  }

  /// Ratings are 1–5; pass 0/null for categories the user skipped.
  Future<double> submitReview({
    required String offerId,
    required Map<String, int> ratings,
    String comment = '',
  }) async {
    final res = await _client.rpc(
      'submit_review',
      params: {
        'p_offer_id': offerId,
        'p_cleanliness': ratings['Cleanliness'],
        'p_staff': ratings['Staff'],
        'p_value': ratings['Value'],
        'p_location': ratings['Location'],
        'p_amenities': ratings['Amenities'],
        'p_comment': comment,
      },
    );
    return (res as num).toDouble();
  }
}

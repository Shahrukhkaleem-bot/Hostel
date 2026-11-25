import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bid_models.dart';

/// Bids (seeker requests) and offers (manager responses).
/// Manager actions are RPCs so the server enforces ownership and pricing rules.
class SupabaseBidRepository {
  SupabaseBidRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // ── Manager ──

  Future<DashboardStats> dashboard(String hostelId) async {
    final res = await _client.rpc(
      'manager_dashboard',
      params: {'p_hostel_id': hostelId},
    );
    final rows = res as List;
    if (rows.isEmpty) return const DashboardStats();
    return DashboardStats.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  /// [status]: pending | offered | accepted | all
  Future<List<IncomingBidModel>> incomingBids(
    String hostelId, {
    String status = 'all',
    int limit = 100,
  }) async {
    final res = await _client.rpc(
      'manager_incoming_bids',
      params: {
        'p_hostel_id': hostelId,
        'p_status': status,
        'p_limit': limit,
      },
    );
    return (res as List)
        .map((e) => IncomingBidModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Accept at the same price or counter higher ([price] >= seeker offer).
  Future<void> respond({
    required String bidId,
    required String hostelId,
    required int price,
  }) async {
    await _client.rpc(
      'respond_to_bid',
      params: {'p_bid_id': bidId, 'p_hostel_id': hostelId, 'p_price': price},
    );
  }

  Future<void> reject({required String bidId, required String hostelId}) async {
    await _client.rpc(
      'reject_bid',
      params: {'p_bid_id': bidId, 'p_hostel_id': hostelId},
    );
  }

  Future<void> withdraw(String offerId) async {
    await _client.rpc('withdraw_offer', params: {'p_offer_id': offerId});
  }

  // ── Seeker ──

  Future<String> placeBid({
    required String city,
    required String hostelType,
    required String seaterLabel,
    required List<String> amenities,
    required int offerAmount,
  }) async {
    final row = await _client
        .from('bids')
        .insert({
          'city': city,
          'hostel_type': hostelType,
          'seater_label': seaterLabel,
          'seater': parseSeater(seaterLabel),
          'amenities': amenities,
          'offer_amount': offerAmount,
        })
        .select('id')
        .single();
    return row['id'].toString();
  }

  Future<void> updateBid({
    required String bidId,
    required String hostelType,
    required String seaterLabel,
    required List<String> amenities,
    required int offerAmount,
  }) async {
    await _client
        .from('bids')
        .update({
          'hostel_type': hostelType,
          'seater_label': seaterLabel,
          'seater': parseSeater(seaterLabel),
          'amenities': amenities,
          'offer_amount': offerAmount,
        })
        .eq('id', bidId);
  }

  Future<void> deleteBid(String bidId) async {
    await _client.from('bids').delete().eq('id', bidId);
  }

  Future<void> acceptOffer(String offerId) async {
    await _client.rpc('accept_offer', params: {'p_offer_id': offerId});
  }
}

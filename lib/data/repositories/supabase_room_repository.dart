import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/room_model.dart';

/// Rooms of a hostel. Row-level security limits writes to the hostel owner.
class SupabaseRoomRepository {
  SupabaseRoomRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _table = 'rooms';

  Future<List<RoomModel>> fetchRooms(String hostelId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('hostel_id', hostelId)
        .order('floor')
        .order('room_number');
    return rows.map(RoomModel.fromJson).toList();
  }

  Future<RoomModel> addRoom({
    required String hostelId,
    required String number,
    required int floor,
    required int seater,
    required int rent,
    required String status,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'hostel_id': hostelId,
          'room_number': number,
          'floor': floor,
          'seater': seater,
          'rent': rent,
          'status': status,
        })
        .select()
        .single();
    return RoomModel.fromJson(row);
  }

  Future<void> updateStatus(String roomId, String status) async {
    await _client.from(_table).update({'status': status}).eq('id', roomId);
  }

  Future<void> deleteRoom(String roomId) async {
    await _client.from(_table).delete().eq('id', roomId);
  }
}

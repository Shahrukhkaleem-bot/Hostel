import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/i_hostel_repository.dart';
import '../models/hostel_model.dart';

class SupabaseHostelRepository implements IHostelRepository {
  SupabaseHostelRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'hostels';
  static const _bucket = 'hostel-photos';

  /// `contact` is not publicly selectable (it is gated behind coins), so the
  /// table is never read with `*`. The owner's contact comes from an RPC.
  static const _cols =
      'id, owner_id, name, hostel_type, city, area, description, total_rooms, '
      'room_types, facilities, photo_urls, rating_avg, rating_count';

  String get _uid {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Sign in again before registering a hostel.');
    }
    return user.id;
  }

  @override
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
  }) async {
    final uid = _uid;
    final uploaded = <String>[];

    try {
      final batch = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < photoPaths.length; i++) {
        uploaded.add(await _uploadPhoto(uid, batch, i, photoPaths[i]));
      }

      final row = await _client
          .from(_table)
          .insert(
            HostelModel.toInsertJson(
              name: name,
              type: type,
              city: city,
              area: area,
              contact: contact,
              description: description,
              totalRooms: totalRooms,
              roomTypes: roomTypes,
              facilities: facilities,
              photoUrls: uploaded
                  .map((p) => _client.storage.from(_bucket).getPublicUrl(p))
                  .toList(),
            ),
          )
          .select(_cols)
          .single();
      return HostelModel.fromJson(row, contact: contact);
    } catch (_) {
      // Don't leave orphaned photos behind if the insert (or a later upload) failed.
      if (uploaded.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove(uploaded);
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<List<HostelModel>> fetchMyHostels() async {
    final rows = await _client
        .from(_table)
        .select(_cols)
        .eq('owner_id', _uid)
        .order('created_at', ascending: true);
    final contacts = <String, String>{};
    try {
      final res = await _client.rpc('my_hostel_contacts');
      for (final r in res as List) {
        contacts[r['hostel_id'].toString()] = (r['contact'] ?? '').toString();
      }
    } catch (_) {
      // Listing still works without contacts.
    }
    return rows
        .map((r) => HostelModel.fromJson(r, contact: contacts[r['id'].toString()]))
        .toList();
  }

  @override
  Future<HostelModel> updateHostel({
    required String id,
    required String name,
    required String type,
    required String city,
    required String area,
    required String contact,
    required String description,
    required int totalRooms,
  }) async {
    final row = await _client
        .from(_table)
        .update({
          'name': name,
          'hostel_type': type,
          'city': city,
          'area': area,
          'contact': contact,
          'description': description,
          'total_rooms': totalRooms,
        })
        .eq('id', id)
        .select(_cols)
        .single();
    return HostelModel.fromJson(row, contact: contact);
  }

  @override
  Future<void> deleteHostel(String id) async {
    // Photos live under <uid>/<batch>/<n>.<ext>; remove the ones this hostel uses.
    final row = await _client
        .from(_table)
        .select('photo_urls')
        .eq('id', id)
        .maybeSingle();
    await _client.from(_table).delete().eq('id', id);

    final marker = '/object/public/$_bucket/';
    final paths = <String>[
      for (final url in (row?['photo_urls'] as List?) ?? const [])
        if (url.toString().contains(marker))
          Uri.decodeComponent(url.toString().split(marker).last),
    ];
    if (paths.isNotEmpty) {
      try {
        await _client.storage.from(_bucket).remove(paths);
      } catch (_) {
        // The hostel is already gone; leftover photos are harmless.
      }
    }
  }

  Future<String> _uploadPhoto(
    String uid,
    int batch,
    int index,
    String localPath,
  ) async {
    final ext = localPath.contains('.')
        ? localPath.split('.').last.toLowerCase()
        : 'jpg';
    final storagePath = '$uid/$batch/$index.$ext';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          storagePath,
          await File(localPath).readAsBytes(),
          fileOptions: FileOptions(contentType: _contentType(ext)),
        );
    return storagePath;
  }

  String _contentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}

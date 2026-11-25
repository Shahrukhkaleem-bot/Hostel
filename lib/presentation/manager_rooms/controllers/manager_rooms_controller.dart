import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/manager_context.dart';
import '../../../core/utils/time_ago.dart';
import '../../../data/models/bid_models.dart';
import '../../../data/models/room_model.dart';
import '../../../data/repositories/supabase_room_repository.dart';
import '../../../routes/app_routes.dart';

class HostelRoom {
  HostelRoom({
    required this.id,
    required this.number,
    required this.seater,
    required this.rent,
    required this.status, // vacant | occupied | reserved
    this.floor = '1',
  });

  final String id;
  String number;
  String seater;
  String rent;
  String status;
  String floor;

  factory HostelRoom.fromModel(RoomModel m) => HostelRoom(
    id: m.id,
    number: m.number,
    seater: m.seater == 1 ? 'Single' : '${m.seater}-seater',
    rent: m.rent > 0 ? 'Rs ${formatRs(m.rent)}/mo' : 'Rs —',
    status: m.status,
    floor: '${m.floor}',
  );
}

class ManagerRoomsController extends GetxController {
  final _repo = Get.find<SupabaseRoomRepository>();
  String? _hostelId;

  final selectedNavIndex = 2.obs; // Rooms tab
  final selectedFilter = 0.obs; // 0 All · 1 Vacant · 2 Occupied · 3 Reserved
  final searchQuery = ''.obs;
  final isLoading = true.obs;

  final rooms = <HostelRoom>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadRooms();
  }

  Future<void> loadRooms() async {
    isLoading.value = true;
    try {
      _hostelId = await ManagerContext.selectedHostelId();
      if (_hostelId == null) {
        rooms.clear();
        return;
      }
      final list = await _repo.fetchRooms(_hostelId!);
      rooms.assignAll(list.map(HostelRoom.fromModel));
    } catch (error) {
      AppSnackbar.error('Rooms', friendlyError(error));
    } finally {
      isLoading.value = false;
    }
  }

  int get totalCount => rooms.length;
  int get vacantCount => rooms.where((r) => r.status == 'vacant').length;
  int get occupiedCount => rooms.where((r) => r.status == 'occupied').length;
  int get reservedCount => rooms.where((r) => r.status == 'reserved').length;

  List<HostelRoom> get filtered {
    var list = rooms.toList();
    switch (selectedFilter.value) {
      case 1:
        list = list.where((r) => r.status == 'vacant').toList();
        break;
      case 2:
        list = list.where((r) => r.status == 'occupied').toList();
        break;
      case 3:
        list = list.where((r) => r.status == 'reserved').toList();
        break;
    }
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (r) =>
                r.number.toLowerCase().contains(q) ||
                r.seater.toLowerCase().contains(q) ||
                r.floor.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  void onFilterChanged(int i) => selectedFilter.value = i;
  void onSearchChanged(String q) => searchQuery.value = q;

  void onNavTap(int index) {
    if (index == selectedNavIndex.value) return;
    selectedNavIndex.value = index;
    switch (index) {
      case 0:
        Get.offAllNamed(AppRoutes.managerHome);
        break;
      case 1:
        Get.offAllNamed(AppRoutes.managerIncomingBids);
        break;
      case 2:
        break;
      case 3:
        Get.toNamed(AppRoutes.profile);
        selectedNavIndex.value = 2;
        break;
    }
  }

  void onAddRoom() {
    final numberCtrl = TextEditingController();
    final seaterCtrl = TextEditingController(text: '2-seater');
    final rentCtrl = TextEditingController();
    final floorCtrl = TextEditingController(text: '1');
    final status = 'vacant'.obs;
    final saving = false.obs;

    Get.bottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(Get.context!).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEE0E6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Add room',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF57092D),
                ),
              ),
              const SizedBox(height: 16),
              _field(numberCtrl, 'Room number', 'e.g. 105'),
              const SizedBox(height: 12),
              _field(seaterCtrl, 'Seater type', 'e.g. 2-seater'),
              const SizedBox(height: 12),
              _field(rentCtrl, 'Monthly rent', 'e.g. 12000',
                  keyboard: TextInputType.number),
              const SizedBox(height: 12),
              _field(floorCtrl, 'Floor', 'e.g. 1'),
              const SizedBox(height: 12),
              Obx(
                () => Wrap(
                  spacing: 8,
                  children: ['vacant', 'occupied', 'reserved'].map((s) {
                    final sel = status.value == s;
                    return ChoiceChip(
                      label: Text(
                        s[0].toUpperCase() + s.substring(1),
                        style: TextStyle(
                          color: sel ? Colors.white : const Color(0xFF57092D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: sel,
                      selectedColor: const Color(0xFF0D9488),
                      backgroundColor: const Color(0xFFFCF5FD),
                      onSelected: (_) => status.value = s,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (saving.value) return;
                    final num = numberCtrl.text.trim();
                    if (num.isEmpty) {
                      AppSnackbar.warning('Room', 'Enter room number');
                      return;
                    }
                    final seater = parseSeater(seaterCtrl.text.trim());
                    if (seater == null) {
                      AppSnackbar.warning(
                        'Seater',
                        'Use a format like "2-seater" or "Single".',
                      );
                      return;
                    }
                    final rent = int.tryParse(
                      rentCtrl.text.replaceAll(',', '').trim(),
                    );
                    if (rent == null || rent <= 0) {
                      AppSnackbar.warning('Rent', 'Enter the monthly rent.');
                      return;
                    }
                    final floor = int.tryParse(floorCtrl.text.trim()) ?? 1;
                    final hostelId = _hostelId;
                    if (hostelId == null) {
                      AppSnackbar.warning('Hostel', 'Register a hostel first.');
                      return;
                    }

                    saving.value = true;
                    try {
                      final room = await _repo.addRoom(
                        hostelId: hostelId,
                        number: num,
                        floor: floor,
                        seater: seater,
                        rent: rent,
                        status: status.value,
                      );
                      rooms.add(HostelRoom.fromModel(room));
                      Get.back();
                      AppSnackbar.success('Added', 'Room $num added');
                    } catch (error) {
                      final dup = error is PostgrestException &&
                          error.code == '23505';
                      AppSnackbar.error(
                        'Could not add room',
                        dup
                            ? 'Room $num already exists in this hostel.'
                            : friendlyError(error),
                      );
                    } finally {
                      saving.value = false;
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Add room',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> onRoomTap(HostelRoom room) async {
    // vacant → occupied → vacant; reserved → vacant
    final previous = room.status;
    final next = previous == 'vacant' ? 'occupied' : 'vacant';
    room.status = next;
    rooms.refresh();
    try {
      await _repo.updateStatus(room.id, next);
      AppSnackbar.info('Updated', 'Room ${room.number} → $next');
    } catch (error) {
      room.status = previous;
      rooms.refresh();
      AppSnackbar.error('Could not update', friendlyError(error));
    }
  }

  Future<void> onDeleteRoom(HostelRoom room) async {
    try {
      await _repo.deleteRoom(room.id);
      rooms.removeWhere((r) => r.id == room.id);
      AppSnackbar.info('Removed', 'Room ${room.number} deleted');
    } catch (error) {
      AppSnackbar.error('Could not delete', friendlyError(error));
    }
  }

  Widget _field(
    TextEditingController c,
    String label,
    String hint, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFA97887),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: keyboard,
          style: const TextStyle(
            color: Color(0xFF57092D),
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC6A0B2)),
            filled: true,
            fillColor: const Color(0xFFFFF5F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEEE0E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEEE0E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF95314D),
                width: 1.4,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

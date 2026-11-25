import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_text.dart';
import '../../../core/utils/time_ago.dart';
import '../../../data/models/seeker_models.dart';
import '../../../data/repositories/supabase_seeker_repository.dart';
import '../../../data/repositories/supabase_bid_repository.dart';
import '../../../routes/app_routes.dart';

class BidItem {
  BidItem({
    required this.id,
    required this.hostelName,
    required this.initials,
    required this.location,
    required this.offeredPrice,
    required this.yourBid,
    required this.phone,
    required this.roomType,
    required this.seater,
    this.isActive = true,
    this.overallRating,
  });

  /// Builds the card from a server offer. [id] is the *offer* id.
  factory BidItem.fromOffer(SeekerOffer o) {
    final words = o.hostelName.trim().split(RegExp(r'\s+'));
    final initials = words.length > 1
        ? '${words.first[0]}${words[1][0]}'.toUpperCase()
        : (o.hostelName.isEmpty ? '?' : o.hostelName[0].toUpperCase());
    final label = o.seaterLabel.toLowerCase();
    return BidItem(
      id: o.offerId,
      hostelName: o.hostelName,
      initials: initials,
      location: o.area.isEmpty ? o.city : '${o.area}, ${o.city}',
      offeredPrice: 'Rs ${formatRs(o.offeredPrice)}/mo',
      yourBid: 'Rs ${formatRs(o.bidAmount)}/mo',
      phone: o.contact ?? '',
      roomType: (label.startsWith('1') || label.contains('single'))
          ? 'Private'
          : 'Shared',
      seater: o.seaterLabel,
      overallRating: o.myRating,
    );
  }

  final String id;
  final String hostelName;
  final String initials;
  final String location;
  final String offeredPrice;
  final String yourBid;
  final String phone;
  final String roomType;
  final String seater;
  final bool isActive;
  double? overallRating;
}

class MyBidItem {
  MyBidItem({
    required this.id,
    required this.seater,
    required this.amenities,
    required this.yourOffer,
    required this.status,
    required this.createdAt,
    this.location = '',
    this.hostelType = 'Boys Hostel',
    this.offerAmount = 15000,
    this.endsIn = '24h',
  });

  final String id;
  final String seater;
  final List<String> amenities;
  final String yourOffer;
  final String status;
  final String createdAt;
  final String location;
  final String hostelType;
  final int offerAmount;
  final String endsIn;

  factory MyBidItem.fromRow(MyBidRow r) {
    final left = r.expiresAt.difference(DateTime.now());
    return MyBidItem(
      id: r.id,
      seater: r.seaterLabel,
      amenities: r.amenities,
      yourOffer: 'Rs ${formatRs(r.offerAmount)}/mo',
      status: r.status == 'closed'
          ? 'won'
          : (r.offerCount > 0 ? 'responded' : 'pending'),
      createdAt: r.createdAt.toIso8601String(),
      location: r.city,
      hostelType: r.hostelType,
      offerAmount: r.offerAmount,
      endsIn: left.isNegative ? '0h' : '${left.inHours}h',
    );
  }

  factory MyBidItem.fromMap(Map<String, dynamic> map) {
    return MyBidItem(
      id: map['id']?.toString() ?? '',
      seater: map['seater']?.toString() ?? '',
      amenities: List<String>.from(map['amenities'] ?? []),
      yourOffer: map['yourOffer']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['createdAt']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      hostelType: map['hostelType']?.toString() ?? 'Boys Hostel',
      offerAmount: (map['offerAmount'] as num?)?.toInt() ?? 15000,
      endsIn: map['endsIn']?.toString() ?? '24h',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'seater': seater,
        'amenities': amenities,
        'yourOffer': yourOffer,
        'status': status,
        'createdAt': createdAt,
        'location': location,
        'hostelType': hostelType,
        'offerAmount': offerAmount,
        'endsIn': endsIn,
      };

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'responded':
        return 'Responded';
      case 'won':
        return 'Won';
      case 'lost':
        return 'Lost';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  bool get isExpired {
    if (createdAt.isEmpty) return false;
    final t = DateTime.tryParse(createdAt);
    if (t == null) return false;
    return DateTime.now().difference(t) > const Duration(hours: 24);
  }

  String get timeLeftLabel {
    if (createdAt.isEmpty) return '—';
    final t = DateTime.tryParse(createdAt);
    if (t == null) return '—';
    final left = t.add(const Duration(hours: 24)).difference(DateTime.now());
    if (left.isNegative) return 'Expired';
    final h = left.inHours;
    final m = left.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m left';
    return '${m}m left';
  }
}

class SeekerBidsController extends GetxController {
  final _repo = Get.find<SupabaseSeekerRepository>();

  final mainSection = 0.obs; // 0 Offered · 1 My bids
  final selectedTab = 0.obs; // Received · Pending · Closed
  final selectedNavIndex = 1.obs;
  final coins = 0.obs;
  final isLoading = true.obs;
  static const unlockCost = 100;

  final myCreatedBids = <MyBidItem>[].obs;
  final myBidsSearch = ''.obs;

  final reviewRatings = <String, double>{
    'Cleanliness': 0,
    'Staff': 0,
    'Value': 0,
    'Location': 0,
    'Amenities': 0,
  }.obs;
  final reviewText = ''.obs;

  double get overallRating {
    final values = reviewRatings.values.where((v) => v > 0).toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  final received = <BidItem>[].obs;
  final pending = <BidItem>[].obs;
  final closed = <BidItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll() async {
    isLoading.value = true;
    await Future.wait([loadOffers(), loadMyBids(), _loadCoins()]);
    isLoading.value = false;
  }

  void onMainSectionChanged(int i) {
    mainSection.value = i;
    if (i == 1) loadMyBids();
  }

  void onTabChanged(int i) => selectedTab.value = i;

  Future<void> _loadCoins() async {
    try {
      coins.value = (await _repo.dashboard()).coins;
    } catch (_) {}
  }

  /// Offers from hostels, split into Received / Pending / Closed.
  Future<void> loadOffers() async {
    try {
      final offers = await _repo.offers();
      List<BidItem> tab(String t) => offers
          .where((o) => o.tab == t)
          .map(BidItem.fromOffer)
          .toList();
      received.assignAll(tab('received'));
      pending.assignAll(tab('pending'));
      closed.assignAll(tab('closed'));
    } catch (error) {
      AppSnackbar.error('Offers', friendlyError(error));
    }
  }

  /// The seeker's own bids (expired ones are filtered out by the server).
  Future<void> loadMyBids() async {
    try {
      final rows = await _repo.myBids();
      myCreatedBids.assignAll(rows.map(MyBidItem.fromRow));
    } catch (error) {
      AppSnackbar.error('My bids', friendlyError(error));
    }
  }

  List<MyBidItem> get filteredMyBids {
    final q = myBidsSearch.value.trim().toLowerCase();
    if (q.isEmpty) return myCreatedBids.toList();
    return myCreatedBids.where((b) {
      return b.seater.toLowerCase().contains(q) ||
          b.yourOffer.toLowerCase().contains(q) ||
          b.hostelType.toLowerCase().contains(q) ||
          b.status.toLowerCase().contains(q) ||
          b.amenities.any((a) => a.toLowerCase().contains(q));
    }).toList();
  }

  void onMyBidsSearchChanged(String v) => myBidsSearch.value = v;

  void openMyBidDetail(MyBidItem item) {
    Get.toNamed(AppRoutes.seekerMyBidDetail, arguments: item);
  }

  Future<void> updateBid(
    String id, {
    required String seater,
    required String offer,
    required List<String> amenities,
    required String hostelType,
    required int offerAmount,
  }) async {
    final index = myCreatedBids.indexWhere((b) => b.id == id);
    if (index == -1) return;
    final old = myCreatedBids[index];
    try {
      await Get.find<SupabaseBidRepository>().updateBid(
        bidId: id,
        hostelType: hostelType,
        seaterLabel: seater,
        amenities: amenities,
        offerAmount: offerAmount,
      );
    } catch (error) {
      AppSnackbar.error('Could not update bid', friendlyError(error));
      return;
    }
    myCreatedBids[index] = MyBidItem(
      id: old.id,
      seater: seater,
      amenities: amenities,
      yourOffer: offer,
      status: old.status,
      createdAt: old.createdAt,
      location: old.location,
      hostelType: hostelType,
      offerAmount: offerAmount,
      endsIn: old.endsIn,
    );
    myCreatedBids.refresh();
    AppSnackbar.success('Updated', 'Bid saved successfully.');
    loadMyBids();
  }

  Future<void> deleteBid(MyBidItem item) async {
    try {
      await Get.find<SupabaseBidRepository>().deleteBid(item.id);
    } catch (error) {
      AppSnackbar.error('Could not delete bid', friendlyError(error));
      return;
    }
    myCreatedBids.removeWhere((b) => b.id == item.id);
    AppSnackbar.info('Removed', 'Bid deleted.');
  }

  void onNavTap(int index) {
    if (index == selectedNavIndex.value) return;
    selectedNavIndex.value = index;
    switch (index) {
      case 0:
        Get.offAllNamed(AppRoutes.seekerHome);
        break;
      case 1:
        break;
      case 2:
        Get.offAllNamed(AppRoutes.seekerSearch);
        break;
      case 3:
        Get.toNamed(AppRoutes.profile);
        selectedNavIndex.value = 1;
        break;
    }
  }

  Future<void> onContinue(BidItem item) async {
    if (coins.value < unlockCost) {
      AppSnackbar.error(
        'Not enough coins',
        'You need $unlockCost coins to continue.',
      );
      return;
    }
    try {
      final result = await _repo.unlockOffer(item.id);
      coins.value = result.coins;
      await loadOffers();
      selectedTab.value = 1;
      Get.back();
      AppSnackbar.success('Moved to Pending', '$unlockCost coins used.');
    } catch (error) {
      AppSnackbar.error('Could not continue', friendlyError(error));
      _loadCoins();
    }
  }

  void onAccept(BidItem item) {
    Get.dialog(
      barrierDismissible: false,
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.home_work_rounded,
                    color: AppColors.accent, size: 28),
              ),
              const SizedBox(height: 14),
              const Text(
                'Confirm acceptance',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'By accepting, you confirm that you have visited '
                '${item.hostelName} and everything matches what the manager offered '
                '(${item.offeredPrice}, ${item.roomType}, ${item.seater}).\n\n'
                'Do you want to continue?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back();
                        try {
                          await _repo.acceptOffer(item.id);
                          await Future.wait([loadOffers(), loadMyBids()]);
                          selectedTab.value = 2;
                          AppSnackbar.success(
                            'Accepted',
                            'Deal closed with ${item.hostelName}.',
                          );
                        } catch (error) {
                          AppSnackbar.error(
                            'Could not accept',
                            friendlyError(error),
                          );
                          loadOffers();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Yes, continue',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void onReject(BidItem item) {
    final reasonCtrl = TextEditingController();
    final selectedReason = ''.obs;
    const reasons = [
      'Price too high',
      'Location not suitable',
      'Facilities not as offered',
      'Found a better option',
      'Other',
    ];

    Get.dialog(
      barrierDismissible: false,
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Reject offer?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Why are you rejecting ${item.hostelName}?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => Column(
                    children: reasons.map((r) {
                      final sel = selectedReason.value == r;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () => selectedReason.value = r,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppColors.error.withValues(alpha: 0.08)
                                  : AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    sel ? AppColors.error : AppColors.border,
                              ),
                            ),
                            child: Text(
                              r,
                              style: TextStyle(
                                color: sel
                                    ? AppColors.error
                                    : AppColors.textPrimary,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Obx(() {
                  if (selectedReason.value != 'Other') {
                    return const SizedBox.shrink();
                  }
                  return TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Write your reason…',
                      filled: true,
                      fillColor: AppColors.surfaceSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (selectedReason.value.isEmpty) {
                            AppSnackbar.warning(
                                'Reason', 'Please select a reason');
                            return;
                          }
                          if (selectedReason.value == 'Other' &&
                              reasonCtrl.text.trim().isEmpty) {
                            AppSnackbar.warning(
                                'Reason', 'Please write your reason');
                            return;
                          }
                          final reason = selectedReason.value == 'Other'
                              ? reasonCtrl.text.trim()
                              : selectedReason.value;
                          Get.back();
                          try {
                            await _repo.declineOffer(item.id, reason: reason);
                            received.removeWhere((e) => e.id == item.id);
                            pending.removeWhere((e) => e.id == item.id);
                            AppSnackbar.info('Rejected', 'Reason: $reason');
                          } catch (error) {
                            AppSnackbar.error(
                              'Could not reject',
                              friendlyError(error),
                            );
                            loadOffers();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> onCall(String phone) async {
    if (phone.trim().isEmpty) {
      AppSnackbar.info('No number', 'Continue with this offer to see contact.');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''));
    try {
      if (!await launchUrl(uri)) {
        AppSnackbar.info('Call', phone);
      }
    } catch (_) {
      AppSnackbar.info('Call', phone);
    }
  }

  void setRating(String category, double value) {
    reviewRatings[category] = value;
    reviewRatings.refresh();
  }

  Future<void> submitReview(BidItem item) async {
    final hasRating = reviewRatings.values.any((v) => v > 0);
    if (!hasRating) {
      AppSnackbar.warning('Rate at least one', 'Please give a star rating.');
      return;
    }
    try {
      final overall = await _repo.submitReview(
        offerId: item.id,
        ratings: {
          for (final e in reviewRatings.entries) e.key: e.value.round(),
        },
        comment: reviewText.value.trim(),
      );
      await loadOffers();
      Get.back();
      AppSnackbar.success(
        'Review submitted',
        'Thanks! Overall ${overall.toStringAsFixed(1)}',
      );
    } catch (error) {
      AppSnackbar.error('Could not submit', friendlyError(error));
    }
  }

  void resetReview() {
    reviewRatings.updateAll((key, value) => 0);
    reviewRatings.refresh();
    reviewText.value = '';
  }
}
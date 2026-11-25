import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../data/models/seeker_models.dart';
import '../controllers/hostel_details_controller.dart';

class DetailsView extends GetView<HostelDetailsController> {
  const DetailsView({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Column(
          children: [
            _Header(top: top),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: RefreshIndicator(
                  onRefresh: controller.load,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottom),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    child: Obx(() {
                      final d = controller.detail.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TitleCard(controller: controller),
                          if (controller.isLoading.value && d == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (d != null) ..._body(d),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: controller.placeBid,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: const Text(
                                'Place a bid',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(HostelDetail d) {
    return [
      const SizedBox(height: 16),
      const _SectionTitle('Room info'),
      const SizedBox(height: 10),
      _InfoChip(icon: Icons.people_alt_outlined, label: d.type),
      const SizedBox(height: 10),
      if (d.rooms.isEmpty)
        const _InfoChip(
          icon: Icons.meeting_room_outlined,
          label: 'Rooms not listed yet — place a bid to get offers',
        )
      else
        ...d.rooms.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InfoChip(
              icon: Icons.bed_outlined,
              label:
                  '${r.seater == 1 ? 'Single' : '${r.seater}-seater'} · '
                  '${r.vacant} vacant'
                  '${r.minRent != null ? ' · from Rs ${formatRs(r.minRent!)}' : ''}',
            ),
          ),
        ),
      if (d.facilities.isNotEmpty) ...[
        const SizedBox(height: 10),
        const _SectionTitle('Amenities'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: d.facilities
              .map(
                (a) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    a,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
      const SizedBox(height: 20),
      const _SectionTitle('About'),
      const SizedBox(height: 8),
      Text(
        d.description.trim().isEmpty
            ? 'A ${d.type.toLowerCase()} in ${d.area.isEmpty ? d.city : '${d.area}, ${d.city}'}.'
            : d.description,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 20),
      _SectionTitle(
        d.ratingCount > 0 ? 'Reviews (${d.ratingCount})' : 'Reviews',
      ),
      const SizedBox(height: 10),
      if (d.reviews.isEmpty)
        const Text(
          'No reviews yet.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        )
      else
        ...d.reviews.map((r) => _ReviewTile(review: r)),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.top});
  final double top;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HostelDetailsController>();
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: top + 200,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Obx(() {
            final photos = controller.detail.value?.photoUrls ?? const [];
            if (photos.isEmpty) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: photos.length,
                  onPageChanged: (i) => controller.photoIndex.value = i,
                  itemBuilder: (_, i) => Image.network(
                    photos[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.apartment_rounded,
                      size: 72,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                if (photos.length > 1)
                  Positioned(
                    bottom: 34,
                    left: 0,
                    right: 0,
                    child: Obx(
                      () => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          photos.length,
                          (i) => Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == controller.photoIndex.value
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
        Positioned(
          top: top + 8,
          left: 12,
          child: GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({required this.controller});
  final HostelDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Obx(() {
        final d = controller.detail.value;
        final minRent = d?.minRent;
        final avg = d?.ratingAvg;
        final priceText = d == null
            ? (controller.card['price']?.toString() ?? '')
            : (minRent == null ? 'No vacancy' : 'From Rs ${formatRs(minRent)}/mo');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    controller.area.isEmpty
                        ? controller.city
                        : '${controller.area}, ${controller.city}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  priceText,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: Color(0xFFFFC107),
                ),
                const SizedBox(width: 4),
                Text(
                  avg == null ? 'New' : avg.toStringAsFixed(1),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final HostelReviewItem review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFC107)),
              const SizedBox(width: 2),
              Text(
                review.rating.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            timeAgo(review.createdAt),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

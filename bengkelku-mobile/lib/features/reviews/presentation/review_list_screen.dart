import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/rating_stars.dart";

class ReviewListScreen extends StatelessWidget {
  const ReviewListScreen({super.key, required this.workshopId});

  final String workshopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ulasan Pelanggan"),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ReviewItem(
            name: "Budi Santoso",
            rating: 5,
            comment:
                "Servis sangat cepat dan mekanik ramah. Oli yang dipakai terjamin orisinal.",
            dateStr: "2 hari lalu",
          ),
          _ReviewItem(
            name: "Andi Wijaya",
            rating: 4,
            comment:
                "Tempat bersih, harga sesuai dengan yang tertera di aplikasi BengkelKu.",
            dateStr: "1 minggu lalu",
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.name,
    required this.rating,
    required this.comment,
    required this.dateStr,
  });

  final String name;
  final double rating;
  final String comment;
  final String dateStr;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: AppTypography.bodyStrong.copyWith(color: c.ink),
              ),
              Text(
                dateStr,
                style: AppTypography.caption
                    .copyWith(color: c.ink.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RatingStars(rating: rating, starSize: 16),
          const SizedBox(height: 8),
          Text(
            comment,
            style: AppTypography.body
                .copyWith(color: c.ink.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

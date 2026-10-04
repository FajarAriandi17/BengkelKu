import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/rating_stars.dart";

class OwnerReviewsScreen extends StatelessWidget {
  const OwnerReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ulasan Pelanggan Masuk"),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
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
                      "Budi Santoso",
                      style: AppTypography.bodyStrong.copyWith(color: c.ink),
                    ),
                    Text(
                      "Kemarin",
                      style: AppTypography.caption
                          .copyWith(color: c.ink.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const RatingStars(rating: 5, starSize: 16),
                const SizedBox(height: 8),
                Text(
                  "Servis sangat cepat dan mekanik ramah. Oli yang dipakai terjamin orisinal.",
                  style: AppTypography.body
                      .copyWith(color: c.ink.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

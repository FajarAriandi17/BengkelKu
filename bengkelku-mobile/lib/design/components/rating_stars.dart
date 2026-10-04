import "package:flutter/material.dart";

import "../../core/theme/app_colors.dart";

/// Komponen bintang rating (bisa read-only atau interaktif).
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.starSize = 20,
    this.interactive = false,
  });

  final double rating;
  final ValueChanged<double>? onRatingChanged;
  final double starSize;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFull = rating >= starValue;
        final isHalf = rating >= starValue - 0.5 && rating < starValue;

        final icon = isFull
            ? Icons.star
            : isHalf
                ? Icons.star_half
                : Icons.star_border;

        final widgetIcon = Icon(
          icon,
          size: starSize,
          color: c.star,
        );

        if (!interactive) return widgetIcon;

        return GestureDetector(
          onTap: () => onRatingChanged?.call(starValue.toDouble()),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: widgetIcon,
          ),
        );
      }),
    );
  }
}

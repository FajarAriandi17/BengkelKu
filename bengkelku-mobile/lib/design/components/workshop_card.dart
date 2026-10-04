import "package:flutter/material.dart";

import "../../core/theme/app_colors.dart";
import "../../core/theme/app_typography.dart";
import "../../core/utils/formatters.dart";
import "app_chip.dart";
import "favorite_button.dart";

/// Kartu bengkel untuk daftar terdekat & pencarian.
class WorkshopCard extends StatelessWidget {
  const WorkshopCard({
    super.key,
    required this.id,
    required this.name,
    required this.address,
    required this.ratingAvg,
    required this.ratingCount,
    required this.distanceMeters,
    this.photoUrl,
    this.isOpen = true,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteToggle,
  });

  final String id;
  final String name;
  final String address;
  final double ratingAvg;
  final int ratingCount;
  final double distanceMeters;
  final String? photoUrl;
  final bool isOpen;
  final bool isFavorite;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Foto
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 84,
                  height: 84,
                  color: c.blueSoft,
                  child: photoUrl != null && photoUrl!.isNotEmpty
                      ? Image.network(photoUrl!, fit: BoxFit.cover)
                      : Icon(Icons.storefront, color: c.blue, size: 36),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onFavoriteToggle != null)
                          FavoriteButton(
                            isFavorite: isFavorite,
                            onToggle: onFavoriteToggle!,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: AppTypography.caption.copyWith(color: c.ink.withOpacity(0.6)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Rating
                        Icon(Icons.star, size: 16, color: c.star),
                        const SizedBox(width: 4),
                        Text(
                          "$ratingAvg",
                          style: AppTypography.label.copyWith(color: c.ink),
                        ),
                        Text(
                          " ($ratingCount)",
                          style: AppTypography.caption.copyWith(color: c.ink.withOpacity(0.5)),
                        ),
                        const SizedBox(width: 12),
                        // Jarak
                        Icon(Icons.near_me, size: 14, color: c.blue),
                        const SizedBox(width: 4),
                        Text(
                          Formatters.distance(distanceMeters),
                          style: AppTypography.label.copyWith(color: c.blue),
                        ),
                        const Spacer(),
                        // Buka/Tutup
                        AppStatusBadge(
                          label: isOpen ? "Buka" : "Tutup",
                          color: isOpen ? c.ok : c.bad,
                          backgroundColor: isOpen ? c.okSoft : c.badSoft,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

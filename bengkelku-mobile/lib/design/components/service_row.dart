import "package:flutter/material.dart";

import "../../core/theme/app_colors.dart";
import "../../core/theme/app_typography.dart";
import "../../core/utils/formatters.dart";

/// Baris item layanan bengkel + harga & durasi.
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    super.key,
    required this.name,
    required this.priceIdr,
    required this.durationMinutes,
    this.isSelected = false,
    this.onTap,
  });

  final String name;
  final int priceIdr;
  final int durationMinutes;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? c.blueSoft : c.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? c.blue : c.blueSoft.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.bodyStrong.copyWith(color: c.ink),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: c.ink.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Text(
                          "$durationMinutes menit",
                          style: AppTypography.caption.copyWith(color: c.ink.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                Formatters.rupiah(priceIdr),
                style: AppTypography.h2.copyWith(color: c.blue, fontSize: 16),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 10),
                Icon(
                  isSelected ? Icons.check_circle : Icons.add_circle_outline,
                  color: isSelected ? c.blue : c.ink.withOpacity(0.4),
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

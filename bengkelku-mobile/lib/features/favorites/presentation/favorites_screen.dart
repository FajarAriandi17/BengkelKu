import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/workshop_card.dart";

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bengkel Favorit"),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WorkshopCard(
            id: "ws-1",
            name: "Bengkel Jaya Motor",
            address: "Jl. Fatmawati No. 12, Jakarta Selatan",
            ratingAvg: 4.8,
            ratingCount: 120,
            distanceMeters: 850,
            isOpen: true,
            isFavorite: true,
            onTap: () => context.push("/home/workshop/ws-1"),
            onFavoriteToggle: (_) {},
          ),
        ],
      ),
    );
  }
}

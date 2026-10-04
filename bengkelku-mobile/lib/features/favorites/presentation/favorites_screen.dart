import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../design/components/state_views.dart";
import "../../../design/components/workshop_card.dart";
import "../../workshops/data/workshop_model.dart";
import "../../workshops/data/workshop_repository.dart";

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repo = WorkshopRepository();
  List<Workshop> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.favoriteWorkshops();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Gagal memuat favorit.";
        _loading = false;
      });
    }
  }

  Future<void> _remove(Workshop w) async {
    final idx = _items.indexOf(w);
    setState(() => _items.remove(w));
    try {
      await _repo.setFavorite(w.id, false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.insert(idx, w));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Gagal menghapus favorit.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const SkeletonList(itemCount: 3);
    } else if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = EmptyState(
        title: "Belum ada bengkel favorit",
        message: "Ketuk ikon hati di halaman bengkel untuk menyimpannya di sini.",
        icon: Icons.favorite_border,
        actionLabel: "Cari Bengkel",
        onAction: () => context.go("/home"),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final w = _items[i];
            return WorkshopCard(
              id: w.id,
              name: w.name,
              address: w.address,
              ratingAvg: w.ratingAvg,
              ratingCount: w.ratingCount,
              distanceMeters: w.distanceMeters,
              isFavorite: true,
              onTap: () => context.push("/home/workshop/${w.id}"),
              onFavoriteToggle: (_) => _remove(w),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Bengkel Favorit"), elevation: 0),
      body: body,
    );
  }
}

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_shell.dart";
import "../../../design/components/booking_status_badge.dart";
import "../../../design/components/state_views.dart";
import "../data/booking_model.dart";
import "../data/booking_repository.dart";

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = BookingRepository();
  List<Booking> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getRiderBookings();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = bookingErrorMessage(e);
        _loading = false;
      });
    }
  }

  Widget _list(List<Booking> items, {required bool active}) {
    if (_loading) return const SkeletonList();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 60),
            EmptyState(
              title: active ? "Belum ada booking aktif" : "Belum ada riwayat",
              message: active
                  ? "Cari bengkel terdekat dan pesan servis tanpa antre."
                  : "Booking yang selesai atau dibatalkan akan muncul di sini.",
              icon: Icons.receipt_long_outlined,
              actionLabel: active ? "Cari Bengkel" : null,
              onAction: active ? () => context.go("/home") : null,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _BookingCard(
          booking: items[i],
          onTap: () async {
            await context.push("/ticket?bookingId=${items[i].id}");
            await _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = _items.where((b) => b.isActive).toList();
    final history = _items.where((b) => !b.isActive).toList();

    return Scaffold(
      backgroundColor: c.panel2,
      bottomNavigationBar: const AppBottomNav(current: AppTab.bookings),
      appBar: AppBar(
        title: const Text("Booking"),
        automaticallyImplyLeading: false,
        backgroundColor: c.panel2,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: c.blue,
          unselectedLabelColor: c.ink2,
          indicatorColor: c.blue,
          tabs: [
            Tab(text: "Aktif${active.isEmpty ? "" : " (${active.length})"}"),
            const Tab(text: "Riwayat"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _list(active, active: true),
          _list(history, active: false),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});
  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final b = booking;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    b.workshopName ?? "Bengkel",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong.copyWith(color: c.ink),
                  ),
                ),
                BookingStatusBadge(status: b.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "${b.code} · ${Formatters.dateTimeLocal(b.scheduledAt)}",
              style: AppTypography.caption.copyWith(color: c.ink2),
            ),
            if (b.vehicleInfo != null && b.vehicleInfo!.isNotEmpty)
              Text(
                b.vehicleInfo!,
                style: AppTypography.caption.copyWith(color: c.ink2),
              ),
            const SizedBox(height: 8),
            Text(
              Formatters.rupiah(b.totalIdr),
              style: AppTypography.bodyStrong.copyWith(color: c.blue),
            ),
          ],
        ),
      ),
    );
  }
}

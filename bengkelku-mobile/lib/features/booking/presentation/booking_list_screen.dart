import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/booking_status_badge.dart";

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({super.key});

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daftar Booking Servis"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: c.blue,
          unselectedLabelColor: c.ink.withOpacity(0.5),
          indicatorColor: c.blue,
          tabs: const [
            Tab(text: "Aktif"),
            Tab(text: "Selesai / Batal"),
          ],
        ),
        elevation: 0,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Aktif
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BookingCardItem(
                id: "bk-1",
                workshopName: "Bengkel Jaya Motor",
                dateTimeStr: "Besok, 09.00 WIB",
                vehicleInfo: "Honda Vario 160",
                status: "DIKONFIRMASI",
                onTap: () => context.push("/ticket?bookingId=bk-1"),
              ),
            ],
          ),
          // Tab Selesai
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BookingCardItem(
                id: "bk-0",
                workshopName: "Honda AHASS Sentosa",
                dateTimeStr: "12 Sep 2026, 10.00 WIB",
                vehicleInfo: "Honda Vario 160",
                status: "SELESAI",
                onTap: () => context.push("/ticket?bookingId=bk-0"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingCardItem extends StatelessWidget {
  const _BookingCardItem({
    required this.id,
    required this.workshopName,
    required this.dateTimeStr,
    required this.vehicleInfo,
    required this.status,
    this.onTap,
  });

  final String id;
  final String workshopName;
  final String dateTimeStr;
  final String vehicleInfo;
  final String status;
  final VoidCallback? onTap;

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
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(workshopName, style: AppTypography.h2.copyWith(color: c.ink, fontSize: 16)),
                  BookingStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: c.ink.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Text(dateTimeStr, style: AppTypography.caption.copyWith(color: c.ink.withOpacity(0.7))),
                  const SizedBox(width: 16),
                  Icon(Icons.two_wheeler, size: 14, color: c.ink.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Text(vehicleInfo, style: AppTypography.caption.copyWith(color: c.ink.withOpacity(0.7))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

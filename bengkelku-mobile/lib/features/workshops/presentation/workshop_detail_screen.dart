import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_chip.dart";
import "../../../design/components/favorite_button.dart";
import "../../../design/components/rating_stars.dart";
import "../../../design/components/service_row.dart";
import "../data/workshop_model.dart";
import "../data/workshop_repository.dart";

class WorkshopDetailScreen extends StatefulWidget {
  const WorkshopDetailScreen({super.key, required this.workshopId});

  final String workshopId;

  @override
  State<WorkshopDetailScreen> createState() => _WorkshopDetailScreenState();
}

class _WorkshopDetailScreenState extends State<WorkshopDetailScreen> {
  final _workshopRepo = WorkshopRepository();
  Workshop? _workshop;
  List<WorkshopServiceItem> _services = [];
  final Set<String> _selectedServiceIds = {};
  bool _loading = true;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final ws = await _workshopRepo.getWorkshopDetail(widget.workshopId);
    final sv = await _workshopRepo.getWorkshopServices(widget.workshopId);

    if (mounted) {
      setState(() {
        _workshop = ws;
        _services = sv;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final name = _workshop?.name ?? "Bengkel Jaya Motor";
    final address =
        _workshop?.address ?? "Jl. Fatmawati No. 12, Jakarta Selatan";
    final ratingAvg = _workshop?.ratingAvg ?? 4.8;
    final ratingCount = _workshop?.ratingCount ?? 120;

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          FavoriteButton(
            isFavorite: _isFavorite,
            onToggle: (fav) => setState(() => _isFavorite = fav),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto Galeri
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: c.blueSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.storefront, size: 64, color: c.blue),
                  ),
                  const SizedBox(height: 16),

                  // Info Bengkel
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(name,
                            style: AppTypography.h1.copyWith(color: c.ink)),
                      ),
                      AppStatusBadge(
                        label: "Buka",
                        color: c.ok,
                        backgroundColor: c.okSoft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(address,
                      style: AppTypography.body
                          .copyWith(color: c.ink.withValues(alpha: 0.7))),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      RatingStars(rating: ratingAvg, starSize: 18),
                      const SizedBox(width: 6),
                      Text("$ratingAvg ($ratingCount ulasan)",
                          style: AppTypography.label.copyWith(color: c.ink)),
                    ],
                  ),
                  const Divider(height: 32),

                  // Jam buka
                  Text("Jam Operasional",
                      style: AppTypography.h2
                          .copyWith(color: c.ink, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text("Senin - Sabtu: 08.00 - 17.00 WIB",
                      style: AppTypography.body
                          .copyWith(color: c.ink.withValues(alpha: 0.7))),
                  const Divider(height: 32),

                  // Layanan
                  Text("Pilih Layanan Servis",
                      style: AppTypography.h2
                          .copyWith(color: c.ink, fontSize: 16)),
                  const SizedBox(height: 12),

                  if (_services.isEmpty)
                    Column(
                      children: [
                        ServiceRow(
                          name: "Servis Rutin / Ringan",
                          priceIdr: 55000,
                          durationMinutes: 45,
                          isSelected: _selectedServiceIds.contains("s1"),
                          onTap: () {
                            setState(() {
                              if (_selectedServiceIds.contains("s1")) {
                                _selectedServiceIds.remove("s1");
                              } else {
                                _selectedServiceIds.add("s1");
                              }
                            });
                          },
                        ),
                        ServiceRow(
                          name: "Ganti Oli Mesin Sintetik",
                          priceIdr: 65000,
                          durationMinutes: 15,
                          isSelected: _selectedServiceIds.contains("s2"),
                          onTap: () {
                            setState(() {
                              if (_selectedServiceIds.contains("s2")) {
                                _selectedServiceIds.remove("s2");
                              } else {
                                _selectedServiceIds.add("s2");
                              }
                            });
                          },
                        ),
                        ServiceRow(
                          name: "Servis Injeksi & Throttle Body",
                          priceIdr: 90000,
                          durationMinutes: 60,
                          isSelected: _selectedServiceIds.contains("s3"),
                          onTap: () {
                            setState(() {
                              if (_selectedServiceIds.contains("s3")) {
                                _selectedServiceIds.remove("s3");
                              } else {
                                _selectedServiceIds.add("s3");
                              }
                            });
                          },
                        ),
                      ],
                    )
                  else
                    ..._services.map(
                      (s) => ServiceRow(
                        name: s.name,
                        priceIdr: s.priceIdr,
                        durationMinutes: s.durationMinutes,
                        isSelected: _selectedServiceIds.contains(s.id),
                        onTap: () {
                          setState(() {
                            if (_selectedServiceIds.contains(s.id)) {
                              _selectedServiceIds.remove(s.id);
                            } else {
                              _selectedServiceIds.add(s.id);
                            }
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: "Lanjut Pilih Jadwal",
          onPressed: _selectedServiceIds.isEmpty
              ? null
              : () => context.push("/schedule?workshopId=${widget.workshopId}"),
        ),
      ),
    );
  }
}

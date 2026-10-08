import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_shell.dart";
import "../../../design/components/app_text_field.dart";
import "../../../design/components/state_views.dart";
import "../data/garage_repository.dart";
import "../data/vehicle_model.dart";

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  final _garageRepo = GarageRepository();
  List<Vehicle> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final res = await _garageRepo.getUserVehicles();
    if (mounted) {
      setState(() {
        _vehicles = res;
        _loading = false;
      });
    }
  }

  void _showAddVehicleSheet() {
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    final plateController = TextEditingController();
    final odoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tambah Motor ke Garasi",
                style: AppTypography.h1.copyWith(color: context.colors.ink),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: brandController,
                label: "Merek Motor",
                hint: "misal: Honda / Yamaha",
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: modelController,
                label: "Model Motor",
                hint: "misal: Vario 160 / NMAX",
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: plateController,
                label: "Plat Nomor",
                hint: "misal: B 1234 XYZ",
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: odoController,
                label: "Odometer Terkini (km)",
                hint: "12500",
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              AppButton(
                label: "Simpan Motor",
                onPressed: () async {
                  if (brandController.text.isEmpty ||
                      modelController.text.isEmpty) {
                    return;
                  }
                  Navigator.pop(ctx);
                  await _garageRepo.addVehicle(
                    brand: brandController.text,
                    model: modelController.text,
                    plate: plateController.text,
                    odometer: int.tryParse(odoController.text) ?? 0,
                  );
                  _fetch();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.panel2,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Garasi",
                      style: AppTypography.display.copyWith(color: c.ink),
                    ),
                  ),
                  SquareIconButton(
                    icon: Icons.add,
                    tooltip: "Tambah motor",
                    onTap: _showAddVehicleSheet,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const SizedBox(height: 300, child: SkeletonList(itemCount: 2))
              else if (_vehicles.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.two_wheeler,
                    title: "garasi masih kosong",
                    message:
                        "tambahkan motor untuk memantau jadwal ganti oli & riwayat servis.",
                    actionLabel: "Tambah motor pertama",
                    onAction: _showAddVehicleSheet,
                  ),
                )
              else ...[
                for (final v in _vehicles) ...[
                  _VehicleCard(
                    vehicle: v,
                    onTap: () => context.push("/oil-detail?vehicleId=${v.id}"),
                  ),
                  const SizedBox(height: 12),
                ],
                AppCard(
                  onTap: () => context.push("/notifications/settings"),
                  child: Row(
                    children: [
                      const IconTile(icon: Icons.notifications_none_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Pengingat saya",
                              style: AppTypography.label
                                  .copyWith(color: c.ink, fontSize: 15),
                            ),
                            Text(
                              "atur kapan kami mengingatkan ganti oli",
                              style:
                                  AppTypography.caption.copyWith(color: c.ink2),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.ink),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DashedButton(
                  label: "Tambah motor",
                  onTap: _showAddVehicleSheet,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.garage),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onTap});
  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = vehicle;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const IconTile(icon: Icons.two_wheeler, size: 66),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${v.brand} ${v.model}".trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTypography.label.copyWith(color: c.ink, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  "${v.plate ?? "-"} · ${Formatters.odometer(v.odometer)}",
                  style: AppTypography.caption.copyWith(color: c.ink2),
                ),
                const SizedBox(height: 8),
                StatusPill(
                  label: "Ganti tiap ${Formatters.odometer(v.oilIntervalKm)}",
                  color: c.okText,
                  background: c.okSoft,
                ),
              ],
            ),
          ),
          MiniOilGauge(progress: 0.8, color: c.okC, size: 72),
        ],
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: CustomPaint(
        painter: _DashPainter(c.line),
        child: SizedBox(
          height: 60,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: c.blueText, size: 20),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.label.copyWith(color: c.blueText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadius.lg),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

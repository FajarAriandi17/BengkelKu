import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../core/utils/formatters.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../../oil/domain/oil_calculator.dart";
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
              Text("Tambah Motor ke Garasi", style: AppTypography.h1.copyWith(color: context.colors.ink)),
              const SizedBox(height: 16),
              AppTextField(controller: brandController, label: "Merek Motor", hint: "misal: Honda / Yamaha"),
              const SizedBox(height: 12),
              AppTextField(controller: modelController, label: "Model Motor", hint: "misal: Vario 160 / NMAX"),
              const SizedBox(height: 12),
              AppTextField(controller: plateController, label: "Plat Nomor", hint: "misal: B 1234 XYZ"),
              const SizedBox(height: 12),
              AppTextField(controller: odoController, label: "Odometer Terkini (km)", hint: "12500", keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              AppButton(
                label: "Simpan Motor",
                onPressed: () async {
                  if (brandController.text.isEmpty || modelController.text.isEmpty) return;
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
      appBar: AppBar(
        title: const Text("Garasi Motor Saya"),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.two_wheeler, size: 80, color: c.blueSoft),
                      const SizedBox(height: 16),
                      Text("Garasi Masih Kosong", style: AppTypography.h1.copyWith(color: c.ink)),
                      const SizedBox(height: 8),
                      Text("Tambahkan motor kamu ke Garasi untuk memantau jadwal ganti oli & riwayat servis.", style: AppTypography.body.copyWith(color: c.ink.withOpacity(0.7)), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      AppButton(
                        label: "Tambah Motor Pertama",
                        onPressed: _showAddVehicleSheet,
                        icon: Icons.add,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _vehicles.length,
                  itemBuilder: (context, index) {
                    final v = _vehicles[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.panel,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.two_wheeler, size: 32, color: c.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${v.brand} ${v.model}", style: AppTypography.h2.copyWith(color: c.ink)),
                                    Text("${v.plate ?? '-'} • Odometer: ${Formatters.odometer(v.odometer)}", style: AppTypography.caption.copyWith(color: c.ink.withOpacity(0.6))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Status Oli:", style: AppTypography.body.copyWith(color: c.ink.withOpacity(0.7))),
                              TextButton.icon(
                                icon: const Icon(Icons.opacity, size: 16),
                                label: const Text("Detail Oli"),
                                onPressed: () => context.push("/oil-detail?vehicleId=${v.id}"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: _vehicles.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: c.blue,
              onPressed: _showAddVehicleSheet,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

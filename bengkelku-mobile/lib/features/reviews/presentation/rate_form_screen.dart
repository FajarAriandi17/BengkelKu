import "dart:io";
import "package:flutter/material.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../../../design/components/media_picker_tile.dart";
import "../../../design/components/rating_stars.dart";

class RateFormScreen extends StatefulWidget {
  const RateFormScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<RateFormScreen> createState() => _RateFormScreenState();
}

class _RateFormScreenState extends State<RateFormScreen> {
  double _rating = 5.0;
  final _commentController = TextEditingController();
  File? _reviewPhoto;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Beri Ulasan Servis"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bagaimana Pengalaman Servis Kamu?",
              style: AppTypography.h1.copyWith(color: c.ink),
            ),
            const SizedBox(height: 8),
            Text(
              "Ulasan kamu membantu pengguna lain memilih bengkel terpercaya.",
              style: AppTypography.body
                  .copyWith(color: c.ink.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 24),

            // Star picker
            Center(
              child: RatingStars(
                rating: _rating,
                starSize: 36,
                interactive: true,
                onRatingChanged: (r) => setState(() => _rating = r),
              ),
            ),
            const SizedBox(height: 24),

            AppTextField(
              controller: _commentController,
              label: "Ulasan Teks",
              hint:
                  "Tuliskan pendapat kamu mengenai pengerjaan & pelayanan bengkel...",
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            Text(
              "Foto Ulasan (Opsional, Maks 2 MB)",
              style: AppTypography.label.copyWith(color: c.ink),
            ),
            const SizedBox(height: 8),
            MediaPickerTile(
              title: "Unggah Foto Ulasan",
              subtitle: "Format JPG / PNG, Maksimal 2 MB",
              selectedFile: _reviewPhoto,
              onFileSelected: (file) => setState(() => _reviewPhoto = file),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: AppButton(
          label: "Kirim Ulasan",
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Terima kasih atas ulasan kamu!")),
            );
          },
        ),
      ),
    );
  }
}

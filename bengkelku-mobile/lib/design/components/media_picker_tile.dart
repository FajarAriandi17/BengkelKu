import "dart:io";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";

import "../../core/theme/app_colors.dart";
import "../../core/theme/app_typography.dart";
import "../../core/utils/media_guard.dart";

/// Tile unggah media (KTP/Selfie/Foto) yang mengintegrasikan [MediaGuard] (2 MB limit).
class MediaPickerTile extends StatefulWidget {
  const MediaPickerTile({
    super.key,
    required this.title,
    this.subtitle,
    this.selectedFile,
    required this.onFileSelected,
    this.useCameraOnly = false,
  });

  final String title;
  final String? subtitle;
  final File? selectedFile;
  final ValueChanged<File?> onFileSelected;
  final bool useCameraOnly;

  @override
  State<MediaPickerTile> createState() => _MediaPickerTileState();
}

class _MediaPickerTileState extends State<MediaPickerTile> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final bytes = await file.readAsBytes();

      // Guard 2 MB
      MediaGuard.ensureBytesUnderLimit(bytes);

      widget.onFileSelected(file);
    } catch (e) {
      if (!mounted) return;
      final errorMessage =
          e is MediaTooLargeException ? e.message : kMediaTooLargeMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Theme.of(context).extension<AppColors>()!.bad,
        ),
      );
    }
  }

  void _showPickerOptionSheet() {
    if (widget.useCameraOnly) {
      _pickImage(ImageSource.camera);
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final c = context.colors;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Pilih Sumber Foto",
                style: AppTypography.h2.copyWith(color: c.ink),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt, color: c.blue),
                title: const Text(
                  "Kamera In-App",
                  style: AppTypography.bodyStrong,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: c.blue),
                title:
                    const Text("Galeri Foto", style: AppTypography.bodyStrong),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
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

    return InkWell(
      onTap: _showPickerOptionSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: c.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.selectedFile != null ? c.blue : c.blueSoft,
            width: widget.selectedFile != null ? 1.8 : 1.0,
          ),
        ),
        child: widget.selectedFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      widget.selectedFile!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => widget.onFileSelected(null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 32, color: c.blue),
                  const SizedBox(height: 6),
                  Text(
                    widget.title,
                    style: AppTypography.label.copyWith(color: c.ink),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: AppTypography.caption
                          .copyWith(color: c.ink.withValues(alpha: 0.5)),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

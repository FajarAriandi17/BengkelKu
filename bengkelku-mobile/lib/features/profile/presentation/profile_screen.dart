import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../auth/presentation/auth_provider.dart";

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil Saya"),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Profil
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.panel,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: c.blueSoft,
                  child: Icon(Icons.person, size: 36, color: c.blue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Pengendara BengkelKu",
                          style: AppTypography.h2.copyWith(color: c.ink)),
                      Text("rider@bengkelku.id",
                          style: AppTypography.caption
                              .copyWith(color: c.ink.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text("Akun Pemilik Bengkel",
              style: AppTypography.label
                  .copyWith(color: c.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 8),

          ListTile(
            leading: Icon(Icons.storefront, color: c.blue),
            title: Text("Beralih ke Dashboard Owner",
                style: AppTypography.bodyStrong.copyWith(color: c.ink)),
            subtitle: Text("Kelola usaha bengkel, booking, & dompet",
                style: AppTypography.caption
                    .copyWith(color: c.ink.withValues(alpha: 0.6))),
            trailing: const Icon(Icons.chevron_right),
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => context.go("/owner"),
          ),
          const SizedBox(height: 8),

          ListTile(
            leading: Icon(Icons.add_business, color: c.blue),
            title: Text("Daftarkan Usaha Bengkel Baru",
                style: AppTypography.bodyStrong.copyWith(color: c.ink)),
            subtitle: Text("Daftar dan unggah dokumen verifikasi",
                style: AppTypography.caption
                    .copyWith(color: c.ink.withValues(alpha: 0.6))),
            trailing: const Icon(Icons.chevron_right),
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => context.push("/owner/register"),
          ),
          const SizedBox(height: 20),

          Text("Pengaturan Akun",
              style: AppTypography.label
                  .copyWith(color: c.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 8),

          ListTile(
            leading: Icon(Icons.notifications_outlined, color: c.ink),
            title: Text("Pengaturan Notifikasi",
                style: AppTypography.bodyStrong.copyWith(color: c.ink)),
            trailing: const Icon(Icons.chevron_right),
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => context.push("/notifications/settings"),
          ),
          const SizedBox(height: 8),

          ListTile(
            leading: Icon(Icons.help_outline, color: c.ink),
            title: Text("Bantuan",
                style: AppTypography.bodyStrong.copyWith(color: c.ink)),
            subtitle: Text("FAQ, laporkan masalah, & status laporan",
                style: AppTypography.caption
                    .copyWith(color: c.ink.withValues(alpha: 0.6))),
            trailing: const Icon(Icons.chevron_right),
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => context.push("/help"),
          ),
          const SizedBox(height: 8),

          ListTile(
            leading: Icon(Icons.lock_outline, color: c.ink),
            title: Text("Ubah Kata Sandi",
                style: AppTypography.bodyStrong.copyWith(color: c.ink)),
            trailing: const Icon(Icons.chevron_right),
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => context.push("/forgot-password"),
          ),
          const SizedBox(height: 20),

          ListTile(
            leading: Icon(Icons.logout, color: c.bad),
            title: Text("Keluar (Logout)",
                style: AppTypography.bodyStrong.copyWith(color: c.bad)),
            tileColor: c.panel,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go("/login");
            },
          ),
        ],
      ),
    );
  }
}

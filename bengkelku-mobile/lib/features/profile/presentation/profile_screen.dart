import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/network/supabase_client.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_shell.dart";
import "../../auth/presentation/auth_provider.dart";
import "../../chat/presentation/chat_provider.dart";

/// Profil — mengikuti prototype: avatar & nama, kartu biru "Punya bengkel
/// motor?", baris mode bengkel, dan daftar menu akun.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final unread = ref.watch(chatUnreadCountProvider);
    final name = (profile?["full_name"] as String?)?.trim();
    final email = SupabaseService.isLoggedIn
        ? (SupabaseService.currentUser?.email ?? "")
        : "";
    final display = (name == null || name.isEmpty) ? "Pengendara" : name;
    final initial = display.characters.first.toUpperCase();

    final menu = <(IconData, String, String, int)>[
      (Icons.two_wheeler_outlined, "Garasi saya", "/garage", 0),
      (Icons.favorite_border_rounded, "Bengkel favorit", "/favorites", 0),
      (Icons.chat_bubble_outline_rounded, "Chat", "/chat", unread),
      (
        Icons.notifications_none_rounded,
        "Notifikasi",
        "/notifications/settings",
        0,
      ),
      (Icons.help_outline_rounded, "Bantuan", "/help", 0),
      (Icons.lock_outline_rounded, "Ubah kata sandi", "/forgot-password", 0),
    ];

    return Scaffold(
      backgroundColor: c.panel2,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            Center(
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.blue,
                  boxShadow: [
                    BoxShadow(
                      color: c.blue.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  initial,
                  style: AppTypography.display
                      .copyWith(color: Colors.white, fontSize: 34),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              display,
              textAlign: TextAlign.center,
              style: AppTypography.h1.copyWith(color: c.ink),
            ),
            if (email.isNotEmpty)
              Text(
                email,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: c.ink2),
              ),
            const SizedBox(height: 20),
            Material(
              color: c.blue,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: () => context.push("/owner/register"),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconTile(
                        icon: Icons.storefront_outlined,
                        color: Colors.white,
                        background: Colors.white.withValues(alpha: 0.18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Punya bengkel motor?",
                              style: AppTypography.label.copyWith(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              "Daftarkan bengkelmu dan terima booking dari pengendara sekitar.",
                              style: AppTypography.caption
                                  .copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              onTap: () => context.go("/owner"),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: c.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Mode bengkel",
                          style: AppTypography.label.copyWith(color: c.ink),
                        ),
                        Text(
                          "Kelola booking, jadwal buka & dompet",
                          style: AppTypography.caption.copyWith(color: c.ink2),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.ink2),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (i, m) in menu.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 52, color: c.line),
                    ListTile(
                      leading: Badge(
                        isLabelVisible: m.$4 > 0,
                        label: Text("${m.$4}"),
                        backgroundColor: c.heart,
                        child: Icon(m.$1, color: c.ink2),
                      ),
                      title: Text(
                        m.$2,
                        style: AppTypography.body.copyWith(
                          color: c.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: c.ink2),
                      onTap: () => m.$3 == "/garage"
                          ? context.go(m.$3)
                          : context.push(m.$3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.logout_rounded, color: c.bad),
                title: Text(
                  "Keluar",
                  style: AppTypography.body.copyWith(
                    color: c.bad,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go("/login");
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        current: AppTab.profile,
        badges: {AppTab.profile: unread},
      ),
    );
  }
}

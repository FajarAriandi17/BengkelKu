// Pusat Notifikasi — data nyata dari public.notifications (RLS: milik sendiri).
// Notifikasi verifikasi bengkel, balasan bantuan, booking, oli. Realtime.

import "dart:async";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../../core/network/supabase_client.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/state_views.dart";

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    required this.kind,
    this.data,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? body;
  final String kind;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get unread => readAt == null;
  String? get route => data?["route"] as String?;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j["id"] as String,
        title: j["title"] as String? ?? "",
        body: j["body"] as String?,
        kind: j["kind"] as String? ?? "general",
        data: (j["data"] as Map?)?.cast<String, dynamic>(),
        readAt: j["read_at"] != null
            ? DateTime.parse(j["read_at"] as String)
            : null,
        createdAt: DateTime.parse(j["created_at"] as String),
      );
}

/// "2 jam yang lalu", "kemarin", "3 hari yang lalu", "12 Jan".
String relativeTimeId(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(t.toLocal());
  if (d.inMinutes < 1) return "baru saja";
  if (d.inMinutes < 60) return "${d.inMinutes} menit yang lalu";
  if (d.inHours < 24) return "${d.inHours} jam yang lalu";
  if (d.inDays == 1) return "kemarin";
  if (d.inDays < 7) return "${d.inDays} hari yang lalu";
  const m = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "Mei",
    "Jun",
    "Jul",
    "Agu",
    "Sep",
    "Okt",
    "Nov",
    "Des"
  ];
  final l = t.toLocal();
  return "${l.day} ${m[l.month - 1]}${l.year != n.year ? " ${l.year}" : ""}";
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = const [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _channel;

  SupabaseClient get _db => SupabaseService.client;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    final uid = SupabaseService.currentUser?.id;
    if (uid != null) {
      _channel = _db
          .channel("notif:$uid")
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: "public",
            table: "notifications",
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: "user_id",
              value: uid,
            ),
            callback: (_) => unawaited(_load()),
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    if (_channel != null) unawaited(_db.removeChannel(_channel!));
    super.dispose();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final rows = await _db
          .from("notifications")
          .select()
          .eq("user_id", uid)
          .order("created_at", ascending: false)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _items = rows.map(AppNotification.fromJson).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is PostgrestException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _db.rpc("notifications_mark_all_read");
      await _load();
    } catch (_) {}
  }

  Future<void> _open(AppNotification n) async {
    if (n.unread) {
      try {
        await _db
            .from("notifications")
            .update({"read_at": DateTime.now().toUtc().toIso8601String()}).eq(
                "id", n.id);
      } catch (_) {}
    }
    if (!mounted) return;
    final route =
        n.route ?? (n.kind == "verification" ? "/owner/status" : null);
    if (route != null) {
      await context.push(route);
    }
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unread = _items.where((n) => n.unread).length;

    Widget body;
    if (_loading) {
      body = const Padding(padding: EdgeInsets.all(16), child: SkeletonList());
    } else if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = ListView(children: const [
        SizedBox(height: 80),
        EmptyState(
          icon: Icons.notifications_none,
          title: "belum ada notifikasi",
          message:
              "info booking, pengingat oli, dan status verifikasi muncul di sini.",
        ),
      ]);
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) => NotificationTile(
          notification: _items[i],
          onTap: () => _open(_items[i]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pusat Notifikasi"),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text("Tandai dibaca"),
            ),
          IconButton(
            tooltip: "Pengaturan notifikasi",
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push("/notifications/settings"),
          ),
        ],
        elevation: 0,
      ),
      backgroundColor: c.stage,
      body: SafeArea(child: RefreshIndicator(onRefresh: _load, child: body)),
    );
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = notification;
    final (icon, color) = switch (n.kind) {
      "oil" => (Icons.opacity, c.warn),
      "booking" => (Icons.event_available, c.ok),
      "verification" => (Icons.verified_outlined, c.blue),
      "support" => (Icons.support_agent, c.blue),
      "sos" => (Icons.car_crash_outlined, c.bad),
      _ => (Icons.notifications_none, c.ink2),
    };

    return Semantics(
      button: onTap != null,
      label: "${n.unread ? "belum dibaca, " : ""}${n.title}",
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: n.unread ? c.blueSoft : c.panel,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title,
                            style: AppTypography.bodyStrong
                                .copyWith(color: c.ink)),
                        if ((n.body ?? "").isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(n.body!,
                              style: AppTypography.caption
                                  .copyWith(color: c.ink2)),
                        ],
                        const SizedBox(height: 6),
                        Text(relativeTimeId(n.createdAt),
                            style: AppTypography.caption
                                .copyWith(color: c.ink2, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (n.unread)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6),
                      decoration:
                          BoxDecoration(color: c.blue, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Host global siaga darurat bengkel.
//
// Dipasang di MaterialApp.router(builder:) sehingga tawaran masuk dibuka
// sebagai layar penuh ownerSosOffer dari layar mana pun (PRD 3.3 poin 2).
// Memuat ulang status siaga saat login/logout.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import 'owner_sos_controller.dart';

class OwnerSosHost extends ConsumerStatefulWidget {
  const OwnerSosHost({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<OwnerSosHost> createState() => _OwnerSosHostState();
}

class _OwnerSosHostState extends ConsumerState<OwnerSosHost> {
  StreamSubscription<AuthState>? _auth;

  @override
  void initState() {
    super.initState();
    try {
      _auth = SupabaseService.auth.onAuthStateChange.listen((s) {
        if (s.event == AuthChangeEvent.signedIn ||
            s.event == AuthChangeEvent.signedOut) {
          ref.read(ownerSosControllerProvider.notifier).load();
        }
      });
    } catch (_) {
      // Supabase belum terinisialisasi (mis. di widget test).
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      ownerSosControllerProvider.select((s) => s.incomingOfferId),
      (prev, next) {
        if (next == null || next == prev) return;
        ref.read(ownerSosControllerProvider.notifier).consumeIncoming();
        final current =
            widget.router.routerDelegate.currentConfiguration.uri.path;
        if (current.startsWith('/owner/sos/')) return; // sedang menangani
        widget.router.push('/owner/sos/offer/$next');
      },
    );
    return widget.child;
  }
}

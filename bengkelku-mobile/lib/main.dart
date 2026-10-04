import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:sentry_flutter/sentry_flutter.dart";

import "app/app.dart";
import "core/network/supabase_client.dart";

const String _sentryDsn = String.fromEnvironment("SENTRY_DSN");

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.init();

  Future<void> boot() async {
    runApp(const ProviderScope(child: BengkelKuApp()));
  }

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) => options.dsn = _sentryDsn,
      appRunner: boot,
    );
  } else {
    await boot();
  }
}

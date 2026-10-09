import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
import "../domain/auth_error_mapper.dart";
import "auth_provider.dart";

/// Layar atur kata sandi baru — dibuka otomatis setelah pengguna mengetuk
/// tautan reset kata sandi dari email (event passwordRecovery).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading) return;
    final pw = _password.text;
    final err = validatePassword(pw) ??
        (pw != _confirm.text ? "konfirmasi kata sandi tidak sama" : null);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(pw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("kata sandi berhasil diperbarui")),
      );
      ref.read(authRefreshProvider).clearRecovery();
      context.go("/home");
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text("Kata Sandi Baru"), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Atur kata sandi baru",
                style: AppTypography.h1.copyWith(color: c.ink),
              ),
              const SizedBox(height: 8),
              Text(
                "Masukkan kata sandi baru untuk akun kamu (minimal 6 karakter).",
                style: AppTypography.body
                    .copyWith(color: c.ink.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: _password,
                label: "Kata Sandi Baru",
                hint: "Minimal 6 karakter",
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _confirm,
                label: "Ulangi Kata Sandi",
                hint: "Ketik ulang kata sandi",
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTypography.caption.copyWith(color: c.bad),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: "Simpan Kata Sandi",
                onPressed: _save,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

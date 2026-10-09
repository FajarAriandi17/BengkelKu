import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../core/network/supabase_client.dart";
import "../../../design/components/app_text_field.dart";
import "../data/auth_repository.dart";
import "../domain/auth_error_mapper.dart";
import "auth_provider.dart";

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  /// Pesan validasi lokal (sebelum request ke server).
  String? _localError;

  /// Pesan sukses (mis. "cek email untuk konfirmasi").
  String? _info;
  String? _pendingConfirmEmail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      ref.read(authControllerProvider.notifier).clearError();
      setState(() {
        _localError = null;
        if (_pendingConfirmEmail == null) _info = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  static const _notConnected =
      "aplikasi belum terhubung ke server. hubungi pengembang";

  Future<void> _submit() async {
    if (ref.read(authControllerProvider).isLoading) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim().toLowerCase();
    // Kata sandi TIDAK di-trim: spasi adalah karakter yang sah.
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final isRegister = _tabController.index == 1;

    final err =
        (isRegister && name.isEmpty ? "nama lengkap wajib diisi" : null) ??
            validateEmail(email) ??
            validatePassword(password);
    setState(() {
      _localError = err;
      _info = null;
      _pendingConfirmEmail = null;
    });
    if (err != null) return;

    if (!SupabaseService.isReady) {
      setState(() => _localError = _notConnected);
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);

    if (isRegister) {
      final result = await controller.register(email, password, name);
      if (!mounted || result == null) return;
      if (result == SignUpResult.needsEmailConfirmation) {
        setState(() {
          _pendingConfirmEmail = email;
          _info = "akun berhasil dibuat. kami mengirim tautan konfirmasi ke "
              "$email — buka tautan itu, lalu masuk";
          _passwordController.clear();
        });
        _tabController.animateTo(0);
        return;
      }
      context.go("/home");
    } else {
      final ok = await controller.login(email, password);
      if (ok && mounted) context.go("/home");
    }
  }

  Future<void> _resendConfirmation() async {
    final email =
        _pendingConfirmEmail ?? _emailController.text.trim().toLowerCase();
    if (validateEmail(email) != null) {
      _show("isi email kamu terlebih dahulu");
      return;
    }
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(email);
      if (mounted) _show("email konfirmasi dikirim ulang ke $email");
    } catch (e) {
      if (mounted) _show(authErrorMessage(e));
    }
  }

  Future<void> _loginGoogle() async {
    if (!SupabaseService.isReady) {
      _show(_notConnected);
      return;
    }
    final controller = ref.read(authControllerProvider.notifier);
    final launched = await controller.loginWithGoogle();
    if (!launched && mounted && controller.errorMessage == null) {
      _show("tidak dapat membuka halaman masuk Google");
    }
  }

  Future<void> _loginApple() async {
    if (!SupabaseService.isReady) {
      _show(_notConnected);
      return;
    }
    await ref.read(authControllerProvider.notifier).loginWithApple();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authState = ref.watch(authControllerProvider);
    final errorText = _localError ??
        (authState.hasError ? authErrorMessage(authState.error!) : null) ??
        (SupabaseService.isReady ? null : _notConnected);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Logo
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.blueSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.two_wheeler, size: 40, color: c.blue),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "BengkelKu",
                style: AppTypography.display.copyWith(color: c.ink),
                textAlign: TextAlign.center,
              ),
              Text(
                "Marketplace Servis & Pengingat Oli Motor",
                style: AppTypography.caption
                    .copyWith(color: c.ink.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // Tab
              TabBar(
                controller: _tabController,
                labelColor: c.blue,
                unselectedLabelColor: c.ink.withValues(alpha: 0.5),
                indicatorColor: c.blue,
                tabs: const [
                  Tab(text: "Masuk"),
                  Tab(text: "Daftar"),
                ],
              ),
              const SizedBox(height: 20),

              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  final isRegister = _tabController.index == 1;
                  return Column(
                    children: [
                      if (isRegister) ...[
                        AppTextField(
                          controller: _nameController,
                          label: "Nama Lengkap",
                          hint: "Masukkan nama kamu",
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        const SizedBox(height: 14),
                      ],
                      AppTextField(
                        controller: _emailController,
                        label: "Email",
                        hint: "nama@email.com",
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _passwordController,
                        label: "Kata Sandi",
                        hint: "Masukkan kata sandi",
                        obscureText: true,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push("/forgot-password"),
                  child: Text(
                    "Lupa kata sandi?",
                    style: AppTypography.caption.copyWith(color: c.blue),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_info != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.okSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _info!,
                        style: AppTypography.caption.copyWith(color: c.okText),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: _resendConfirmation,
                        child: const Text("kirim ulang email konfirmasi"),
                      ),
                    ],
                  ),
                ),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Text(
                        errorText,
                        style: AppTypography.caption.copyWith(color: c.bad),
                        textAlign: TextAlign.center,
                      ),
                      if (errorText.startsWith("email belum dikonfirmasi"))
                        TextButton(
                          onPressed: _resendConfirmation,
                          child: const Text("kirim ulang email konfirmasi"),
                        ),
                    ],
                  ),
                ),

              AppButton(
                label: _tabController.index == 0 ? "Masuk" : "Daftar Akun",
                onPressed: _submit,
                loading: authState.isLoading,
              ),
              const SizedBox(height: 20),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: c.blueSoft)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "atau masuk dengan",
                      style: AppTypography.caption
                          .copyWith(color: c.ink.withValues(alpha: 0.5)),
                    ),
                  ),
                  Expanded(child: Divider(color: c.blueSoft)),
                ],
              ),
              const SizedBox(height: 16),

              // Social Auth Buttons (Google & Apple)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.ink,
                  side: BorderSide(color: c.blueSoft),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon:
                    const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                label: const Text("Masuk dengan Google"),
                onPressed: authState.isLoading ? null : _loginGoogle,
              ),
              if (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.macOS) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.ink,
                    side: BorderSide(color: c.blueSoft),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.apple, size: 22),
                  label: const Text("Sign in with Apple"),
                  onPressed: authState.isLoading ? null : _loginApple,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

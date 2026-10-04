import "dart:io";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../../core/theme/app_colors.dart";
import "../../../core/theme/app_typography.dart";
import "../../../design/components/app_button.dart";
import "../../../design/components/app_text_field.dart";
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan kata sandi wajib diisi")),
      );
      return;
    }

    final isRegister = _tabController.index == 1;
    final controller = ref.read(authControllerProvider.notifier);

    bool success = false;
    if (isRegister) {
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Nama lengkap wajib diisi")),
        );
        return;
      }
      success = await controller.register(email, password, name);
    } else {
      success = await controller.login(email, password);
    }

    if (success && mounted) {
      context.go("/home");
    }
  }

  Future<void> _loginGoogle() async {
    final controller = ref.read(authControllerProvider.notifier);
    await controller.loginWithGoogle();
  }

  Future<void> _loginApple() async {
    final controller = ref.read(authControllerProvider.notifier);
    await controller.loginWithApple();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authState = ref.watch(authControllerProvider);

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

              if (authState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    "Gagal: ${authState.error}",
                    style: AppTypography.caption.copyWith(color: c.bad),
                    textAlign: TextAlign.center,
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
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon:
                    const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                label: const Text("Masuk dengan Google"),
                onPressed: _loginGoogle,
              ),
              if (Platform.isIOS || Platform.isMacOS) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.ink,
                    side: BorderSide(color: c.blueSoft),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.apple, size: 22),
                  label: const Text("Sign in with Apple"),
                  onPressed: _loginApple,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

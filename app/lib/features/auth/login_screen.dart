import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _matKhau = TextEditingController();
  bool _hienMatKhau = false;
  bool _dangGui = false;

  @override
  void dispose() {
    _email.dispose();
    _matKhau.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (!_form.currentState!.validate() || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      await context.read<Session>().dangNhap(_email.text.trim(), _matKhau.text);
      // AuthGate tự đổi màn hình khi Session có user, không cần navigate.
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.house_outlined, size: 64, color: NhaCai.mauChuDao),
                  const SizedBox(height: 8),
                  Text(
                    'RoomFinder',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: NhaCai.mauChuDao,
                    ),
                  ),
                  Text(
                    context.t('Tìm phòng trọ cho sinh viên'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: context.t('Email'),
                      prefixIcon: const Icon(Icons.mail_outline),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? context.t('Vui lòng nhập email') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _matKhau,
                    obscureText: !_hienMatKhau,
                    onFieldSubmitted: (_) => _gui(),
                    decoration: InputDecoration(
                      labelText: context.t('Mật khẩu'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hienMatKhau = !_hienMatKhau),
                        icon: Icon(_hienMatKhau ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                    validator: (value) =>
                        (value ?? '').isEmpty ? context.t('Vui lòng nhập mật khẩu') : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _dangGui ? null : _gui,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _dangGui
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(context.t('Đăng nhập')),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: Text(context.t('Chưa có tài khoản? Đăng ký ngay')),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.t('Tài khoản Admin chỉ tạo được từ trang web (đồ án cơ sở).'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blueGrey),
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

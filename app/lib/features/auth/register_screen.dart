import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _hoTen = TextEditingController();
  final _email = TextEditingController();
  final _matKhau = TextEditingController();
  final _nhaiLai = TextEditingController();

  String _vaiTro = 'SinhVien';
  bool _dangGui = false;

  @override
  void dispose() {
    _hoTen.dispose();
    _email.dispose();
    _matKhau.dispose();
    _nhaiLai.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (!_form.currentState!.validate() || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      await context.read<Session>().dangKy(
        hoTen: _hoTen.text.trim(),
        email: _email.text.trim(),
        matKhau: _matKhau.text,
        vaiTro: _vaiTro,
      );
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Đăng ký tài khoản'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _hoTen,
                  decoration: InputDecoration(
                    labelText: context.t('Họ và tên'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().length < 2 ? context.t('Vui lòng nhập họ tên') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: context.t('Email'),
                    prefixIcon: const Icon(Icons.mail_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      !(value ?? '').contains('@') ? context.t('Email không hợp lệ') : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _matKhau,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.t('Mật khẩu (tối thiểu 6 ký tự)'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').length < 6
                      ? context.t('Mật khẩu tối thiểu 6 ký tự')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nhaiLai,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.t('Nhập lại mật khẩu'),
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value != _matKhau.text ? context.t('Mật khẩu nhập lại không khớp') : null,
                ),
                const SizedBox(height: 24),
                Text(context.t('Bạn là'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _VaiTroCard(
                  giaTri: 'SinhVien',
                  vaiTroHienTai: _vaiTro,
                  icon: Icons.school_outlined,
                  tieuDe: context.t('Sinh viên'),
                  moTa: context.t('Tìm trọ, đặt cọc, thuê phòng và chat với chủ trọ.'),
                  onChon: () => setState(() => _vaiTro = 'SinhVien'),
                ),
                const SizedBox(height: 8),
                _VaiTroCard(
                  giaTri: 'ChuTro',
                  vaiTroHienTai: _vaiTro,
                  icon: Icons.storefront_outlined,
                  tieuDe: context.t('Chủ trọ'),
                  moTa: context.t('Đăng tin phòng, quản lý danh sách phòng đang cho thuê.'),
                  onChon: () => setState(() => _vaiTro = 'ChuTro'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _dangGui ? null : _gui,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(
                    _dangGui ? context.t('Đang tạo tài khoản...') : context.t('Đăng ký'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VaiTroCard extends StatelessWidget {
  const _VaiTroCard({
    required this.giaTri,
    required this.vaiTroHienTai,
    required this.icon,
    required this.tieuDe,
    required this.moTa,
    required this.onChon,
  });

  final String giaTri;
  final String vaiTroHienTai;
  final IconData icon;
  final String tieuDe;
  final String moTa;
  final VoidCallback onChon;

  @override
  Widget build(BuildContext context) {
    final duocChon = giaTri == vaiTroHienTai;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: duocChon ? NhaCai.mauChuDao : Colors.grey.shade300, width: duocChon ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onChon,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Radio<String>(
                value: giaTri,
                groupValue: vaiTroHienTai,
                onChanged: (_) => onChon(),
              ),
              Icon(icon, color: duocChon ? NhaCai.mauChuDao : Colors.blueGrey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tieuDe, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(moTa, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

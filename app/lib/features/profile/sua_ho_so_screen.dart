import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

class SuaHoSoScreen extends StatefulWidget {
  const SuaHoSoScreen({super.key});

  @override
  State<SuaHoSoScreen> createState() => _SuaHoSoScreenState();
}

class _SuaHoSoScreenState extends State<SuaHoSoScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _hoTen;
  late final TextEditingController _soDienThoai;
  late final TextEditingController _diaChi;
  DateTime? _ngaySinh;
  bool _dangGui = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<Session>().user;
    _hoTen = TextEditingController(text: user?.hoTen ?? '');
    _soDienThoai = TextEditingController(text: user?.soDienThoai ?? '');
    _diaChi = TextEditingController(text: user?.diaChi ?? '');
    _ngaySinh = user?.ngaySinh;
  }

  @override
  void dispose() {
    _hoTen.dispose();
    _soDienThoai.dispose();
    _diaChi.dispose();
    super.dispose();
  }

  Future<void> _chonNgaySinh() async {
    final homNay = DateTime.now();
    final ngay = await showDatePicker(
      context: context,
      initialDate: _ngaySinh ?? DateTime(homNay.year - 20),
      firstDate: DateTime(1950),
      lastDate: homNay,
    );
    if (ngay != null) setState(() => _ngaySinh = ngay);
  }

  Future<void> _luu() async {
    if (!_form.currentState!.validate() || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      await context.read<Session>().capNhatHoSo(
        hoTen: _hoTen.text.trim(),
        soDienThoai: _soDienThoai.text.trim(),
        ngaySinh: _ngaySinh,
        diaChi: _diaChi.text.trim(),
      );
      if (!mounted) return;
      bao(context: context, message: context.t('Đã lưu thông tin cá nhân.'));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Sửa thông tin cá nhân'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
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
                controller: _soDienThoai,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: context.t('Số điện thoại'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final chuoi = (value ?? '').trim();
                  if (chuoi.isEmpty) return null;
                  return RegExp(r'^0\d{9}$').hasMatch(chuoi)
                      ? null
                      : context.t('Số điện thoại bắt đầu bằng 0 và có 10 số');
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _chonNgaySinh,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.t('Ngày sinh'),
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(
                    _ngaySinh == null
                        ? context.t('Chưa chọn')
                        : '${_ngaySinh!.day.toString().padLeft(2, '0')}/${_ngaySinh!.month.toString().padLeft(2, '0')}/${_ngaySinh!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _diaChi,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.t('Địa chỉ liên hệ'),
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _dangGui ? null : _luu,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_dangGui ? context.t('Đang lưu...') : context.t('Lưu thay đổi')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

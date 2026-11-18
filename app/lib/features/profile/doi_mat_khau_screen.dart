import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

class DoiMatKhauScreen extends StatefulWidget {
  const DoiMatKhauScreen({super.key});

  @override
  State<DoiMatKhauScreen> createState() => _DoiMatKhauScreenState();
}

class _DoiMatKhauScreenState extends State<DoiMatKhauScreen> {
  final _form = GlobalKey<FormState>();
  final _cu = TextEditingController();
  final _moi = TextEditingController();
  final _nhaiLai = TextEditingController();
  bool _dangGui = false;

  @override
  void dispose() {
    _cu.dispose();
    _moi.dispose();
    _nhaiLai.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    if (!_form.currentState!.validate() || _dangGui) return;
    setState(() => _dangGui = true);
    try {
      await context.read<Session>().doiMatKhau(_cu.text, _moi.text);
      if (!mounted) return;
      bao(context: context, message: context.t('Đổi mật khẩu thành công, phiên đăng nhập vẫn giữ nguyên.'));
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
      appBar: AppBar(title: Text(context.t('Đổi mật khẩu'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              _Ong(
                textEditingController: _cu,
                nhan: context.t('Mật khẩu hiện tại'),
                validator: (value) =>
                    (value ?? '').isEmpty ? context.t('Vui lòng nhập mật khẩu hiện tại') : null,
              ),
              const SizedBox(height: 16),
              _Ong(
                textEditingController: _moi,
                nhan: context.t('Mật khẩu mới (tối thiểu 6 ký tự)'),
                validator: (value) => (value ?? '').length < 6
                    ? context.t('Mật khẩu mới tối thiểu 6 ký tự')
                    : null,
              ),
              const SizedBox(height: 16),
              _Ong(
                textEditingController: _nhaiLai,
                nhan: context.t('Nhập lại mật khẩu mới'),
                validator: (value) =>
                    value != _moi.text ? context.t('Mật khẩu nhập lại không khớp') : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _dangGui ? null : _gui,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_dangGui ? context.t('Đang đổi...') : context.t('Đổi mật khẩu')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ong extends StatefulWidget {
  const _Ong({required this.textEditingController, required this.nhan, required this.validator});

  final TextEditingController textEditingController;
  final String nhan;
  final String? Function(String?) validator;

  @override
  State<_Ong> createState() => _OngState();
}

class _OngState extends State<_Ong> {
  bool _hien = false;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.textEditingController,
    obscureText: !_hien,
    validator: widget.validator,
    decoration: InputDecoration(
      labelText: widget.nhan,
      border: const OutlineInputBorder(),
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        onPressed: () => setState(() => _hien = !_hien),
        icon: Icon(_hien ? Icons.visibility_off : Icons.visibility),
      ),
    ),
  );
}

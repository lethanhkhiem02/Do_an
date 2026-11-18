import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/pick_anh.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

class CccdScreen extends StatefulWidget {
  const CccdScreen({super.key});

  @override
  State<CccdScreen> createState() => _CccdScreenState();
}

class _CccdScreenState extends State<CccdScreen> {
  UploadFile? _truoc;
  UploadFile? _sau;
  bool _dangGui = false;

  Future<void> _chon({required bool matTruoc}) async {
    final anh = await PickAnh.one(field: matTruoc ? 'truoc' : 'sau');
    if (anh == null) return;
    setState(() {
      if (matTruoc) {
        _truoc = anh;
      } else {
        _sau = anh;
      }
    });
  }

  Future<void> _gui() async {
    if (_truoc == null && _sau == null) {
      bao(context: context, message: context.t('Vui lòng chọn ít nhất một mặt CCCD.'), loi: true);
      return;
    }
    setState(() => _dangGui = true);
    try {
      await context.read<Session>().taiCCCD(truoc: _truoc, sau: _sau);
      if (!mounted) return;
      bao(context: context, message: context.t('Đã gửi CCCD, Admin sẽ duyệt hồ sơ của bạn.'));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().user;
    final trangThai = XacThuc.nhan(user?.trangThaiXacThuc);
    final daDuyet = XacThuc.xong(user?.trangThaiXacThuc);

    return Scaffold(
      appBar: AppBar(title: Text(context.t('Xác thực CCCD'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                daDuyet ? Icons.verified : Icons.pending_actions_outlined,
                color: daDuyet ? Colors.green : Colors.orange,
              ),
              title: Text('${context.t('Trạng thái')}: $trangThai'),
              subtitle: Text(
                context.t(
                  'Tài khoản được duyệt CCCD sẽ hiển thị tích xanh trong chat và tin đăng, '
                  'giống trang Hồ sơ trên web.',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (user != null && user.soCCCDQuetDuoc != null && user.soCCCDQuetDuoc!.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.numbers),
              title: Text('${context.t('Số CCCD máy quét nhận dạng:')} ${user.soCCCDQuetDuoc}'),
            ),
          const SizedBox(height: 8),
          _MatCCCD(
            tieuDe: context.t('Mặt trước CCCD'),
            daChonMay: _truoc,
            duongDanCu: AppConfig.cccd(user?.cccdTruoc),
            onChon: () => _chon(matTruoc: true),
          ),
          const SizedBox(height: 16),
          _MatCCCD(
            tieuDe: context.t('Mặt sau CCCD'),
            daChonMay: _sau,
            duongDanCu: AppConfig.cccd(user?.cccdSau),
            onChon: () => _chon(matTruoc: false),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _dangGui ? null : _gui,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_dangGui ? context.t('Đang gửi...') : context.t('Gửi cho Admin duyệt')),
          ),
        ],
      ),
    );
  }
}

class _MatCCCD extends StatelessWidget {
  const _MatCCCD({
    required this.tieuDe,
    required this.duongDanCu,
    required this.onChon,
    this.daChonMay,
  });

  final String tieuDe;
  final String duongDanCu;
  final UploadFile? daChonMay;
  final VoidCallback onChon;

  @override
  Widget build(BuildContext context) {
    final Widget hinh = daChonMay != null
        ? Image.memory(daChonMay!.bytes, fit: BoxFit.cover, width: double.infinity, height: 160)
        : (duongDanCu.isEmpty
              ? Container(
                  height: 160,
                  alignment: Alignment.center,
                  color: Colors.blueGrey.shade50,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined, size: 40, color: Colors.blueGrey.shade300),
                      const SizedBox(height: 8),
                      Text(context.t('Chưa có ảnh')),
                    ],
                  ),
                )
              : Image.network(
                  duongDanCu,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 160,
                  errorBuilder: (context, error, stack) => const SizedBox(height: 160),
                ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tieuDe, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(12), child: hinh),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onChon,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(daChonMay == null ? context.t('Chọn ảnh') : context.t('Chọn ảnh khác')),
        ),
      ],
    );
  }
}

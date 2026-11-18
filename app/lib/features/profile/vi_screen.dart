import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../core/thanh_toan.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class ViScreen extends StatefulWidget {
  const ViScreen({super.key});

  @override
  State<ViScreen> createState() => _ViScreenState();
}

class _ViScreenState extends State<ViScreen> {
  late Future<Wallet> _vi;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  void _tai() {
    final session = context.read<Session>();
    setState(() => _vi = session.api.get('api/thanhtoan/vi').then(Wallet.fromJson));
  }

  Future<void> _napTien(Session session) async {
    final soTien = await _hopNapTien();
    if (soTien == null || !mounted) return;

    final duoc = await ThanhToan.chi(
      context,
      session: session,
      endpoint: 'api/thanhtoan/nap-tien',
      tenGiaoDich: context.t('nạp ví'),
      body: {'soTien': soTien},
    );
    if (!mounted) return;
    bao(
      context: context,
      message: duoc
          ? '${context.t('Nạp')} ${Fmt.tien(soTien)} ${context.t('vào ví thành công.')}'
          : context.t('Chưa ghi nhận được giao dịch nạp tiền.'),
      loi: !duoc,
    );
    _tai();
  }

  Future<double?> _hopNapTien() async {
    final controller = TextEditingController();
    const goc = [100000.0, 200000.0, 500000.0];

    final ketQua = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.t('Nạp tiền vào ví')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final tien in goc)
                  ActionChip(
                    label: Text(Fmt.tien(tien)),
                    onPressed: () => Navigator.pop(dialogContext, tien),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: dialogContext.t('Hoặc nhập số tiền (tối thiểu 10.000đ)'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.t('Hủy')),
          ),
          FilledButton(
            onPressed: () {
              final soTien = double.tryParse(controller.text.replaceAll('.', '').replaceAll(',', ''));
              Navigator.pop(dialogContext, (soTien == null || soTien < 10000) ? null : soTien);
            },
            child: Text(dialogContext.t('Nạp')),
          ),
        ],
      ),
    );
    controller.dispose();
    return ketQua;
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Ví của tôi')),
        actions: [
          IconButton(onPressed: _tai, icon: const Icon(Icons.refresh)),
          if (session.laChuTro)
            IconButton(onPressed: () => _napTien(session), icon: const Icon(Icons.add_card_outlined)),
        ],
      ),
      body: FutureBuilder<Wallet>(
        future: _vi,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoiView(
              thongBao: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : context.t('Không tải được ví.'),
              tai: _tai,
            );
          }
          if (!snapshot.hasData) return const NangLuongView();

          final vi = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _tai(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  color: NhaCai.mauChuDao,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('Số dư khả dụng'),
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Fmt.tien(vi.soDu),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (session.laChuTro) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.t('Cần 50.000đ trong ví để đăng tin VIP.'),
                            style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(context.t('Lịch sử giao dịch'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (vi.giaoDich.isEmpty)
                  TrongView(
                    icon: Icons.receipt_long_outlined,
                    chuThich: context.t('Chưa có giao dịch nào.'),
                  )
                else
                  for (final hoaDon in vi.giaoDich) _HoaDon(hoaDon: hoaDon),
                if (session.laChuTro) const SizedBox(height: 12),
                if (session.laChuTro)
                  OutlinedButton.icon(
                    onPressed: () => _napTien(session),
                    icon: const Icon(Icons.add_card_outlined),
                    label: Text(context.t('Nạp tiền qua VNPay')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HoaDon extends StatelessWidget {
  const _HoaDon({required this.hoaDon});

  final Invoice hoaDon;

  @override
  Widget build(BuildContext context) {
    final (mau, icon) = switch (hoaDon.trangThai) {
      'HoanThanh' => (Colors.green, Icons.check_circle_outline),
      'TamGiu' => (Colors.orange, Icons.hourglass_top),
      'HoanTien' => (Colors.blueGrey, Icons.undo),
      _ => (NhaCai.mauChuDao, Icons.receipt_outlined),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: mau),
        title: Text(
          '${hoaDon.loaiHienThi} · ${hoaDon.diaChiPhong ?? "${context.t('Phòng')} ${hoaDon.phongTroId}"}',
        ),
        subtitle: Text('${Fmt.ngay(hoaDon.ngayGiaoDich)} · ${hoaDon.trangThaiHienThi}'),
        trailing: Text(
          Fmt.tien(hoaDon.tongTien),
          style: TextStyle(fontWeight: FontWeight.bold, color: mau),
        ),
      ),
    );
  }
}

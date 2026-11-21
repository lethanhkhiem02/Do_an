import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Toàn văn hợp đồng thuê phòng online.
/// Bên A = chủ trọ, Bên B = sinh viên, mỗi bên xác nhận bằng nút "Đồng ý và ký".
class ChiTietHopDongScreen extends StatefulWidget {
  const ChiTietHopDongScreen({super.key, required this.id});

  final int id;

  @override
  State<ChiTietHopDongScreen> createState() => _ChiTietHopDongScreenState();
}

class _ChiTietHopDongScreenState extends State<ChiTietHopDongScreen> {
  late Future<RentalContract> _hopDong = _tai();

  Future<RentalContract> _tai() =>
      context.read<Session>().api.get('api/hop-dong/${widget.id}').then(RentalContract.fromJson);

  Future<void> _gui({required String action, required String hoi, required String yes, required String xong}) async {
    final dich = context.read<NgonNgu>().d;
    final session = context.read<Session>();

    final chac = await xacNhan(context, hoi: dich(hoi), yes: dich(yes));
    if (!chac) return;
    try {
      await session.api.post('api/hop-dong/${widget.id}/$action');
      if (!mounted) return;
      bao(context: context, message: dich(xong));
      setState(() { _hopDong = _tai(); });
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Hợp đồng thuê phòng')),
        actions: [
          IconButton(
            onPressed: () => setState(() { _hopDong = _tai(); }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<RentalContract>(
        future: _hopDong,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoiView(
              thongBao: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : context.t('Không tải được hợp đồng.'),
              tai: () => setState(() { _hopDong = _tai(); }),
            );
          }
          if (!snapshot.hasData) return const NangLuongView();

          final hd = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TieuDe(context.t('CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM'), dam: true, giua: true),
                    _TieuDe(context.t('Độc lập - Tự do - Hạnh phúc'), nghieng: true, giua: true),
                    const Divider(height: 24),
                    _TieuDe(context.t('HỢP ĐỒNG THUÊ PHÒNG TRỌ'), lon: true, dam: true, giua: true),
                    _TieuDe(
                      '${context.t('Số')} ${hd.id.toString().padLeft(3, '0')}/HĐTP'
                      ' · ${context.t('Lập ngày')} ${Fmt.ngay(hd.ngayLap, gio: false)}',
                      nho: true,
                      giua: true,
                    ),
                    const SizedBox(height: 20),
                    _Ben(
                      nhan: context.t('BÊN A (BÊN CHO THUÊ)'),
                      moTa: context.t('Chủ tài khoản chủ trọ'),
                      ten: hd.tenBenA,
                      ngaySinh: hd.ngaySinhBenA,
                      kyLuc: hd.kyBenALuc,
                    ),
                    const SizedBox(height: 12),
                    _Ben(
                      nhan: context.t('BÊN B (BÊN THUÊ)'),
                      moTa: context.t('Chủ tài khoản sinh viên'),
                      ten: hd.tenBenB,
                      ngaySinh: hd.ngaySinhBenB,
                      kyLuc: hd.kyBenBLuc,
                    ),
                    const SizedBox(height: 20),
                    _Muc(
                      context.t('Điều 1. Đối tượng thuê'),
                      dong: [
                        '${context.t('Địa chỉ phòng')}: ${hd.diaChiPhong}',
                        if (hd.tenPhong?.isNotEmpty == true)
                          '${context.t('Mô tả tin đăng')}: ${hd.tenPhong}',
                      ],
                    ),
                    _Muc(
                      context.t('Điều 2. Giá thuê'),
                      dong: [
                        '${Fmt.tien(hd.giaThue)} / ${context.t('tháng')}',
                        context.t('Giá này được chốt khi lập hợp đồng và giữ nguyên suốt thời hạn thuê.'),
                      ],
                    ),
                    _Muc(
                      context.t('Điều 3. Thời hạn'),
                      dong: [
                        '${dem(hd.thoiHanThang, 'tháng')}, ${context.t('từ')} '
                        '${Fmt.ngay(hd.ngayBatDau, gio: false)} ${context.t('đến')} '
                        '${Fmt.ngay(hd.ngayKetThuc, gio: false)}',
                      ],
                    ),
                    _Muc(
                      context.t('Điều 4. Xác nhận bằng chữ ký điện tử'),
                      dong: [
                        context.t(
                          'Hai bên xác nhận đã đọc toàn bộ nội dung trên và đồng ý bằng cách bấm '
                          '"Đồng ý và ký" trong ứng dụng RoomFinder. Thời điểm ký của mỗi bên được hệ thống lưu lại.',
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    _TieuDe(context.t('CHỮ KÝ CỦA HAI BÊN'), dam: true),
                    const SizedBox(height: 8),
                    _Ky(nhan: context.t('Bên A'), ten: hd.tenBenA, kyLuc: hd.kyBenALuc),
                    const SizedBox(height: 10),
                    _Ky(nhan: context.t('Bên B'), ten: hd.tenBenB, kyLuc: hd.kyBenBLuc),
                    const SizedBox(height: 20),
                    _TrangThaiHopDong(hd: hd),
                    if (hd.conChoMinhKy) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _gui(
                            action: 'ky',
                            hoi: 'Bạn xác nhận toàn bộ nội dung hợp đồng trên và ghi chữ ký của mình?',
                            yes: 'Đồng ý và ký',
                            xong: 'Đã ghi nhận chữ ký của bạn.',
                          ),
                          icon: const Icon(Icons.how_to_reg),
                          label: Text(context.t('Đồng ý và ký')),
                        ),
                      ),
                    ],
                    if (hd.choKy) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _gui(
                            action: 'huy',
                            hoi: 'Hủy hợp đồng này? Hành động không hoàn tác được.',
                            yes: 'Hủy hợp đồng',
                            xong: 'Đã hủy hợp đồng.',
                          ),
                          icon: const Icon(Icons.close),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                          label: Text(context.t('Hủy hợp đồng')),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TieuDe extends StatelessWidget {
  const _TieuDe(
    this.vanBan, {
    this.lon = false,
    this.nho = false,
    this.dam = false,
    this.giua = false,
    this.nghieng = false,
  });

  final String vanBan;
  final bool lon;
  final bool nho;
  final bool dam;
  final bool giua;
  final bool nghieng;

  @override
  Widget build(BuildContext context) => Text(
    vanBan,
    textAlign: giua ? TextAlign.center : TextAlign.left,
    style: TextStyle(
      fontSize: lon ? 18 : (nho ? 12 : 14),
      fontWeight: dam || lon ? FontWeight.w700 : FontWeight.w600,
      fontStyle: nghieng ? FontStyle.italic : FontStyle.normal,
      color: nho ? Colors.blueGrey.shade700 : null,
    ),
  );
}

class _Ben extends StatelessWidget {
  const _Ben({
    required this.nhan,
    required this.moTa,
    required this.ten,
    required this.ngaySinh,
    required this.kyLuc,
  });

  final String nhan;
  final String moTa;
  final String ten;
  final DateTime? ngaySinh;
  final DateTime? kyLuc;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nhan, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(moTa, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
        const SizedBox(height: 6),
        Text('${context.t('Họ và tên')}: $ten', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('${context.t('Ngày sinh')}: ${Fmt.ngay(ngaySinh, gio: false)}'),
      ],
    ),
  );
}

class _Muc extends StatelessWidget {
  const _Muc(this.tieuDe, {required this.dong});

  final String tieuDe;
  final List<String> dong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tieuDe, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        for (final dong in dong)
          Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(dong, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}

class _Ky extends StatelessWidget {
  const _Ky({required this.nhan, required this.ten, required this.kyLuc});

  final String nhan;
  final String ten;
  final DateTime? kyLuc;

  @override
  Widget build(BuildContext context) {
    final mau = kyLuc == null ? Colors.orange.shade800 : Colors.green.shade700;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nhan, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
              Text(ten, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Flexible(
          child: Text(
            kyLuc == null ? context.t('Chưa ký') : '${context.t('Đã ký lúc')} ${Fmt.ngay(kyLuc)}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: mau, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _TrangThaiHopDong extends StatelessWidget {
  const _TrangThaiHopDong({required this.hd});

  final RentalContract hd;

  @override
  Widget build(BuildContext context) {
    final benKhac = hd.vaiTro == 'A' ? hd.tenBenB : hd.tenBenA;
    final (mau, icon, chu) = switch (hd) {
      _ when hd.daKy => (Colors.green, Icons.verified_outlined, context.t('Hợp đồng đã có hiệu lực.')),
      _ when hd.daHuy => (Colors.blueGrey, Icons.do_not_disturb_outlined, context.t('Hợp đồng đã bị hủy.')),
      _ when hd.vaiTro == 'A' => (
        Colors.orange,
        Icons.pending_outlined,
        '${context.t('Đang chờ')} $benKhac ${context.t('ký')}.',
      ),
      _ => (Colors.orange, Icons.pending_outlined, context.t('Bạn là bên còn lại cần ký hợp đồng này.')),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: mau.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: mau, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${hd.trangThaiHienThi} · $chu',
              style: TextStyle(color: mau, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

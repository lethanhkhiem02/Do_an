import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'chi_tiet_phong_screen.dart';

/// Sinh viên xem lại các phòng đã thuê/đã cọc kèm hóa đơn, giống trang "Phòng đã thuê" của web.
class PhongDaThueScreen extends StatefulWidget {
  const PhongDaThueScreen({super.key});

  @override
  State<PhongDaThueScreen> createState() => _PhongDaThueScreenState();
}

class _PhongDaThueScreenState extends State<PhongDaThueScreen> {
  late Future<List<Invoice>> _hoaDon = _tai();

  Future<List<Invoice>> _tai() => context
      .read<Session>()
      .api
      .get('api/phong-tro/phong-da-thue')
      .then((json) => (json as List).map(Invoice.fromJson).toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Phòng tôi đã thuê')),
        actions: [IconButton(onPressed: () => setState(() { _hoaDon = _tai(); }), icon: const Icon(Icons.refresh))],
      ),
      body: FutureBuilder<List<Invoice>>(
        future: _hoaDon,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoiView(
              thongBao: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : context.t('Không tải được danh sách phòng đã thuê.'),
              tai: () => setState(() { _hoaDon = _tai(); }),
            );
          }
          if (!snapshot.hasData) return const NangLuongView();
          final danhSach = snapshot.data!;
          if (danhSach.isEmpty) {
            return TrongView(
              icon: Icons.meeting_room_outlined,
              chuThich: context.t('Bạn chưa thuê hay đặt cọc phòng nào.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: danhSach.length,
            itemBuilder: (context, chiSo) {
              final hoaDon = danhSach[chiSo];
              final (mau, icon) = switch (hoaDon.trangThai) {
                'HoanThanh' => (Colors.green, Icons.check_circle_outline),
                'TamGiu' => (Colors.orange, Icons.hourglass_top),
                'HoanTien' => (Colors.blueGrey, Icons.undo),
                _ => (NhaCai.mauChuDao, Icons.receipt_long_outlined),
              };

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(icon, color: mau, size: 30),
                  title: Text(hoaDon.diaChiPhong ?? '${context.t('Phòng')} ${hoaDon.phongTroId}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${hoaDon.loaiHienThi} · ${hoaDon.trangThaiHienThi}'),
                      Text(
                        '${Fmt.tien(hoaDon.tongTien)} · ${Fmt.ngay(hoaDon.ngayGiaoDich)}'
                        '${hoaDon.chuTro == null ? '' : '\n${context.t('Chủ trọ:')} ${hoaDon.chuTro}'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChiTietPhongScreen(phongId: hoaDon.phongTroId)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

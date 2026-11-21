import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'chi_tiet_hop_dong_screen.dart';

/// Danh sách hợp đồng mà tài khoản đang đăng nhập là Bên A hoặc Bên B.
class HopDongScreen extends StatefulWidget {
  const HopDongScreen({super.key});

  @override
  State<HopDongScreen> createState() => _HopDongScreenState();
}

class _HopDongScreenState extends State<HopDongScreen> {
  late Future<List<RentalContract>> _danhSach = _tai();

  Future<List<RentalContract>> _tai() => context
      .read<Session>()
      .api
      .get('api/hop-dong/danh-sach')
      .then((json) => (json as List).map(RentalContract.fromJson).toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Hợp đồng của tôi')),
        actions: [
          IconButton(
            onPressed: () => setState(() { _danhSach = _tai(); }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<RentalContract>>(
        future: _danhSach,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoiView(
              thongBao: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : context.t('Không tải được danh sách hợp đồng.'),
              tai: () => setState(() { _danhSach = _tai(); }),
            );
          }
          if (!snapshot.hasData) return const NangLuongView();

          final hopDong = snapshot.data!;
          if (hopDong.isEmpty) {
            return TrongView(
              icon: Icons.description_outlined,
              chuThich: context.t(
                'Chưa có hợp đồng nào.\nChủ trọ lập hợp đồng từ phòng đang cho thuê, '
                'sinh viên xác nhận ký ngay trong app.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: hopDong.length,
            itemBuilder: (context, chiSo) => _DongHopDong(hd: hopDong[chiSo]),
          );
        },
      ),
    );
  }
}

class _DongHopDong extends StatelessWidget {
  const _DongHopDong({required this.hd});

  final RentalContract hd;

  @override
  Widget build(BuildContext context) {
    final mau = hd.daKy
        ? Colors.green
        : (hd.daHuy ? Colors.blueGrey : Colors.orange);
    final benKhac = hd.vaiTro == 'A' ? hd.tenBenB : hd.tenBenA;
    final vaiTro = hd.vaiTro == 'A' ? context.t('Bên A - cho thuê') : context.t('Bên B - đi thuê');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChiTietHopDongScreen(id: hd.id)),
        ),
        leading: Icon(
          hd.choKy ? Icons.pending_outlined : Icons.description_outlined,
          color: mau,
        ),
        title: Text(hd.diaChiPhong, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('$vaiTro · $benKhac', style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade700)),
            Text(
              '${context.t('Hiệu lực từ')} ${Fmt.ngay(hd.ngayBatDau, gio: false)} · '
              '${Fmt.tien(hd.giaThue)}/${context.t('tháng')}',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: mau.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            hd.trangThaiHienThi,
            style: TextStyle(color: mau, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

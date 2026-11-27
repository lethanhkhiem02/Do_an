import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../features/contracts/tao_hop_dong_screen.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/room_card.dart';

/// Danh sách phòng chủ trọ đã đăng, cho phép xác nhận cho thuê / mở lại / xóa.
class QuanLyPhongScreen extends StatefulWidget {
  const QuanLyPhongScreen({super.key});

  @override
  State<QuanLyPhongScreen> createState() => _QuanLyPhongScreenState();
}

class _QuanLyPhongScreenState extends State<QuanLyPhongScreen> {
  late Future<List<Room>> _danhSach = _tai();

  Future<List<Room>> _tai() => context
      .read<Session>()
      .api
      .get('api/phong-tro/quan-ly')
      .then((json) => (json as List).map(Room.fromJson).toList());

  Future<void> _hanhDong(String endpoint, String thanhCong) async {
    try {
      await context.read<Session>().api.post(endpoint);
      if (!mounted) return;
      bao(context: context, message: thanhCong);
      setState(() { _danhSach = _tai(); });
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    }
  }

  Future<void> _xoa(Room phong) async {
    final chac = await xacNhan(
      context,
      hoi:
          '${context.t('Xóa phòng')} "${phong.diaChi}"? ${context.t('Toàn bộ đánh giá và báo cáo liên quan cũng bị gỡ.')}',
      yes: context.t('Xóa'),
    );
    if (!chac) return;
    try {
      await context.read<Session>().api.delete('api/phong-tro/${phong.id}');
      if (!mounted) return;
      bao(context: context, message: context.t('Đã xóa phòng.'));
      setState(() { _danhSach = _tai(); });
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Phòng của tôi')),
        actions: [IconButton(onPressed: () => setState(() { _danhSach = _tai(); }), icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_dang_phong_quan_ly',
        onPressed: () => Navigator.pushNamed(context, '/dang-phong'),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(context.t('Đăng phòng')),
      ),
      body: FutureBuilder<List<Room>>(
        future: _danhSach,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoiView(
              thongBao: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : context.t('Không tải được danh sách phòng.'),
              tai: () => setState(() { _danhSach = _tai(); }),
            );
          }
          if (!snapshot.hasData) return const NangLuongView();
          if (snapshot.data!.isEmpty) {
            return TrongView(
              icon: Icons.house_siding_outlined,
              chuThich: context.t(
                'Bạn chưa đăng phòng nào.\nBấm "Đăng phòng" để đưa tin đầu tiên lên RoomFinder.',
              ),
            );
          }

          final phong = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            itemCount: phong.length,
            itemBuilder: (context, chiSo) {
              final item = phong[chiSo];
              final conLai = Fmt.ngayConLai(item.ngayHetHan);
              return PhongCard(
                phong: item,
                footer: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conLai > 0
                            ? '${demConLai(conLai, 'ngày hiển thị')} · ${item.dienTich == null ? context.t('chưa rõ diện tích') : '${Fmt.soThapPhan(item.dienTich)} m²'}'
                            : context.t('Tin đã hết hạn hiển thị, gia hạn để hiện lại trên trang chủ.'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!item.daChoThue)
                            ActionChip(
                              avatar: const Icon(Icons.how_to_reg, size: 16),
                              label: Text(context.t('Xác nhận đã cho thuê')),
                              onPressed: () => _hanhDong(
                                'api/phong-tro/${item.id}/xac-nhan-cho-thue',
                                context.t('Đã đánh dấu phòng này cho thuê.'),
                              ),
                            )
                          else
                            ActionChip(
                              avatar: const Icon(Icons.restart_alt, size: 16),
                              label: Text(context.t('Mở lại tin')),
                              onPressed: () => _hanhDong(
                                'api/phong-tro/${item.id}/mo-lai',
                                context.t('Đã mở lại phòng, mọi người có thể thuê.'),
                              ),
                            ),
                          if (item.daChoThue)
                            ActionChip(
                              avatar: const Icon(Icons.description_outlined, size: 16),
                              label: Text(context.t('Tạo hợp đồng')),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaoHopDongScreen(phongTroId: item.id),
                                ),
                              ),
                            ),
                          ActionChip(
                            avatar: Icon(Icons.delete_outline, size: 16, color: Colors.red.shade700),
                            label: Text(context.t('Xóa'), style: TextStyle(color: Colors.red.shade700)),
                            onPressed: () => _xoa(item),
                          ),
                        ],
                      ),
                    ],
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

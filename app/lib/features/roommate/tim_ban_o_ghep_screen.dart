import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';
import '../chat/tro_chuyen_screen.dart';
import 'ho_so_o_ghep_screen.dart';

class GoiYOGhepItem {
  GoiYOGhepItem({
    required this.id,
    required this.userId,
    required this.hoTen,
    this.avatar,
    this.phoneNumber,
    required this.gioGiacSinhHoat,
    required this.gioiTinhUuTien,
    required this.coNauAn,
    required this.coNuoiPet,
    required this.khongHutThuoc,
    required this.uaSachSe,
    required this.nganSachToiDa,
    required this.khuVucMongMuon,
    this.moTaThem,
    required this.dangTimBan,
    required this.ngayCapNhat,
    required this.phanTramPhuHop,
    required this.matchGioiTinh,
    required this.matchKhuVuc,
    required this.matchNganSach,
    required this.matchGioGiac,
    required this.matchNauAn,
    required this.matchNuoiPet,
    required this.matchKhongHutThuoc,
    required this.matchUaSachSe,
  });

  factory GoiYOGhepItem.fromJson(Map<String, dynamic> json) {
    return GoiYOGhepItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['userId']?.toString() ?? '',
      hoTen: json['hoTen']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      gioGiacSinhHoat: json['gioGiacSinhHoat']?.toString() ?? 'Linh hoạt',
      gioiTinhUuTien: json['gioiTinhUuTien']?.toString() ?? 'Không yêu cầu',
      coNauAn: json['coNauAn'] == true,
      coNuoiPet: json['coNuoiPet'] == true,
      khongHutThuoc: json['khongHutThuoc'] == true,
      uaSachSe: json['uaSachSe'] == true,
      nganSachToiDa: (json['nganSachToiDa'] as num?)?.toDouble() ?? 0,
      khuVucMongMuon: json['khuVucMongMuon']?.toString() ?? '',
      moTaThem: json['moTaThem']?.toString(),
      dangTimBan: json['dangTimBan'] != false,
      ngayCapNhat: DateTime.tryParse(json['ngayCapNhat']?.toString() ?? '') ?? DateTime.now(),
      phanTramPhuHop: (json['phanTramPhuHop'] as num?)?.toInt() ?? 0,
      matchGioiTinh: json['matchGioiTinh'] == true,
      matchKhuVuc: json['matchKhuVuc'] == true,
      matchNganSach: json['matchNganSach'] == true,
      matchGioGiac: json['matchGioGiac'] == true,
      matchNauAn: json['matchNauAn'] == true,
      matchNuoiPet: json['matchNuoiPet'] == true,
      matchKhongHutThuoc: json['matchKhongHutThuoc'] == true,
      matchUaSachSe: json['matchUaSachSe'] == true,
    );
  }

  final int id;
  final String userId;
  final String hoTen;
  final String? avatar;
  final String? phoneNumber;
  final String gioGiacSinhHoat;
  final String gioiTinhUuTien;
  final bool coNauAn;
  final bool coNuoiPet;
  final bool khongHutThuoc;
  final bool uaSachSe;
  final double nganSachToiDa;
  final String khuVucMongMuon;
  final String? moTaThem;
  final bool dangTimBan;
  final DateTime ngayCapNhat;
  final int phanTramPhuHop;

  final bool matchGioiTinh;
  final bool matchKhuVuc;
  final bool matchNganSach;
  final bool matchGioGiac;
  final bool matchNauAn;
  final bool matchNuoiPet;
  final bool matchKhongHutThuoc;
  final bool matchUaSachSe;
}

class TimBanOGhepScreen extends StatefulWidget {
  const TimBanOGhepScreen({super.key});

  @override
  State<TimBanOGhepScreen> createState() => _TimBanOGhepScreenState();
}

class _TimBanOGhepScreenState extends State<TimBanOGhepScreen> {
  bool _dangTai = true;
  String? _loi;
  List<GoiYOGhepItem> _danhSach = [];

  @override
  void initState() {
    super.initState();
    _taiDanhSach();
  }

  Future<void> _taiDanhSach() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });

    try {
      final api = context.read<Session>().api;
      final res = await api.get('api/oghep/goi-y');

      if (res is List) {
        setState(() {
          _danhSach = res
              .whereType<Map>()
              .map((e) => GoiYOGhepItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        });
      } else {
        setState(() => _danhSach = []);
      }
    } on ApiException catch (e) {
      setState(() => _loi = e.message);
    } catch (e) {
      setState(() => _loi = context.t('Không thể tải danh sách gợi ý.'));
    } finally {
      if (mounted) {
        setState(() => _dangTai = false);
      }
    }
  }

  Widget _buildHuyHieuPhuHop(int phanTram) {
    final (mauNen, mauChu, icon) = switch (phanTram) {
      >= 80 => (Colors.green.shade50, Colors.green.shade800, Icons.favorite),
      >= 60 => (Colors.blue.shade50, Colors.blue.shade800, Icons.thumb_up_alt_outlined),
      >= 40 => (Colors.orange.shade50, Colors.orange.shade800, Icons.sentiment_satisfied_alt),
      _ => (Colors.grey.shade100, Colors.grey.shade800, Icons.person_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: mauNen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mauChu.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: mauChu),
          const SizedBox(width: 4),
          Text(
            '$phanTram% ${context.t('Phù hợp')}',
            style: TextStyle(
              color: mauChu,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Tìm bạn ở ghép')),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final daCapNhat = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const HoSoOGhepScreen()),
              );
              if (daCapNhat == true) {
                _taiDanhSach();
              }
            },
            icon: const Icon(Icons.assignment_ind_outlined, size: 20),
            label: Text(context.t('Hồ sơ của tôi')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _taiDanhSach,
        child: _dangTai
            ? const NangLuongView()
            : _loi != null
                ? LoiView(thongBao: _loi!, tai: _taiDanhSach)
                : _danhSach.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          TrongView(
                            icon: Icons.people_outline,
                            chuThich: context.t(
                              'Hiện chưa có bạn nào đang tìm người ở ghép hoặc hãy tạo hồ sơ của bạn để nhận gợi ý phù hợp nhất!',
                            ),
                            hanhDong: FilledButton.icon(
                              onPressed: () async {
                                final daCapNhat = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => const HoSoOGhepScreen()),
                                );
                                if (daCapNhat == true) _taiDanhSach();
                              },
                              icon: const Icon(Icons.edit_note_outlined),
                              label: Text(context.t('Thiết lập hồ sơ của tôi')),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _danhSach.length,
                        itemBuilder: (context, index) {
                          final item = _danhSach[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hàng tiêu đề: Avatar, Tên, Khu vực & Huy hiệu % Phù hợp
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AnhDaiDien(
                                        tenFile: item.avatar,
                                        hoTen: item.hoTen,
                                        kichThuoc: 54,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.hoTen,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.place_outlined,
                                                  size: 14,
                                                  color: item.matchKhuVuc
                                                      ? Colors.green.shade700
                                                      : Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 3),
                                                Expanded(
                                                  child: Text(
                                                    item.khuVucMongMuon,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: item.matchKhuVuc
                                                          ? Colors.green.shade800
                                                          : Colors.grey.shade700,
                                                      fontWeight: item.matchKhuVuc
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (item.matchKhuVuc) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.shade100,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      context.t('Trùng khu vực'),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.green.shade800,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildHuyHieuPhuHop(item.phanTramPhuHop),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),

                                  // Nhãn thói quen & tiêu chí sinh hoạt đầy đủ
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      // 1. Ưu tiên giới tính
                                      _NhanThoiQuen(
                                        icon: item.gioiTinhUuTien == 'Nữ'
                                            ? Icons.female
                                            : item.gioiTinhUuTien == 'Nam'
                                                ? Icons.male
                                                : Icons.wc_outlined,
                                        label: item.gioiTinhUuTien == 'Không yêu cầu'
                                            ? context.t('Mọi giới tính')
                                            : '${context.t('Ưu tiên')} ${item.gioiTinhUuTien}',
                                        trungKhop: item.matchGioiTinh,
                                      ),

                                      // 2. Giờ giấc
                                      _NhanThoiQuen(
                                        icon: item.gioGiacSinhHoat == 'Ngủ sớm'
                                            ? Icons.bedtime_outlined
                                            : item.gioGiacSinhHoat == 'Cú đêm'
                                                ? Icons.nightlight_round
                                                : Icons.timelapse,
                                        label: item.gioGiacSinhHoat,
                                        trungKhop: item.matchGioGiac,
                                      ),

                                      // 3. Không hút thuốc
                                      _NhanThoiQuen(
                                        icon: Icons.smoke_free_outlined,
                                        label: item.khongHutThuoc
                                            ? context.t('Không hút thuốc')
                                            : context.t('Chấp nhận hút thuốc'),
                                        trungKhop: item.matchKhongHutThuoc,
                                      ),

                                      // 4. Ưa gọn gàng sạch sẽ
                                      _NhanThoiQuen(
                                        icon: Icons.cleaning_services_outlined,
                                        label: item.uaSachSe
                                            ? context.t('Ưa sạch sẽ')
                                            : context.t('Thoải mái'),
                                        trungKhop: item.matchUaSachSe,
                                      ),

                                      // 5. Nấu ăn
                                      _NhanThoiQuen(
                                        icon: Icons.restaurant_outlined,
                                        label: item.coNauAn
                                            ? context.t('Có tự nấu ăn')
                                            : context.t('Không nấu ăn'),
                                        trungKhop: item.matchNauAn,
                                      ),

                                      // 6. Nuôi thú cưng
                                      _NhanThoiQuen(
                                        icon: Icons.pets_outlined,
                                        label: item.coNuoiPet
                                            ? context.t('Có nuôi pet')
                                            : context.t('Không nuôi pet'),
                                        trungKhop: item.matchNuoiPet,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Ngân sách tối đa
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: item.matchNganSach
                                          ? Colors.green.shade50
                                          : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: item.matchNganSach
                                            ? Colors.green.shade300
                                            : Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.payments_outlined,
                                          size: 16,
                                          color: item.matchNganSach
                                              ? Colors.green.shade800
                                              : Colors.blue.shade800,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${context.t('Ngân sách tối đa:')} ${Fmt.tien(item.nganSachToiDa)}/${context.t('tháng')}',
                                          style: TextStyle(
                                            color: item.matchNganSach
                                                ? Colors.green.shade900
                                                : Colors.blue.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (item.matchNganSach) ...[
                                          const SizedBox(width: 6),
                                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Mô tả thêm nếu có
                                  if (item.moTaThem != null && item.moTaThem!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      item.moTaThem!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade800,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],

                                  const SizedBox(height: 14),

                                  // Nút Nhắn tin kết nối
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TroChuyenScreen(
                                              nguoiKhacId: item.userId,
                                              tenNguoiKhac: item.hoTen,
                                              avatarNguoiKhac: item.avatar,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.chat_outlined, size: 18),
                                      label: Text(
                                        context.t('Nhắn tin kết nối'),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _NhanThoiQuen extends StatelessWidget {
  const _NhanThoiQuen({
    required this.icon,
    required this.label,
    required this.trungKhop,
  });

  final IconData icon;
  final String label;
  final bool trungKhop;

  @override
  Widget build(BuildContext context) {
    if (trungKhop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green.shade400, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.green.shade700),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.check, size: 13, color: Colors.green.shade700),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';
import '../chat/tro_chuyen_screen.dart';
import '../rooms/chi_tiet_phong_screen.dart';
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
    required this.daCoPhong,
    this.phongTroId,
    this.diaChiPhongHienTai,
    this.giaChiaMoiNguoi,
    this.thoiGianDonVao,
    this.phongTro,
    this.moTaThem,
    required this.dangTimBan,
    required this.ngayCapNhat,
    required this.phanTramPhuHop,
    required this.uuTienBoTro,
    required this.matchGioiTinh,
    required this.matchKhuVuc,
    required this.matchNganSach,
    required this.matchGiaChia,
    required this.matchThoiGianDonVao,
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
      daCoPhong: json['daCoPhong'] == true,
      phongTroId: (json['phongTroId'] as num?)?.toInt(),
      diaChiPhongHienTai: json['diaChiPhongHienTai']?.toString(),
      giaChiaMoiNguoi: (json['giaChiaMoiNguoi'] as num?)?.toDouble(),
      thoiGianDonVao: json['thoiGianDonVao']?.toString(),
      phongTro: json['phongTro'] != null && json['phongTro'] is Map
          ? Map<String, dynamic>.from(json['phongTro'])
          : null,
      moTaThem: json['moTaThem']?.toString(),
      dangTimBan: json['dangTimBan'] != false,
      ngayCapNhat: DateTime.tryParse(json['ngayCapNhat']?.toString() ?? '') ?? DateTime.now(),
      phanTramPhuHop: (json['phanTramPhuHop'] as num?)?.toInt() ?? 0,
      uuTienBoTro: (json['uuTienBoTro'] as num?)?.toInt() ?? 2,
      matchGioiTinh: json['matchGioiTinh'] == true,
      matchKhuVuc: json['matchKhuVuc'] == true,
      matchNganSach: json['matchNganSach'] == true,
      matchGiaChia: json['matchGiaChia'] == true,
      matchThoiGianDonVao: json['matchThoiGianDonVao'] == true,
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
  final bool daCoPhong;
  final int? phongTroId;
  final String? diaChiPhongHienTai;
  final double? giaChiaMoiNguoi;
  final String? thoiGianDonVao;
  final Map<String, dynamic>? phongTro;
  final String? moTaThem;
  final bool dangTimBan;
  final DateTime ngayCapNhat;
  final int phanTramPhuHop;
  final int uuTienBoTro;

  final bool matchGioiTinh;
  final bool matchKhuVuc;
  final bool matchNganSach;
  final bool matchGiaChia;
  final bool matchThoiGianDonVao;
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

  // Bộ lọc: 'all' | 'da_co_phong' | 'chua_co_phong'
  String _boLocNhuCau = 'all';

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
      final query = <String, dynamic>{};
      if (_boLocNhuCau != 'all') {
        query['loaiNhuCau'] = _boLocNhuCau;
      }

      final res = await api.get('api/oghep/goi-y', query: query);

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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
            '$phanTram% ${context.t('Hợp')}',
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

  Widget _buildThanhLocNhuCau() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              showCheckmark: false,
              label: Text(context.t('Tất cả')),
              selected: _boLocNhuCau == 'all',
              onSelected: (val) {
                if (val && _boLocNhuCau != 'all') {
                  setState(() => _boLocNhuCau = 'all');
                  _taiDanhSach();
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              showCheckmark: false,
              avatar: Icon(
                Icons.home_outlined,
                size: 16,
                color: _boLocNhuCau == 'da_co_phong' ? Colors.teal.shade900 : null,
              ),
              label: Text(context.t('Đã có phòng sẵn')),
              selected: _boLocNhuCau == 'da_co_phong',
              selectedColor: Colors.teal.shade100,
              labelStyle: TextStyle(
                color: _boLocNhuCau == 'da_co_phong' ? Colors.teal.shade900 : null,
                fontWeight: _boLocNhuCau == 'da_co_phong' ? FontWeight.bold : null,
              ),
              onSelected: (val) {
                if (val && _boLocNhuCau != 'da_co_phong') {
                  setState(() => _boLocNhuCau = 'da_co_phong');
                  _taiDanhSach();
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              showCheckmark: false,
              avatar: Icon(
                Icons.person_search_outlined,
                size: 16,
                color: _boLocNhuCau == 'chua_co_phong' ? Colors.indigo.shade900 : null,
              ),
              label: Text(context.t('Chưa có phòng (Thuê chung)')),
              selected: _boLocNhuCau == 'chua_co_phong',
              selectedColor: Colors.indigo.shade100,
              labelStyle: TextStyle(
                color: _boLocNhuCau == 'chua_co_phong' ? Colors.indigo.shade900 : null,
                fontWeight: _boLocNhuCau == 'chua_co_phong' ? FontWeight.bold : null,
              ),
              onSelected: (val) {
                if (val && _boLocNhuCau != 'chua_co_phong') {
                  setState(() => _boLocNhuCau = 'chua_co_phong');
                  _taiDanhSach();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;

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
      body: Column(
        children: [
          _buildThanhLocNhuCau(),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
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
                                    'Không tìm thấy bạn ở ghép nào phù hợp bộ lọc hiện tại. Hãy tạo hồ sơ của bạn để nhận thêm gợi ý!',
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
                                final giaHienThi = item.daCoPhong
                                    ? (item.giaChiaMoiNguoi ?? item.nganSachToiDa)
                                    : item.nganSachToiDa;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: item.uuTienBoTro == 1
                                          ? Colors.teal.shade300
                                          : Colors.grey.shade200,
                                      width: item.uuTienBoTro == 1 ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Hàng 1: Avatar, Tên, Cờ bổ trợ & Huy hiệu % Phù hợp
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            AnhDaiDien(
                                              tenFile: item.avatar,
                                              hoTen: item.hoTen,
                                              kichThuoc: 52,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          item.hoTen,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      if (item.uuTienBoTro == 1) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber.shade100,
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(color: Colors.amber.shade600),
                                                          ),
                                                          child: Text(
                                                            context.t('Gợi ý hàng đầu'),
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.amber.shade900,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
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
                                                          item.daCoPhong
                                                              ? (item.diaChiPhongHienTai ?? item.phongTro?['diaChi'] ?? item.khuVucMongMuon)
                                                              : item.khuVucMongMuon,
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

                                        // Hàng 2: Huy hiệu phân loại trạng thái chỗ ở nổi bật
                                        if (item.daCoPhong)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: Colors.teal.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.teal.shade300),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.home_outlined, size: 18, color: Colors.teal.shade700),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    '${context.t('Đã có phòng sẵn')} • ${Fmt.tien(giaHienThi)}/${context.t('người')}',
                                                    style: TextStyle(
                                                      color: Colors.teal.shade900,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                if (item.matchGiaChia || item.matchNganSach) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.check_circle, size: 15, color: Colors.teal.shade700),
                                                ],
                                              ],
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: Colors.indigo.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.indigo.shade200),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.person_search_outlined, size: 18, color: Colors.indigo.shade700),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    '${context.t('Chưa có phòng')} • ${context.t('Ngân sách')} ${Fmt.tien(giaHienThi)}',
                                                    style: TextStyle(
                                                      color: Colors.indigo.shade900,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                if (item.matchNganSach) ...[
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.check_circle, size: 15, color: Colors.indigo.shade700),
                                                ],
                                              ],
                                            ),
                                          ),

                                        // Hàng 3: Inset Card thông tin phòng trọ đính kèm (nếu có PhongTroId)
                                        if (item.phongTroId != null) ...[
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.grey.shade300),
                                            ),
                                            child: Row(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: SizedBox(
                                                    width: 52,
                                                    height: 52,
                                                    child: item.phongTro?['anhDaiDien'] != null
                                                        ? Image.network(
                                                            '${ApiClient.baseUrl}/' + (item.phongTro!['anhDaiDien'].toString().startsWith('/') ? item.phongTro!['anhDaiDien'].toString().substring(1) : item.phongTro!['anhDaiDien'].toString()),
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_, __, ___) => Container(
                                                              color: Colors.teal.shade50,
                                                              child: const Icon(Icons.home, color: Colors.teal),
                                                            ),
                                                          )
                                                        : Container(
                                                            color: Colors.teal.shade50,
                                                            child: const Icon(Icons.home, color: Colors.teal),
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        item.phongTro?['moTa']?.toString() ?? 'Phòng trọ #${item.phongTroId}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        item.phongTro?['diaChi']?.toString() ?? item.diaChiPhongHienTai ?? '',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      if (item.phongTro?['gia'] != null)
                                                        Text(
                                                          '${Fmt.tien((item.phongTro!['gia'] as num).toDouble())} / tháng',
                                                          style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                OutlinedButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => ChiTietPhongScreen(phongId: item.phongTroId!),
                                                      ),
                                                    );
                                                  },
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    side: const BorderSide(color: Colors.teal),
                                                    foregroundColor: Colors.teal,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(context.t('Xem phòng'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                      const SizedBox(width: 2),
                                                      const Icon(Icons.open_in_new, size: 13),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],

                                        const SizedBox(height: 10),

                                        // Hàng 4: Thời gian dọn vào (nếu có) & Thói quen sinh hoạt
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            // Thời gian dọn vào
                                            if (item.thoiGianDonVao != null && item.thoiGianDonVao!.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: Colors.purple.shade200),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.calendar_month_outlined, size: 13, color: Colors.purple.shade700),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${context.t('Dọn vào:')} ${item.thoiGianDonVao}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.purple.shade900,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                            // Ưu tiên giới tính
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

                                            // Giờ giấc
                                            _NhanThoiQuen(
                                              icon: item.gioGiacSinhHoat == 'Ngủ sớm'
                                                  ? Icons.bedtime_outlined
                                                  : item.gioGiacSinhHoat == 'Cú đêm'
                                                      ? Icons.nightlight_round
                                                      : Icons.timelapse,
                                              label: item.gioGiacSinhHoat,
                                              trungKhop: item.matchGioGiac,
                                            ),

                                            // Không hút thuốc
                                            _NhanThoiQuen(
                                              icon: Icons.smoke_free_outlined,
                                              label: item.khongHutThuoc
                                                  ? context.t('Không hút thuốc')
                                                  : context.t('Chấp nhận hút thuốc'),
                                              trungKhop: item.matchKhongHutThuoc,
                                            ),

                                            // Ưa sạch sẽ
                                            _NhanThoiQuen(
                                              icon: Icons.cleaning_services_outlined,
                                              label: item.uaSachSe
                                                  ? context.t('Ưa sạch sẽ')
                                                  : context.t('Thoải mái'),
                                              trungKhop: item.matchUaSachSe,
                                            ),

                                            // Nấu ăn
                                            _NhanThoiQuen(
                                              icon: Icons.restaurant_outlined,
                                              label: item.coNauAn
                                                  ? context.t('Có tự nấu ăn')
                                                  : context.t('Không nấu ăn'),
                                              trungKhop: item.matchNauAn,
                                            ),

                                            // Thú cưng
                                            _NhanThoiQuen(
                                              icon: Icons.pets_outlined,
                                              label: item.coNuoiPet
                                                  ? context.t('Có nuôi pet')
                                                  : context.t('Không nuôi pet'),
                                              trungKhop: item.matchNuoiPet,
                                            ),
                                          ],
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

                                        // Nút hành động chính: Nhắn tin / Xin ở ghép
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: () {
                                              final diaDiem = item.phongTro?['diaChi'] ??
                                                  item.diaChiPhongHienTai ??
                                                  item.khuVucMongMuon;

                                              final tinNhanBanDau = item.daCoPhong
                                                  ? 'Chào ${item.hoTen}, mình thấy bạn đang có phòng ở ghép tại $diaDiem và hồ sơ của tụi mình phù hợp ${item.phanTramPhuHop}%. Mình muốn trao đổi thêm về việc ở ghép cùng bạn nhé!'
                                                  : 'Chào ${item.hoTen}, mình thấy hồ sơ tìm bạn ở ghép của tụi mình hợp ${item.phanTramPhuHop}% tại khu vực ${item.khuVucMongMuon}. Mình muốn trao đổi thêm về việc tìm phòng và ở ghép cùng bạn nhé!';

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => TroChuyenScreen(
                                                    nguoiKhacId: item.userId,
                                                    tenNguoiKhac: item.hoTen,
                                                    avatarNguoiKhac: item.avatar,
                                                    tinNhanBanDau: tinNhanBanDau,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                            label: Text(
                                              item.daCoPhong
                                                  ? context.t('Nhắn tin / Xin ở ghép')
                                                  : context.t('Nhắn tin kết nối'),
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: item.daCoPhong ? Colors.teal.shade700 : null,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
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
          ),
        ],
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
                fontSize: 11,
                color: Colors.green.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 3),
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
              fontSize: 11,
              color: Colors.blueGrey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}


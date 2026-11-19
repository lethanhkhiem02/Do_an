import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../core/thanh_toan.dart';
import '../../models/models.dart';
import '../../widgets/ban_do.dart';
import '../../widgets/common.dart';
import '../../widgets/room_card.dart';
import '../../widgets/tien_ich_xung_quanh.dart';
import '../chat/tro_chuyen_screen.dart';

class ChiTietPhongScreen extends StatefulWidget {
  const ChiTietPhongScreen({super.key, required this.phongId, this.tomTap});

  final int phongId;
  final Room? tomTap;

  @override
  State<ChiTietPhongScreen> createState() => _ChiTietPhongScreenState();
}

class _ChiTietPhongScreenState extends State<ChiTietPhongScreen> with SingleTickerProviderStateMixin {
  static const List<String> _lyDoBaoCao = [
    'Lừa đảo tiền cọc',
    'Phòng trọ không giống ảnh',
    'Chủ trọ có thái độ không tốt / đe dọa',
    'Địa chỉ giả mạo',
    'Khác',
  ];

  RoomDetail? _phong;
  String? _loi;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tai();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _tai() async {
    setState(() => _loi = null);
    try {
      final json = await context.read<Session>().api.get('api/phong-tro/${widget.phongId}');
      setState(() => _phong = RoomDetail.fromJson(json));
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    }
  }

  Future<void> _thuePhong() async {
    final phong = _phong;
    if (phong == null) return;
    final duoc = await ThanhToan.chi(
      context,
      session: context.read<Session>(),
      endpoint: 'api/thanhtoan/thue-phong/${phong.id}',
      tenGiaoDich: '${context.t('thuê phòng')} ${Fmt.tien(phong.gia)}',
      phongId: phong.id,
    );
    if (!mounted) return;
    bao(
      context: context,
      message: duoc
          ? context.t('🎉 Thuê phòng thành công, phòng đã được ghi nhận là đã cho thuê.')
          : context.t('Giao dịch chưa hoàn tất.'),
      loi: !duoc,
    );
    _tai();
  }

  Future<void> _datCoc() async {
    final phong = _phong;
    if (phong == null) return;
    final duoc = await ThanhToan.chi(
      context,
      session: context.read<Session>(),
      endpoint: 'api/thanhtoan/dat-coc/${phong.id}',
      tenGiaoDich: context.t('đặt cọc 500.000đ'),
      phongId: phong.id,
    );
    if (!mounted) return;
    bao(
      context: context,
      message: duoc
          ? '${context.t('🎉 Đặt cọc thành công! Hệ thống đang giữ chỗ cho bạn đến')} ${Fmt.ngay(phong.hanDatCoc)}.'
          : context.t('Đặt cọc chưa hoàn tất.'),
      loi: !duoc,
    );
    _tai();
  }

  Future<void> _thanhToanPhanConLai() async {
    final phong = _phong;
    if (phong == null) return;
    final duoc = await ThanhToan.chi(
      context,
      session: context.read<Session>(),
      endpoint: 'api/thanhtoan/phan-con-lai/${phong.id}',
      tenGiaoDich: context.t('phần còn lại'),
      phongId: phong.id,
    );
    if (!mounted) return;
    bao(
      context: context,
      message: duoc
          ? context.t('Đã thanh toán đủ, chúc bạn ở mới vui vẻ!')
          : context.t('Giao dịch chưa hoàn tất.'),
      loi: !duoc,
    );
    _tai();
  }

  Future<void> _huyCoc() async {
    final phong = _phong;
    if (phong == null) return;
    final chac = await xacNhan(
      context,
      hoi: context.t('Hủy cọc phòng này? 500.000đ sẽ được hoàn về ví của bạn.'),
      yes: context.t('Hủy cọc'),
    );
    if (!chac) return;
    try {
      final json = await context.read<Session>().api.post('api/thanhtoan/huy-coc/${phong.id}');
      final thongBao = json is Map
          ? (json['message'] ?? context.t('Đã hủy cọc.'))
          : context.t('Đã hủy cọc.');
      bao(context: context, message: '$thongBao');
    } on ApiException catch (e) {
      bao(context: context, message: e.message, loi: true);
    }
    _tai();
  }

  Future<void> _baoCao() async {
    String lyDo = _lyDoBaoCao.first;
    final chiTiet = TextEditingController();

    final gui = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, rebuild) => AlertDialog(
          title: Text(context.t('Báo cáo phòng trọ')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: lyDo,
                decoration: InputDecoration(
                  labelText: context.t('Lý do'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final reason in _lyDoBaoCao)
                    DropdownMenuItem(value: reason, child: Text(context.t(reason)))
                ],
                onChanged: (value) => rebuild(() => lyDo = value ?? lyDo),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chiTiet,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.t('Mô tả thêm (không bắt buộc)'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.t('Hủy')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.t('Gửi Admin')),
            ),
          ],
        ),
      ),
    );
    if (gui != true) return;

    try {
      await context.read<Session>().api.post(
        'api/phong-tro/${widget.phongId}/bao-cao',
        body: {'lyDo': lyDo, 'chiTiet': chiTiet.text.trim()},
      );
      if (mounted) bao(context: context, message: context.t('🚩 Cảm ơn bạn! Admin sẽ kiểm tra và xử lý ngay.'));
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    }
    chiTiet.dispose();
  }

  Future<void> _danhGia() async {
    int sao = 5;
    final noiDung = TextEditingController();

    final gui = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, rebuild) => AlertDialog(
          title: Text(context.t('Đánh giá phòng trọ')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (context, rebuildSao) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      IconButton(
                        onPressed: () => rebuildSao(() => sao = i),
                        icon: Icon(i <= sao ? Icons.star : Icons.star_border, color: Colors.amber, size: 30),
                      ),
                  ],
                ),
              ),
              TextField(
                controller: noiDung,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.t('Cảm nhận của bạn'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.t('Hủy')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, noiDung.text.trim().isNotEmpty),
              child: Text(context.t('Gửi đánh giá')),
            ),
          ],
        ),
      ),
    );

    if (gui == true) {
      try {
        await context.read<Session>().api.post(
          'api/phong-tro/${widget.phongId}/danh-gia',
          body: {'sao': sao, 'noiDung': noiDung.text.trim()},
        );
        if (mounted) bao(context: context, message: context.t('🎉 Cảm ơn bạn đã để lại đánh giá!'));
        _tai();
      } on ApiException catch (e) {
        if (mounted) bao(context: context, message: e.message, loi: true);
      }
    }
    noiDung.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loi != null) return Scaffold(appBar: AppBar(), body: LoiView(thongBao: _loi!, tai: _tai));
    final phong = _phong;
    if (phong == null) return const Scaffold(body: NangLuongView());

    final session = context.watch<Session>();

    return Scaffold(
      appBar: AppBar(
        title: Text('${context.t('Phòng trọ')} #${phong.id}'),
        actions: [
          IconButton(
            onPressed: _baoCao,
            tooltip: context.t('Báo cáo lừa đảo'),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: context.t('Thông tin')),
            Tab(text: context.t('Tiện ích xung quanh')),
          ],
        ),
      ),
      persistentFooterButtons: _nutHanhdDong(session, phong),
      body: TabBarView(
        controller: _tab,
        children: [
          _tabThongTin(session, phong),
          TienIchXungQuanh(phong: phong, duocQuet: _duocQuetTienIch(session, phong)),
        ],
      ),
    );
  }

  Widget _tabThongTin(Session session, RoomDetail phong) => ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _ThuAnh(anh: phong.anh.isEmpty ? const ['', ] : phong.anh),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Fmt.tien(phong.gia),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: NhaCai.mauChuDao),
                      ),
                    ),
                    NhanTrangThai(trangThai: phong.trangThai),
                  ],
                ),
                const SizedBox(height: 6),
                Text(phong.diaChi, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TeuMau(
                      icon: phong.laKyTucXa ? Icons.apartment_outlined : Icons.home_outlined,
                      chu: phong.tenLoaiHinh,
                      mau: phong.laKyTucXa ? Colors.indigo : Colors.blueGrey,
                    ),
                    if (phong.isVip)
                      _TeuMau(icon: Icons.workspace_premium, chu: context.t('Tin VIP'), mau: Colors.amber),
                    if (phong.dienTich != null)
                      _TeuMau(icon: Icons.straighten, chu: '${Fmt.soThapPhan(phong.dienTich)} m²', mau: Colors.blueGrey),
                    if (phong.coNhaVeSinh)
                      _TeuMau(icon: Icons.bathtub_outlined, chu: context.t('Vệ sinh riêng'), mau: Colors.teal),
                    if (phong.coBanCong)
                      _TeuMau(icon: Icons.security_outlined, chu: context.t('Có ban công'), mau: Colors.teal),
                    _TeuMau(
                      icon: Icons.event_available_outlined,
                      chu:
                          demConLai(Fmt.ngayConLai(phong.ngayHetHan), 'ngày hiển thị'),
                      mau: Colors.indigo,
                    ),
                    if (phong.soNgayGiuPhong != null)
                      _TeuMau(
                        icon: Icons.hourglass_bottom,
                        chu:
                            '${context.t('Giữ chỗ')} ${dem(phong.soNgayGiuPhong!, 'ngày')}',
                        mau: Colors.orange,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(context.t('Mô tả'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(phong.moTa),
                const SizedBox(height: 16),
                _ChuTro(phong: phong, daDangNhap: session.daDangNhap),
                const SizedBox(height: 16),
                if (phong.latitude != null && phong.longitude != null) ...[
                  Text(context.t('Vị trí trên bản đồ'), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  BanDo(
                    diem: [DiemDo(phong: phong, viDo: phong.latitude!, kinhDo: phong.longitude!)],
                    height: 220,
                    zoom: 15,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text(context.t('Đánh giá'), style: Theme.of(context).textTheme.titleMedium)),
                    Text(Fmt.sao(phong.trungBinhSao, phong.soDanhGia),
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                if (phong.duocDanhGia)
                  OutlinedButton.icon(
                    onPressed: _danhGia,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text(context.t('Viết đánh giá cho phòng này')),
                  ),
                if (phong.duocDanhGia) const SizedBox(height: 12),
                if (phong.danhGia.isEmpty)
                  Text(context.t('Chưa có đánh giá nào cho phòng này.'))
                else
                  for (final danhGia in phong.danhGia) _DanhGiaCard(danhGia: danhGia),
              ],
            ),
          ),
        ],
      );

  bool _duocQuetTienIch(Session session, RoomDetail phong) =>
      session.daDangNhap &&
      (session.laAdmin || (session.laChuTro && session.user?.id == phong.chuTroId));

  List<Widget> _nutHanhdDong(Session session, RoomDetail phong) {
    if (!session.daDangNhap) {
      return [
        SizedBox(
          width: double.infinity,
          child: Text(
            context.t('Đăng nhập để đặt cọc hoặc thuê phòng này.'),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    if (!session.laSinhVien) return const [];

    if (phong.daThue) {
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: null,
            child: Text(context.t('Bạn đã thuê phòng này 🎉')),
          ),
        ),
      ];
    }

    if (phong.daDatCoc) {
      return [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _thanhToanPhanConLai,
                icon: const Icon(Icons.payments_outlined),
                label: Text(context.t('Thanh toán phần còn lại')),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _huyCoc,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: Text(context.t('Hủy cọc')),
            ),
          ],
        ),
      ];
    }

    if (!phong.conTrong) {
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: null,
            child: Text(
              phong.dangDuocGiU
                  ? context.t('Phòng đang được người khác giữ chỗ')
                  : context.t('Tin đăng đã hết hạn hiển thị'),
            ),
          ),
        ),
      ];
    }

    return [
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _datCoc,
              icon: const Icon(Icons.lock_clock),
              label: Text(context.t('Đặt cọc 500.000đ')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: _thuePhong,
              icon: const Icon(Icons.key_outlined),
              label: Text(context.t('Thuê ngay')),
            ),
          ),
        ],
      ),
    ];
  }
}

class _ThuAnh extends StatefulWidget {
  const _ThuAnh({required this.anh});

  final List<String> anh;

  @override
  State<_ThuAnh> createState() => _ThuAnhState();
}

class _ThuAnhState extends State<_ThuAnh> {
  int _hienTai = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            itemCount: widget.anh.length,
            onPageChanged: (chiSo) => setState(() => _hienTai = chiSo),
            itemBuilder: (context, chiSo) => AnhPhongTro(duongDan: widget.anh[chiSo], height: 260),
          ),
        ),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: widget.anh.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, chiSo) => GestureDetector(
              onTap: () => setState(() => _hienTai = chiSo),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnhPhongTro(duongDan: widget.anh[chiSo], height: 58),
                  ),
                  if (_hienTai == chiSo)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: NhaCai.mauChuDao, width: 3),
                      ),
                      child: const SizedBox.expand(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChuTro extends StatelessWidget {
  const _ChuTro({required this.phong, required this.daDangNhap});

  final RoomDetail phong;
  final bool daDangNhap;

  @override
  Widget build(BuildContext context) {
    final session = context.read<Session>();
    final coTheChat =
        daDangNhap && phong.chuTroId != null && session.laSinhVien && session.user?.id != phong.chuTroId;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                AnhDaiDien(tenFile: phong.avatarChuTro, hoTen: phong.tenChuTro, kichThuoc: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              phong.tenChuTro ?? context.t('Chủ trọ'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (XacThuc.xong(phong.chuTroXacThuc))
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.verified, color: Colors.green, size: 18),
                            ),
                        ],
                      ),
                      if (phong.chuTroDienThoai != null && phong.chuTroDienThoai!.isNotEmpty)
                        Text('${context.t('SĐT:')} ${phong.chuTroDienThoai}',
                            style: Theme.of(context).textTheme.bodySmall),
                      if (phong.chuTroDiaChi != null && phong.chuTroDiaChi!.isNotEmpty)
                        Text(phong.chuTroDiaChi!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _DanhSachPhongChuTroScreen(chuTroId: phong.chuTroId!),
                      ),
                    ),
                    icon: const Icon(Icons.apps_outlined, size: 18),
                    label: Text(context.t('Phòng khác của chủ trọ')),
                  ),
                ),
                if (coTheChat) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TroChuyenScreen(
                            nguoiKhacId: phong.chuTroId!,
                            tenNguoiKhac: phong.tenChuTro ?? context.t('Chủ trọ'),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text(context.t('Chat')),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chủ trọ chưa đăng nhập hoặc người xem là chủ trọ: chỉ còn nút xem danh sách phòng của chủ.
class _DanhSachPhongChuTroScreen extends StatefulWidget {
  const _DanhSachPhongChuTroScreen({required this.chuTroId});

  final String chuTroId;

  @override
  State<_DanhSachPhongChuTroScreen> createState() => _DanhSachPhongChuTroScreenState();
}

class _DanhSachPhongChuTroScreenState extends State<_DanhSachPhongChuTroScreen> {
  late Future<List<Room>> _danhSach = _tai();

  Future<List<Room>> _tai() => context
      .read<Session>()
      .api
      .get('api/phong-tro/chu-tro/${widget.chuTroId}')
      .then((json) => (json as List).map(Room.fromJson).toList());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Phòng của chủ trọ này'))),
      body: FutureBuilder<List<Room>>(
        future: _danhSach,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoiView(
              thongBao: context.t('Không tải được danh sách phòng.'),
              tai: () => setState(() { _danhSach = _tai(); }),
            );
          }
          if (!snapshot.hasData) return const NangLuongView();
          if (snapshot.data!.isEmpty) {
            return TrongView(
              icon: Icons.house_siding_outlined,
              chuThich: context.t('Chủ trọ chưa có phòng nào đang hiển thị.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final phong in snapshot.data!)
                PhongCard(
                  phong: phong,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChiTietPhongScreen(phongId: phong.id)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DanhGiaCard extends StatelessWidget {
  const _DanhGiaCard({required this.danhGia});

  final Review danhGia;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: AnhDaiDien(hoTen: danhGia.tenNguoiDanhGia, kichThuoc: 40),
      title: Row(
        children: [
          Expanded(child: Text(danhGia.tenNguoiDanhGia ?? context.t('Người dùng'))),
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= danhGia.sao ? Icons.star : Icons.star_border,
              size: 16,
              color: Colors.amber.shade700,
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(danhGia.noiDung),
          Text(Fmt.tuNho(danhGia.ngayTao), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: true,
    ),
  );
}

class _TeuMau extends StatelessWidget {
  const _TeuMau({required this.icon, required this.chu, required this.mau});

  final IconData icon;
  final String chu;
  final Color mau;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: mau.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: mau),
        const SizedBox(width: 6),
        Text(chu, style: TextStyle(color: mau, fontWeight: FontWeight.w600, fontSize: 12.5)),
      ],
    ),
  );
}

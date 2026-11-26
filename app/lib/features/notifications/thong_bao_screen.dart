import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../core/signalr_chat.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../rooms/chi_tiet_phong_screen.dart';

/// Hộp thư thông báo của tài khoản đang đăng nhập. Chủ trọ duyệt hoặc từ chối lịch
/// hẹn xem phòng ngay trong mục này nên app không cần màn hình lịch hẹn riêng.
class ThongBaoScreen extends StatefulWidget {
  const ThongBaoScreen({super.key});

  @override
  State<ThongBaoScreen> createState() => _ThongBaoScreenState();
}

class _ThongBaoScreenState extends State<ThongBaoScreen> {
  late Future<_HopThu> _hopThu = _tai();
  StreamSubscription<ThongBaoMoi>? _nhanThongBao;

  // Lịch hẹn đang chờ server trả lời. Vừa chặn bấm đúp (POST thứ hai luôn bị
  // "không còn ở trạng thái chờ") vừa cho nút hiện vòng tải.
  int? _dangGui;

  @override
  void initState() {
    super.initState();
    _nhanThongBao = context.read<SignalRChat>().onThongBao.listen((_) {
      if (mounted) _taiLai();
    });
  }

  @override
  void dispose() {
    _nhanThongBao?.cancel();
    super.dispose();
  }

  Future<_HopThu> _tai() async {
    final json = await context.read<Session>().api.get('api/thong-bao');
    final danhSach = ((json as Map)['danhSach'] as List? ?? const [])
        .map(AppNotification.fromJson)
        .toList();
    return _HopThu(danhSach, (json['soChuaDoc'] as num?)?.toInt() ?? 0);
  }

  void _taiLai() => setState(() => _hopThu = _tai());

  Future<void> _gui(String endpoint, {int? lich, bool baoCao = false}) async {
    if (_dangGui != null) return;
    final session = context.read<Session>();
    setState(() => _dangGui = lich);
    String? loi;
    try {
      final ketQua = await session.api.post(endpoint);
      if (baoCao && ketQua is Map && ketQua['message'] is String && mounted) {
        bao(context: context, message: ketQua['message'] as String);
      }
    } on ApiException catch (e) {
      loi = e.message;
    } finally {
      if (mounted) {
        setState(() => _dangGui = null);
        // Luôn tải lại, kể cả khi server báo lỗi: thẻ đã duyệt mà còn giữ nút
        // thì người dùng tưởng bấm chưa ăn và bấm lại.
        _taiLai();
        if (loi != null) bao(context: context, message: loi, loi: true);
      }
    }
  }

  Future<void> _mo(AppNotification tb) async {
    if (!tb.daDoc) await _gui('api/thong-bao/${tb.id}/da-doc');
    if (!mounted || tb.phongTroId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChiTietPhongScreen(phongId: tb.phongTroId!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Thông báo')),
        actions: [
          IconButton(
            tooltip: context.t('Đánh dấu tất cả đã đọc'),
            onPressed: () => _gui('api/thong-bao/doc-tat-ca'),
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: FutureBuilder<_HopThu>(
        future: _hopThu,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoiView(
              thongBao: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : context.t('Không tải được hộp thư thông báo.'),
              tai: _taiLai,
            );
          }
          if (!snapshot.hasData) return const NangLuongView();
          if (snapshot.data!.danhSach.isEmpty) {
            return TrongView(
              icon: Icons.notifications_none,
              chuThich: context.t('Chưa có thông báo nào. Lịch xem phòng và phản hồi của chủ trọ sẽ xuất hiện ở đây.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: snapshot.data!.danhSach.length,
            itemBuilder: (context, chiSo) => _The(
              tb: snapshot.data!.danhSach[chiSo],
              mo: _mo,
              gui: (endpoint, lich) => _gui(endpoint, lich: lich, baoCao: true),
              dangGui: _dangGui,
            ),
          );
        },
      ),
    );
  }
}

class _The extends StatelessWidget {
  const _The({required this.tb, required this.mo, required this.gui, required this.dangGui});

  final AppNotification tb;
  final Future<void> Function(AppNotification) mo;
  final Future<void> Function(String, int?) gui;
  final int? dangGui;

  IconData get _icon => switch (tb.loai) {
    'DatLichXemPhong' => Icons.event_available_outlined,
    'XacNhanLichXemPhong' => Icons.event_available,
    'TuChoiLichXemPhong' => Icons.event_busy_outlined,
    _ => Icons.notifications_none,
  };

  /// Chủ trọ cần nhìn thấy ngay lịch này mình đã trả lời chưa, nếu không thì
  /// sau khi bấm nút chỉ có một cái flash rồi thẻ trở lại y như cũ.
  Widget? _ketLuan(BuildContext context) {
    if (!tb.laYeuCauXemPhong || tb.conChoDuyet) return null;
    final daDongY = tb.trangThaiLich == 'DaXacNhan';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Icon(
            daDongY ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 18,
            color: daDongY ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            context.t(daDongY ? 'Đã xác nhận' : 'Đã từ chối'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: daDongY ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ketLuan = _ketLuan(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Icon(_icon, color: tb.daDoc ? Colors.blueGrey : NhaCai.mauChuDao),
            title: Text(
              tb.tieuDe,
              style: TextStyle(fontWeight: tb.daDoc ? FontWeight.normal : FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((tb.noiDung ?? '').isNotEmpty) Text(tb.noiDung!),
                const SizedBox(height: 4),
                Text(Fmt.tuNho(tb.ngayTao), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            onTap: () => mo(tb),
          ),
          if (tb.conChoDuyet && tb.maLichXemPhong != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: dangGui == null
                          ? () => gui('api/lich-xem-phong/${tb.maLichXemPhong}/xac-nhan', tb.maLichXemPhong)
                          : null,
                      icon: dangGui == tb.maLichXemPhong
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.how_to_reg_outlined),
                      label: Text(context.t('Xác nhận xem phòng')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: dangGui == null
                          ? () => gui('api/lich-xem-phong/${tb.maLichXemPhong}/tu-choi', tb.maLichXemPhong)
                          : null,
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                      child: Text(context.t('Từ chối')),
                    ),
                  ),
                ],
              ),
            ),
          ?ketLuan,
        ],
      ),
    );
  }
}

/// Chuông ở tab dưới: hiện số thông báo chưa đọc và tự cập nhật khi hub đẩy sự kiện.
class ChuongThongBao extends StatefulWidget {
  const ChuongThongBao({super.key});

  @override
  State<ChuongThongBao> createState() => _ChuongThongBaoState();
}

class _ChuongThongBaoState extends State<ChuongThongBao> {
  int _soChuaDoc = 0;
  StreamSubscription<ThongBaoMoi>? _nhanThongBao;

  @override
  void initState() {
    super.initState();
    _taiSoDong();
    _nhanThongBao = context.read<SignalRChat>().onThongBao.listen((_) {
      if (mounted) _taiSoDong();
    });
  }

  @override
  void dispose() {
    _nhanThongBao?.cancel();
    super.dispose();
  }

  Future<void> _taiSoDong() async {
    try {
      final json = await context.read<Session>().api.get('api/thong-bao/chua-doc');
      if (!mounted) return;
      setState(() => _soChuaDoc = (json as Map)['soChuaDoc'] as int? ?? 0);
    } on ApiException {
      // Mất kết nối: giữ số cũ, người dùng vẫn vào được hộp thư để tải lại.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      count: _soChuaDoc,
      backgroundColor: Colors.red,
      child: const Icon(Icons.notifications_none),
    );
  }
}

class _HopThu {
  const _HopThu(this.danhSach, this.soChuaDoc);

  final List<AppNotification> danhSach;
  final int soChuaDoc;
}

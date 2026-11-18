import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Quản trị tài khoản: tìm kiếm, lọc theo trạng thái CCCD, khóa/mở khóa,
/// duyệt CCCD và xóa người dùng (đúng các thao tác trang Admin của web).
class AdminNguoiDungScreen extends StatefulWidget {
  const AdminNguoiDungScreen({super.key});

  @override
  State<AdminNguoiDungScreen> createState() => _AdminNguoiDungScreenState();
}

class _AdminNguoiDungScreenState extends State<AdminNguoiDungScreen> {
  final _tim = TextEditingController();
  String? _loc;
  late Future<List<AdminUserRow>> _danhSach = _tai();

  @override
  void dispose() {
    _tim.dispose();
    super.dispose();
  }

  Future<List<AdminUserRow>> _tai() {
    final session = context.read<Session>();
    return session.api
        .get(
          'api/admin/nguoi-dung',
          query: {
            if (_tim.text.trim().isNotEmpty) 'timKiem': _tim.text.trim(),
            if (_loc != null) 'locXacThuc': _loc,
          },
        )
        .then((json) => (json as List).map(AdminUserRow.fromJson).toList());
  }

  Future<void> _api(Future<dynamic> Function() goi, {String? thang}) async {
    try {
      final json = await goi();
      if (!mounted) return;
      final tinNhan = json is Map && json['message'] != null
          ? '${json['message']}'
          : (thang ?? context.t('Đã thực hiện.'));
      bao(context: context, message: tinNhan);
      setState(() => _danhSach = _tai());
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    }
  }

  Future<void> _duyetCCCD(AdminUserRow user) async {
    final hanhDong = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${sheetContext.t('CCCD của')} ${user.hoTen}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (user.cccdTruoc != null || user.cccdSau != null)
              SizedBox(
                height: 170,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (user.cccdTruoc != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AnhPhongTro(duongDan: AppConfig.cccd(user.cccdTruoc), height: 170),
                      ),
                    if (user.cccdSau != null)
                      AnhPhongTro(duongDan: AppConfig.cccd(user.cccdSau), height: 170),
                  ],
                ),
              ),
            if ((user.soCCCDQuetDuoc ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('${sheetContext.t('Máy quét đọc được:')} ${user.soCCCDQuetDuoc}'),
              ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(sheetContext.t('Duyệt hồ sơ (chuyển các tin thành VIP miễn phí)')),
              onTap: () => Navigator.pop(sheetContext, 'Duyet'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: Text(sheetContext.t('Từ chối (xóa ảnh CCCD đã tải)')),
              onTap: () => Navigator.pop(sheetContext, 'TuChoi'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (hanhDong == null) return;
    await _api(
      () => context.read<Session>().api.post(
        'api/admin/nguoi-dung/${user.id}/duyet-cccd',
        body: {'hanhDong': hanhDong},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Quản lý người dùng')),
        actions: [IconButton(onPressed: () => setState(() => _danhSach = _tai()), icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tim,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => setState(() => _danhSach = _tai()),
                    decoration: InputDecoration(
                      hintText: context.t('Tìm theo tên hoặc email'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      suffixIcon: _tim.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _tim.clear();
                                setState(() => _danhSach = _tai());
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _loc,
                  hint: Text(context.t('Trạng thái')),
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(context.t('Tất cả'))),
                    for (final trangThai in XacThuc.tatCa)
                      DropdownMenuItem<String?>(value: trangThai, child: Text(context.t(trangThai))),
                  ],
                  onChanged: (value) => setState(() {
                    _loc = value;
                    _danhSach = _tai();
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AdminUserRow>>(
              future: _danhSach,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return LoiView(
                    thongBao: snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : context.t('Không tải được danh sách người dùng.'),
                    tai: () => setState(() => _danhSach = _tai()),
                  );
                }
                if (!snapshot.hasData) return const NangLuongView();
                if (snapshot.data!.isEmpty) {
                  return TrongView(
                    icon: Icons.people_outline,
                    chuThich: context.t('Không có tài khoản nào khớp bộ lọc.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, chiSo) => _HangNguoiDung(
                    user: snapshot.data![chiSo],
                    onKhoa: () => _api(
                      () => context.read<Session>().api.post('api/admin/nguoi-dung/${snapshot.data![chiSo].id}/khoa'),
                    ),
                    onDuyet: () => _duyetCCCD(snapshot.data![chiSo]),
                    onXoa: () async {
                      final user = snapshot.data![chiSo];
                      final chac = await xacNhan(
                        context,
                        hoi:
                            '${context.t('Xóa hẳn tài khoản')} ${user.hoTen}?\n${context.t('Toàn bộ phòng, hóa đơn, tin nhắn và đánh giá của người này cũng bị gỡ.')}',
                        yes: context.t('Xóa'),
                      );
                      if (!chac) return;
                      await _api(
                        () => context.read<Session>().api.delete('api/admin/nguoi-dung/${user.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HangNguoiDung extends StatelessWidget {
  const _HangNguoiDung({required this.user, required this.onKhoa, required this.onDuyet, required this.onXoa});

  final AdminUserRow user;
  final VoidCallback onKhoa;
  final VoidCallback onDuyet;
  final VoidCallback onXoa;

  @override
  Widget build(BuildContext context) {
    final choDuyet = user.trangThaiXacThuc == XacThuc.choDuyet;

    return ExpansionTile(
      leading: Stack(
        children: [
          AnhDaiDien(hoTen: user.hoTen, kichThuoc: 44),
          if (user.trangThaiKhoa)
            Positioned(right: 0, bottom: 0, child: Icon(Icons.lock, size: 16, color: Colors.red.shade700)),
        ],
      ),
      title: Text(user.hoTen, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.email, style: Theme.of(context).textTheme.bodySmall),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _Nhan(text: user.roles.join(', '), mau: NhaCai.mauChuDao),
              _Nhan(text: dem(user.soTinDang, 'tin đăng'), mau: Colors.blueGrey),
              _Nhan(text: Fmt.tien(user.soDu), mau: Colors.teal),
              _Nhan(
                text: context.t(XacThuc.nhan(user.trangThaiXacThuc)),
                mau: choDuyet ? Colors.orange : (XacThuc.xong(user.trangThaiXacThuc) ? Colors.green : Colors.blueGrey),
              ),
            ],
          ),
        ],
      ),
      trailing: user.trangThaiKhoa
          ? Text(context.t('ĐANG KHÓA'),
                style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))
          : null,
      children: [
        ButtonBar(
          children: [
            TextButton(
              onPressed: onKhoa,
              style: TextButton.styleFrom(foregroundColor: user.trangThaiKhoa ? Colors.green : Colors.orange.shade800),
              child: Text(user.trangThaiKhoa ? context.t('Mở khóa') : context.t('Khóa tài khoản')),
            ),
            if (choDuyet)
              FilledButton(onPressed: onDuyet, child: Text(context.t('Duyệt CCCD'))),
            TextButton(
              onPressed: onXoa,
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: Text(context.t('Xóa')),
            ),
          ],
        ),
      ],
    );
  }
}

class _Nhan extends StatelessWidget {
  const _Nhan({required this.text, required this.mau});

  final String text;
  final Color mau;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: mau.withValues(alpha: .12), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: mau, fontSize: 11.5, fontWeight: FontWeight.w600)),
  );
}

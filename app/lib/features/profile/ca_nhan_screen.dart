import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/pick_anh.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';
import '../rooms/phong_da_thue_screen.dart';
import 'cccd_screen.dart';
import 'doi_mat_khau_screen.dart';
import 'sua_ho_so_screen.dart';
import 'vi_screen.dart';

class CaNhanScreen extends StatelessWidget {
  const CaNhanScreen({super.key});

  Future<void> _doiAnhDaiDien(BuildContext context, Session session) async {
    final anh = await PickAnh.one(field: 'file');
    if (anh == null) return;
    try {
      await session.taiAnhDaiDien(anh);
      if (context.mounted) bao(context: context, message: context.t('Đã cập nhật ảnh đại diện.'));
    } on ApiException catch (e) {
      if (context.mounted) bao(context: context, message: e.message, loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.user;
    if (user == null) return TrongView(icon: Icons.person_off_outlined, chuThich: context.t('Chưa đăng nhập.'));

    final trangThaiXacThuc = XacThuc.nhan(user.trangThaiXacThuc);

    return Scaffold(
      appBar: AppBar(title: Text(context.t('Cá nhân'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _doiAnhDaiDien(context, session),
                    child: Stack(
                      children: [
                        AnhDaiDien(tenFile: user.avatar, hoTen: user.hoTen, kichThuoc: 72),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: NhaCai.mauChuDao,
                            child: const Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.hoTen, style: Theme.of(context).textTheme.titleLarge),
                        Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
                        if (user.soDienThoai != null && user.soDienThoai!.isNotEmpty)
                          Text('${context.t('SĐT:')} ${user.soDienThoai}',
                              style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final role in session.roles) _NhanVaiTro(role),
                            _NhanXacThuc(trangThaiXacThuc),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(context.t('Ví của tôi')),
                  subtitle: Text(Fmt.tien(user.soDu)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ViScreen()),
                  ),
                ),
                const Divider(height: 1),
                if (session.laSinhVien)
                  ListTile(
                    leading: const Icon(Icons.meeting_room_outlined),
                    title: Text(context.t('Phòng tôi đã thuê')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PhongDaThueScreen()),
                    ),
                  ),
                if (session.laSinhVien) const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(context.t('CCCD / xác thực danh tính')),
                  subtitle: Text(
                    user.cccdTruoc == null
                        ? context.t('Chưa tải CCCD lên')
                        : '${context.t('Đã tải ảnh, trạng thái:')} $trangThaiXacThuc',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CccdScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(context.t('Sửa thông tin cá nhân')),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SuaHoSoScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(context.t('Đổi mật khẩu')),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoiMatKhauScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.translate),
                  const SizedBox(width: 16),
                  Expanded(child: Text(context.t('Ngôn ngữ giao diện'))),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'vi', label: Text('VI')),
                      ButtonSegment(value: 'en', label: Text('EN')),
                    ],
                    selected: {context.ngonNgu.ma},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => context.read<NgonNgu>().chon(s.first),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final chac = await xacNhan(
                context,
                hoi: context.read<NgonNgu>().d('Đăng xuất khỏi thiết bị này?'),
              );
              if (chac) await session.dangXuat();
            },
            icon: const Icon(Icons.logout),
            label: Text(context.t('Đăng xuất')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Backend: ${AppConfig.baseUrl}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }
}

class _NhanVaiTro extends StatelessWidget {
  const _NhanVaiTro(this.role);

  final String role;

  @override
  Widget build(BuildContext context) {
    final (chu, mau) = switch (role) {
      'Admin' => ('Admin', Colors.purple),
      'ChuTro' => (context.t('Chủ trọ'), Colors.teal),
      'SinhVien' => (context.t('Sinh viên'), NhaCai.mauChuDao),
      _ => (role, Colors.blueGrey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: mau.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
      child: Text(chu, style: TextStyle(color: mau, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _NhanXacThuc extends StatelessWidget {
  const _NhanXacThuc(this.trangThai);

  final String trangThai;

  @override
  Widget build(BuildContext context) {
    final daDuyet = XacThuc.xong(trangThai);
    final mau = daDuyet ? Colors.green : (trangThai == XacThuc.choDuyet ? Colors.orange : Colors.blueGrey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: mau.withValues(alpha: .4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(daDuyet ? Icons.verified : Icons.shield_outlined, size: 14, color: mau),
          const SizedBox(width: 4),
          Text(context.t(trangThai), style: TextStyle(color: mau, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

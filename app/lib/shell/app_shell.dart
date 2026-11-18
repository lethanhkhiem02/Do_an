import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/localization.dart';
import '../core/session.dart';
import '../features/admin/admin_bao_cao_screen.dart';
import '../features/admin/admin_nguoi_dung_screen.dart';
import '../features/chat/danh_sach_tro_chuyen_screen.dart';
import '../features/chat/tro_ly_ao_screen.dart';
import '../features/profile/ca_nhan_screen.dart';
import '../features/profile/vi_screen.dart';
import '../features/rooms/quan_ly_phong_screen.dart';
import '../features/rooms/tim_phong_screen.dart';

/// Khung điều hướng chính: danh sách tab phụ thuộc vai trò của tài khoản đang đăng nhập.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    final tabs = session.laAdmin
        ? const [
              _Tab(Icons.people_outline, 'Người dùng'),
              _Tab(Icons.flag_outlined, 'Báo cáo'),
              _Tab(Icons.person_outline, 'Cá nhân'),
            ]
        : session.laChuTro
        ? const [
              _Tab(Icons.search, 'Tìm trọ'),
              _Tab(Icons.storefront_outlined, 'Phòng của tôi'),
              _Tab(Icons.chat_bubble_outline, 'Tin nhắn'),
              _Tab(Icons.person_outline, 'Cá nhân'),
            ]
        : const [
              _Tab(Icons.search, 'Tìm trọ'),
              _Tab(Icons.chat_bubble_outline, 'Tin nhắn'),
              _Tab(Icons.account_balance_wallet_outlined, 'Ví'),
              _Tab(Icons.person_outline, 'Cá nhân'),
            ];

    final manHinh = [for (final tab in tabs) _manHinhCua(tab.chu)];
    // Đăng xuất/đổi tài khoản có thể khiến số tab thay đổi nên phải kẹp lại chỉ mục.
    final chiSo = _tab < manHinh.length ? _tab : 0;

    return Scaffold(
      body: IndexedStack(index: chiSo, children: manHinh),
      floatingActionButton: FloatingActionButton.small(
        tooltip: context.t('Trợ lý RoomFinder'),
        backgroundColor: Colors.amber.shade400,
        foregroundColor: Colors.black87,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TroLyAoScreen()),
        ),
        child: const Icon(Icons.smart_toy_outlined),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: chiSo,
        onDestinationSelected: (chiSo) => setState(() => _tab = chiSo),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), label: context.t(tab.chu)),
        ],
      ),
    );
  }

  Widget _manHinhCua(String tab) => switch (tab) {
    'Người dùng' => const AdminNguoiDungScreen(),
    'Báo cáo' => const AdminBaoCaoScreen(),
    'Phòng của tôi' => const QuanLyPhongScreen(),
    'Tin nhắn' => const DanhSachTroChuyenScreen(),
    'Ví' => const ViScreen(),
    'Cá nhân' => const CaNhanScreen(),
    _ => const TimPhongScreen(),
  };
}

class _Tab {
  const _Tab(this.icon, this.chu);

  final IconData icon;
  final String chu;
}

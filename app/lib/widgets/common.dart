import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/formatting.dart';
import '../core/localization.dart';

/// Các widget nhỏ dùng lại ở nhiều màn hình.
class NhaCai {
  static const Color mauChuDao = Color(0xFF1565C0);
  static const Color mauVip = Color(0xFFFFB300);
}

class AnhDaiDien extends StatelessWidget {
  const AnhDaiDien({
    super.key,
    this.tenFile,
    this.hoTen,
    this.kichThuoc = 44,
  });

  final String? tenFile;
  final String? hoTen;
  final double kichThuoc;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.avatar(tenFile);
    return CircleAvatar(
      radius: kichThuoc / 2,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: url.isEmpty ? null : NetworkImage(url),
      child: url.isEmpty
          ? Text(
              Fmt.tenHoDem(hoTen ?? 'U'),
              style: TextStyle(
                fontSize: kichThuoc / 2.4,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
          : null,
    );
  }
}

class AnhPhongTro extends StatelessWidget {
  const AnhPhongTro({
    super.key,
    required this.duongDan,
    this.height = 180,
    this.fit = BoxFit.cover,
  });

  final String duongDan;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.media(duongDan);
    if (url.isEmpty) {
      return Container(
        height: height,
        color: Colors.blueGrey.shade100,
        child: Icon(Icons.house_siding_outlined, size: height / 3, color: Colors.blueGrey),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: fit,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _Placeholder(height: height, child: const CircularProgressIndicator()),
        errorBuilder: (context, error, stack) =>
            _Placeholder(height: height, child: const Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    alignment: Alignment.center,
    color: Colors.blueGrey.shade100,
    child: child,
  );
}

class NangLuongView extends StatelessWidget {
  const NangLuongView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
}

class LoiView extends StatelessWidget {
  const LoiView({super.key, required this.thongBao, this.tai});

  final String thongBao;
  final VoidCallback? tai;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 44, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(thongBao, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          if (tai != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: tai, child: Text(context.t('Thử lại'))),
          ],
        ],
      ),
    ),
  );
}

class TrongView extends StatelessWidget {
  const TrongView({super.key, required this.icon, required this.chuThich, this.hanhDong});

  final IconData icon;
  final String chuThich;
  final Widget? hanhDong;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.blueGrey.shade300),
          const SizedBox(height: 12),
          Text(chuThich, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          if (hanhDong != null) ...[const SizedBox(height: 16), hanhDong!],
        ],
      ),
    ),
  );
}

/// Nhãn trạng thái phòng (Còn trống / Đang được giữ / Đã cho thuê / Hết hạn).
class NhanTrangThai extends StatelessWidget {
  const NhanTrangThai({super.key, required this.trangThai});

  final String trangThai;

  @override
  Widget build(BuildContext context) {
    final (mau, chu) = switch (trangThai) {
      'DaChoThue' => (Colors.green, context.t('Đã cho thuê')),
      'DangGiuCho' => (Colors.orange, context.t('Đang giữ chỗ')),
      'HetHienThi' => (Colors.blueGrey, context.t('Tạm ẩn (hết hạn đăng)')),
      _ => (NhaCai.mauChuDao, context.t('Còn trống')),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: mau.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(chu, style: TextStyle(color: mau, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

void bao({required BuildContext context, required String message, bool loi = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: loi ? Colors.red.shade700 : null,
      ),
    );
}

Future<bool> xacNhan(BuildContext context, {required String hoi, String yes = 'Đồng ý', String no = 'Hủy'}) async {
  final ketQua = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(hoi),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t(no))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.t(yes))),
      ],
    ),
  );
  return ketQua ?? false;
}

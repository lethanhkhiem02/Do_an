import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/formatting.dart';
import '../core/localization.dart';
import '../core/session.dart';
import '../models/models.dart';
import 'ban_do.dart';
import 'common.dart';

/// Tab "Tiện ích xung quanh" của màn chi tiết phòng: bản đồ khoanh vùng đúng
/// bán kính server đã quét, các chốt tiện ích và danh sách chia theo nhóm.
///
/// Số liệu đọc từ bảng TienIchXungQuanh nên mở tab tức thì; chỉ chủ trọ bấm
/// quét lại, và một lần quét mất gần một phút vì server phải hỏi OpenStreetMap.
class TienIchXungQuanh extends StatefulWidget {
  const TienIchXungQuanh({super.key, required this.phong, required this.duocQuet});

  final Room phong;

  /// Chủ trọ hoặc Admin thì mới thấy nút quét lại.
  final bool duocQuet;

  @override
  State<TienIchXungQuanh> createState() => _TienIchXungQuanhState();
}

class _TienIchXungQuanhState extends State<TienIchXungQuanh> {
  AmenityPage? _page;
  bool _dangQuet = false;
  String? _loi;

  Room get _phong => widget.phong;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    try {
      final json = await context.read<Session>().api.get('api/phong-tro/${_phong.id}/tien-ich');
      if (mounted) setState(() => _page = AmenityPage.fromJson(json));
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    }
  }

  Future<void> _quet() async {
    if (_dangQuet) return;
    setState(() {
      _dangQuet = true;
      _loi = null;
    });
    try {
      final json = await context.read<Session>().api.post(
        'api/phong-tro/${_phong.id}/tien-ich/quet',
        // Overpass trả lời chậm (~45 giây đo thực tế) nên phải thả thời gian chờ
        // rộng hơn nhiều so với mức 25 giây dùng cho các request thường.
        timeout: const Duration(seconds: 100),
      );
      final page = AmenityPage.fromJson(json);
      if (!mounted) return;
      setState(() => _page = page);
      bao(
        context: context,
        message: '${context.t('Đã quét lại')} · ${dem(page.tienIch.length, 'tiện ích')}.',
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _loi = e.message);
    } finally {
      if (mounted) setState(() => _dangQuet = false);
    }
  }

  void _chiTietTienIch(Amenity t) {
    final ten = (t.ten == null || t.ten!.trim().isEmpty) ? context.t('Không có tên') : t.ten!;
    bao(context: context, message: '${t.tenLoai}: $ten · ${t.khoangCach}');
  }

  @override
  Widget build(BuildContext context) {
    if (_phong.latitude == null || _phong.longitude == null) {
      return _Trong(
        bieuTuong: Icons.location_off_outlined,
        thongBao: context.t(
          'Phòng này chưa có vị trí trên bản đồ nên chưa quét được tiện ích xung quanh.',
        ),
      );
    }

    final page = _page;
    final coTienIch = page != null && page.tienIch.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (_loi != null)
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: Icon(Icons.error_outline, color: Colors.red.shade700),
              title: Text(_loi!),
              trailing: IconButton(onPressed: _tai, tooltip: context.t('Thử lại'), icon: const Icon(Icons.refresh)),
            ),
          ),
        _ThanhTieuDe(page: page, duocQuet: widget.duocQuet, dangQuet: _dangQuet, onQuet: _quet),
        const SizedBox(height: 12),
        BanDo(
          diem: [DiemDo(phong: _phong, viDo: _phong.latitude!, kinhDo: _phong.longitude!)],
          height: 280,
          zoom: 14,
          vongTronMet: coTienIch ? page.banKinhMet.toDouble() : null,
          tienIch: page?.tienIch ?? const [],
          onChonTienIch: _chiTietTienIch,
        ),
        const SizedBox(height: 12),
        if (_dangQuet)
          _DangQuet()
        else if (page == null)
          const NangLuongView()
        else if (!page.daQuet)
          _Trong(
            bieuTuong: Icons.wifi_tethering_rounded,
            thongBao: widget.duocQuet
                ? context.t('Bài đăng này chưa quét tiện ích. Bấm Quét lại để tìm trạm xe buýt, siêu thị, quán cà phê, cây xăng và cửa hàng tiện lợi gần phòng.')
                : context.t('Chủ trọ chưa quét tiện ích xung quanh phòng này.'),
          )
        else if (!coTienIch)
          _Trong(
            bieuTuong: Icons.search_off,
            thongBao: context.t('Không tìm thấy tiện ích nào trong bán kính quanh phòng này.'),
          )
        else
          _DanhSachNhom(page: page),
      ],
    );
  }
}

class _ThanhTieuDe extends StatelessWidget {
  const _ThanhTieuDe({
    required this.page,
    required this.duocQuet,
    required this.dangQuet,
    required this.onQuet,
  });

  final AmenityPage? page;
  final bool duocQuet;
  final bool dangQuet;
  final Future<void> Function() onQuet;

  @override
  Widget build(BuildContext context) {
    final tienIch = page?.tienIch ?? const <Amenity>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.t('Khoanh vùng tiện ích gần phòng'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (duocQuet)
              OutlinedButton.icon(
                onPressed: dangQuet ? null : onQuet,
                icon: dangQuet
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.radar),
                label: Text(dangQuet ? context.t('Đang quét...') : context.t('Quét lại')),
              ),
          ],
        ),
        if (tienIch.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '${dem(tienIch.length, 'tiện ích')} · ${context.t('bán kính')} ${Fmt.km((page?.banKinhMet ?? 0) / 1000)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (page?.quetNgay != null)
            Text(
              '${context.t('Quét lúc')} ${Fmt.ngay(page!.quetNgay)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

class _DangQuet extends StatelessWidget {
  const _DangQuet();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.t('Đang hỏi bản đồ OpenStreetMap, việc này mất khoảng một phút...'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _Trong extends StatelessWidget {
  const _Trong({required this.bieuTuong, required this.thongBao});

  final IconData bieuTuong;
  final String thongBao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Icon(bieuTuong, size: 46, color: Colors.blueGrey.shade300),
          const SizedBox(height: 12),
          Text(thongBao, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Danh sách chia theo 5 nhóm cố định, luôn hiện cả nhóm trống để sinh viên biết
/// app đã quét loại đó chứ không phải chưa tìm.
class _DanhSachNhom extends StatelessWidget {
  const _DanhSachNhom({required this.page});

  final AmenityPage page;

  @override
  Widget build(BuildContext context) {
    final theoNhom = <String, List<Amenity>>{};
    for (final t in page.tienIch) {
      theoNhom.putIfAbsent(t.loai, () => []).add(t);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final nhom in cacNhomTienIch)
          if ((theoNhom[nhom] ?? const []).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(nhanDienTienIch(nhom).bieuTuong, size: 18, color: Colors.blueGrey.shade300),
                  const SizedBox(width: 10),
                  Text(
                    tenNhomTienIch(nhom),
                    style: TextStyle(color: Colors.blueGrey.shade400, decoration: TextDecoration.lineThrough),
                  ),
                ],
              ),
            )
          else
            _NhomTienIch(tenNhom: nhom, danhSach: theoNhom[nhom]!),
      ],
    );
  }
}

class _NhomTienIch extends StatelessWidget {
  const _NhomTienIch({required this.tenNhom, required this.danhSach});

  final String tenNhom;
  final List<Amenity> danhSach;

  @override
  Widget build(BuildContext context) {
    final nhanDien = nhanDienTienIch(tenNhom);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Icon(nhanDien.bieuTuong, size: 18, color: nhanDien.mau),
              const SizedBox(width: 8),
              Text(
                '${tenNhomTienIch(tenNhom)} (${danhSach.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: nhanDien.mau),
              ),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final t in danhSach)
                ListTile(
                  dense: true,
                  leading: Text(
                    t.khoangCach,
                    style: TextStyle(color: nhanDien.mau, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  title: Text(
                    (t.ten == null || t.ten!.trim().isEmpty) ? context.t('Không có tên') : t.ten!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

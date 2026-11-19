import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../core/localization.dart';
import '../models/models.dart';
import 'common.dart';

/// Thẻ phòng dùng chung cho màn tìm trọ, phòng của chủ trọ và phòng đã thuê.
class PhongCard extends StatelessWidget {
  const PhongCard({
    super.key,
    required this.phong,
    this.onTap,
    this.footer,
    this.hienKhoangCach = true,
  });

  final Room phong;
  final VoidCallback? onTap;
  final Widget? footer;
  final bool hienKhoangCach;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _DanAnh(anh: phong.anh),
                if (phong.isVip)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: const _NhanVip(),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: NhanTrangThai(trangThai: phong.trangThai),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Fmt.tien(phong.gia),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: NhaCai.mauChuDao),
                        ),
                      ),
                      if (phong.trungBinhSao > 0)
                        Text(Fmt.sao(phong.trungBinhSao, phong.soDanhGia),
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(phong.moTa, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          phong.diaChi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                        ),
                      ),
                      if (hienKhoangCach && phong.khoangCach > 0)
                        Text(Fmt.km(phong.khoangCach),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Teu(
                        phong.laKyTucXa ? Icons.apartment_outlined : Icons.home_outlined,
                        phong.tenLoaiHinh,
                      ),
                      if (phong.dienTich != null) _Teu(Icons.straighten, '${Fmt.soThapPhan(phong.dienTich)} m²'),
                      if (phong.coNhaVeSinh) _Teu(Icons.bathtub_outlined, context.t('Vệ sinh riêng')),
                      if (phong.coBanCong) _Teu(Icons.security_outlined, context.t('Có ban công')),
                      if (phong.tenChuTro != null) _Teu(Icons.person_outline, phong.tenChuTro!),
                    ],
                  ),
                ],
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

class _DanAnh extends StatefulWidget {
  const _DanAnh({required this.anh});

  final List<String> anh;

  @override
  State<_DanAnh> createState() => _DanAnhState();
}

class _DanAnhState extends State<_DanAnh> {
  final _controller = PageController();
  int _hienTai = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.anh.isEmpty) return const AnhPhongTro(duongDan: '');
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.anh.length,
            onPageChanged: (chiSo) => setState(() => _hienTai = chiSo),
            itemBuilder: (context, chiSo) => AnhPhongTro(duongDan: widget.anh[chiSo], height: 180),
          ),
        ),
        if (widget.anh.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.anh.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _hienTai ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _hienTai ? NhaCai.mauChuDao : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NhanVip extends StatelessWidget {
  const _NhanVip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: NhaCai.mauVip, borderRadius: BorderRadius.circular(6)),
    child: const Text(
      'VIP',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
    ),
  );
}

class _Teu extends StatelessWidget {
  const _Teu(this.icon, this.chu);

  final IconData icon;
  final String chu;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.blueGrey.shade50,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.blueGrey.shade700),
        const SizedBox(width: 4),
        Text(chu, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800)),
      ],
    ),
  );
}

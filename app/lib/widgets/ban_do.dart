import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import 'common.dart';

class DiemDo {
  const DiemDo({required this.phong, required this.viDo, required this.kinhDo});

  final Room phong;
  final double viDo;
  final double kinhDo;
}

/// Biểu tượng + màu nhận diện cho từng nhóm tiện ích, dùng chung giữa bản đồ
/// và danh sách trong tab "Tiện ích xung quanh".
({IconData bieuTuong, Color mau}) nhanDienTienIch(String loai) => switch (loai) {
  'bus_stop' => (bieuTuong: Icons.directions_bus_filled, mau: Colors.blue.shade700),
  'supermarket' => (bieuTuong: Icons.local_mall, mau: Colors.purple.shade700),
  'cafe' => (bieuTuong: Icons.local_cafe, mau: Colors.brown.shade700),
  'fuel' => (bieuTuong: Icons.local_gas_station, mau: Colors.red.shade700),
  'convenience' => (bieuTuong: Icons.local_convenience_store, mau: Colors.teal.shade700),
  _ => (bieuTuong: Icons.place, mau: Colors.blueGrey),
};

/// Bản đồ OpenStreetMap - cùng nguồn tile mà trang web đồ án cơ sở hiển thị.
///
/// Vẽ thêm được vòng tròn khoanh vùng bán kính (mét) quanh điểm đầu tiên và
/// các chốt tiện ích, nên tab "Tiện ích xung quanh" dùng lại đúng widget này.
class BanDo extends StatelessWidget {
  const BanDo({
    super.key,
    required this.diem,
    this.tieuDiem,
    this.zoom = 13,
    this.height = 240,
    this.onChon,
    this.vongTronMet,
    this.tienIch = const [],
    this.onChonTienIch,
  });

  final List<DiemDo> diem;
  final LatLng? tieuDiem;
  final double zoom;
  final double height;
  final ValueChanged<Room>? onChon;

  /// Bán kính vòng khoanh vùng tính bằng mét quanh điểm đầu của [diem]; null là không vẽ.
  final double? vongTronMet;
  final List<Amenity> tienIch;
  final ValueChanged<Amenity>? onChonTienIch;

  @override
  Widget build(BuildContext context) {
    final trungTam = tieuDiem ??
        (diem.isNotEmpty ? LatLng(diem.first.viDo, diem.first.kinhDo) : LatLng(10.7769, 106.7009));

    // Khi có vòng khoanh vùng + chốt tiện ích thì tự thụt máy quay ra cho vừa
    // hết mọi thứ, thay vì bắt người dùng kéo zoom thủ công.
    final canFit = vongTronMet != null && tienIch.isNotEmpty;
    final diemCanFit = <LatLng>[
      trungTam,
      for (final t in tienIch) LatLng(t.viDo, t.kinhDo),
    ];

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: trungTam,
            initialZoom: zoom,
            initialCameraFit: canFit
                ? CameraFit.coordinates(
                    coordinates: diemCanFit,
                    padding: const EdgeInsets.all(28),
                    maxZoom: 16,
                  )
                : null,
            onTap: (_, _) {
              if (diem.length == 1 && onChon != null) onChon!(diem.first.phong);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'vn.edu.roomfinder.app',
              maxZoom: 19,
            ),
            if (vongTronMet != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: trungTam,
                    useRadiusInMeter: true,
                    radius: vongTronMet!,
                    color: NhaCai.mauChuDao.withValues(alpha: 0.12),
                    borderColor: NhaCai.mauChuDao.withValues(alpha: 0.7),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            if (tienIch.isNotEmpty)
              MarkerLayer(
                markers: [
                  for (final t in tienIch)
                    Marker(
                      point: LatLng(t.viDo, t.kinhDo),
                      // 26 px avatar + 14 px mũi tên, khai báo tường minh vì
                      // flutter_map cắt child đúng theo kích thước này.
                      width: 34,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: onChonTienIch == null ? null : () => onChonTienIch!(t),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: nhanDienTienIch(t.loai).mau,
                              child: Icon(
                                nhanDienTienIch(t.loai).bieuTuong,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                            Icon(Icons.arrow_drop_up, size: 14, color: nhanDienTienIch(t.loai).mau),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (tieuDiem != null)
                  Marker(
                    point: tieuDiem!,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.school, color: Colors.purple, size: 34),
                  ),
                for (final item in diem)
                  Marker(
                    point: LatLng(item.viDo, item.kinhDo),
                    width: 40,
                    height: 40,
                    child: IconButton(
                      onPressed: onChon == null ? null : () => onChon!(item.phong),
                      icon: Icon(
                        Icons.home_work,
                        color: item.phong.isVip ? Colors.amber.shade700 : NhaCai.mauChuDao,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

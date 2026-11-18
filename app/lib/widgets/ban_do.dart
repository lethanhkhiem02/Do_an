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

/// Bản đồ OpenStreetMap - cùng nguồn tile mà trang web đồ án cơ sở hiển thị.
class BanDo extends StatelessWidget {
  const BanDo({
    super.key,
    required this.diem,
    this.tieuDiem,
    this.zoom = 13,
    this.height = 240,
    this.onChon,
  });

  final List<DiemDo> diem;
  final LatLng? tieuDiem;
  final double zoom;
  final double height;
  final ValueChanged<Room>? onChon;

  @override
  Widget build(BuildContext context) {
    final trungTam = tieuDiem ??
        (diem.isNotEmpty ? LatLng(diem.first.viDo, diem.first.kinhDo) : LatLng(10.7769, 106.7009));

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: trungTam,
            initialZoom: zoom,
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/pick_anh.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

/// Chủ trọ đăng phòng mới: giống form Create của web nhưng thêm chọn vị trí trên bản đồ.
class DangPhongScreen extends StatefulWidget {
  const DangPhongScreen({super.key});

  @override
  State<DangPhongScreen> createState() => _DangPhongScreenState();
}

class _DangPhongScreenState extends State<DangPhongScreen> {
  static const List<int> _mocNgayDang = [7, 15, 30, 60, 90];
  static const List<int> _mocNgayGiu = [3, 5, 7, 10, 15];

  final _form = GlobalKey<FormState>();
  final _moTa = TextEditingController();
  final _gia = TextEditingController();
  final _diaChi = TextEditingController();
  final _chieuDai = TextEditingController();
  final _chieuRong = TextEditingController();

  bool _nhaVeSinh = false;
  bool _banCong = false;
  bool _vip = false;
  int _ngayDang = 30;
  int _ngayGiu = 7;
  LatLng? _viTri;
  List<_AnhChon> _anh = [];
  bool _dangGui = false;

  @override
  void dispose() {
    _moTa.dispose();
    _gia.dispose();
    _diaChi.dispose();
    _chieuDai.dispose();
    _chieuRong.dispose();
    super.dispose();
  }

  Future<void> _chonAnh() async {
    final danhSach = await PickAnh.many(field: 'images', max: 6);
    if (danhSach.isEmpty) return;
    setState(() => _anh = [..._anh, ...danhSach.map((f) => _AnhChon(f))]);
  }

  Future<void> _chonViTri() async {
    final diem = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChonViTriSheet(banDau: _viTri),
    );
    if (diem != null && mounted) setState(() => _viTri = diem);
  }

  Future<void> _gui() async {
    if (!_form.currentState!.validate() || _dangGui) return;
    setState(() => _dangGui = true);

    final session = context.read<Session>();
    try {
      await session.api.upload(
        'api/phong-tro',
        fields: {
          'moTa': _moTa.text.trim(),
          'gia': _soHoa(_gia.text)!.toString(),
          'diaChi': _diaChi.text.trim(),
          'isVip': _vip.toString(),
          'coNhaVeSinh': _nhaVeSinh.toString(),
          'coBanCong': _banCong.toString(),
          'soNgayDangBai': '$_ngayDang',
          'soNgayGiuPhong': '$_ngayGiu',
          if (_soHoa(_chieuDai.text) != null) 'chieuDai': '${_soHoa(_chieuDai.text)}',
          if (_soHoa(_chieuRong.text) != null) 'chieuRong': '${_soHoa(_chieuRong.text)}',
          if (_viTri != null) 'latitude': '${_viTri!.latitude}',
          if (_viTri != null) 'longitude': '${_viTri!.longitude}',
        },
        files: [for (final item in _anh) item.file],
      );
      if (!mounted) return;
      bao(
        context: context,
        message: _vip
            ? context.t('Đã đăng tin VIP, hệ thống trừ 50.000đ trong ví của bạn.')
            : context.t('Đã đăng phòng thành công, phòng xuất hiện ở trang chủ.'),
      );
      Navigator.pop(context);
      session.lamMoiHoSo(baoLoi: false); // cập nhật số dư ví sau khi trừ tiền VIP
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  static double? _soHoa(String text) => double.tryParse(text.replaceAll('.', '').replaceAll(',', ''));

  @override
  Widget build(BuildContext context) {
    final soDu = context.watch<Session>().user?.soDu ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('Đăng phòng trọ mới'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(context.t('Ảnh phòng'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _anh.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_anh[i].file.bytes, width: 90, height: 90, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          iconSize: 18,
                          onPressed: () => setState(() => _anh.removeAt(i)),
                          icon: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                if (_anh.length < 6)
                  OutlinedButton.icon(
                    onPressed: _chonAnh,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(_anh.isEmpty ? context.t('Chọn ảnh') : context.t('Thêm ảnh')),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _moTa,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.t('Mô tả phòng (tiêu đề tin đăng)'),
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value ?? '').trim().length < 10 ? context.t('Mô tả tối thiểu 10 ký tự') : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _gia,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.t('Giá thuê / tháng (VNĐ)'),
                border: const OutlineInputBorder(),
                helperText: context.t('Ví dụ: 2500000'),
              ),
              validator: (value) => _soHoa(value ?? '') == null || _soHoa(value!) == 0
                  ? context.t('Nhập giá phòng hợp lệ')
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _diaChi,
              decoration: InputDecoration(
                labelText: context.t('Địa chỉ'),
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value ?? '').trim().length < 5 ? context.t('Nhập địa chỉ cụ thể') : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _chieuDai,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.t('Chiều dài (m)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _chieuRong,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.t('Chiều rộng (m)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _nhaVeSinh,
              onChanged: (value) => setState(() => _nhaVeSinh = value),
              title: Text(context.t('Có vệ sinh riêng')),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _banCong,
              onChanged: (value) => setState(() => _banCong = value),
              title: Text(context.t('Có ban công')),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _vip,
              onChanged: (value) => setState(() => _vip = value),
              title: Text(context.t('Đăng tin VIP (ưu tiên đầu trang)')),
              subtitle: Text('${context.t('Trừ 50.000đ trong ví, hiện có')} ${Fmt.tien(soDu)}'),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: NhaCai.mauVip,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _ngayDang,
              decoration: InputDecoration(
                labelText: context.t('Số ngày hiển thị tin'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final ngay in _mocNgayDang)
                  DropdownMenuItem(value: ngay, child: Text(dem(ngay, 'ngày')))
              ],
              onChanged: (value) => setState(() => _ngayDang = value ?? 30),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _ngayGiu,
              decoration: InputDecoration(
                labelText: context.t('Số ngày giữ chỗ khi đặt cọc'),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final ngay in _mocNgayGiu)
                  DropdownMenuItem(value: ngay, child: Text(dem(ngay, 'ngày')))
              ],
              onChanged: (value) => setState(() => _ngayGiu = value ?? 7),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _chonViTri,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _viTri == null
                    ? context.t('Chọn vị trí phòng trên bản đồ (không bắt buộc)')
                    : '${context.t('Vị trí')}: ${_viTri!.latitude.toStringAsFixed(5)}, ${_viTri!.longitude.toStringAsFixed(5)}',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _dangGui ? null : _gui,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(_dangGui ? context.t('Đang đăng tin...') : context.t('Đăng phòng')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnhChon {
  _AnhChon(this.file);

  final UploadFile file;
}

class _ChonViTriSheet extends StatefulWidget {
  const _ChonViTriSheet({this.banDau});

  final LatLng? banDau;

  @override
  State<_ChonViTriSheet> createState() => _ChonViTriSheetState();
}

class _ChonViTriSheetState extends State<_ChonViTriSheet> {
  late LatLng _diem = widget.banDau ?? LatLng(10.7769, 106.7009);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          children: [
            Text(context.t('Chạm vào bản đồ để đặt vị trí phòng'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _diem,
                    initialZoom: 15,
                    onTap: (_, viTri) => setState(() => _diem = viTri),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'vn.edu.roomfinder.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _diem,
                          width: 50,
                          height: 50,
                          child: const Icon(Icons.location_searching, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('${_diem.latitude.toStringAsFixed(6)}, ${_diem.longitude.toStringAsFixed(6)}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.t('Không chọn')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _diem),
                    child: Text(context.t('Chọn vị trí này')),
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

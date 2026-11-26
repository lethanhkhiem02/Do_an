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
  final _giaDien = TextEditingController();
  final _giaNuoc = TextEditingController();
  final _diaChi = TextEditingController();
  final _chieuDai = TextEditingController();
  final _chieuRong = TextEditingController();

  bool _nhaVeSinh = false;
  bool _banCong = false;
  bool _vip = false;

  /// 'PhongRieng' / 'KyTucXa', đúng tên enum LoaiHinhPhong backend nhận qua field `loaiHinh`.
  String _loaiHinh = 'PhongRieng';
  int _ngayDang = 30;
  int _ngayGiu = 7;
  LatLng? _viTri;
  List<_AnhChon> _anh = [];
  bool _dangGui = false;

  /// Bài đăng vừa tạo xong đang chờ server quét tiện ích (mất gần một phút).
  bool _dangQuetTienIch = false;

  @override
  void dispose() {
    _moTa.dispose();
    _gia.dispose();
    _giaDien.dispose();
    _giaNuoc.dispose();
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
      final tao = await session.api.upload(
        'api/phong-tro',
        fields: {
          'moTa': _moTa.text.trim(),
          'gia': _soHoa(_gia.text)!.toString(),
          'giaDien': _soHoa(_giaDien.text)!.toString(),
          'giaNuoc': _soHoa(_giaNuoc.text)!.toString(),
          'diaChi': _diaChi.text.trim(),
          'loaiHinh': _loaiHinh,
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

      final phongId = tao is Map ? (tao['id'] as num?)?.toInt() : null;

      // Quét tiện ích ngay lúc đăng (thay vì để sinh viên chờ khi mở phòng).
      // Lỗi quét không được làm hỏng bài đăng đã tạo, nên chỉ nuốt exception.
      int? soTienIch;
      if (phongId != null && _viTri != null) {
        setState(() => _dangQuetTienIch = true);
        try {
          final ketQua = await session.api.post(
            'api/phong-tro/$phongId/tien-ich/quet',
            timeout: const Duration(seconds: 100),
          );
          if (ketQua is Map) soTienIch = (ketQua['tienIch'] as List?)?.length;
        } on ApiException {
          // Overpass đang bảo trì: chủ trọ vẫn quét lại được trong tab tiện ích.
        } finally {
          if (mounted) setState(() => _dangQuetTienIch = false);
        }
      }

      if (!mounted) return;
      bao(
        context: context,
        message: _vip
            ? context.t('Đã đăng tin VIP, hệ thống trừ 50.000đ trong ví của bạn.')
            : soTienIch != null
            // Nối từng cụm đã dịch sẵn thay vì đưa cả câu có số vào từ điển,
            // vì từ điển tra theo đúng chuỗi tiếng Việt gốc.
            ? '${context.t('Đã đăng phòng, tìm được')} ${dem(soTienIch, 'tiện ích')} ${context.t('xung quanh phòng')}.'
            : context.t('Đã đăng phòng thành công, phòng xuất hiện ở trang chủ.'),
      );
      Navigator.pop(context);
      session.lamMoiHoSo(baoLoi: false); // cập nhật số dư ví sau khi trừ tiền VIP
    } on ApiException catch (e) {
      if (!mounted) return;
      final msgLower = e.message.toLowerCase();
      if (msgLower.contains('trùng') || msgLower.contains('duplicate') || msgLower.contains('tương đồng') || msgLower.contains('hủy đăng')) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.cancel_outlined, size: 52, color: Colors.red),
            title: Text(
              context.t('Hệ thống đã hủy đăng bài!'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Hệ thống kiểm duyệt hình ảnh tự động đã phát hiện ảnh vi phạm và hủy đăng bài:'),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.report_problem_outlined, size: 20, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.message,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.t('Vui lòng kiểm tra lại danh sách ảnh bên dưới, xóa bỏ ảnh bị trùng lặp hoặc chụp lại ảnh thực tế mới của phòng trọ để tiếp tục đăng bài.'),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.t('Đã hiểu, tôi sẽ chọn ảnh khác')),
              ),
            ],
          ),
        );
      } else {
        bao(context: context, message: e.message, loi: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _dangGui = false;
          _dangQuetTienIch = false;
        });
      }
    }
  }

  static double? _soHoa(String text) => double.tryParse(text.replaceAll('.', '').replaceAll(',', ''));

  /// Đơn giá điện/nước bắt buộc nhập và phải nằm trong khoảng server cho phép
  /// (Range của CreateRoomRequest), để chủ trọ biết lỗi ngay thay vì bị API từ chối.
  String? _validateDonGia(String? value, double max, String maLoiTrong, String maLoiVuot) {
    final so = _soHoa(value ?? '');
    if (so == null || so <= 0) return context.t(maLoiTrong);
    if (so > max) return context.t(maLoiVuot);
    return null;
  }

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _giaDien,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.t('Giá điện (VNĐ/kWh)'),
                      border: const OutlineInputBorder(),
                      helperText: context.t('Ví dụ: 3500'),
                    ),
                    validator: (value) => _validateDonGia(
                      value,
                      100000,
                      'Nhập giá điện lớn hơn 0',
                      'Giá điện không được vượt quá 100.000 VNĐ/kWh',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _giaNuoc,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.t('Giá nước (VNĐ/m³)'),
                      border: const OutlineInputBorder(),
                      helperText: context.t('Ví dụ: 20000'),
                    ),
                    validator: (value) => _validateDonGia(
                      value,
                      1000000,
                      'Nhập giá nước lớn hơn 0',
                      'Giá nước không được vượt quá 1.000.000 VNĐ/m³',
                    ),
                  ),
                ),
              ],
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
            Text(context.t('Loại hình phòng'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'PhongRieng',
                  icon: const Icon(Icons.home_outlined),
                  label: Text(context.t('Phòng riêng')),
                ),
                ButtonSegment(
                  value: 'KyTucXa',
                  icon: const Icon(Icons.apartment_outlined),
                  label: Text(context.t('Ký túc xá')),
                ),
              ],
              selected: {_loaiHinh},
              showSelectedIcon: false,
              onSelectionChanged: (value) => setState(() => _loaiHinh = value.first),
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
            if (_viTri == null) ...[
              const SizedBox(height: 6),
              Text(
                context.t(
                  'Chọn vị trí để hệ thống tự tìm trạm xe buýt, siêu thị, quán cà phê, cây xăng và cửa hàng tiện lợi xung quanh phòng.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _dangGui ? null : _gui,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(
                _dangQuetTienIch
                    ? context.t('Đang quét tiện ích xung quanh...')
                    : _dangGui
                    ? context.t('Đang đăng tin...')
                    : context.t('Đăng phòng'),
              ),
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

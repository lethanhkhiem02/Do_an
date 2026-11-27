import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/dich.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/ban_do.dart';
import '../../widgets/common.dart';
import '../../widgets/room_card.dart';
import 'chi_tiet_phong_screen.dart';

/// Màn hình tìm trọ: lọc theo trường đại học + bán kính, khoảng giá và cách sắp xếp.
/// Gọi đúng API /api/phong-tro/tim-kiem mà trang web đang dùng.
class TimPhongScreen extends StatefulWidget {
  const TimPhongScreen({super.key});

  @override
  State<TimPhongScreen> createState() => _TimPhongScreenState();
}

class _BoLoc {
  _BoLoc({
    required this.truongId,
    required this.banKinh,
    required this.min,
    required this.max,
    required this.sapXep,
    this.loaiHinh,
  });

  final String? truongId;
  final double banKinh;
  final String min;
  final String max;
  final String sapXep;

  /// null là "Tất cả"; ngược lại là 'PhongRieng' / 'KyTucXa' đúng như enum
  /// LoaiHinhPhong của backend nhận qua query `loaiHinh`.
  final String? loaiHinh;

  bool get coBoLoc =>
      truongId != null ||
      min.trim().isNotEmpty ||
      max.trim().isNotEmpty ||
      loaiHinh != null;

  static double? _soHoa(String text) => double.tryParse(text.replaceAll('.', '').replaceAll(',', ''));

  /// Chỉ có loại hình đổi được ngay trên danh sách (bằng chip), nên copyWith
  /// bắt buộc nêu rõ giá trị mới, kể cả null để bỏ lọc.
  _BoLoc copyWith({required String? loaiHinh}) => _BoLoc(
    truongId: truongId,
    banKinh: banKinh,
    min: min,
    max: max,
    sapXep: sapXep,
    loaiHinh: loaiHinh,
  );

  Map<String, dynamic> toJson() => {
    if (truongId != null) 'truongId': truongId,
    if (truongId != null) 'radius': banKinh,
    if (_soHoa(min) != null) 'minPrice': _soHoa(min),
    if (_soHoa(max) != null) 'maxPrice': _soHoa(max),
    if (loaiHinh != null) 'loaiHinh': loaiHinh,
    'sortBy': sapXep,
  };
}

class _TimPhongScreenState extends State<TimPhongScreen> {
  static const List<(String, String)> _cachSapXep = [
    ('distance_asc', 'Gần trường nhất'),
    ('price_asc', 'Giá thấp → cao'),
    ('price_desc', 'Giá cao → thấp'),
    ('rating_desc', 'Đánh giá cao nhất'),
    ('newest', 'Mới đăng nhất'),
  ];

  static const List<String> _goiYAi = [
    'Phòng Thủ Đức dưới 3tr',
    'Phòng riêng có ban công, vệ sinh riêng',
    'Ký túc xá giá rẻ',
    'Phòng Bình Thạnh có máy lạnh, gác lửng',
  ];

  final TextEditingController _aiCtrl = TextEditingController();

  List<School> _truongs = const [];
  _BoLoc _loc = _BoLoc(truongId: null, banKinh: 3, min: '', max: '', sapXep: 'newest');

  List<Room> _ketQua = const [];
  String? _tenTruongTim;
  bool _dangTai = true;
  bool _dangTimAi = false;
  bool _daTimAi = false;
  List<String> _tieuChiAi = const [];
  String? _thongBaoAi;
  String? _loi;
  bool _xemBanDo = false;

  @override
  void initState() {
    super.initState();
    _khoiDong();
  }

  @override
  void dispose() {
    _aiCtrl.dispose();
    super.dispose();
  }

  Future<void> _khoiDong() async {
    final session = context.read<Session>();
    try {
      final truong = await session.api.get('api/phong-tro/truong');
      _truongs = (truong as List).map(School.fromJson).toList();
    } on ApiException {
      // Danh sách trường là dữ liệu tĩnh, lỗi mạng thì vẫn tìm được phòng mới nhất.
    }
    await _tai();
  }

  Future<void> _tai() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    final session = context.read<Session>();
    try {
      final json = _loc.coBoLoc
          ? await session.api.get('api/phong-tro/tim-kiem', query: _loc.toJson())
          : await session.api.get('api/phong-tro/danh-sach');
      final ketQua = SearchResult.fromJson(json);
      setState(() {
        _ketQua = ketQua.rooms;
        _tenTruongTim = ketQua.tenTruong;
        _dangTai = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _loi = e.message;
        _dangTai = false;
      });
    }
  }

  Future<void> _timBangAi([String? mau]) async {
    if (mau != null) {
      _aiCtrl
        ..text = mau
        ..selection = TextSelection.collapsed(offset: mau.length);
    }

    final moTa = _aiCtrl.text.trim();
    if (moTa.isEmpty) {
      bao(context: context, message: context.t('Vui lòng nhập mô tả nhu cầu tìm phòng.'), loi: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _dangTimAi = true;
    });

    final session = context.read<Session>();
    try {
      final json = await session.api.post(
        'api/rooms/ai-search',
        body: {'moTa': moTa},
        timeout: const Duration(seconds: 30),
      );
      final ketQua = AiSearchResult.fromJson(json);
      if (!mounted) return;
      setState(() {
        _ketQua = ketQua.danhSachPhong;
        _tieuChiAi = ketQua.cacTieuChi;
        _thongBaoAi = ketQua.thongBao;
        _tenTruongTim = null;
        _loi = null;
        _daTimAi = true;
        _dangTimAi = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _dangTimAi = false);
      bao(context: context, message: e.message, loi: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _dangTimAi = false);
      bao(context: context, message: context.t('Máy chủ gặp lỗi, vui lòng thử lại sau.'), loi: true);
    }
  }

  Future<void> _xoaLocAi() async {
    _aiCtrl.clear();
    setState(() {
      _daTimAi = false;
      _tieuChiAi = const [];
      _thongBaoAi = null;
    });
    await _tai();
  }

  Future<void> _lamMoiHienTai() {
    if (_daTimAi && _aiCtrl.text.trim().isNotEmpty) {
      return _timBangAi();
    }
    return _tai();
  }

  String get _moTaKetQua {
    if (_daTimAi) {
      return _thongBaoAi?.isNotEmpty == true
          ? _thongBaoAi!
          : dem(_ketQua.length, 'phòng');
    }
    if (_tenTruongTim == null) return x('Phòng mới đăng, tin VIP ưu tiên trước.');
    return '${x('Gần')} $_tenTruongTim (${_loc.banKinh.toStringAsFixed(1)} km) · ${dem(_ketQua.length, 'phòng')}';
  }

  Future<void> _moBoLoc() async {
    final ketQua = await showModalBottomSheet<_BoLoc>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BoLocSheet(
        truongs: _truongs,
        hienTai: _loc,
        cachSapXep: _cachSapXep,
      ),
    );
    if (ketQua == null || !mounted) return;
    // Bảng bottom sheet không có mục loại hình (chip đã nằm ngay ngoài danh
    // sách) nên giữ lại lựa chọn hiện tại khi áp dụng các bộ lọc khác.
    setState(() {
      _loc = ketQua.copyWith(loaiHinh: _loc.loaiHinh);
      _daTimAi = false;
      _tieuChiAi = const [];
      _thongBaoAi = null;
    });
    await _tai();
  }

  void _moChiTiet(Room phong) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChiTietPhongScreen(phongId: phong.id, tomTap: phong)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Tìm phòng trọ')),
        actions: [
          IconButton(
            tooltip: _xemBanDo ? context.t('Xem danh sách') : context.t('Xem trên bản đồ'),
            onPressed: () => setState(() => _xemBanDo = !_xemBanDo),
            icon: Icon(_xemBanDo ? Icons.view_list_outlined : Icons.map_outlined),
          ),
          IconButton(onPressed: _lamMoiHienTai, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: session.laChuTro
          ? FloatingActionButton.extended(
              heroTag: 'fab_dang_phong_tim_phong',
              onPressed: () => Navigator.pushNamed(context, '/dang-phong'),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(context.t('Đăng phòng')),
            )
          : null,
      body: Column(
        children: [
          _ThanhBoLoc(
            soLuong: [
              _loc.truongId != null,
              _loc.min.trim().isNotEmpty,
              _loc.max.trim().isNotEmpty,
              _loc.loaiHinh != null,
            ].where((e) => e).length,
            moTa: _moTaKetQua,
            moBoLoc: _moBoLoc,
          ),
          _HangLoaiHinh(
            dangChon: _loc.loaiHinh,
            onChon: (loaiHinh) {
              setState(() {
                _loc = _loc.copyWith(loaiHinh: loaiHinh);
                _daTimAi = false;
                _tieuChiAi = const [];
                _thongBaoAi = null;
              });
              _tai();
            },
          ),
          _KhuVucTimAi(
            controller: _aiCtrl,
            dangTim: _dangTimAi,
            daTimAi: _daTimAi,
            tieuChi: _tieuChiAi,
            thongBao: _thongBaoAi,
            goiY: _goiYAi,
            onTim: _timBangAi,
            onXoaLocAi: _xoaLocAi,
          ),
          if (_dangTimAi) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _dangTai
                ? const NangLuongView()
                : _loi != null
                ? LoiView(thongBao: _loi!, tai: _lamMoiHienTai)
                : _ketQua.isEmpty
                ? TrongView(
                    icon: Icons.search_off,
                    chuThich: _daTimAi
                        ? context.t('Không tìm thấy phòng phù hợp với mô tả AI.')
                        : context.t(
                            'Không tìm thấy phòng nào phù hợp.\nThử tăng bán kính hoặc đổi bộ lọc.',
                          ),
                    hanhDong: _daTimAi
                        ? FilledButton.tonalIcon(
                            onPressed: _xoaLocAi,
                            icon: const Icon(Icons.close),
                            label: Text(context.t('Xóa lọc AI')),
                          )
                        : null,
                  )
                : _xemBanDo
                ? _BanDoKetQua(
                    phong: _ketQua,
                    truong: _truongs.where((t) => t.id == _loc.truongId).toList(),
                    onChon: _moChiTiet,
                  )
                : RefreshIndicator(
                    onRefresh: _lamMoiHienTai,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _ketQua.length,
                      itemBuilder: (context, chiSo) =>
                          PhongCard(phong: _ketQua[chiSo], onTap: () => _moChiTiet(_ketQua[chiSo])),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KhuVucTimAi extends StatelessWidget {
  const _KhuVucTimAi({
    required this.controller,
    required this.dangTim,
    required this.daTimAi,
    required this.tieuChi,
    this.thongBao,
    required this.goiY,
    required this.onTim,
    required this.onXoaLocAi,
  });

  final TextEditingController controller;
  final bool dangTim;
  final bool daTimAi;
  final List<String> tieuChi;
  final String? thongBao;
  final List<String> goiY;
  final Future<void> Function([String? mau]) onTim;
  final Future<void> Function() onXoaLocAi;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 17, color: NhaCai.mauChuDao),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.t('Tìm nhanh bằng mô tả AI'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: NhaCai.mauChuDao,
                  ),
                ),
              ),
              if (daTimAi)
                TextButton.icon(
                  onPressed: dangTim ? null : onXoaLocAi,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.close, size: 15),
                  label: Text(context.t('Xóa lọc AI'), style: const TextStyle(fontSize: 12.5)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !dangTim,
                  minLines: 1,
                  maxLines: 2,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onTim(),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    hintText: context.t('VD: Phòng Thủ Đức dưới 3tr, có vệ sinh riêng, ban công...'),
                    hintStyle: TextStyle(fontSize: 12.5, color: Colors.blueGrey.shade400),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: dangTim ? null : () => onTim(),
                style: FilledButton.styleFrom(
                  backgroundColor: NhaCai.mauChuDao,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: dangTim
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(context.t('AI Tìm'), style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final mau in goiY)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.blue.shade100),
                      label: Text(context.t(mau), style: const TextStyle(fontSize: 12)),
                      onPressed: dangTim ? null : () => onTim(mau),
                    ),
                  ),
              ],
            ),
          ),
          if (daTimAi && tieuChi.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tc in tieuChi)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: NhaCai.mauChuDao.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        tc,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: NhaCai.mauChuDao,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (daTimAi && (thongBao?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blueGrey.shade600),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    thongBao!.trim(),
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Ba chip loại hình phòng nằm ngay dưới thanh bộ lọc, đổi là tải lại luôn vì
/// đây là lọc nhanh kiểu "tìm ký túc xá gần trường" sinh viên dùng nhiều nhất.
class _HangLoaiHinh extends StatelessWidget {
  const _HangLoaiHinh({required this.dangChon, required this.onChon});

  final String? dangChon;
  final ValueChanged<String?> onChon;

  @override
  Widget build(BuildContext context) {
    const cacLoai = <(String?, String)>[
      (null, 'Tất cả'),
      ('PhongRieng', 'Phòng riêng'),
      ('KyTucXa', 'Ký túc xá'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          for (final (giaTri, ten) in cacLoai)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(context.t(ten)),
                avatar: Icon(
                  switch (giaTri) {
                    'KyTucXa' => Icons.apartment_outlined,
                    'PhongRieng' => Icons.home_outlined,
                    _ => Icons.filter_alt_outlined,
                  },
                  size: 18,
                ),
                selected: dangChon == giaTri,
                onSelected: (_) => onChon(giaTri),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThanhBoLoc extends StatelessWidget {
  const _ThanhBoLoc({required this.soLuong, required this.moTa, required this.moBoLoc});

  final int soLuong;
  final String moTa;
  final VoidCallback moBoLoc;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.blueGrey.shade50,
    child: InkWell(
      onTap: moBoLoc,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Badge.count(
              count: soLuong,
              isLabelVisible: soLuong > 0,
              child: const Icon(Icons.tune, color: NhaCai.mauChuDao),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(moTa, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
            ),
            Text(context.t('Bộ lọc'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

class _BoLocSheet extends StatefulWidget {
  const _BoLocSheet({
    required this.truongs,
    required this.hienTai,
    required this.cachSapXep,
  });

  final List<School> truongs;
  final _BoLoc hienTai;
  final List<(String, String)> cachSapXep;

  @override
  State<_BoLocSheet> createState() => _BoLocSheetState();
}

class _BoLocSheetState extends State<_BoLocSheet> {
  late String? _truongId = widget.hienTai.truongId;
  late double _banKinh = widget.hienTai.banKinh;
  late String _sapXep = widget.hienTai.sapXep;
  late final TextEditingController _min = TextEditingController(text: widget.hienTai.min);
  late final TextEditingController _max = TextEditingController(text: widget.hienTai.max);

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apDung() {
    Navigator.pop(
      context,
      _BoLoc(
        truongId: _truongId,
        banKinh: _banKinh,
        min: _min.text.trim(),
        max: _max.text.trim(),
        sapXep: _sapXep,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.t('Bộ lọc tìm phòng'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _truongId,
              decoration: InputDecoration(
                labelText: context.t('Gần trường đại học'),
                prefixIcon: const Icon(Icons.school_outlined),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(context.t('Toàn bộ (không lọc theo trường)')),
                ),
                for (final truong in widget.truongs)
                  DropdownMenuItem<String?>(
                    value: truong.id,
                    child: Text('${truong.tenTruong} - ${truong.quan}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _truongId = value),
            ),
            if (_truongId != null) ...[
              const SizedBox(height: 8),
              Text('${context.t('Bán kính tìm')}: ${_banKinh.toStringAsFixed(1)} km'),
              Slider(
                value: _banKinh,
                min: 0.5,
                max: 10,
                divisions: 19,
                label: '${_banKinh.toStringAsFixed(1)} km',
                onChanged: (value) => setState(() => _banKinh = value),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.t('Giá tối thiểu'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.t('Giá tối đa'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _sapXep,
              decoration: InputDecoration(
                labelText: context.t('Sắp xếp'),
                prefixIcon: const Icon(Icons.sort),
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final (giaTri, nhan) in widget.cachSapXep)
                  DropdownMenuItem(value: giaTri, child: Text(context.t(nhan)))
              ],
              onChanged: (value) => setState(() => _sapXep = value ?? 'newest'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _truongId = null;
                      _banKinh = 3;
                      _sapXep = 'newest';
                      _min.clear();
                      _max.clear();
                    }),
                    child: Text(context.t('Xóa lọc')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(onPressed: _apDung, child: Text(context.t('Áp dụng'))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BanDoKetQua extends StatelessWidget {
  const _BanDoKetQua({required this.phong, required this.truong, required this.onChon});

  final List<Room> phong;
  final List<School> truong;
  final ValueChanged<Room> onChon;

  @override
  Widget build(BuildContext context) {
    final diem = [
      for (final item in phong)
        if (item.latitude != null && item.longitude != null)
          DiemDo(phong: item, viDo: item.latitude!, kinhDo: item.longitude!),
    ];

    if (diem.isEmpty) {
      return TrongView(
        icon: Icons.map_outlined,
        chuThich: context.t('Các phòng tìm được chưa có tọa độ nên không hiển thị trên bản đồ.'),
      );
    }

    final truongTim = truong.isEmpty ? null : LatLng(truong.first.latitude, truong.first.longitude);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: BanDo(
        diem: diem,
        tieuDiem: truongTim,
        height: MediaQuery.sizeOf(context).height - 260,
        zoom: truongTim == null ? 12 : 13,
        onChon: onChon,
      ),
    );
  }
}

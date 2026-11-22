import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

class HoSoOGhepScreen extends StatefulWidget {
  const HoSoOGhepScreen({super.key});

  @override
  State<HoSoOGhepScreen> createState() => _HoSoOGhepScreenState();
}

class _HoSoOGhepScreenState extends State<HoSoOGhepScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _dangTai = true;
  bool _dangLuu = false;
  String? _loi;

  // Trạng thái chỗ ở
  bool _daCoPhong = false; // false: Chưa có phòng (tìm thuê chung), true: Đã có phòng (tìm người ghép)
  int? _phongTroId;
  Map<String, dynamic>? _phongTroData;

  final _diaChiPhongHienTaiController = TextEditingController();
  final _giaChiaMoiNguoiController = TextEditingController();
  final _nganSachController = TextEditingController();
  final _khuVucController = TextEditingController();
  final _moTaController = TextEditingController();

  String _thoiGianDonVao = 'Ở ngay';
  String _gioGiac = 'Linh hoạt';
  String _gioiTinhUuTien = 'Không yêu cầu';
  bool _coNauAn = false;
  bool _coNuoiPet = false;
  bool _khongHutThuoc = true;
  bool _uaSachSe = true;
  bool _dangTimBan = true;

  final List<String> _cacMocThoiGian = ['Ở ngay', 'Đầu tháng sau', 'Giữa tháng sau', 'Linh hoạt'];
  final List<String> _cacMucGioGiac = ['Ngủ sớm', 'Cú đêm', 'Linh hoạt'];
  final List<String> _cacMucGioiTinh = ['Không yêu cầu', 'Nam', 'Nữ'];

  static const List<String> _danhSachKhuVucPhoBien = [
    'Thủ Đức',
    'Bình Thạnh',
    'Quận 9',
    'Gò Vấp',
    'Quận 12',
    'Quận 7',
    'Tân Bình',
    'Quận 10',
  ];

  static const List<int> _cacMucNganSachNhanh = [
    1500000,
    2000000,
    2500000,
    3000000,
    4000000,
  ];

  static const List<int> _cacMucGiaChiaNhanh = [
    1200000,
    1500000,
    1800000,
    2000000,
    2500000,
    3000000,
  ];

  @override
  void initState() {
    super.initState();
    _taiHoSo();
  }

  @override
  void dispose() {
    _diaChiPhongHienTaiController.dispose();
    _giaChiaMoiNguoiController.dispose();
    _nganSachController.dispose();
    _khuVucController.dispose();
    _moTaController.dispose();
    super.dispose();
  }

  static String dinhDangTien(num? soTien) => Fmt.tien(soTien);

  static String? _ghepUrlAnh(String? relative) {
    if (relative == null || relative.isEmpty) return null;
    if (relative.startsWith('http://') || relative.startsWith('https://')) return relative;
    final base = ApiClient.baseUrl.endsWith('/')
        ? ApiClient.baseUrl.substring(0, ApiClient.baseUrl.length - 1)
        : ApiClient.baseUrl;
    final path = relative.startsWith('/') ? relative.substring(1) : relative;
    return '$base/$path';
  }

  String _dinhDangTien(num soTien) {
    final so = soTien.round();
    return so.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  void _chonNganSachNhanh(int soTien) {
    setState(() {
      _nganSachController.text = _dinhDangTien(soTien);
    });
  }

  void _chonGiaChiaNhanh(int soTien) {
    setState(() {
      _giaChiaMoiNguoiController.text = _dinhDangTien(soTien);
    });
  }

  void _chonKhuVuc(String khuVuc) {
    setState(() {
      if (_daCoPhong) {
        _diaChiPhongHienTaiController.text = khuVuc;
      } else {
        _khuVucController.text = khuVuc;
      }
    });
  }

  Future<void> _taiHoSo() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });

    try {
      final api = context.read<Session>().api;
      final res = await api.get('api/oghep/my-profile');

      if (res != null && res is Map) {
        setState(() {
          _daCoPhong = res['daCoPhong'] == true;
          _phongTroId = (res['phongTroId'] as num?)?.toInt();
          if (res['phongTro'] != null && res['phongTro'] is Map) {
            _phongTroData = Map<String, dynamic>.from(res['phongTro']);
          }

          _diaChiPhongHienTaiController.text = res['diaChiPhongHienTai']?.toString() ?? '';

          final giaChia = res['giaChiaMoiNguoi'];
          if (giaChia != null && giaChia is num && giaChia > 0) {
            _giaChiaMoiNguoiController.text = _dinhDangTien(giaChia.toInt());
          }

          final ns = res['nganSachToiDa'];
          if (ns != null && ns is num && ns > 0) {
            _nganSachController.text = _dinhDangTien(ns.toInt());
          }

          _khuVucController.text = res['khuVucMongMuon']?.toString() ?? '';
          _thoiGianDonVao = res['thoiGianDonVao']?.toString() ?? 'Ở ngay';
          if (!_cacMocThoiGian.contains(_thoiGianDonVao)) {
            _thoiGianDonVao = 'Ở ngay';
          }

          _gioGiac = res['gioGiacSinhHoat']?.toString() ?? 'Linh hoạt';
          if (!_cacMucGioGiac.contains(_gioGiac)) {
            _gioGiac = 'Linh hoạt';
          }

          _gioiTinhUuTien = res['gioiTinhUuTien']?.toString() ?? 'Không yêu cầu';
          if (!_cacMucGioiTinh.contains(_gioiTinhUuTien)) {
            _gioiTinhUuTien = 'Không yêu cầu';
          }

          _coNauAn = res['coNauAn'] == true;
          _coNuoiPet = res['coNuoiPet'] == true;
          _khongHutThuoc = res['khongHutThuoc'] == true;
          _uaSachSe = res['uaSachSe'] == true;

          _moTaController.text = res['moTaThem']?.toString() ?? '';
          _dangTimBan = res['dangTimBan'] != false;
        });
      }
    } on ApiException catch (e) {
      _loi = e.message;
    } catch (e) {
      _loi = context.t('Không thể tải thông tin hồ sơ.');
    } finally {
      if (mounted) {
        setState(() => _dangTai = false);
      }
    }
  }

  Future<void> _moModalChonPhongTro() async {
    final api = context.read<Session>().api;
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> danhSachPhong = [];
    bool dangTaiPhong = true;

    Future<void> timKiem(StateSetter setModalState, String tuKhoa) async {
      setModalState(() => dangTaiPhong = true);
      try {
        final res = await api.get('api/oghep/danh-sach-phong', query: {'q': tuKhoa.trim()});
        if (res is List) {
          setModalState(() {
            danhSachPhong = res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      } catch (_) {
        // bỏ qua lỗi tìm kiếm
      } finally {
        setModalState(() => dangTaiPhong = false);
      }
    }

    final phongDaChon = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            if (dangTaiPhong && danhSachPhong.isEmpty && searchCtrl.text.isEmpty) {
              timKiem(setModalState, '');
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.home_work_outlined, color: Colors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.t('Chọn phòng trọ trên RoomFinder'),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        decoration: InputDecoration(
                          hintText: context.t('Tìm theo tên phòng, đường, quận...'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchCtrl.clear();
                                    timKiem(setModalState, '');
                                  },
                                )
                              : null,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (kw) => timKiem(setModalState, kw),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: dangTaiPhong
                            ? const Center(child: CircularProgressIndicator())
                            : danhSachPhong.isEmpty
                                ? Center(
                                    child: Text(
                                      context.t('Không tìm thấy phòng trọ nào phù hợp.'),
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scrollCtrl,
                                    itemCount: danhSachPhong.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (ctx, idx) {
                                      final r = danhSachPhong[idx];
                                      final gia = (r['gia'] as num?)?.toDouble() ?? 0;
                                      final anh = r['anhDaiDien']?.toString();
                                      final anhUrl = _ghepUrlAnh(anh);

                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: SizedBox(
                                            width: 58,
                                            height: 58,
                                            child: anhUrl != null
                                                ? Image.network(
                                                    anhUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(
                                                      color: Colors.grey.shade200,
                                                      child: const Icon(Icons.home, color: Colors.grey),
                                                    ),
                                                  )
                                                : Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(Icons.home, color: Colors.grey),
                                                  ),
                                          ),
                                        ),
                                        title: Text(
                                          r['moTa']?.toString() ?? 'Phòng trọ #${r['id']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r['diaChi']?.toString() ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${Fmt.tien(gia)} / ${context.t('tháng')}',
                                              style: const TextStyle(
                                                color: Colors.teal,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: const Icon(Icons.chevron_right),
                                        onTap: () => Navigator.pop(modalCtx, r),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (phongDaChon != null && mounted) {
      setState(() {
        _phongTroId = (phongDaChon['id'] as num?)?.toInt();
        _phongTroData = phongDaChon;

        // Tự động điền địa chỉ nếu ô địa chỉ đang trống
        final diaChi = phongDaChon['diaChi']?.toString();
        if (_diaChiPhongHienTaiController.text.trim().isEmpty && diaChi != null && diaChi.isNotEmpty) {
          _diaChiPhongHienTaiController.text = diaChi;
        }

        // Tự động gợi ý giá chia = nửa giá phòng nếu ô giá chia đang trống
        final gia = (phongDaChon['gia'] as num?)?.toDouble() ?? 0;
        if (_giaChiaMoiNguoiController.text.trim().isEmpty && gia > 0) {
          final nuaGia = (gia / 2).toInt();
          _giaChiaMoiNguoiController.text = _dinhDangTien(nuaGia);
        }
      });
    }
  }

  Future<void> _luuHoSo() async {
    if (!_formKey.currentState!.validate() || _dangLuu) return;

    double nganSach = 0;
    double? giaChia;

    if (_daCoPhong) {
      final rawGiaChia = _giaChiaMoiNguoiController.text.replaceAll('.', '').replaceAll(',', '').trim();
      giaChia = double.tryParse(rawGiaChia) ?? 0;
      if (giaChia <= 0) {
        bao(context: context, message: context.t('Vui lòng nhập giá chia mỗi người/tháng hợp lệ.'), loi: true);
        return;
      }
      nganSach = giaChia; // đồng bộ ngân sách
    } else {
      final rawNganSach = _nganSachController.text.replaceAll('.', '').replaceAll(',', '').trim();
      nganSach = double.tryParse(rawNganSach) ?? 0;
      if (nganSach <= 0) {
        bao(context: context, message: context.t('Vui lòng nhập ngân sách tối đa hợp lệ.'), loi: true);
        return;
      }
    }

    setState(() => _dangLuu = true);

    try {
      final api = context.read<Session>().api;
      final khuVucLuu = _daCoPhong
          ? (_diaChiPhongHienTaiController.text.trim().isNotEmpty
              ? _diaChiPhongHienTaiController.text.trim()
              : _khuVucController.text.trim())
          : _khuVucController.text.trim();

      final body = {
        'gioGiacSinhHoat': _gioGiac,
        'gioiTinhUuTien': _gioiTinhUuTien,
        'coNauAn': _coNauAn,
        'coNuoiPet': _coNuoiPet,
        'khongHutThuoc': _khongHutThuoc,
        'uaSachSe': _uaSachSe,
        'daCoPhong': _daCoPhong,
        'phongTroId': _daCoPhong ? _phongTroId : null,
        'diaChiPhongHienTai': _daCoPhong ? _diaChiPhongHienTaiController.text.trim() : null,
        'giaChiaMoiNguoi': _daCoPhong ? giaChia : null,
        'thoiGianDonVao': _thoiGianDonVao,
        'nganSachToiDa': nganSach,
        'khuVucMongMuon': khuVucLuu,
        'moTaThem': _moTaController.text.trim(),
        'dangTimBan': _dangTimBan,
      };

      await api.post('api/oghep/my-profile', body: body);

      if (mounted) {
        bao(context: context, message: context.t('Đã lưu hồ sơ tìm bạn ở ghép!'));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    } catch (e) {
      if (mounted) bao(context: context, message: context.t('Lỗi khi lưu hồ sơ, vui lòng thử lại.'), loi: true);
    } finally {
      if (mounted) {
        setState(() => _dangLuu = false);
      }
    }
  }

  Widget _buildChonTrangThaiChoO() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Tình trạng chỗ ở hiện tại của bạn:'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Thẻ 1: Đã có phòng
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _daCoPhong = true),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _daCoPhong ? Colors.teal.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _daCoPhong ? Colors.teal : Colors.grey.shade300,
                      width: _daCoPhong ? 2 : 1,
                    ),
                    boxShadow: _daCoPhong
                        ? [
                            BoxShadow(
                              color: Colors.teal.withValues(alpha: .15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.home_work,
                        size: 32,
                        color: _daCoPhong ? Colors.teal.shade700 : Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('ĐÃ CÓ PHÒNG'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _daCoPhong ? Colors.teal.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('Tìm bạn ở ghép cùng để chia tiền'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: _daCoPhong ? Colors.teal.shade800 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Thẻ 2: Chưa có phòng
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _daCoPhong = false),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: !_daCoPhong ? Colors.indigo.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_daCoPhong ? Colors.indigo : Colors.grey.shade300,
                      width: !_daCoPhong ? 2 : 1,
                    ),
                    boxShadow: !_daCoPhong
                        ? [
                            BoxShadow(
                              color: Colors.indigo.withValues(alpha: .15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 32,
                        color: !_daCoPhong ? Colors.indigo.shade700 : Colors.grey.shade600,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('CHƯA CÓ PHÒNG'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: !_daCoPhong ? Colors.indigo.shade900 : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.t('Tìm chỗ ở ghép hoặc rủ thuê chung'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: !_daCoPhong ? Colors.indigo.shade800 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPhanDaCoPhong() {
    final api = context.read<Session>().api;
    final anh = _phongTroData?['anhDaiDien']?.toString();
    final anhUrl = anh != null ? '${ApiClient.baseUrl}/' + (anh.startsWith('/') ? anh.substring(1) : anh) : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_outlined, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  context.t('Chi tiết phòng trọ hiện tại của bạn'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Gắn phòng trọ trên RoomFinder
            if (_phongTroData != null || _phongTroId != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: anhUrl != null
                            ? Image.network(
                                anhUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.teal.shade100,
                                  child: const Icon(Icons.home, color: Colors.teal),
                                ),
                              )
                            : Container(
                                color: Colors.teal.shade100,
                                child: const Icon(Icons.home, color: Colors.teal),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Đã liên kết',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _phongTroData?['moTa']?.toString() ?? 'Phòng trọ #${_phongTroId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _phongTroData?['diaChi']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      tooltip: context.t('Hủy liên kết'),
                      onPressed: () {
                        setState(() {
                          _phongTroId = null;
                          _phongTroData = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              OutlinedButton.icon(
                onPressed: _moModalChonPhongTro,
                icon: const Icon(Icons.add_link, color: Colors.teal),
                label: Text(context.t('Gắn phòng trọ từ RoomFinder (tùy chọn)')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Địa chỉ phòng hiện tại
            Text(
              context.t('Địa chỉ / Khu vực phòng hiện tại *'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _danhSachKhuVucPhoBien.map((kv) {
                final dangChon = _diaChiPhongHienTaiController.text.toLowerCase().contains(kv.toLowerCase());
                return FilterChip(
                  showCheckmark: false,
                  label: Text(kv),
                  selected: dangChon,
                  selectedColor: Colors.teal.shade100,
                  labelStyle: TextStyle(
                    color: dangChon ? Colors.teal.shade900 : Colors.grey.shade800,
                    fontWeight: dangChon ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                  onSelected: (_) => _chonKhuVuc(kv),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _diaChiPhongHienTaiController,
              decoration: InputDecoration(
                labelText: context.t('Địa chỉ chi tiết phòng hiện tại *'),
                hintText: 'VD: 123 Võ Văn Ngân, P. Linh Chiểu, TP. Thủ Đức',
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (val) {
                if (_daCoPhong && (val == null || val.trim().isEmpty)) {
                  return context.t('Vui lòng nhập địa chỉ phòng trọ hiện tại');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Giá chia mỗi người/tháng
            TextFormField(
              controller: _giaChiaMoiNguoiController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _TienInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: context.t('Giá chia mỗi người / tháng (VNĐ) *'),
                hintText: 'VD: 1.800.000',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: const OutlineInputBorder(),
                suffixText: 'đ',
              ),
              validator: (val) {
                if (_daCoPhong) {
                  if (val == null || val.trim().isEmpty) {
                    return context.t('Vui lòng nhập số tiền chia mỗi người');
                  }
                  final num = double.tryParse(val.replaceAll('.', '').replaceAll(',', '').trim());
                  if (num == null || num <= 0) {
                    return context.t('Số tiền không hợp lệ');
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Nút chọn nhanh giá chia
            Text(
              context.t('Chọn nhanh giá chia:'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _cacMucGiaChiaNhanh.map((muc) {
                  final textMuc = muc == 1200000
                      ? '1.2 tr'
                      : muc == 1500000
                          ? '1.5 tr'
                          : muc == 1800000
                              ? '1.8 tr'
                              : muc == 2000000
                                  ? '2 tr'
                                  : muc == 2500000
                                      ? '2.5 tr'
                                      : '3 tr';
                  final dangChon = _giaChiaMoiNguoiController.text == _dinhDangTien(muc);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(textMuc),
                      backgroundColor: dangChon ? Colors.teal.shade100 : Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: dangChon ? Colors.teal.shade900 : Colors.grey.shade800,
                        fontWeight: dangChon ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onPressed: () => _chonGiaChiaNhanh(muc),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Thời gian dọn vào
            Text(
              context.t('Thời gian có thể dọn vào:'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _cacMocThoiGian.map((moc) {
                final selected = _thoiGianDonVao == moc;
                return ChoiceChip(
                  showCheckmark: false,
                  label: Text(context.t(moc)),
                  selected: selected,
                  selectedColor: Colors.teal.shade100,
                  labelStyle: TextStyle(
                    color: selected ? Colors.teal.shade900 : null,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _thoiGianDonVao = moc);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhanChuaCoPhong() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  context.t('Nhu cầu tìm chỗ ở & Ngân sách'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Khu vực mong muốn
            Text(
              context.t('Khu vực mong muốn *'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _danhSachKhuVucPhoBien.map((kv) {
                final dangChon = _khuVucController.text.trim().toLowerCase() == kv.toLowerCase();
                return FilterChip(
                  showCheckmark: false,
                  label: Text(kv),
                  selected: dangChon,
                  selectedColor: Colors.indigo.shade100,
                  labelStyle: TextStyle(
                    color: dangChon ? Colors.indigo.shade900 : Colors.grey.shade800,
                    fontWeight: dangChon ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                  onSelected: (_) => _chonKhuVuc(kv),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _khuVucController,
              decoration: InputDecoration(
                labelText: context.t('Chi tiết khu vực / quận khác *'),
                hintText: 'VD: Thủ Đức, gần ĐH Sư Phạm Kỹ Thuật',
                prefixIcon: const Icon(Icons.map_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (val) {
                if (!_daCoPhong && (val == null || val.trim().isEmpty)) {
                  return context.t('Vui lòng nhập hoặc chọn khu vực mong muốn');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Ngân sách tối đa
            TextFormField(
              controller: _nganSachController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _TienInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: context.t('Ngân sách tối đa (VNĐ/tháng) *'),
                hintText: 'VD: 2.500.000',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: const OutlineInputBorder(),
                suffixText: 'đ',
              ),
              validator: (val) {
                if (!_daCoPhong) {
                  if (val == null || val.trim().isEmpty) {
                    return context.t('Vui lòng nhập ngân sách tối đa');
                  }
                  final num = double.tryParse(val.replaceAll('.', '').replaceAll(',', '').trim());
                  if (num == null || num <= 0) {
                    return context.t('Ngân sách không hợp lệ');
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Chọn nhanh mức ngân sách
            Text(
              context.t('Chọn nhanh ngân sách:'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _cacMucNganSachNhanh.map((muc) {
                  final textMuc = muc == 1500000
                      ? '1.5 tr'
                      : muc == 2000000
                          ? '2 tr'
                          : muc == 2500000
                              ? '2.5 tr'
                              : muc == 3000000
                                  ? '3 tr'
                                  : '4 tr';
                  final dangChon = _nganSachController.text == _dinhDangTien(muc);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(textMuc),
                      backgroundColor: dangChon ? Colors.indigo.shade100 : Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: dangChon ? Colors.indigo.shade900 : Colors.grey.shade800,
                        fontWeight: dangChon ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onPressed: () => _chonNganSachNhanh(muc),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Thời gian dự kiến dọn vào
            Text(
              context.t('Thời gian dự kiến dọn vào:'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _cacMocThoiGian.map((moc) {
                final selected = _thoiGianDonVao == moc;
                return ChoiceChip(
                  showCheckmark: false,
                  label: Text(context.t(moc)),
                  selected: selected,
                  selectedColor: Colors.indigo.shade100,
                  labelStyle: TextStyle(
                    color: selected ? Colors.indigo.shade900 : null,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _thoiGianDonVao = moc);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Hồ sơ ở ghép của tôi')),
      ),
      bottomNavigationBar: _dangTai || _loi != null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _dangLuu ? null : _luuHoSo,
                    icon: _dangLuu
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _dangLuu ? context.t('Đang lưu hồ sơ...') : context.t('Lưu hồ sơ ở ghép'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
      body: _dangTai
          ? const NangLuongView()
          : _loi != null
              ? LoiView(thongBao: _loi!, tai: _taiHoSo)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      // Card trạng thái tìm bạn
                      Card(
                        margin: EdgeInsets.zero,
                        color: _dangTimBan ? Colors.green.shade50 : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _dangTimBan ? Colors.green.shade300 : Colors.grey.shade300,
                          ),
                        ),
                        child: SwitchListTile(
                          value: _dangTimBan,
                          onChanged: (v) => setState(() => _dangTimBan = v),
                          title: Text(
                            context.t('Đang tìm bạn ở ghép'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _dangTimBan ? Colors.green.shade800 : Colors.grey.shade700,
                            ),
                          ),
                          subtitle: Text(
                            _dangTimBan
                                ? context.t('Hồ sơ của bạn đang hiển thị cho các bạn khác tìm kiếm')
                                : context.t('Tạm dừng tìm kiếm (hồ sơ sẽ ẩn khỏi danh sách gợi ý)'),
                            style: TextStyle(
                              fontSize: 12,
                              color: _dangTimBan ? Colors.green.shade700 : Colors.grey.shade600,
                            ),
                          ),
                          activeColor: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Bộ chọn tình trạng chỗ ở nổi bật
                      _buildChonTrangThaiChoO(),
                      const SizedBox(height: 16),

                      // 2. Chi tiết theo trạng thái (Đã có phòng VS Chưa có phòng)
                      if (_daCoPhong) _buildPhanDaCoPhong() else _buildPhanChuaCoPhong(),
                      const SizedBox(height: 16),

                      // 3. Card Tiêu chí ưu tiên
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.tune_outlined, color: NhaCai.mauChuDao),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.t('Tiêu chí ưu tiên'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Ưu tiên giới tính
                              Text(
                                context.t('Ưu tiên giới tính bạn cùng phòng:'),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _cacMucGioiTinh.map((gt) {
                                  final selected = _gioiTinhUuTien == gt;
                                  return ChoiceChip(
                                    showCheckmark: false,
                                    label: Text(context.t(gt)),
                                    selected: selected,
                                    selectedColor: NhaCai.mauChuDao.withValues(alpha: .18),
                                    labelStyle: TextStyle(
                                      color: selected ? NhaCai.mauChuDao : null,
                                      fontWeight: selected ? FontWeight.bold : null,
                                    ),
                                    avatar: Icon(
                                      gt == 'Nam'
                                          ? Icons.male
                                          : gt == 'Nữ'
                                              ? Icons.female
                                              : Icons.people_outline,
                                      size: 18,
                                      color: selected ? NhaCai.mauChuDao : null,
                                    ),
                                    onSelected: (val) {
                                      if (val) setState(() => _gioiTinhUuTien = gt);
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),

                              // Không hút thuốc
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _khongHutThuoc,
                                onChanged: (v) => setState(() => _khongHutThuoc = v),
                                secondary: const Icon(Icons.smoke_free_outlined),
                                title: Text(context.t('Không hút thuốc')),
                                subtitle: Text(context.t('Không hút thuốc lá hoặc thuốc lá điện tử')),
                              ),
                              const Divider(height: 1),

                              // Ưa gọn gàng sạch sẽ
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _uaSachSe,
                                onChanged: (v) => setState(() => _uaSachSe = v),
                                secondary: const Icon(Icons.cleaning_services_outlined),
                                title: Text(context.t('Ưa gọn gàng, sạch sẽ')),
                                subtitle: Text(context.t('Giữ gìn vệ sinh chung, dọn dẹp phòng thường xuyên')),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Card thói quen sinh hoạt
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.style_outlined, color: NhaCai.mauChuDao),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.t('Thói quen sinh hoạt'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Giờ giấc sinh hoạt
                              Text(
                                context.t('Giờ giấc sinh hoạt:'),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: _cacMucGioGiac.map((muc) {
                                  final selected = _gioGiac == muc;
                                  return ChoiceChip(
                                    showCheckmark: false,
                                    label: Text(context.t(muc)),
                                    selected: selected,
                                    selectedColor: NhaCai.mauChuDao.withValues(alpha: .18),
                                    labelStyle: TextStyle(
                                      color: selected ? NhaCai.mauChuDao : null,
                                      fontWeight: selected ? FontWeight.bold : null,
                                    ),
                                    avatar: Icon(
                                      muc == 'Ngủ sớm'
                                          ? Icons.bedtime_outlined
                                          : muc == 'Cú đêm'
                                              ? Icons.nightlight_round
                                              : Icons.timelapse,
                                      size: 16,
                                      color: selected ? NhaCai.mauChuDao : null,
                                    ),
                                    onSelected: (val) {
                                      if (val) setState(() => _gioGiac = muc);
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),

                              // Nấu ăn
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _coNauAn,
                                onChanged: (v) => setState(() => _coNauAn = v),
                                secondary: const Icon(Icons.restaurant_outlined),
                                title: Text(context.t('Có tự nấu ăn')),
                                subtitle: Text(context.t('Thường xuyên nấu nướng tại phòng')),
                              ),
                              const Divider(height: 1),

                              // Nuôi pet
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: _coNuoiPet,
                                onChanged: (v) => setState(() => _coNuoiPet = v),
                                secondary: const Icon(Icons.pets_outlined),
                                title: Text(context.t('Có nuôi thú cưng')),
                                subtitle: Text(context.t('Đang nuôi hoặc đồng ý ở cùng thú cưng')),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Card Mô tả thêm
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.edit_note_outlined, color: NhaCai.mauChuDao),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.t('Giới thiệu bản thân & Ghi chú thêm'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _moTaController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: context.t('Mô tả tính cách, sở thích, yêu cầu bạn cùng phòng'),
                                  hintText: context.t(
                                      'VD: Mình là sinh viên năm 3 vui vẻ, sạch sẽ, tìm bạn nam/nữ cùng phòng không hút thuốc...'),
                                  border: const OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// Formatter tự động định dạng số có dấu chấm ngăn cách hàng nghìn (ví dụ: 2.500.000)
class _TienInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final chuoiSo = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (chuoiSo.isEmpty) {
      return const TextEditingValue();
    }

    final so = int.tryParse(chuoiSo);
    if (so == null) return oldValue;

    final dinhDang = so.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );

    return TextEditingValue(
      text: dinhDang,
      selection: TextSelection.collapsed(offset: dinhDang.length),
    );
  }
}


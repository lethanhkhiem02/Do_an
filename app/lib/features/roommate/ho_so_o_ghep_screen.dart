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

  String _gioGiac = 'Linh hoạt';
  String _gioiTinhUuTien = 'Không yêu cầu';
  bool _coNauAn = false;
  bool _coNuoiPet = false;
  bool _khongHutThuoc = true;
  bool _uaSachSe = true;

  final _nganSachController = TextEditingController();
  final _khuVucController = TextEditingController();
  final _moTaController = TextEditingController();
  bool _dangTimBan = true;

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

  @override
  void initState() {
    super.initState();
    _taiHoSo();
  }

  @override
  void dispose() {
    _nganSachController.dispose();
    _khuVucController.dispose();
    _moTaController.dispose();
    super.dispose();
  }

  String _dinhDangTien(int soTien) {
    return soTien.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  void _chonNganSachNhanh(int soTien) {
    setState(() {
      _nganSachController.text = _dinhDangTien(soTien);
    });
  }

  void _chonKhuVuc(String khuVuc) {
    setState(() {
      _khuVucController.text = khuVuc;
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

          final ns = res['nganSachToiDa'];
          if (ns != null && ns is num && ns > 0) {
            _nganSachController.text = _dinhDangTien(ns.toInt());
          }

          _khuVucController.text = res['khuVucMongMuon']?.toString() ?? '';
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

  Future<void> _luuHoSo() async {
    if (!_formKey.currentState!.validate() || _dangLuu) return;

    final rawNganSach = _nganSachController.text.replaceAll('.', '').replaceAll(',', '').trim();
    final nganSach = double.tryParse(rawNganSach) ?? 0;
    if (nganSach <= 0) {
      bao(context: context, message: context.t('Vui lòng nhập ngân sách tối đa hợp lệ.'), loi: true);
      return;
    }

    setState(() => _dangLuu = true);

    try {
      final api = context.read<Session>().api;
      final body = {
        'gioGiacSinhHoat': _gioGiac,
        'gioiTinhUuTien': _gioiTinhUuTien,
        'coNauAn': _coNauAn,
        'coNuoiPet': _coNuoiPet,
        'khongHutThuoc': _khongHutThuoc,
        'uaSachSe': _uaSachSe,
        'nganSachToiDa': nganSach,
        'khuVucMongMuon': _khuVucController.text.trim(),
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

                      // Card Tiêu chí ưu tiên (MỚI)
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

                      // Card thói quen sinh hoạt
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

                      // Card mong muốn phòng trọ & ngân sách
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, color: NhaCai.mauChuDao),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.t('Nhu cầu thuê phòng'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

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
                                  if (val == null || val.trim().isEmpty) {
                                    return context.t('Vui lòng nhập ngân sách tối đa');
                                  }
                                  final num = double.tryParse(val.replaceAll('.', '').replaceAll(',', '').trim());
                                  if (num == null || num <= 0) {
                                    return context.t('Ngân sách không hợp lệ');
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
                                        backgroundColor: dangChon
                                            ? NhaCai.mauChuDao.withValues(alpha: .18)
                                            : Colors.grey.shade100,
                                        labelStyle: TextStyle(
                                          color: dangChon ? NhaCai.mauChuDao : Colors.grey.shade800,
                                          fontWeight: dangChon ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                        onPressed: () => _chonNganSachNhanh(muc),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Khu vực mong muốn
                              Text(
                                context.t('Khu vực mong muốn *'),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.t('Chọn nhanh quận/khu vực tại TP.HCM:'),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: _danhSachKhuVucPhoBien.map((kv) {
                                  final dangChon = _khuVucController.text.trim().toLowerCase() == kv.toLowerCase();
                                  return FilterChip(
                                    showCheckmark: false,
                                    label: Text(kv),
                                    selected: dangChon,
                                    selectedColor: NhaCai.mauChuDao.withValues(alpha: .18),
                                    labelStyle: TextStyle(
                                      color: dangChon ? NhaCai.mauChuDao : Colors.grey.shade800,
                                      fontWeight: dangChon ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    onSelected: (_) => _chonKhuVuc(kv),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _khuVucController,
                                decoration: InputDecoration(
                                  labelText: context.t('Chi tiết khu vực / quận khác *'),
                                  hintText: 'VD: Thủ Đức, gần ĐH Sư Phạm Kỹ Thuật',
                                  prefixIcon: const Icon(Icons.map_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return context.t('Vui lòng nhập hoặc chọn khu vực mong muốn');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Mô tả thêm
                              TextFormField(
                                controller: _moTaController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: context.t('Mô tả thêm về bản thân & yêu cầu bạn cùng phòng'),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

class CanhBaoItem {
  CanhBaoItem({
    required this.id,
    required this.userId,
    this.tenChuTro,
    this.emailChuTro,
    this.soDienThoaiChuTro,
    this.trangThaiKhoaChuTro = false,
    this.phongTroId,
    this.tieuDePhongTro,
    this.giaPhongTro,
    this.diaChiPhongTro,
    required this.loaiViPham,
    required this.moTaChiTiet,
    this.anhBangChungUrl,
    required this.daXuLy,
    required this.ngayTao,
  });

  factory CanhBaoItem.fromJson(Map<String, dynamic> json) {
    return CanhBaoItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['userId']?.toString() ?? '',
      tenChuTro: json['tenChuTro']?.toString(),
      emailChuTro: json['emailChuTro']?.toString(),
      soDienThoaiChuTro: json['soDienThoaiChuTro']?.toString(),
      trangThaiKhoaChuTro: json['trangThaiKhoaChuTro'] == true,
      phongTroId: (json['phongTroId'] as num?)?.toInt(),
      tieuDePhongTro: json['tieuDePhongTro']?.toString(),
      giaPhongTro: (json['giaPhongTro'] as num?)?.toDouble(),
      diaChiPhongTro: json['diaChiPhongTro']?.toString(),
      loaiViPham: json['loaiViPham']?.toString() ?? 'AnhTrungLap',
      moTaChiTiet: json['moTaChiTiet']?.toString() ?? '',
      anhBangChungUrl: json['anhBangChungUrl']?.toString(),
      daXuLy: json['daXuLy'] == true,
      ngayTao: DateTime.tryParse(json['ngayTao']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  final int id;
  final String userId;
  final String? tenChuTro;
  final String? emailChuTro;
  final String? soDienThoaiChuTro;
  final bool trangThaiKhoaChuTro;
  final int? phongTroId;
  final String? tieuDePhongTro;
  final double? giaPhongTro;
  final String? diaChiPhongTro;
  final String loaiViPham;
  final String moTaChiTiet;
  final String? anhBangChungUrl;
  final bool daXuLy;
  final DateTime ngayTao;
}

/// Màn hình quản lý Cảnh báo bất thường (Lọc ảnh trùng lặp & AI Vision) dành cho Admin
class AdminCanhBaoAiScreen extends StatefulWidget {
  const AdminCanhBaoAiScreen({super.key});

  @override
  State<AdminCanhBaoAiScreen> createState() => _AdminCanhBaoAiScreenState();
}

class _AdminCanhBaoAiScreenState extends State<AdminCanhBaoAiScreen> {
  bool _dangTai = true;
  String? _loi;
  List<CanhBaoItem> _danhSach = [];

  // Bộ lọc: null = tất cả, false = chưa xử lý, true = đã xử lý
  bool? _locDaXuLy = false;

  @override
  void initState() {
    super.initState();
    _taiDanhSach();
  }

  Future<void> _taiDanhSach() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });

    try {
      final api = context.read<Session>().api;
      final query = <String, dynamic>{};
      if (_locDaXuLy != null) {
        query['daXuLy'] = _locDaXuLy;
      }

      final res = await api.get('api/admin/canh-bao', query: query);

      if (res is List) {
        setState(() {
          _danhSach = res
              .whereType<Map>()
              .map((e) => CanhBaoItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        });
      } else {
        setState(() => _danhSach = []);
      }
    } on ApiException catch (e) {
      setState(() => _loi = e.message);
    } catch (e) {
      setState(() => _loi = context.t('Không thể tải danh sách cảnh báo.'));
    } finally {
      if (mounted) {
        setState(() => _dangTai = false);
      }
    }
  }

  String _urlAnh(String? relative) {
    if (relative == null || relative.isEmpty) return '';
    if (relative.startsWith('http')) return relative;
    final clean = relative.startsWith('/') ? relative.substring(1) : relative;
    return '${ApiClient.baseUrl}/$clean';
  }

  Future<void> _xuLyCanhBao(CanhBaoItem item, {required bool khoaTaiKhoan}) async {
    final api = context.read<Session>().api;

    if (khoaTaiKhoan) {
      final xacNhanKhoa = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.block, color: Colors.red, size: 40),
          title: Text(context.t('Khóa tài khoản chủ trọ?')),
          content: Text(
            '${context.t('Bạn có chắc chắn muốn khóa tài khoản của chủ trọ')} "${item.tenChuTro ?? item.userId}"?\n\n'
            '${context.t('Tài khoản này sẽ không thể đăng phòng hoặc thực hiện các thao tác trên hệ thống.')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('Hủy')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.t('Xác nhận khóa')),
            ),
          ],
        ),
      );

      if (xacNhanKhoa != true) return;
    }

    try {
      final res = await api.post(
        'api/admin/canh-bao/${item.id}/xu-ly',
        body: {'khoaTaiKhoan': khoaTaiKhoan},
      );

      if (!mounted) return;
      final msg = (res is Map && res['message'] != null)
          ? res['message'].toString()
          : (khoaTaiKhoan
              ? context.t('Đã xử lý cảnh báo và khóa tài khoản chủ trọ thành công.')
              : context.t('Đã đánh dấu xử lý cảnh báo thành công.'));

      bao(context: context, message: msg);
      _taiDanhSach();
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    } catch (e) {
      if (mounted) bao(context: context, message: context.t('Lỗi khi xử lý cảnh báo.'), loi: true);
    }
  }

  Widget _buildBadgeLoaiViPham(String loai) {
    final (mauNen, mauChu, icon, text) = switch (loai) {
      'AnhMauTrenMang' => (
          Colors.purple.shade50,
          Colors.purple.shade800,
          Icons.auto_awesome,
          context.t('Ảnh mẫu trên mạng (AI)'),
        ),
      'SpamNhieuBai' => (
          Colors.red.shade50,
          Colors.red.shade800,
          Icons.copy_all_outlined,
          context.t('Spam ảnh nhiều bài'),
        ),
      _ => (
          Colors.amber.shade50,
          Colors.amber.shade900,
          Icons.photo_library_outlined,
          context.t('Trùng ảnh bài khác'),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: mauNen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mauChu.withValues(alpha: .3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: mauChu),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: mauChu,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Cảnh báo bất thường (AI)')),
      ),
      body: Column(
        children: [
          // Thanh bộ lọc
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  label: Text(context.t('Chưa xử lý')),
                  selected: _locDaXuLy == false,
                  selectedColor: Colors.orange.shade100,
                  labelStyle: TextStyle(
                    color: _locDaXuLy == false ? Colors.orange.shade900 : null,
                    fontWeight: _locDaXuLy == false ? FontWeight.bold : null,
                  ),
                  onSelected: (val) {
                    setState(() => _locDaXuLy = val ? false : null);
                    _taiDanhSach();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.t('Đã xử lý')),
                  selected: _locDaXuLy == true,
                  selectedColor: Colors.green.shade100,
                  labelStyle: TextStyle(
                    color: _locDaXuLy == true ? Colors.green.shade900 : null,
                    fontWeight: _locDaXuLy == true ? FontWeight.bold : null,
                  ),
                  onSelected: (val) {
                    setState(() => _locDaXuLy = val ? true : null);
                    _taiDanhSach();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(context.t('Tất cả')),
                  selected: _locDaXuLy == null,
                  onSelected: (val) {
                    if (val) {
                      setState(() => _locDaXuLy = null);
                      _taiDanhSach();
                    }
                  },
                ),
              ],
            ),
          ),

          // Danh sách cảnh báo
          Expanded(
            child: RefreshIndicator(
              onRefresh: _taiDanhSach,
              child: _dangTai
                  ? const NangLuongView()
                  : _loi != null
                      ? LoiView(thongBao: _loi!, tai: _taiDanhSach)
                      : _danhSach.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 100),
                                TrongView(
                                  icon: Icons.verified_user_outlined,
                                  chuThich: context.t('Không có cảnh báo bất thường nào.'),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _danhSach.length,
                              itemBuilder: (context, index) {
                                final item = _danhSach[index];
                                final urlAnh = _urlAnh(item.anhBangChungUrl);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: item.daXuLy
                                          ? Colors.grey.shade300
                                          : Colors.orange.shade300,
                                      width: item.daXuLy ? 1 : 1.5,
                                    ),
                                  ),
                                  elevation: item.daXuLy ? 1 : 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Badge loại vi phạm & Trạng thái xử lý
                                        Row(
                                          children: [
                                            _buildBadgeLoaiViPham(item.loaiViPham),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: item.daXuLy
                                                    ? Colors.green.shade50
                                                    : Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    item.daXuLy
                                                        ? Icons.check_circle_outline
                                                        : Icons.pending_outlined,
                                                    size: 13,
                                                    color: item.daXuLy
                                                        ? Colors.green.shade700
                                                        : Colors.red.shade700,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item.daXuLy
                                                        ? context.t('Đã xử lý')
                                                        : context.t('Chưa xử lý'),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: item.daXuLy
                                                        ? Colors.green.shade800
                                                        : Colors.red.shade800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Thời gian tạo
                                        Row(
                                          children: [
                                            Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              Fmt.ngay(item.ngayTao),
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Ảnh bằng chứng (nếu có)
                                        if (urlAnh.isNotEmpty) ...[
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              height: 160,
                                              width: double.infinity,
                                              color: Colors.grey.shade100,
                                              child: Image.network(
                                                urlAnh,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Center(
                                                  child: Icon(Icons.broken_image_outlined,
                                                      size: 40, color: Colors.grey.shade400),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],

                                        // Hộp phân tích chi tiết AI / dHash
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blueGrey.shade200),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.psychology_outlined,
                                                  size: 20, color: Colors.blueGrey.shade700),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item.moTaChiTiet,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blueGrey.shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        // Thông tin chủ trọ vi phạm & phòng trọ
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.person_pin_outlined, size: 18),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      '${context.t('Chủ trọ:')} ${item.tenChuTro ?? item.userId}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                    ),
                                                  ),
                                                  if (item.trangThaiKhoaChuTro)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.shade100,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        context.t('Đã khóa'),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.red.shade800,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (item.soDienThoaiChuTro != null && item.soDienThoaiChuTro!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${context.t('SĐT:')} ${item.soDienThoaiChuTro}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                ),
                                              ],
                                              if (item.emailChuTro != null && item.emailChuTro!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${context.t('Email:')} ${item.emailChuTro}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                ),
                                              ],
                                              if (item.phongTroId != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${context.t('Phòng trọ liên quan:')} #${item.phongTroId} - ${item.tieuDePhongTro ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blue.shade800,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // Hàng nút hành động
                                        if (!item.daXuLy) ...[
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _xuLyCanhBao(item, khoaTaiKhoan: false),
                                                  icon: const Icon(Icons.done_all, size: 16),
                                                  label: Text(context.t('Bỏ qua / Đã xử lý')),
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: FilledButton.icon(
                                                  onPressed: item.trangThaiKhoaChuTro
                                                      ? null
                                                      : () => _xuLyCanhBao(item, khoaTaiKhoan: true),
                                                  icon: const Icon(Icons.lock_person_outlined, size: 16),
                                                  label: Text(context.t('Khóa tài khoản')),
                                                  style: FilledButton.styleFrom(
                                                    backgroundColor: Colors.red.shade700,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

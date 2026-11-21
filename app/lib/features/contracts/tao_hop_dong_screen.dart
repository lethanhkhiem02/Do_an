import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'chi_tiet_hop_dong_screen.dart';

/// Giống AddMonths của .NET: ngày 31/01 + 1 tháng ra 28/02 chứ không nhảy sang tháng sau.
DateTime ketThucTheoThang(DateTime batDau, int soThang) {
  final thangDo = DateTime(batDau.year, batDau.month + soThang + 1).subtract(const Duration(days: 1));
  final ngay = batDau.day <= thangDo.day ? batDau.day : thangDo.day;
  return DateTime(batDau.year, batDau.month + soThang, ngay, batDau.hour, batDau.minute);
}

/// Chủ trọ lập hợp đồng cho một phòng đang cho thuê: màn này cho xem trước/// tên + ngày sinh của hai bên trước khi bấm "Lập hợp đồng" (= chữ ký của Bên A).
class TaoHopDongScreen extends StatefulWidget {
  const TaoHopDongScreen({super.key, required this.phongTroId});

  final int phongTroId;

  @override
  State<TaoHopDongScreen> createState() => _TaoHopDongScreenState();
}

class _TaoHopDongScreenState extends State<TaoHopDongScreen> {
  static const List<int> _thoiHan = [3, 6, 12, 24];

  late Future<ContractTenant> _duThao = _tai();
  int _thoiHanThang = 6;
  DateTime _ngayBatDau = DateTime.now();
  bool _dangGui = false;

  Future<ContractTenant> _tai() => context
      .read<Session>()
      .api
      .get('api/hop-dong/khach-thue/${widget.phongTroId}')
      .then(ContractTenant.fromJson);

  Future<void> _chonNgay() async {
    final homNay = DateTime.now();
    final ngay = await showDatePicker(
      context: context,
      initialDate: _ngayBatDau,
      firstDate: homNay.subtract(const Duration(days: 180)),
      lastDate: homNay.add(const Duration(days: 90)),
    );
    if (ngay != null) setState(() => _ngayBatDau = ngay);
  }

  Future<void> _lap() async {
    if (_dangGui) return;
    final dich = context.read<NgonNgu>().d;
    final session = context.read<Session>();

    final chac = await xacNhan(
      context,
      hoi: dich('Tên và ngày sinh của hai bên ở trên đã chính xác? Bấm Lập hợp đồng nghĩa là Bên A ký.'),
      yes: dich('Lập hợp đồng'),
    );
    if (!chac) return;

    setState(() => _dangGui = true);
    try {
      final json = await session.api.post(
        'api/hop-dong',
        body: {
          'phongTroId': widget.phongTroId,
          'thoiHanThang': _thoiHanThang,
          'ngayBatDau': _ngayBatDau.toIso8601String(),
        },
      );
      if (!mounted) return;
      final hopDong = RentalContract.fromJson(json);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ChiTietHopDongScreen(id: hopDong.id)),
      );
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Lập hợp đồng thuê phòng'))),
      body: FutureBuilder<ContractTenant>(
        future: _duThao,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return LoiView(
              thongBao: snapshot.error is ApiException
                  ? (snapshot.error as ApiException).message
                  : context.t('Không đọc được thông tin người thuê.'),
              tai: () => setState(() { _duThao = _tai(); }),
            );
          }
          if (!snapshot.hasData) return const NangLuongView();

          final dd = snapshot.data!;
          final thieuNgaySinh = dd.ngaySinhBenA == null || dd.ngaySinhBenB == null;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dd.diaChiPhong, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (dd.tenPhong?.isNotEmpty == true)
                        Text(dd.tenPhong!, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700)),
                      Text('${context.t('Giá thuê')}: ${Fmt.tien(dd.giaThue)} / ${context.t('tháng')}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _BenCard(
                nhan: context.t('BÊN A (BÊN CHO THUÊ)'),
                ten: dd.tenBenA,
                ngaySinh: dd.ngaySinhBenA,
              ),
              const SizedBox(height: 8),
              _BenCard(
                nhan: context.t('BÊN B (BÊN THUÊ)'),
                ten: dd.tenBenB,
                ngaySinh: dd.ngaySinhBenB,
              ),
              if (thieuNgaySinh) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.t(
                            'Một trong hai bên chưa có ngày sinh trong hồ sơ. Hợp đồng vẫn lập được '
                            'nhưng ô ngày sinh sẽ trống, bên đó nên bổ sung ở mục Cá nhân.',
                          ),
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _thoiHanThang,
                decoration: InputDecoration(
                  labelText: context.t('Thời hạn thuê'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final thang in _thoiHan)
                    DropdownMenuItem(value: thang, child: Text(dem(thang, 'tháng')))
                ],
                onChanged: (value) => setState(() => _thoiHanThang = value ?? _thoiHanThang),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _chonNgay,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.t('Ngày bắt đầu'),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(Fmt.ngay(_ngayBatDau, gio: false)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${context.t('Ngày kết thúc')}: '
                '${Fmt.ngay(ketThucTheoThang(_ngayBatDau, _thoiHanThang), gio: false)}',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _dangGui ? null : _lap,
                  icon: _dangGui
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.description_outlined),
                  label: Text(context.t('Lập hợp đồng')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BenCard extends StatelessWidget {
  const _BenCard({required this.nhan, required this.ten, required this.ngaySinh});

  final String nhan;
  final String ten;
  final DateTime? ngaySinh;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.blueGrey.shade50,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(nhan, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(ten, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${context.t('Ngày sinh')}: ${Fmt.ngay(ngaySinh, gio: false)}'),
        ],
      ),
    ),
  );
}

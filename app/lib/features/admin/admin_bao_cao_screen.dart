import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Danh sách báo cáo lừa đảo từ người dùng, đánh dấu đã xử lý giống trang web.
class AdminBaoCaoScreen extends StatefulWidget {
  const AdminBaoCaoScreen({super.key});

  @override
  State<AdminBaoCaoScreen> createState() => _AdminBaoCaoScreenState();
}

class _AdminBaoCaoScreenState extends State<AdminBaoCaoScreen> {
  bool _chiChuaXuLy = true;
  late Future<List<AdminReport>> _danhSach = _tai();

  Future<List<AdminReport>> _tai() => context
      .read<Session>()
      .api
      .get('api/admin/bao-cao', query: {'chiChuaXuLy': _chiChuaXuLy})
      .then((json) => (json as List).map(AdminReport.fromJson).toList());

  Future<void> _daXuLy(AdminReport baoCao) async {
    try {
      final json = await context.read<Session>().api.post('api/admin/bao-cao/${baoCao.id}/da-xu-ly');
      if (!mounted) return;
      bao(context: context, message: json is Map ? '${json['message']}' : context.t('Đã đánh dấu xử lý.'));
      setState(() { _danhSach = _tai(); });
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Báo cáo vi phạm')),
        actions: [IconButton(onPressed: () => setState(() { _danhSach = _tai(); }), icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Switch(
                  value: _chiChuaXuLy,
                  onChanged: (value) => setState(() {
                    _chiChuaXuLy = value;
                    _danhSach = _tai();
                  }),
                ),
                Text(context.t('Chỉ hiện báo cáo chưa xử lý')),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AdminReport>>(
              future: _danhSach,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return LoiView(
                    thongBao: snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : context.t('Không tải được báo cáo.'),
                    tai: () => setState(() { _danhSach = _tai(); }),
                  );
                }
                if (!snapshot.hasData) return const NangLuongView();
                if (snapshot.data!.isEmpty) {
                  return TrongView(
                    icon: Icons.flag_outlined,
                    chuThich: context.t('Không có báo cáo nào. Cộng đồng đang an toàn 👍'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, chiSo) {
                    final baoCao = snapshot.data![chiSo];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    baoCao.lyDo,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                Text(Fmt.tuNho(baoCao.ngayBaoCao),
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            if ((baoCao.chiTiet ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(baoCao.chiTiet!),
                            ],
                            const SizedBox(height: 8),
                            Text('${context.t('Người báo cáo:')} ${baoCao.nguoiBaoCao ?? context.t('Không rõ')}',
                                style: Theme.of(context).textTheme.bodySmall),
                            if ((baoCao.nguoiBiBaoCao ?? '').isNotEmpty)
                              Text('${context.t('Bị báo cáo:')} ${baoCao.nguoiBiBaoCao}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            if (baoCao.diaChiPhong != null)
                              Text(
                                  '${context.t('Phòng')}: ${baoCao.diaChiPhong} (${context.t('chủ trọ')} ${baoCao.chuTroCuaPhong ?? '?'})',
                                  style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: baoCao.daXuLy
                                  ? Text(context.t('Đã xử lý'),
                                      style: const TextStyle(color: Colors.green))
                                  : FilledButton.tonal(
                                      onPressed: () => _daXuLy(baoCao),
                                      child: Text(context.t('Đánh dấu đã xử lý')),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

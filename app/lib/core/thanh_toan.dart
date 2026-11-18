import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'localization.dart';
import 'session.dart';

/// VNPay chỉ chạy trên trình duyệt nên app mở link thanh toán rồi quay lại
/// poll backend (đã port nguyên logic callback của web) để biết giao dịch thành công chưa.
class ThanhToan {
  /// Trả về true nếu backend ghi nhận giao dịch, false nếu người dùng bỏ giữa chừng.
  static Future<bool> chi(
    BuildContext context, {
    required Session session,
    required String endpoint,
    required String tenGiaoDich,
    Object? body,
    int? phongId,
    double? soDuTruoc,
  }) async {
    PaymentUrl thanhToan;
    try {
      thanhToan = PaymentUrl.fromJson(await session.api.post(endpoint, body: body));
    } on ApiException catch (e) {
      _bao(context, e.message, loi: true);
      return false;
    }

    if (!await _moTrinhDuyet(thanhToan.url)) {
      _bao(context, context.t('Không mở được trình duyệt để thanh toán.'), loi: true);
      return false;
    }

    final ketQua = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _TheoDoiDialog(
        session: session,
        tenGiaoDich: tenGiaoDich,
        phongId: phongId,
        soDuTruoc: soDuTruoc,
      ),
    );

    return ketQua ?? false;
  }

  static Future<bool> _moTrinhDuyet(String url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }

  static Future<bool> _daXong(Session session, int? phongId, double? soDuTruoc) async {
    if (phongId != null) {
      final status = PaymentStatus.fromJson(
        await session.api.get('api/thanhtoan/trang-thai-phong/$phongId'),
      );
      return switch (status.trangThai) {
        'DaChoThue' || 'DaDatCoc' => true,
        _ => false,
      };
    }
    final vi = Wallet.fromJson(await session.api.get('api/thanhtoan/vi'));
    return soDuTruoc == null || vi.soDu > soDuTruoc;
  }

  static void _bao(BuildContext context, String message, {bool loi = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: loi ? Colors.red.shade700 : null));
  }
}

class _TheoDoiDialog extends StatefulWidget {
  const _TheoDoiDialog({
    required this.session,
    required this.tenGiaoDich,
    this.phongId,
    this.soDuTruoc,
  });

  final Session session;
  final String tenGiaoDich;
  final int? phongId;
  final double? soDuTruoc;

  @override
  State<_TheoDoiDialog> createState() => _TheoDoiDialogState();
}

class _TheoDoiDialogState extends State<_TheoDoiDialog> {
  Timer? _poll;
  bool _dangKiemTra = false;
  int _daTho = 0;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _kiemTra());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _kiemTra() async {
    if (_dangKiemTra) return;
    setState(() => _dangKiemTra = true);
    bool xong = false;
    try {
      xong = await ThanhToan._daXong(widget.session, widget.phongId, widget.soDuTruoc);
    } on ApiException {
      // backend chưa ghi nhận hoặc mất mạng, lần poll kế tiếp sẽ thử lại
    }
    if (!mounted) return;
    setState(() {
      _dangKiemTra = false;
      _daTho++;
    });
    if (xong) {
      _poll?.cancel();
      Navigator.pop(context, true);
    } else if (_daTho >= 40) {
      _poll?.cancel();
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${context.t('Thanh toán')} ${widget.tenGiaoDich}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            context.t(
              'Trình duyệt đã mở trang VNPay.\nKhi thanh toán xong, quay lại app để hệ thống ghi nhận giao dịch.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _daTho == 0
                ? context.t('Đang chờ phản hồi từ máy chủ...')
                : '${context.t('Đã kiểm tra')} ${dem(_daTho, 'lần.')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.t('Hủy thanh toán')),
        ),
        FilledButton(
          onPressed: _dangKiemTra ? null : _kiemTra,
          child: Text(context.t('Tôi đã trả xong')),
        ),
      ],
    );
  }
}

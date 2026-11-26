import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'localization.dart';
import 'session.dart';

/// VNPay chỉ chạy trên trình duyệt nên app nhúng thẳng trang thanh toán vào một
/// màn hình của chính nó. Mở Chrome ra ngoài thì không kéo app quay lại được
/// (Android 10+ chặn app đang chạy nền tự hiện ra trước màn hình), còn nhúng
/// WebView thì app tự pop về trang phòng trọ ngay khi backend ghi nhận tiền.
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
      if (context.mounted) _bao(context, e.message, loi: true);
      return false;
    }

    if (!context.mounted) return false;
    final duoc = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _TrangThanhToan(
          session: session,
          url: thanhToan.url,
          tenGiaoDich: tenGiaoDich,
          phongId: phongId,
          soDuTruoc: soDuTruoc,
        ),
      ),
    );

    return duoc ?? false;
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

class _TrangThanhToan extends StatefulWidget {
  const _TrangThanhToan({
    required this.session,
    required this.url,
    required this.tenGiaoDich,
    this.phongId,
    this.soDuTruoc,
  });

  final Session session;
  final String url;
  final String tenGiaoDich;
  final int? phongId;
  final double? soDuTruoc;

  @override
  State<_TrangThanhToan> createState() => _TrangThanhToanState();
}

class _TrangThanhToanState extends State<_TrangThanhToan> {
  late final WebViewController _controller;
  Timer? _poll;
  bool _dangKiemTra = false;
  bool _daVe = false;
  int? _tienDo;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (g) {
            if (mounted) setState(() => _tienDo = g);
          },
          // Trang callback ghi tiền vào DB trước khi trình bày trang, nên vừa tải
          // xong là hỏi kết quả được ngay, không phải chờ tới nhịp poll kế tiếp.
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _tienDo = null);
            _kiemTra();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _kiemTra());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _kiemTra() async {
    if (_dangKiemTra || _daVe) return;
    _dangKiemTra = true;

    bool xong = false;
    try {
      xong = await ThanhToan._daXong(widget.session, widget.phongId, widget.soDuTruoc);
    } catch (_) {
      // Mất mạng hay backend chưa ghi nhận thì lần kiểm tra sau sẽ thử lại.
      // Không bắt riêng ApiException: TimeoutException lọt ra ngoài sẽ làm
      // _dangKiemTra kẹt ở true và màn hình không bao giờ nhận ra đã trả xong.
    }
    _dangKiemTra = false;
    if (!mounted || _daVe) return;

    if (xong) {
      _daVe = true;
      _poll?.cancel();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${context.t('Thanh toán')} ${widget.tenGiaoDich}'),
        bottom: _tienDo == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(value: (_tienDo! / 100).clamp(0.0, 1.0)),
              ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

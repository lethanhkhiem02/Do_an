import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/pick_anh.dart';
import '../../core/session.dart';
import '../../core/signalr_chat.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// Chat 1-1 với một người dùng khác (thường là chủ trọ).
/// Lịch sử lấy từ /api/chat, tin realtime nhận qua Hub /chatHub của backend web.
class TroChuyenScreen extends StatefulWidget {
  const TroChuyenScreen({
    super.key,
    required this.nguoiKhacId,
    required this.tenNguoiKhac,
    this.avatarNguoiKhac,
    this.tinNhanBanDau,
  });

  final String nguoiKhacId;
  final String tenNguoiKhac;
  final String? avatarNguoiKhac;
  final String? tinNhanBanDau;

  @override
  State<TroChuyenScreen> createState() => _TroChuyenScreenState();
}

class _TroChuyenScreenState extends State<TroChuyenScreen> {
  static const List<String> _lyDoBaoCao = [
    'Lừa đảo tiền cọc',
    'Tin nhắn rác / quảng cáo',
    'Thái độ không tốt, đe dọa',
    'Giả mạo thông tin',
    'Khác',
  ];

  final _scroll = ScrollController();
  final _nhap = TextEditingController();

  List<ChatMessage> _tinNhan = [];
  bool _dangTai = true;
  bool _doiPhuongDangGo = false;
  String? _loi;
  StreamSubscription<PrivateMessage>? _nhanTin;
  StreamSubscription<TypingState>? _nhanGao;
  Timer? _throttleGao;

  @override
  void initState() {
    super.initState();
    if (widget.tinNhanBanDau != null && widget.tinNhanBanDau!.trim().isNotEmpty) {
      _nhap.text = widget.tinNhanBanDau!.trim();
    }
    _taiLichSu();
    _dangKyHub();
    _nhap.addListener(_thongBaoDangGo);
  }

  @override
  void dispose() {
    _nhanTin?.cancel();
    _nhanGao?.cancel();
    _throttleGao?.cancel();
    _nhap.removeListener(_thongBaoDangGo);
    _nhap.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _dangKyHub() {
    final chat = context.read<SignalRChat>();
    chat.ketNoi();
    final cuaMinh = context.read<Session>().user?.id;

    _nhanTin = chat.onPrivateMessage.listen((tin) {
      // Tin của chính mình: hub gửi lại cho caller, app đã render sẵn khi bấm gửi.
      if (tin.senderId == cuaMinh) return;
      if (tin.senderId != widget.nguoiKhacId || !mounted) return;
      setState(() {
        _tinNhan = [..._tinNhan, ChatMessage(noiDung: tin.content, thoiGian: DateTime.now(), tenNguoiGui: widget.tenNguoiKhac)];
        _doiPhuongDangGo = false;
      });
      _cuonXuoi();
    });

    _nhanGao = chat.onTyping.listen((gao) {
      if (gao.senderId != widget.nguoiKhacId || !mounted) return;
      setState(() => _doiPhuongDangGo = gao.isTyping);
    });
  }

  Future<void> _taiLichSu() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final json = await context.read<Session>().api.get('api/chat/lich-su/${widget.nguoiKhacId}');
      setState(() {
        _tinNhan = (json as List).map(ChatMessage.fromJson).toList();
        _dangTai = false;
      });
      _cuonXuoi();
    } on ApiException catch (e) {
      setState(() {
        _loi = e.message;
        _dangTai = false;
      });
    }
  }

  void _cuonXuoi() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _thongBaoDangGo() {
    _throttleGao?.cancel();
    _throttleGao = Timer(const Duration(milliseconds: 900), () {
      final myId = context.read<Session>().user?.id;
      if (myId == null) return;
      context.read<SignalRChat>().invoke('SendTypingState', [myId, widget.nguoiKhacId, _nhap.text.isNotEmpty]);
    });
  }

  Future<void> _gui({String? noiDung}) async {
    const cocNhat = 'api/chat/gui';
    final body = {
      'receiverId': widget.nguoiKhacId,
      'content': noiDung ?? _nhap.text.trim(),
    };
    if ((noiDung ?? _nhap.text).trim().isEmpty) return;

    setState(() => _nhap.clear());
    try {
      final json = await context.read<Session>().api.post(cocNhat, body: body);
      setState(() {
        _tinNhan = [..._tinNhan, ChatMessage.fromJson(json)];
      });
      _cuonXuoi();
    } on ApiException catch (e) {
      bao(context: context, message: e.message, loi: true);
    }
  }

  Future<void> _guiAnh() async {
    final anh = await PickAnh.one(field: 'file');
    if (anh == null) return;
    try {
      final json = await context.read<Session>().api.upload('api/chat/upload-anh', files: [anh]);
      final duongDan = json is Map ? '${json['imageUrl'] ?? ''}' : '';
      if (duongDan.isEmpty) throw ApiException(500, context.t('Backend không trả về đường dẫn ảnh.'));
      await _gui(noiDung: '[IMG]:$duongDan');
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    }
  }

  Future<void> _baoCao() async {
    String lyDo = _lyDoBaoCao.first;
    final chiTiet = TextEditingController();

    final gui = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, rebuild) => AlertDialog(
          title: Text('${context.t('Báo cáo')} ${widget.tenNguoiKhac}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: lyDo,
                decoration: InputDecoration(
                  labelText: context.t('Lý do'),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final reason in _lyDoBaoCao)
                    DropdownMenuItem(value: reason, child: Text(context.t(reason)))
                ],
                onChanged: (value) => rebuild(() => lyDo = value ?? lyDo),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: chiTiet,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.t('Chi tiết'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.t('Hủy')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.t('Gửi Admin')),
            ),
          ],
        ),
      ),
    );

    if (gui == true) {
      try {
        await context.read<Session>().api.post(
          'api/chat/bao-cao-nguoi-dung',
          body: {'nguoiBiBaoCaoId': widget.nguoiKhacId, 'lyDo': lyDo, 'chiTiet': chiTiet.text.trim()},
        );
        if (mounted) bao(context: context, message: context.t('Đã gửi báo cáo tới Admin.'));
      } on ApiException catch (e) {
        if (mounted) bao(context: context, message: e.message, loi: true);
      }
    }
    chiTiet.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<SignalRChat>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tenNguoiKhac, style: const TextStyle(fontSize: 16)),
            Text(
              _doiPhuongDangGo
                  ? context.t('Đang soạn tin...')
                  : switch (chat.trangThai) {
                      KetNoi.san => context.t('Đang trực tuyến'),
                      KetNoi.dangKetNoi => context.t('Đang kết nối server chat...'),
                      _ => context.t('Chỉ hiển thị tin đã gửi'),
                    },
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _baoCao,
            tooltip: context.t('Báo cáo người dùng'),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _dangTai
                ? const NangLuongView()
                : _loi != null
                ? LoiView(thongBao: _loi!, tai: _taiLichSu)
                : _tinNhan.isEmpty
                ? TrongView(icon: Icons.forum_outlined, chuThich: context.t('Chưa có tin nhắn nào. Hãy gửi tin đầu tiên!'))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _tinNhan.length,
                    itemBuilder: (context, chiSo) => _BongBong(tin: _tinNhan[chiSo]),
                  ),
          ),
          _ThanhNhap(
            controller: _nhap,
            onGui: _gui,
            onGuiAnh: _guiAnh,
          ),
        ],
      ),
    );
  }
}

class _BongBong extends StatelessWidget {
  const _BongBong({required this.tin});

  final ChatMessage tin;

  @override
  Widget build(BuildContext context) {
    final cuaMinh = tin.cuaMinh;

    return Align(
      alignment: cuaMinh ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        decoration: BoxDecoration(
          color: cuaMinh ? NhaCai.mauChuDao : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(cuaMinh ? 14 : 4),
            bottomRight: Radius.circular(cuaMinh ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: cuaMinh ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!cuaMinh && (tin.tenNguoiGui ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(tin.tenNguoiGui!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            if (tin.laTinHinh)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AnhPhongTro(duongDan: tin.noiDungHienThi, height: 190, fit: BoxFit.cover),
                ),
              )
            else
              Text(
                tin.noiDung,
                style: TextStyle(color: cuaMinh ? Colors.white : Colors.black87),
              ),
            Text(
              Fmt.gio(tin.thoiGian),
              style: TextStyle(fontSize: 10, color: cuaMinh ? Colors.white70 : Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThanhNhap extends StatelessWidget {
  const _ThanhNhap({required this.controller, required this.onGui, required this.onGuiAnh});

  final TextEditingController controller;
  final Future<void> Function() onGui;
  final VoidCallback onGuiAnh;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: session.user?.trangThaiKhoa == true
            ? Text(context.t('Tài khoản của bạn đã bị khóa nên không thể gửi tin nhắn.'),
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))
            : Row(
                children: [
                  IconButton(
                    onPressed: onGuiAnh,
                    icon: const Icon(Icons.image_outlined),
                    tooltip: context.t('Gửi ảnh'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onGui(),
                      decoration: InputDecoration(
                        hintText: context.t('Nhập tin nhắn...'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: onGui,
                    icon: const Icon(Icons.send),
                    style: IconButton.styleFrom(backgroundColor: NhaCai.mauChuDao),
                  ),
                ],
              ),
      ),
    );
  }
}

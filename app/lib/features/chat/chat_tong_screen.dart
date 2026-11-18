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

/// Chat cộng đồng: mọi người dùng cùng thấy, dùng lại bảng tin [GLOBAL_*] của web.
class ChatTongScreen extends StatefulWidget {
  const ChatTongScreen({super.key});

  @override
  State<ChatTongScreen> createState() => _ChatTongScreenState();
}

class _ChatTongScreenState extends State<ChatTongScreen> {
  final _scroll = ScrollController();
  final _nhap = TextEditingController();

  List<ChatMessage> _tinNhan = [];
  bool _dangTai = true;
  String? _loi;
  StreamSubscription<GlobalMessage>? _nhanTin;

  @override
  void initState() {
    super.initState();
    _taiLichSu();
    final chat = context.read<SignalRChat>();
    chat.ketNoi();
    _nhanTin = chat.onGlobalMessage.listen(_nhan);
  }

  @override
  void dispose() {
    _nhanTin?.cancel();
    _nhap.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _nhan(GlobalMessage tin) {
    if (!mounted) return;
    // Server phát lại cho cả người gửi; app đã thêm bong bóng khi bấm gửi nên bỏ trùng.
    if (_tinNhan.isNotEmpty && _tinNhan.last.noiDung == tin.content && _tinNhan.last.tenNguoiGui == tin.user) {
      return;
    }
    setState(() {
      _tinNhan = [
        ..._tinNhan,
        ChatMessage(
          noiDung: tin.content,
          thoiGian: DateTime.now(),
          tenNguoiGui: tin.user,
        ),
      ];
    });
    _cuonXuoi();
  }

  Future<void> _taiLichSu() async {
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    try {
      final json = await context.read<Session>().api.get('api/chat/chat-tong');
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

  Future<void> _gui(String noiDung, {String loai = 'text'}) async {
    try {
      await context.read<Session>().api.post(
        'api/chat/chat-tong',
        body: {'type': loai, 'content': noiDung},
      );
      if (!mounted) return;
      final ten = context.read<Session>().tenHienThi;
      setState(() {
        _tinNhan = [
          ..._tinNhan,
          ChatMessage(noiDung: noiDung, thoiGian: DateTime.now(), tenNguoiGui: ten, cuaMinh: true),
        ];
      });
      _cuonXuoi();
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    }
  }

  Future<void> _guiText() async {
    final noiDung = _nhap.text.trim();
    if (noiDung.isEmpty) return;
    _nhap.clear();
    await _gui(noiDung);
  }

  Future<void> _guiAnh() async {
    final anh = await PickAnh.one(field: 'file');
    if (anh == null) return;
    try {
      final json = await context.read<Session>().api.upload('api/chat/upload-anh', files: [anh]);
      final duongDan = json is Map ? '${json['imageUrl'] ?? ''}' : '';
      if (duongDan.isEmpty) {
        if (mounted) bao(context: context, message: context.t('Backend không trả về đường dẫn ảnh.'), loi: true);
        return;
      }
      await _gui(duongDan, loai: 'image');
    } on ApiException catch (e) {
      if (mounted) bao(context: context, message: e.message, loi: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    return Scaffold(
      appBar: AppBar(title: Text(context.t('Chat cộng đồng RoomFinder'))),
      body: Column(
        children: [
          Expanded(
            child: _dangTai
                ? const NangLuongView()
                : _loi != null
                ? LoiView(thongBao: _loi!, tai: _taiLichSu)
                : _tinNhan.isEmpty
                ? TrongView(
                    icon: Icons.campaign_outlined,
                    chuThich: context.t(
                      'Bảng tin cộng đồng đang trống.\nChia sẻ kinh nghiệm tìm trọ với các bạn sinh viên!',
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _tinNhan.length,
                    itemBuilder: (context, chiSo) {
                      final tin = _tinNhan[chiSo];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnhDaiDien(hoTen: tin.tenNguoiGui, kichThuoc: 38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        tin.tenNguoiGui ?? context.t('Ẩn danh'),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(Fmt.gio(tin.thoiGian),
                                          style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  if (tin.laTinHinh)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: AnhPhongTro(duongDan: tin.noiDungHienThi, height: 200),
                                    )
                                  else
                                    Text(tin.noiDung),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
              child: session.user?.trangThaiKhoa == true
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(context.t('Tài khoản đã bị khóa nên không thể gửi tin.'),
                          textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    )
                  : Row(
                      children: [
                        IconButton(
                          onPressed: _guiAnh,
                          tooltip: context.t('Gửi ảnh'),
                          icon: const Icon(Icons.image_outlined),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _nhap,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _guiText(),
                            decoration: InputDecoration(
                              hintText: context.t('Nói gì đó với cộng đồng...'),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          onPressed: _guiText,
                          icon: const Icon(Icons.send),
                          style: IconButton.styleFrom(backgroundColor: NhaCai.mauChuDao),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

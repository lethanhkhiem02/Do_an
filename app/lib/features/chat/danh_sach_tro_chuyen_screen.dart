import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/formatting.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../core/signalr_chat.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'chat_tong_screen.dart';
import 'tro_chuyen_screen.dart';

/// Tab "Tin nhắn": danh sách cuộc trò chuyện riêng, giống khung chat của web.
class DanhSachTroChuyenScreen extends StatefulWidget {
  const DanhSachTroChuyenScreen({super.key});

  @override
  State<DanhSachTroChuyenScreen> createState() => _DanhSachTroChuyenScreenState();
}

class _DanhSachTroChuyenScreenState extends State<DanhSachTroChuyenScreen> {
  late Future<List<Conversation>> _danhSach = _tai();

  @override
  void initState() {
    super.initState();
    context.read<SignalRChat>().ketNoi();
  }

  Future<List<Conversation>> _tai() => context
      .read<Session>()
      .api
      .get('api/chat/hoi-thoai')
      .then((json) => (json as List).map(Conversation.fromJson).toList());

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<SignalRChat>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('Tin nhắn')),
        actions: [
          IconButton(
            tooltip: context.t('Chat cộng đồng'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatTongScreen()),
            ),
            icon: const Icon(Icons.groups_outlined),
          ),
          IconButton(onPressed: () => setState(() => _danhSach = _tai()), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          if (chat.trangThai != KetNoi.san)
            Material(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, size: 18, color: Colors.deepOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t(
                          'Chưa kết nối được server chat, tin nhắn mới sẽ không tự hiện. Bấm nút nạp lại để thử.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Conversation>>(
              future: _danhSach,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return LoiView(
                    thongBao: snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : context.t('Không tải được tin nhắn.'),
                    tai: () => setState(() => _danhSach = _tai()),
                  );
                }
                if (!snapshot.hasData) return const NangLuongView();
                if (snapshot.data!.isEmpty) {
                  return TrongView(
                    icon: Icons.forum_outlined,
                    chuThich: context.t(
                      'Chưa có cuộc trò chuyện nào.\nVào chi tiết một phòng trọ và bấm "Chat" để nhắn chủ trọ.',
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, chiSo) {
                    final hoiThoai = snapshot.data![chiSo];
                    return ListTile(
                      leading: AnhDaiDien(tenFile: hoiThoai.avatar, hoTen: hoiThoai.hoTen),
                      title: Text(hoiThoai.hoTen, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        hoiThoai.tinNhan ?? context.t('(tin nhắn ảnh)'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(Fmt.tuNho(hoiThoai.thoiGianNhan),
                          style: Theme.of(context).textTheme.bodySmall),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TroChuyenScreen(
                              nguoiKhacId: hoiThoai.userId,
                              tenNguoiKhac: hoiThoai.hoTen,
                              avatarNguoiKhac: hoiThoai.avatar,
                            ),
                          ),
                        );
                        if (mounted) setState(() => _danhSach = _tai());
                      },
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

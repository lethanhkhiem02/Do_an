import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/dich.dart';
import '../../core/localization.dart';
import '../../core/session.dart';
import '../../widgets/common.dart';

/// Trợ lý tự động của RoomFinder, cùng bộ kịch bản với chatbot nổi trên web
/// (HomeController.ChatWithAI). App chỉ gọi endpoint đó, không lưu lịch sử.
class TroLyAoScreen extends StatefulWidget {
  const TroLyAoScreen({super.key});

  @override
  State<TroLyAoScreen> createState() => _TroLyAoScreenState();
}

class _TroLyAoScreenState extends State<TroLyAoScreen> {
  static const String _cocNhat = 'Home/ChatWithAI';

  final _nhap = TextEditingController();
  final _scroll = ScrollController();
  final List<_Tin> _tinNhan = [
    _Tin(
      tuBot: true,
      noiDung: x(
        '👋 Xin chào! Mình là Trợ lý tự động RoomFinder. Bạn cứ hỏi về giá thuê, diện tích, '
        'tiện ích, đặt cọc, tin VIP hay cách tìm trọ gần trường nhé.',
      ),
    ),
  ];
  bool _dangGui = false;

  @override
  void dispose() {
    _nhap.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _gui() async {
    final cauHoi = _nhap.text.trim();
    if (cauHoi.isEmpty || _dangGui) return;

    setState(() {
      _tinNhan.add(_Tin(noiDung: cauHoi));
      _nhap.clear();
      _dangGui = true;
    });
    _cuonXuoi();

    String traLoi;
    try {
      final json = await context.read<Session>().api.get(_cocNhat, query: {'message': cauHoi});
      traLoi = json is Map ? '${json['reply'] ?? ''}' : '';
      if (traLoi.isEmpty) throw ApiException(500, context.t('Trợ lý không trả lời, thử lại sau nhé.'));
    } on ApiException catch (e) {
      traLoi = '⚠️ ${e.message}';
    }

    setState(() {
      _tinNhan.add(_Tin(tuBot: true, noiDung: traLoi));
      _dangGui = false;
    });
    _cuonXuoi();
  }

  void _cuonXuoi() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t('Trợ lý RoomFinder'))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _tinNhan.length + (_dangGui ? 1 : 0),
              itemBuilder: (context, chiSo) {
                if (chiSo >= _tinNhan.length)
                  return _BongBong(tin: _Tin(tuBot: true, noiDung: context.t('Đang soạn tin...')));
                return _BongBong(tin: _tinNhan[chiSo]);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nhap,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _gui(),
                      decoration: InputDecoration(
                        hintText: context.t('Nhập câu hỏi cho trợ lý...'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _dangGui ? null : _gui,
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

class _Tin {
  const _Tin({this.noiDung = '', this.tuBot = false});

  final String noiDung;
  final bool tuBot;
}

class _BongBong extends StatelessWidget {
  const _BongBong({required this.tin});

  final _Tin tin;

  @override
  Widget build(BuildContext context) {
    final tuBot = tin.tuBot;

    return Align(
      alignment: tuBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
        decoration: BoxDecoration(
          color: tuBot ? Colors.grey.shade200 : NhaCai.mauChuDao,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(tuBot ? 4 : 14),
            bottomRight: Radius.circular(tuBot ? 14 : 4),
          ),
        ),
        child: Text(
          tin.noiDung,
          style: TextStyle(fontSize: 14, color: tuBot ? Colors.black87 : Colors.white),
        ),
      ),
    );
  }
}

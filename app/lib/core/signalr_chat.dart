import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'app_config.dart';

/// Tin nhắn 1-1 hub đẩy xuống ("ReceivePrivateMessage").
class PrivateMessage {
  const PrivateMessage({
    required this.senderId,
    required this.content,
    required this.time,
  });

  factory PrivateMessage.fromArgs(List args) => PrivateMessage(
    senderId: '${args[0]}',
    content: '${args[1]}',
    time: '${args[2]}',
  );

  final String senderId;
  final String content;
  final String time;
}

/// Tin chat tổng ("ReceiveGlobalMessage"), payload là object {User, Type, Content, Time}.
class GlobalMessage {
  const GlobalMessage({
    required this.user,
    required this.type,
    required this.content,
    required this.time,
  });

  factory GlobalMessage.fromJson(Map json) => GlobalMessage(
    user: '${json['User'] ?? ''}',
    type: '${json['Type'] ?? ''}',
    content: '${json['Content'] ?? ''}',
    time: '${json['Time'] ?? ''}',
  );

  final String user;
  final String type;
  final String content;
  final String time;
}

class TypingState {
  const TypingState({required this.senderId, required this.isTyping});

  factory TypingState.fromArgs(List args) =>
      TypingState(senderId: '${args[0]}', isTyping: args[1] == true);

  final String senderId;
  final bool isTyping;
}

/// Sự kiện thông báo hub đẩy xuống ("ReceiveThongBao").
/// Server chỉ gửi mã sự kiện, không gửi câu chữ, vì bản dịch phải theo
/// Accept-Language của chính người nhận nên app phải gọi lại api/thong-bao.
class ThongBaoMoi {
  const ThongBaoMoi({required this.id, required this.loai, this.maLichXemPhong});

  factory ThongBaoMoi.fromJson(Map json) => ThongBaoMoi(
    id: (json['id'] as num?)?.toInt() ?? 0,
    loai: '${json['loai'] ?? ''}',
    maLichXemPhong: (json['maLichXemPhong'] as num?)?.toInt(),
  );

  final int id;
  final String loai;
  final int? maLichXemPhong;
}

enum KetNoi { ngat, dangKetNoi, san, chayThoi }

/// Client SignalR tối giản chạy trên WebSocket.
/// Thư viện `signalr` trên pub.dev chưa hỗ trợ null safety nên app tự nói
/// chuyện trực tiếp với Hub `/chatHub` của đồ án cơ sở theo JSON protocol v1.
class SignalRChat extends ChangeNotifier {
  SignalRChat({required this.layToken});

  final String? Function() layToken;

  static const String _delimiter = '\u001e';

  WebSocketChannel? _socket;
  StreamSubscription? _sub;
  String? _connectionToken;
  bool _coYDinhNgat = false;
  int _invocationId = 0;
  KetNoi _trangThai = KetNoi.ngat;
  Timer? _chong;

  final _tinNhanRieng = StreamController<PrivateMessage>.broadcast();
  final _tinNhanTong = StreamController<GlobalMessage>.broadcast();
  final _dangGo = StreamController<TypingState>.broadcast();
  final _thongBao = StreamController<ThongBaoMoi>.broadcast();

  Stream<PrivateMessage> get onPrivateMessage => _tinNhanRieng.stream;
  Stream<GlobalMessage> get onGlobalMessage => _tinNhanTong.stream;
  Stream<TypingState> get onTyping => _dangGo.stream;
  Stream<ThongBaoMoi> get onThongBao => _thongBao.stream;

  KetNoi get trangThai => _trangThai;
  bool get san => _trangThai == KetNoi.san;

  Future<void> ketNoi() async {
    if (_trangThai == KetNoi.san || _trangThai == KetNoi.dangKetNoi) return;
    if (layToken() == null) return;

    _coYDinhNgat = false;
    _datTrangThai(KetNoi.dangKetNoi);
    try {
      await _negotiate();
      await _moWebSocket();
      _datTrangThai(KetNoi.san);
    } on Object {
      _dongWebSocket();
      _datTrangThai(KetNoi.chayThoi);
      _henNoiLai();
    }
  }

  void ngat() {
    _coYDinhNgat = true;
    _chong?.cancel();
    _dongWebSocket();
    _datTrangThai(KetNoi.ngat);
  }

  /// Gọi Hub method phía server (SendPrivateMessage, SendGlobalMessage, SendTypingState).
  void invoke(String target, List<Object?> args) {
    final socket = _socket;
    if (socket == null || !san) return;
    _gui({
      'type': 1,
      'invocationId': '${++_invocationId}',
      'target': target,
      'arguments': args,
    });
  }

  Future<void> _negotiate() async {
    final token = layToken();
    final response = await http
        .post(
          AppConfig.url('chatHub/negotiate', {'negotiateVersion': '1'}),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Length': '0',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError('Negotiate thất bại (${response.statusCode}).');
    }
    _connectionToken = jsonDecode(response.body)['connectionToken'] as String?;
  }

  Future<void> _moWebSocket() async {
    // Server trả url theo host của chính nó, emulator cần host của mình
    // (10.0.2.2) nên chỉ lấy connectionToken rồi tự ghép địa chỉ.
    final uri = AppConfig.hubUrl(layToken() ?? '');
    final ws = WebSocketChannel.connect(
      _connectionToken == null
          ? uri
          : uri.replace(
              queryParameters: {...uri.queryParameters, 'connectionToken': _connectionToken!},
            ),
    );
    await ws.ready.timeout(const Duration(seconds: 15));
    _socket = ws;

    _gui({'protocol': 'json', 'version': 1});

    final daoTay = Completer<void>();
    _sub = ws.stream.listen(
      (frame) => _xuLyFrame('$frame', daoTay: daoTay),
      onDone: _kyetThuc,
      onError: (_) => _kyetThuc(),
    );

    await daoTay.future.timeout(const Duration(seconds: 15));
  }

  void _gui(Map<String, dynamic> message) {
    final sink = _socket?.sink;
    if (sink == null) return;
    sink.add(jsonEncode(message) + _delimiter);
  }

  void _xuLyFrame(String frame, {Completer<void>? daoTay}) {
    for (final piece in frame.split(_delimiter)) {
      if (piece.trim().isEmpty) continue;
      dynamic json;
      try {
        json = jsonDecode(piece);
      } on FormatException {
        continue;
      }
      if (json is! Map) continue;

      // Bắt tay trả về {} hoặc {"error": "..."}
      if (daoTay != null && !daoTay.isCompleted) {
        if (json['error'] != null) {
          daoTay.completeError(StateError(json['error'].toString()));
        } else {
          daoTay.complete();
        }
        if (json['type'] == null) continue;
      }

      switch (json['type']) {
        case 1:
          _xuLyTin(json['target'] as String?, json['arguments'] as List? ?? const []);
        case 6:
          break; // Ping giữ kết nối
      }
    }
  }

  void _xuLyTin(String? target, List args) {
    switch (target) {
      case 'ReceivePrivateMessage':
        _tinNhanRieng.add(PrivateMessage.fromArgs(args));
      case 'ReceiveGlobalMessage':
        if (args.isNotEmpty && args.first is Map) {
          _tinNhanTong.add(GlobalMessage.fromJson(args.first as Map));
        }
      case 'ReceiveTypingState':
        _dangGo.add(TypingState.fromArgs(args));
      case 'ReceiveThongBao':
        if (args.isNotEmpty && args.first is Map) {
          _thongBao.add(ThongBaoMoi.fromJson(args.first as Map));
        }
    }
  }

  void _kyetThuc() {
    if (_coYDinhNgat) return;
    _dongWebSocket();
    _datTrangThai(KetNoi.chayThoi);
    _henNoiLai();
  }

  void _henNoiLai() {
    if (_coYDinhNgat || _chong?.isActive == true) return;
    _chong = Timer(const Duration(seconds: 4), ketNoi);
  }

  void _dongWebSocket() {
    _sub?.cancel();
    _sub = null;
    try {
      _socket?.sink.close();
    } on Object {
      // socket đã chết trước khi kịp đóng
    }
    _socket = null;
  }

  void _datTrangThai(KetNoi moi) {
    if (_trangThai == moi) return;
    _trangThai = moi;
    notifyListeners();
  }

  @override
  void dispose() {
    ngat();
    _tinNhanRieng.close();
    _tinNhanTong.close();
    _dangGo.close();
    _thongBao.close();
    super.dispose();
  }
}

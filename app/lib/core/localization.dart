import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dich.dart';

// Tái xuất hai hàm đếm để màn nào đã có `context.t` là dùng được ngay, khỏi import thêm.
export 'dich.dart' show dem, demConLai;

/// Ngôn ngữ giao diện của app, lấy theo bộ từ điển vi/en của web đồ án cơ sở.
/// Web lưu lựa chọn vào cookie `.AspNetCore.Culture`; app không có cookie nên
/// lưu vào SharedPreferences và rebuild MaterialApp với locale mới.
class NgonNgu extends ChangeNotifier {
  static const String _key = 'roomfinder.language';
  static const List<String> maHoa = ['vi', 'en'];

  String _ma = 'vi';

  String get ma => _ma;
  Locale get locale => Locale(_ma);
  bool get laTiengAnh => _ma == 'en';

  static Future<NgonNgu> khoiDong() async {
    final nn = NgonNgu();
    final prefs = await SharedPreferences.getInstance();
    final luu = prefs.getString(_key);
    if (luu != null && maHoa.contains(luu)) nn._ma = luu;
    await initializeDateFormatting('vi_VN');
    await initializeDateFormatting('en_US');
    _apDinhDang(nn._ma);
    return nn;
  }

  Future<void> chon(String ma) async {
    if (!maHoa.contains(ma) || ma == _ma) return;
    _ma = ma;
    _apDinhDang(ma);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, ma);
  }

  static void _apDinhDang(String ma) => Intl.defaultLocale = ma == 'en' ? 'en_US' : 'vi_VN';

  /// Trả về bản dịch tiếng Anh nếu đang ở chế độ English, ngược lại giữ nguyên
  /// câu tiếng Việt gốc (câu chưa có trong từ điển cũng giữ nguyên).
  String d(String tiengViet) => x(tiengViet);
}

extension DichTrenContext on BuildContext {
  /// `watch` chỉ hợp lệ khi framework đang build widget. Gọi nó từ callback của
  /// nút bấm (hay sau `await`) sẽ làm provider bắn assertion ở debug mode, và
  /// handler chết trước khi kịp gửi request. Ngoài build thì đọc bằng `read`.
  NgonNgu get ngonNgu {
    try {
      return watch<NgonNgu>();
    } on AssertionError {
      return read<NgonNgu>();
    }
  }

  String t(String tiengViet) => ngonNgu.d(tiengViet);
}

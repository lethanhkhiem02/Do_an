import 'package:intl/intl.dart';

import 'en_dictionary.dart';
import 'en_supplement.dart';

/// App đang chạy bằng tiếng Anh hay tiếng Việt. Đây là tín hiệu duy nhất để
/// các chỗ không có `BuildContext` (ApiClient, Fmt, models) biết đường mà dịch.
bool get dangTiengAnh => Intl.defaultLocale == 'en_US';

/// Giá trị header `Accept-Language` gửi lên backend để chatbot, thông báo lỗi
/// và nội dung phòng trả về đúng ngôn ngữ đang bật trên app.
String get maNgonNguGuiLenServer => dangTiengAnh ? 'en-US,en;q=0.9' : 'vi-VN,vi;q=0.9';

/// Tra bản dịch cho phần code tĩnh (models, Fmt, ApiClient) không cầm `BuildContext`.
/// dựa vào `Intl.defaultLocale` do `NgonNgu` cập nhật mỗi lần đổi ngôn ngữ.
String x(String tiengViet) => dangTiengAnh ? (tuDien[tiengViet] ?? tiengViet) : tiengViet;

/// Tiếng Việt không chia số nhiều, tiếng Anh thì có — và với cụm "minute ago"
/// chữ "s" lại nằm ở đầu cụm chứ không cuối. Vì vậy dạng số nhiều được khai báo
/// tường minh thay vì đoán bằng cách cộng thêm "s".
const Map<String, String> soNhieuTiengAnh = {
  'day': 'days',
  'display day': 'display days',
  'listing': 'listings',
  'minute ago': 'minutes ago',
  'hour ago': 'hours ago',
  'day ago': 'days ago',
  'review': 'reviews',
  'room': 'rooms',
  'amenity': 'amenities',
  'time.': 'times.',
};

/// Gắn một con số với danh từ đi kèm, đúng số ít/số nhiều của từng ngôn ngữ:
/// `dem(1, 'đánh giá')` -> "1 đánh giá" / "1 review", `dem(3, 'đánh giá')` -> "3 reviews".
String dem(int soLuong, String donViSoIt) {
  final don = x(donViSoIt);
  if (!dangTiengAnh || soLuong == 1) return '$soLuong $don';
  return '$soLuong ${soNhieuTiengAnh[don] ?? '${don}s'}';
}

/// Tiếng Việt đặt "Còn" ở đầu cụm, tiếng Anh lại để "left" ở cuối:
/// `demConLai(55, 'ngày hiển thị')` -> "Còn 55 ngày hiển thị" / "55 display days left".
String demConLai(int soLuong, String donViSoIt) => dangTiengAnh
    ? '${dem(soLuong, donViSoIt)} left'
    : '${x('Còn')} ${dem(soLuong, donViSoIt)}';

/// `en_dictionary.dart` sinh tự động từ bộ resx của web, `en_supplement.dart`
/// do tay viết cho các chuỗi chỉ có trong app; chuỗi trùng thì bản của app thắng.
const Map<String, String> tuDien = {
  ...tuDienAnh,
  ...tuDienBoSung,
};

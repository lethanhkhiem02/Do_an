/// Tiền tố và định dạng hiển thị dùng chung toàn app.
library;

import 'package:intl/intl.dart';

import 'dich.dart';

bool get _laTiengAnh => Intl.defaultLocale == 'en_US';

String get _localeCuaDinhDang => _laTiengAnh ? 'en_US' : 'vi_VN';

/// Ba giá trị trạng thái xác thực CCCD đúng như CSDL của web lưu trữ.
class XacThuc {
  static const String chua = 'Chưa xác thực';
  static const String choDuyet = 'Chờ duyệt';
  static const String daDuyet = 'Đã duyệt';

  static const List<String> tatCa = [chua, choDuyet, daDuyet];

  static bool xong(String? trangThai) => trangThai == daDuyet;

  static String nhan(String? trangThai) {
    if (trangThai == daDuyet) return x('Đã xác thực');
    if (trangThai == choDuyet) return choDuyet;
    return chua;
  }
}

class Fmt {
  static final NumberFormat _vnd = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final NumberFormat _soThapPhan = NumberFormat('#,##0.##', 'vi_VN');

  /// 2500000.5 -> "2.500.001 ₫" (giá phòng làm tròn khi hiển thị)
  static String tien(num? gia) => gia == null ? x('Chưa rõ') : _vnd.format(gia.round());

  static String soThapPhan(num? so) => so == null ? '--' : _soThapPhan.format(so);

  static String km(double? khoangCach) {
    if (khoangCach == null) return '';
    if (khoangCach < 1) return '${(khoangCach * 1000).round()} m';
    return '${_soThapPhan.format(khoangCach)} km';
  }

  static String ngay(DateTime? moc, {bool gio = true}) {
    if (moc == null) return '--/--/----';
    final mau = gio && _laTiengAnh ? 'HH:mm dd/MM/yyyy' : 'HH:mm \'ngày\' dd/MM/yyyy';
    return DateFormat(gio ? mau : 'dd/MM/yyyy', _localeCuaDinhDang).format(moc);
  }

  static String gio(DateTime? moc) {
    if (moc == null) return '';
    return DateFormat('HH:mm', _localeCuaDinhDang).format(moc);
  }

  /// "5 phút trước", "2 giờ trước", còn xa thì lùi về ngày/tháng.
  static String tuNho(DateTime? moc) {
    if (moc == null) return '';
    final khac = DateTime.now().difference(moc);
    if (khac.inSeconds < 60) return x('Vừa xong');
    if (khac.inMinutes < 60) return dem(khac.inMinutes, 'phút trước');
    if (khac.inHours < 24) return dem(khac.inHours, 'giờ trước');
    if (khac.inDays < 7) return dem(khac.inDays, 'ngày trước');
    return DateFormat('dd/MM/yyyy', _localeCuaDinhDang).format(moc);
  }

  /// Số ngày còn lại của tin đăng (âm nghĩa là đã hết hạn hiển thị).
  static int ngayConLai(DateTime? hetHan) {
    if (hetHan == null) return 0;
    final now = DateTime.now();
    return DateTime(hetHan.year, hetHan.month, hetHan.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  static String sao(double trungBinh, int soLuot) {
    if (soLuot == 0) return x('Chưa có đánh giá');
    return '${trungBinh.toStringAsFixed(1)} ★ (${dem(soLuot, 'đánh giá')})';
  }

  static String tenHoDem(String hoTen) {
    final tach = hoTen.trim().split(RegExp(r'\s+'));
    return tach.isEmpty || tach.first.isEmpty ? 'U' : tach.last[0].toUpperCase();
  }
}

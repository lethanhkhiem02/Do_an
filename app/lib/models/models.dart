/// Các lớp dữ liệu khớp với JSON mà backend (C:\\DACS\\Do_an_co_so) trả về.
library;

import '../core/dich.dart';
import '../core/formatting.dart';

Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
double _d0(dynamic v) => (v as num?)?.toDouble() ?? 0;
int? _i(dynamic v) => v == null ? null : (v as num).toInt();
int _i0(dynamic v) => (v as num?)?.toInt() ?? 0;
bool _b(dynamic v) => v == true;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v');

class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.hoTen,
    this.avatar,
    this.soDienThoai,
    this.ngaySinh,
    this.diaChi,
    this.soDu = 0,
    this.trangThaiKhoa = false,
    this.trangThaiXacThuc = '',
    this.cccdTruoc,
    this.cccdSau,
    this.soCCCDQuetDuoc,
  });

  factory UserProfile.fromJson(dynamic json) {
    final m = _map(json);
    return UserProfile(
      id: m['id'] ?? '',
      email: m['email'] ?? '',
      hoTen: m['hoTen'] ?? '',
      avatar: m['avatar'],
      soDienThoai: m['soDienThoai'],
      ngaySinh: _dt(m['ngaySinh']),
      diaChi: m['diaChi'],
      soDu: _d0(m['soDu']),
      trangThaiKhoa: _b(m['trangThaiKhoa']),
      trangThaiXacThuc: m['trangThaiXacThuc'] ?? '',
      cccdTruoc: m['cccdTruoc'],
      cccdSau: m['cccdSau'],
      soCCCDQuetDuoc: m['soCCCDQuetDuoc'],
    );
  }

  final String id;
  final String email;
  final String hoTen;
  final String? avatar;
  final String? soDienThoai;
  final DateTime? ngaySinh;
  final String? diaChi;
  final double soDu;
  final bool trangThaiKhoa;
  final String trangThaiXacThuc;
  final String? cccdTruoc;
  final String? cccdSau;
  final String? soCCCDQuetDuoc;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'hoTen': hoTen,
    'avatar': avatar,
    'soDienThoai': soDienThoai,
    'ngaySinh': ngaySinh?.toIso8601String(),
    'diaChi': diaChi,
    'soDu': soDu,
    'trangThaiKhoa': trangThaiKhoa,
    'trangThaiXacThuc': trangThaiXacThuc,
    'cccdTruoc': cccdTruoc,
    'cccdSau': cccdSau,
    'soCCCDQuetDuoc': soCCCDQuetDuoc,
  };
}

class AuthPayload {
  AuthPayload({required this.token, required this.user, required this.roles, this.expiresAt});

  factory AuthPayload.fromJson(dynamic json) {
    final m = _map(json);
    return AuthPayload(
      token: m['token'] ?? '',
      user: UserProfile.fromJson(m['user']),
      roles: (m['roles'] as List?)?.cast<String>() ?? const [],
      expiresAt: _dt(m['expiresAt']),
    );
  }

  final String token;
  final UserProfile user;
  final List<String> roles;
  final DateTime? expiresAt;
}

class Room {
  Room({
    required this.id,
    required this.moTa,
    required this.gia,
    required this.diaChi,
    this.giaDien,
    this.giaNuoc,
    this.anh = const [],
    this.latitude,
    this.longitude,
    this.isVip = false,
    this.daChoThue = false,
    this.coNhaVeSinh = false,
    this.coBanCong = false,
    this.chieuDai,
    this.chieuRong,
    this.ngayHetHan,
    this.soNgayGiuPhong,
    this.khoangCach = 0,
    this.trungBinhSao = 0,
    this.soDanhGia = 0,
    this.chuTroId,
    this.tenChuTro,
    this.trangThai = 'ConTrong',
    this.loaiHinh = 'PhongRieng',
  });

  factory Room.fromJson(dynamic json) {
    final m = _map(json);
    return Room(
      id: _i0(m['id']),
      moTa: m['moTa'] ?? '',
      gia: _d0(m['gia']),
      diaChi: m['diaChi'] ?? '',
      giaDien: _d(m['giaDien']),
      giaNuoc: _d(m['giaNuoc']),
      anh: (m['anh'] as List?)?.cast<String>() ?? const [],
      latitude: _d(m['latitude']),
      longitude: _d(m['longitude']),
      isVip: _b(m['isVip']),
      daChoThue: _b(m['daChoThue']),
      coNhaVeSinh: _b(m['coNhaVeSinh']),
      coBanCong: _b(m['coBanCong']),
      chieuDai: _d(m['chieuDai']),
      chieuRong: _d(m['chieuRong']),
      ngayHetHan: _dt(m['ngayHetHan']),
      soNgayGiuPhong: _i(m['soNgayGiuPhong']),
      khoangCach: _d0(m['khoangCach']),
      trungBinhSao: _d0(m['trungBinhSao']),
      soDanhGia: _i0(m['soDanhGia']),
      chuTroId: m['chuTroId'],
      tenChuTro: m['tenChuTro'],
      trangThai: m['trangThai'] ?? 'ConTrong',
      loaiHinh: m['loaiHinh'] ?? 'PhongRieng',
    );
  }

  final int id;
  final String moTa;
  final double gia;
  final String diaChi;

  /// Đơn giá điện (VNĐ/kWh) và nước (VNĐ/m³) chủ trọ khai lúc đăng bài.
  /// Phòng cũ chưa có hai cột này nên backend trả về 0.
  final double? giaDien;
  final double? giaNuoc;
  final List<String> anh;
  final double? latitude;
  final double? longitude;
  final bool isVip;
  final bool daChoThue;
  final bool coNhaVeSinh;
  final bool coBanCong;
  final double? chieuDai;
  final double? chieuRong;
  final DateTime? ngayHetHan;
  final int? soNgayGiuPhong;
  final double khoangCach;
  final double trungBinhSao;
  final int soDanhGia;
  final String? chuTroId;
  final String? tenChuTro;
  final String trangThai;

  /// "PhongRieng" hoặc "KyTucXa", đúng như enum LoaiHinhPhong của backend.
  final String loaiHinh;

  bool get laKyTucXa => loaiHinh == 'KyTucXa';

  String get tenLoaiHinh => x(laKyTucXa ? 'Ký túc xá' : 'Phòng riêng');

  double? get dienTich =>
      (chieuDai != null && chieuRong != null && chieuDai! > 0 && chieuRong! > 0)
      ? chieuDai! * chieuRong!
      : null;

  bool get dangDuocGiU => trangThai == 'DangGiuCho';
  bool get conTrong => trangThai == 'ConTrong';

  bool get coGiaDien => (giaDien ?? 0) > 0;
  bool get coGiaNuoc => (giaNuoc ?? 0) > 0;
}

class Review {
  Review({
    required this.id,
    required this.sao,
    required this.noiDung,
    required this.ngayTao,
    required this.userId,
    this.tenNguoiDanhGia,
  });

  factory Review.fromJson(dynamic json) {
    final m = _map(json);
    return Review(
      id: _i0(m['id']),
      sao: _i0(m['sao']),
      noiDung: m['noiDung'] ?? '',
      ngayTao: _dt(m['ngayTao']) ?? DateTime.now(),
      userId: m['userId'] ?? '',
      tenNguoiDanhGia: m['nguoiDanhGia'],
    );
  }

  final int id;
  final int sao;
  final String noiDung;
  final DateTime ngayTao;
  final String userId;
  final String? tenNguoiDanhGia;
}

class RoomDetail extends Room {
  RoomDetail({
    required super.id,
    required super.moTa,
    required super.gia,
    super.giaDien,
    super.giaNuoc,
    required super.diaChi,
    super.anh,
    super.latitude,
    super.longitude,
    super.isVip,
    super.daChoThue,
    super.coNhaVeSinh,
    super.coBanCong,
    super.chieuDai,
    super.chieuRong,
    super.ngayHetHan,
    super.soNgayGiuPhong,
    super.khoangCach,
    super.trungBinhSao,
    super.soDanhGia,
    super.chuTroId,
    super.tenChuTro,
    super.trangThai,
    super.loaiHinh,
    this.avatarChuTro,
    this.chuTroDienThoai,
    this.chuTroDiaChi,
    this.chuTroXacThuc,
    this.nguoiDatCocId,
    this.tienCoc,
    this.hanDatCoc,
    this.danhGia = const [],
    this.duocDanhGia = false,
    this.daDatCoc = false,
    this.daThue = false,
  });

  factory RoomDetail.fromJson(dynamic json) {
    final m = _map(json);
    final base = Room.fromJson(m);
    return RoomDetail(
      id: base.id,
      moTa: base.moTa,
      gia: base.gia,
      giaDien: base.giaDien,
      giaNuoc: base.giaNuoc,
      diaChi: base.diaChi,
      anh: base.anh,
      latitude: base.latitude,
      longitude: base.longitude,
      isVip: base.isVip,
      daChoThue: base.daChoThue,
      coNhaVeSinh: base.coNhaVeSinh,
      coBanCong: base.coBanCong,
      chieuDai: base.chieuDai,
      chieuRong: base.chieuRong,
      ngayHetHan: base.ngayHetHan,
      soNgayGiuPhong: base.soNgayGiuPhong,
      khoangCach: base.khoangCach,
      trungBinhSao: base.trungBinhSao,
      soDanhGia: base.soDanhGia,
      chuTroId: base.chuTroId,
      tenChuTro: base.tenChuTro,
      trangThai: base.trangThai,
      loaiHinh: base.loaiHinh,
      avatarChuTro: m['avatarChuTro'],
      chuTroDienThoai: m['chuTroDienThoai'],
      chuTroDiaChi: m['chuTroDiaChi'],
      chuTroXacThuc: m['chuTroXacThuc'],
      nguoiDatCocId: m['nguoiDatCocId'],
      tienCoc: _d(m['tienCoc']),
      hanDatCoc: _dt(m['hanDatCoc']),
      danhGia: (m['danhGia'] as List?)?.map(Review.fromJson).toList() ?? const [],
      duocDanhGia: _b(m['duocDanhGia']),
      daDatCoc: _b(m['daDatCoc']),
      daThue: _b(m['daThue']),
    );
  }

  final String? avatarChuTro;
  final String? chuTroDienThoai;
  final String? chuTroDiaChi;
  final String? chuTroXacThuc;
  final String? nguoiDatCocId;
  final double? tienCoc;
  final DateTime? hanDatCoc;
  final List<Review> danhGia;
  final bool duocDanhGia;
  final bool daDatCoc;
  final bool daThue;
}

class School {
  School({
    required this.id,
    required this.tenTruong,
    required this.quan,
    required this.loaiTruong,
    required this.latitude,
    required this.longitude,
  });

  factory School.fromJson(dynamic json) {
    final m = _map(json);
    return School(
      id: m['id'] ?? '',
      tenTruong: m['tenTruong'] ?? '',
      quan: m['quan'] ?? '',
      loaiTruong: m['loaiTruong'] ?? '',
      latitude: _d0(m['latitude']),
      longitude: _d0(m['longitude']),
    );
  }

  final String id;
  final String tenTruong;
  final String quan;
  final String loaiTruong;
  final double latitude;
  final double longitude;
}

class SearchResult {
  SearchResult({this.rooms = const [], this.truongId, this.tenTruong, this.banKinh, this.sapXep});

  factory SearchResult.fromJson(dynamic json) {
    final m = _map(json);
    return SearchResult(
      rooms: (m['phong'] as List?)?.map(Room.fromJson).toList() ?? const [],
      truongId: m['truongId'],
      tenTruong: m['tenTruong'],
      banKinh: _d(m['banKinh']),
      sapXep: m['sapXep'],
    );
  }

  final List<Room> rooms;
  final String? truongId;
  final String? tenTruong;
  final double? banKinh;
  final String? sapXep;
}

class AiSearchResult {
  AiSearchResult({
    this.cacTieuChi = const [],
    this.thongBao = '',
    this.danhSachPhong = const [],
  });

  factory AiSearchResult.fromJson(dynamic json) {
    final m = _map(json);
    return AiSearchResult(
      cacTieuChi: (m['cacTieuChi'] as List?)?.map((e) => '$e').toList() ?? const [],
      thongBao: m['thongBao'] ?? '',
      danhSachPhong: (m['danhSachPhong'] as List?)?.map(Room.fromJson).toList() ?? const [],
    );
  }

  final List<String> cacTieuChi;
  final String thongBao;
  final List<Room> danhSachPhong;
}

class Invoice {
  Invoice({
    required this.id,
    required this.phongTroId,
    required this.tongTien,
    required this.tienHoaHong,
    required this.tienChuTroNhan,
    required this.ngayGiaoDich,
    required this.loaiHoaDon,
    required this.trangThai,
    this.tenPhong,
    this.diaChiPhong,
    this.chuTro,
  });

  factory Invoice.fromJson(dynamic json) {
    final m = _map(json);
    return Invoice(
      id: _i0(m['id']),
      phongTroId: _i0(m['phongTroId']),
      tongTien: _d0(m['tongTien']),
      tienHoaHong: _d0(m['tienHoaHong']),
      tienChuTroNhan: _d0(m['tienChuTroNhan']),
      ngayGiaoDich: _dt(m['ngayGiaoDich']) ?? DateTime.now(),
      loaiHoaDon: m['loaiHoaDon'] ?? '',
      trangThai: m['trangThai'] ?? '',
      tenPhong: m['tenPhong'],
      diaChiPhong: m['diaChiPhong'],
      chuTro: m['chuTro'],
    );
  }

  final int id;
  final int phongTroId;
  final double tongTien;
  final double tienHoaHong;
  final double tienChuTroNhan;
  final DateTime ngayGiaoDich;
  final String loaiHoaDon;
  final String trangThai;
  final String? tenPhong;
  final String? diaChiPhong;
  final String? chuTro;

  String get loaiHienThi => switch (loaiHoaDon) {
    'ThuePhong' => x('Thuê phòng'),
    'DatCoc' => x('Đặt cọc giữ chỗ'),
    'PhatCoc' => x('Tiền phạt hủy cọc'),
    _ => loaiHoaDon,
  };

  String get trangThaiHienThi => switch (trangThai) {
    'HoanThanh' => x('Hoàn thành'),
    'TamGiu' => x('Đang tạm giữ'),
    'GiaiNgan' => x('Đã giải ngân'),
    'HoanTien' => x('Đã hoàn tiền'),
    'ChoGiaiNgan' => x('Đang chờ phân xử'),
    'PhatChoChuTro' => x('Đã bồi thường cho chủ trọ'),
    'HoanChoNguoiBaoCao' => x('Đã hoàn lại cho bạn'),
    _ => trangThai,
  };
}

class Wallet {
  Wallet({required this.soDu, this.trangThaiXacThuc = '', this.giaoDich = const []});

  factory Wallet.fromJson(dynamic json) {
    final m = _map(json);
    return Wallet(
      soDu: _d0(m['soDu']),
      trangThaiXacThuc: m['trangThaiXacThuc'] ?? '',
      giaoDich: (m['giaoDich'] as List?)?.map(Invoice.fromJson).toList() ?? const [],
    );
  }

  final double soDu;
  final String trangThaiXacThuc;
  final List<Invoice> giaoDich;
}

class Conversation {
  Conversation({
    required this.userId,
    required this.hoTen,
    this.avatar,
    this.tinNhan,
    this.thoiGianNhan,
  });

  factory Conversation.fromJson(dynamic json) {
    final m = _map(json);
    return Conversation(
      userId: m['userId'] ?? '',
      hoTen: m['hoTen'] ?? x('Ẩn danh'),
      avatar: m['avatar'],
      tinNhan: m['tinNganNhat'],
      thoiGianNhan: _dt(m['thoiGianNhan']),
    );
  }

  final String userId;
  final String hoTen;
  final String? avatar;
  final String? tinNhan;
  final DateTime? thoiGianNhan;
}

class ChatMessage {
  ChatMessage({
    required this.noiDung,
    required this.thoiGian,
    this.id = 0,
    this.senderId,
    this.tenNguoiGui,
    this.cuaMinh = false,
  });

  factory ChatMessage.fromJson(dynamic json) {
    final m = _map(json);
    return ChatMessage(
      id: _i0(m['id']),
      senderId: m['senderId'],
      tenNguoiGui: m['tenNguoiGui'],
      noiDung: m['noiDung'] ?? '',
      thoiGian: _dt(m['thoiGian']) ?? DateTime.now(),
      cuaMinh: _b(m['cuaMinh']),
    );
  }

  final int id;
  final String? senderId;
  final String? tenNguoiGui;
  final String noiDung;
  final DateTime thoiGian;
  final bool cuaMinh;

  bool get laHinh => noiDung.startsWith('[IMG]:');

  String get duongDanHinh => noiDung.replaceFirst('[IMG]:', '');

  /// Chat tổng lưu ảnh dạng "[GLOBAL_IMAGE]: /uploads/..." nên backend tách sẵn
  /// đường dẫn; tin ảnh 1-1 vẫn giữ tiền tố [IMG]:.
  bool get laTinHinh => laHinh || noiDung.startsWith('/uploads/');

  String get noiDungHienThi => laHinh ? duongDanHinh : noiDung;
}

class AdminUserRow {
  AdminUserRow({
    required this.id,
    required this.email,
    required this.hoTen,
    this.roles = const [],
    this.trangThaiKhoa = false,
    this.trangThaiXacThuc = '',
    this.cccdTruoc,
    this.cccdSau,
    this.soCCCDQuetDuoc,
    this.soDu = 0,
    this.soTinDang = 0,
  });

  factory AdminUserRow.fromJson(dynamic json) {
    final m = _map(json);
    return AdminUserRow(
      id: m['id'] ?? '',
      email: m['email'] ?? '',
      hoTen: m['hoTen'] ?? '',
      roles: (m['roles'] as List?)?.cast<String>() ?? const [],
      trangThaiKhoa: _b(m['trangThaiKhoa']),
      trangThaiXacThuc: m['trangThaiXacThuc'] ?? '',
      cccdTruoc: m['cccdTruoc'],
      cccdSau: m['cccdSau'],
      soCCCDQuetDuoc: m['soCCCDQuetDuoc'],
      soDu: _d0(m['soDu']),
      soTinDang: _i0(m['soTinDang']),
    );
  }

  final String id;
  final String email;
  final String hoTen;
  final List<String> roles;
  final bool trangThaiKhoa;
  final String trangThaiXacThuc;
  final String? cccdTruoc;
  final String? cccdSau;
  final String? soCCCDQuetDuoc;
  final double soDu;
  final int soTinDang;
}

class AdminReport {
  AdminReport({
    required this.id,
    required this.lyDo,
    required this.ngayBaoCao,
    this.chiTiet,
    this.daXuLy = false,
    this.nguoiBaoCao,
    this.nguoiBiBaoCao,
    this.phongTroId,
    this.diaChiPhong,
    this.chuTroCuaPhong,
    this.hoaDonPhatCocId,
    this.tienPhatCoc,
    this.trangThaiPhatCoc,
    this.coTheHoanCoc = false,
  });

  factory AdminReport.fromJson(dynamic json) {
    final m = _map(json);
    return AdminReport(
      id: _i0(m['id']),
      lyDo: m['lyDo'] ?? '',
      ngayBaoCao: _dt(m['ngayBaoCao']) ?? DateTime.now(),
      chiTiet: m['chiTiet'],
      daXuLy: _b(m['daXuLy']),
      nguoiBaoCao: m['nguoiBaoCao'],
      nguoiBiBaoCao: m['nguoiBiBaoCao'],
      phongTroId: _i(m['phongTroId']),
      diaChiPhong: m['diaChiPhong'],
      chuTroCuaPhong: m['chuTroCuaPhong'],
      hoaDonPhatCocId: _i(m['hoaDonPhatCocId']),
      tienPhatCoc: _d(m['tienPhatCoc']),
      trangThaiPhatCoc: m['trangThaiPhatCoc'],
      coTheHoanCoc: _b(m['coTheHoanCoc']),
    );
  }

  final int id;
  final String lyDo;
  final DateTime ngayBaoCao;
  final String? chiTiet;
  final bool daXuLy;
  final String? nguoiBaoCao;
  final String? nguoiBiBaoCao;
  final int? phongTroId;
  final String? diaChiPhong;
  final String? chuTroCuaPhong;
  final int? hoaDonPhatCocId;
  final double? tienPhatCoc;
  final String? trangThaiPhatCoc;
  final bool coTheHoanCoc;
}

class PaymentUrl {
  PaymentUrl({required this.url, required this.txnRef});

  factory PaymentUrl.fromJson(dynamic json) {
    final m = _map(json);
    return PaymentUrl(url: m['paymentUrl'] ?? '', txnRef: m['txnRef'] ?? '');
  }

  final String url;
  final String txnRef;
}

class PaymentStatus {
  PaymentStatus({required this.phongTroId, required this.trangThai, this.tienCoc, this.hanDatCoc, this.soDu = 0});

  factory PaymentStatus.fromJson(dynamic json) {
    final m = _map(json);
    return PaymentStatus(
      phongTroId: _i0(m['phongTroId']),
      trangThai: m['trangThai'] ?? '',
      tienCoc: _d(m['tienCoc']),
      hanDatCoc: _dt(m['hanDatCoc']),
      soDu: _d0(m['soDu']),
    );
  }

  final int phongTroId;
  final String trangThai;
  final double? tienCoc;
  final DateTime? hanDatCoc;
  final double soDu;
}

/// Một tiện ích backend tìm được quanh phòng qua OpenStreetMap (Overpass).
/// `loai` là khóa tiếng Anh ổn định (bus_stop/supermarket/cafe/fuel/convenience)
/// dùng để chọn icon và nhóm; `ten` là tên do OSM lưu nên thường là tiếng Việt
/// và không qua máy dịch.
class Amenity {
  Amenity({
    required this.loai,
    required this.viDo,
    required this.kinhDo,
    required this.khoangCachMet,
    this.ten,
  });

  factory Amenity.fromJson(dynamic json) {
    final m = _map(json);
    return Amenity(
      loai: m['loai'] ?? '',
      ten: m['ten'],
      viDo: _d0(m['viDo']),
      kinhDo: _d0(m['kinhDo']),
      khoangCachMet: _i0(m['khoangCachMet']),
    );
  }

  final String loai;
  final String? ten;
  final double viDo;
  final double kinhDo;
  final int khoangCachMet;

  String get tenLoai => tenNhomTienIch(loai);

  String get khoangCach => Fmt.km(khoangCachMet / 1000);
}

/// Đáp ứng của GET /api/phong-tro/{id}/tien-ich.
/// `daQuet` phân biệt "chưa quét lần nào" với "quét rồi mà quanh đây không có gì".
class AmenityPage {
  AmenityPage({required this.daQuet, this.quetNgay, this.banKinhMet = 1000, this.tienIch = const []});

  factory AmenityPage.fromJson(dynamic json) {
    final m = _map(json);
    return AmenityPage(
      daQuet: _b(m['daQuet']),
      quetNgay: _dt(m['quetNgay']),
      banKinhMet: _i0(m['banKinhMet']) == 0 ? 1000 : _i0(m['banKinhMet']),
      tienIch: (m['tienIch'] as List?)?.map(Amenity.fromJson).toList() ?? const [],
    );
  }

  final bool daQuet;
  final DateTime? quetNgay;

  /// Bán kính server đã thực sự quét, cũng là vòng tròn app vẽ trên bản đồ.
  final int banKinhMet;
  final List<Amenity> tienIch;
}

/// Tên tiếng Việt của từng nhóm tiện ích, đã tra sang ngôn ngữ đang bật.
String tenNhomTienIch(String loai) => switch (loai) {
  'bus_stop' => x('Trạm xe buýt'),
  'supermarket' => x('Siêu thị'),
  'cafe' => x('Quán cà phê'),
  'fuel' => x('Cây xăng'),
  'convenience' => x('Cửa hàng tiện lợi'),
  _ => x('Tiện ích'),
};

/// Thứ tự các nhóm hiển thị trong tab "Tiện ích xung quanh", kể cả nhóm chưa
/// tìm thấy gì để sinh viên biết app đã quét loại đó rồi.
const List<String> cacNhomTienIch = ['bus_stop', 'supermarket', 'cafe', 'fuel', 'convenience'];

/// Thông tin Bên B mà chủ trọ xem trước ở màn "Tạo hợp đồng"
/// (GET /api/hop-dong/khach-thue/{phongTroId}).
class ContractTenant {
  ContractTenant({
    required this.phongTroId,
    this.tenPhong,
    this.diaChiPhong = '',
    this.giaThue = 0,
    this.benBId,
    this.tenBenB = '',
    this.ngaySinhBenB,
    this.tenBenA = '',
    this.ngaySinhBenA,
  });

  factory ContractTenant.fromJson(dynamic json) {
    final m = _map(json);
    return ContractTenant(
      phongTroId: _i0(m['phongTroId']),
      tenPhong: m['tenPhong'],
      diaChiPhong: m['diaChiPhong'] ?? '',
      giaThue: _d0(m['giaThue']),
      benBId: m['benBId'],
      tenBenB: m['tenBenB'] ?? '',
      ngaySinhBenB: _dt(m['ngaySinhBenB']),
      tenBenA: m['tenBenA'] ?? '',
      ngaySinhBenA: _dt(m['ngaySinhBenA']),
    );
  }

  final int phongTroId;
  final String? tenPhong;
  final String diaChiPhong;
  final double giaThue;
  final String? benBId;
  final String tenBenB;
  final DateTime? ngaySinhBenB;
  final String tenBenA;
  final DateTime? ngaySinhBenA;
}

/// Hợp đồng thuê phòng online (Bên A = chủ trọ, Bên B = sinh viên).
class RentalContract {
  RentalContract({
    required this.id,
    required this.phongTroId,
    this.tenPhong,
    required this.benAId,
    required this.tenBenA,
    this.ngaySinhBenA,
    required this.benBId,
    required this.tenBenB,
    this.ngaySinhBenB,
    required this.diaChiPhong,
    required this.giaThue,
    required this.thoiHanThang,
    required this.ngayBatDau,
    required this.ngayKetThuc,
    required this.trangThai,
    required this.vaiTro,
    this.kyBenALuc,
    this.kyBenBLuc,
    required this.ngayLap,
    required this.conChoMinhKy,
  });

  factory RentalContract.fromJson(dynamic json) {
    final m = _map(json);
    return RentalContract(
      id: _i0(m['id']),
      phongTroId: _i0(m['phongTroId']),
      tenPhong: m['tenPhong'],
      benAId: m['benAId'] ?? '',
      tenBenA: m['tenBenA'] ?? '',
      ngaySinhBenA: _dt(m['ngaySinhBenA']),
      benBId: m['benBId'] ?? '',
      tenBenB: m['tenBenB'] ?? '',
      ngaySinhBenB: _dt(m['ngaySinhBenB']),
      diaChiPhong: m['diaChiPhong'] ?? '',
      giaThue: _d0(m['giaThue']),
      thoiHanThang: _i0(m['thoiHanThang']),
      ngayBatDau: _dt(m['ngayBatDau']) ?? DateTime.now(),
      ngayKetThuc: _dt(m['ngayKetThuc']) ?? DateTime.now(),
      trangThai: m['trangThai'] ?? '',
      vaiTro: m['vaiTro'] ?? '',
      kyBenALuc: _dt(m['kyBenALuc']),
      kyBenBLuc: _dt(m['kyBenBLuc']),
      ngayLap: _dt(m['ngayLap']) ?? DateTime.now(),
      conChoMinhKy: _b(m['conChoMinhKy']),
    );
  }

  final int id;
  final int phongTroId;
  final String? tenPhong;

  final String benAId;
  final String tenBenA;
  final DateTime? ngaySinhBenA;

  final String benBId;
  final String tenBenB;
  final DateTime? ngaySinhBenB;

  final String diaChiPhong;
  final double giaThue;
  final int thoiHanThang;
  final DateTime ngayBatDau;
  final DateTime ngayKetThuc;

  /// ChoKy | DaKy | DaHuy — nhãn hiển thị do từ điển của app quyết định.
  final String trangThai;

  /// "A" nếu người xem là chủ trọ, "B" nếu là sinh viên.
  final String vaiTro;
  final DateTime? kyBenALuc;
  final DateTime? kyBenBLuc;
  final DateTime ngayLap;
  final bool conChoMinhKy;

  bool get daKy => trangThai == 'DaKy';
  bool get daHuy => trangThai == 'DaHuy';
  bool get choKy => trangThai == 'ChoKy';

  /// Bản là bên nào vừa ký: bên A ký trước nên chỉ bên B mới làm hợp đồng có hiệu lực.
  DateTime? get kyCuaMinh => vaiTro == 'A' ? kyBenALuc : kyBenBLuc;

  String get trangThaiHienThi => switch (trangThai) {
    'DaKy' => x('Đã ký'),
    'DaHuy' => x('Đã hủy'),
    _ => x('Chờ ký'),
  };
}


/// Lịch hẹn xem phòng trực tiếp mà sinh viên tạo sau khi đặt cọc xong.
class ViewingAppointment {
  ViewingAppointment({
    required this.id,
    required this.phongTroId,
    this.diaChiPhong,
    this.tenPhong,
    required this.nguoiDatId,
    this.tenNguoiDat,
    required this.chuTroId,
    required this.ngayHen,
    this.ghiChu,
    required this.trangThai,
    this.ngayPhanHoi,
  });

  factory ViewingAppointment.fromJson(dynamic json) {
    final m = _map(json);
    return ViewingAppointment(
      id: _i0(m['id']),
      phongTroId: _i0(m['phongTroId']),
      diaChiPhong: m['diaChiPhong'],
      tenPhong: m['tenPhong'],
      nguoiDatId: m['nguoiDatId'] ?? '',
      tenNguoiDat: m['tenNguoiDat'],
      chuTroId: m['chuTroId'] ?? '',
      ngayHen: _dt(m['ngayHen']) ?? DateTime.now(),
      ghiChu: m['ghiChu'],
      trangThai: m['trangThai'] ?? 'ChoXacNhan',
      ngayPhanHoi: _dt(m['ngayPhanHoi']),
    );
  }

  final int id;
  final int phongTroId;
  final String? diaChiPhong;
  final String? tenPhong;
  final String nguoiDatId;
  final String? tenNguoiDat;
  final String chuTroId;
  final DateTime ngayHen;
  final String? ghiChu;

  /// ChoXacNhan | DaXacNhan | DaTuChoi.
  final String trangThai;
  final DateTime? ngayPhanHoi;

  bool get choXacNhan => trangThai == 'ChoXacNhan';
  bool get daXacNhan => trangThai == 'DaXacNhan';
  bool get daTuChoi => trangThai == 'DaTuChoi';

  String get trangThaiHienThi => switch (trangThai) {
    'DaXacNhan' => x('Đã xác nhận'),
    'DaTuChoi' => x('Đã từ chối'),
    _ => x('Chờ chủ trọ xác nhận'),
  };
}

/// Một mục trong hộp thư thông báo. Server chỉ gửi mã sự kiện nên tiêu đề và
/// nội dung đã được dịch theo ngôn ngữ mà app đang dùng.
class AppNotification {
  AppNotification({
    required this.id,
    required this.loai,
    required this.tieuDe,
    this.noiDung,
    this.maLichXemPhong,
    this.phongTroId,
    this.ngayHen,
    this.trangThaiLich,
    required this.daDoc,
    required this.ngayTao,
  });

  factory AppNotification.fromJson(dynamic json) {
    final m = _map(json);
    return AppNotification(
      id: _i0(m['id']),
      loai: m['loai'] ?? '',
      tieuDe: m['tieuDe'] ?? '',
      noiDung: m['noiDung'],
      maLichXemPhong: _i(m['maLichXemPhong']),
      phongTroId: _i(m['phongTroId']),
      ngayHen: _dt(m['ngayHen']),
      trangThaiLich: m['trangThaiLich'],
      daDoc: _b(m['daDoc']),
      ngayTao: _dt(m['ngayTao']) ?? DateTime.now(),
    );
  }

  final int id;
  final String loai;
  final String tieuDe;
  final String? noiDung;
  final int? maLichXemPhong;
  final int? phongTroId;
  final DateTime? ngayHen;
  final String? trangThaiLich;
  final bool daDoc;
  final DateTime ngayTao;

  bool get laYeuCauXemPhong => loai == 'DatLichXemPhong';
  bool get conChoDuyet => laYeuCauXemPhong && trangThaiLich == 'ChoXacNhan';
}

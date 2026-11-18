import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'dich.dart';

/// Giữ phiên đăng nhập của app: token JWT, thông tin người dùng và vai trò.
/// Mọi màn hình lấy Session qua Provider để gọi API.
class Session extends ChangeNotifier {
  static const String _keyToken = 'roomfinder.token';
  static const String _keyUser = 'roomfinder.user';
  static const String _keyRoles = 'roomfinder.roles';

  late final ApiClient api;

  String? _token;
  UserProfile? _user;
  List<String> _roles = const [];
  bool _loading = true;

  Session() {
    api = ApiClient(onUnauthorized: _clear);
  }

  UserProfile? get user => _user;
  List<String> get roles => _roles;
  bool get isLoading => _loading;
  bool get daDangNhap => _token != null && _user != null;

  bool get laSinhVien => _roles.contains('SinhVien');
  bool get laChuTro => _roles.contains('ChuTro');
  bool get laAdmin => _roles.contains('Admin');

  String get tenHienThi => _user?.hoTen ?? x('Người dùng');

  /// Đọc token đã lưu để tự đăng nhập lại khi mở app.
  Future<void> khoiDong() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token != null && token.isNotEmpty) {
      _token = token;
      api.token = token;
      _user = _parseUser(prefs.getString(_keyUser));
      _roles = _parseRoles(prefs.getString(_keyRoles));
    }
    _loading = false;
    notifyListeners();

    if (_token != null) {
      await lamMoiHoSo(baoLoi: false);
    }
  }

  Future<UserProfile> dangNhap(String email, String matKhau) async {
    final payload = await _sendAuth('api/auth/login', {
      'email': email,
      'password': matKhau,
    });
    return payload.user;
  }

  Future<UserProfile> dangKy({
    required String hoTen,
    required String email,
    required String matKhau,
    required String vaiTro,
  }) async {
    final payload = await _sendAuth('api/auth/register', {
      'hoTen': hoTen,
      'email': email,
      'password': matKhau,
      'role': vaiTro,
    });
    return payload.user;
  }

  Future<void> dangXuat() async {
    _clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
    await prefs.remove(_keyRoles);
    notifyListeners();
  }

  Future<void> lamMoiHoSo({bool baoLoi = true}) async {
    try {
      _apply(AuthPayload.fromJson(await api.get('api/auth/me')));
    } on ApiException {
      if (baoLoi) rethrow;
    }
  }

  Future<void> capNhatHoSo({
    required String hoTen,
    String? soDienThoai,
    DateTime? ngaySinh,
    String? diaChi,
  }) async {
    final json = await api.put(
      'api/auth/profile',
      body: {
        'hoTen': hoTen,
        'soDienThoai': soDienThoai,
        'ngaySinh': ngaySinh?.toIso8601String(),
        'diaChi': diaChi,
      },
    );
    await saveUser(UserProfile.fromJson(json));
  }

  Future<void> taiAnhDaiDien(UploadFile file) async {
    final json = await api.upload('api/auth/avatar', files: [file]);
    await saveUser(UserProfile.fromJson(json));
  }

  Future<void> taiCCCD({UploadFile? truoc, UploadFile? sau}) async {
    final json = await api.upload('api/auth/cccd', files: [
      if (truoc != null) truoc,
      if (sau != null) sau,
    ]);
    await saveUser(UserProfile.fromJson(json));
  }

  /// Backend trả token mới sau khi đổi mật khẩu vì claim trong token cũ đã lệch.
  Future<void> doiMatKhau(String matKhauCu, String matKhauMoi) async {
    _apply(await _sendAuth('api/auth/change-password', {
      'currentPassword': matKhauCu,
      'newPassword': matKhauMoi,
    }));
  }

  Future<void> saveUser(UserProfile user) async {
    _user = user;
    notifyListeners();
    await _persist();
  }

  Future<AuthPayload> _sendAuth(String path, Map<String, dynamic> body) async {
    final payload = AuthPayload.fromJson(await api.post(path, body: body));
    _apply(payload);
    return payload;
  }

  void _apply(AuthPayload payload) {
    _token = payload.token;
    api.token = payload.token;
    _user = payload.user;
    _roles = payload.roles;
    _loading = false;
    notifyListeners();
    _persist();
  }

  void _clear() {
    _token = null;
    api.token = null;
    _user = null;
    _roles = const [];
    _loading = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token == null) {
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
      await prefs.remove(_keyRoles);
      return;
    }
    await prefs.setString(_keyToken, _token!);
    await prefs.setString(_keyUser, jsonEncode(_user?.toJson() ?? const {}));
    await prefs.setString(_keyRoles, jsonEncode(_roles));
  }

  UserProfile? _parseUser(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  List<String> _parseRoles(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } on FormatException {
      return const [];
    }
  }
}

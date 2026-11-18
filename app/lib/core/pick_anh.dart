import 'dart:io' show Platform;

import 'package:image_picker/image_picker.dart';

import 'api_client.dart';

/// Chọn ảnh từ thư viện/máy ảnh của điện thoại rồi đổi thành file gửi lên API.
/// Ảnh được nén (maxWidth 1280, quality 80) để upload nhanh trên máy ảo.
class PickAnh {
  static const int _maxRong = 1280;
  static const int _chatLuong = 80;

  static Future<UploadFile?> one({required String field, ImageSource source = ImageSource.gallery}) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: _maxRong.toDouble(),
      imageQuality: _chatLuong,
    );
    return picked == null ? null : await _lenh(picked, field);
  }

  static Future<List<UploadFile>> many({required String field, int max = 6}) async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: _maxRong.toDouble(), imageQuality: _chatLuong);
    final ketQua = <UploadFile>[];
    for (final anh in picked.take(max)) {
      ketQua.add(await _lenh(anh, field));
    }
    return ketQua;
  }

  static Future<UploadFile> _lenh(XFile anh, String field) async {
    return UploadFile(
      field: field,
      filename: _tenFile(anh.name),
      bytes: await anh.readAsBytes(),
      contentType: _mimeType(anh.name),
    );
  }

  static String _tenFile(String ten) =>
      ten.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static String _mimeType(String ten) {
    final moRong = ten.toLowerCase().split('.').last;
    return switch (moRong) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  /// Android/iOS dùng ảnh trên thiết bị; các nền tảng khác (chạy web/desktop thử) báo lỗi rõ ràng.
  static bool get hoTro => Platform.isAndroid || Platform.isIOS;
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'dich.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  bool get unauthorized => statusCode == 401;
  bool get forbidden => statusCode == 403;

  @override
  String toString() => message;
}

/// File nhị phân gửi lên API (ảnh phòng, avatar, CCCD, ảnh chat).
class UploadFile {
  UploadFile({
    required this.field,
    required this.filename,
    required this.bytes,
    this.contentType = 'image/jpeg',
  });

  final String field;
  final String filename;
  final Uint8List bytes;
  final String contentType;
}

/// Client HTTP chung: tự gắn Bearer token và trả exception có message tiếng Việt
/// từ backend để màn hình chỉ việc hiển thị.
class ApiClient {
  ApiClient({this.onUnauthorized});

  String? token;
  final void Function()? onUnauthorized;

  static const Duration _timeout = Duration(seconds: 25);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query, Duration? timeout}) =>
      _send('POST', path, body: body == null ? null : jsonEncode(body), query: query, timeout: timeout);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body == null ? null : jsonEncode(body));

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> upload(String path, {Map<String, String>? fields, List<UploadFile> files = const []}) async {
    final request = http.MultipartRequest('POST', AppConfig.url(path));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept-Language'] = maNgonNguGuiLenServer;
    if (fields != null) request.fields.addAll(fields);
    for (final f in files) {
      request.files.add(http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.filename));
    }
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Future<dynamic> _send(String method, String path, {
    String? body,
    Map<String, dynamic>? query,
    Duration? timeout,
  }) async {
    final uri = AppConfig.url(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      // Backend đọc header này để trả chatbot, thông báo lỗi và mô tả/địa chỉ
      // phòng bằng đúng ngôn ngữ đang bật trên app.
      'Accept-Language': maNgonNguGuiLenServer,
      if (token != null) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };

    // Vài request (quét tiện ích qua Overpass) thật sự mất gần một phút nên tự
    // khai báo thời gian chờ riêng thay vì dùng mức chung cho mọi call.
    final choPhep = timeout ?? _timeout;

    http.Response response;
    switch (method) {
      case 'POST':
        response = await http.post(uri, headers: headers, body: body).timeout(choPhep);
      case 'PUT':
        response = await http.put(uri, headers: headers, body: body).timeout(choPhep);
      case 'DELETE':
        response = await http.delete(uri, headers: headers).timeout(choPhep);
      default:
        response = await http.get(uri, headers: headers).timeout(choPhep);
    }
    return _handle(response);
  }

  dynamic _handle(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }

    final bodyText = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (bodyText.isEmpty) return null;
      try {
        return jsonDecode(bodyText);
      } on FormatException {
        return bodyText;
      }
    }

    String message = switch (response.statusCode) {
      401 => x('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.'),
      403 => x('Bạn không có quyền thực hiện thao tác này.'),
      404 => x('Không tìm thấy dữ liệu.'),
      405 => x('Thao tác không được hỗ trợ.'),
      500 => x('Máy chủ gặp lỗi, vui lòng thử lại sau.'),
      _ => '${x('Có lỗi xảy ra')} (${response.statusCode}).',
    };

    if (bodyText.isNotEmpty) {
      try {
        final json = jsonDecode(bodyText);
        if (json is Map) {
          message = (json['message'] ?? json['detail'] ?? json['title'] ?? message).toString();
        }
      } on FormatException {
        // body không phải JSON thì giữ thông điệp mặc định theo mã lỗi
      }
    }

    throw ApiException(response.statusCode, message);
  }
}

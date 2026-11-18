/// Địa điểm backend (Visual Studio - đồ án cơ sở) mà app này gọi tới.
class AppConfig {
  /// Khi chạy trên máy ảo Android, 10.0.2.2 là địa chỉ của máy Windows chủ.
  /// Chạy trên máy thật hoặc LAN thì ghi đè bằng:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5295
  static const String _fromDefine = String.fromEnvironment('API_BASE_URL');
  static const String defaultBaseUrl = 'http://10.0.2.2:5295';

  static String get baseUrl {
    final raw = _fromDefine.isNotEmpty ? _fromDefine : defaultBaseUrl;
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  static Uri url(String path, [Map<String, dynamic>? query]) {
    var uri = Uri.parse('$baseUrl/${_boSlash(path)}');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {
        for (final e in query.entries)
          if (e.value != null) e.key: '${e.value}'
      });
    }
    return uri;
  }

  static String _boSlash(String s) => s.startsWith('/') ? s.substring(1) : s;

  /// URL tuyệt đối cho ảnh: "images/abc.jpg" hoặc "/uploads/chat-images/x.png"
  static String media(String? relative) {
    if (relative == null || relative.isEmpty) return '';
    if (relative.startsWith('http')) return relative;
    final clean = relative.startsWith('/') ? relative.substring(1) : relative;
    return '$baseUrl/$clean';
  }

  /// Avatar và CCCD trong CSDL chỉ lưu tên file (giống web), không kèm đường dẫn.
  static String avatar(String? tenFile) =>
      (tenFile == null || tenFile.isEmpty) ? '' : '$baseUrl/images/avatars/$tenFile';

  static String cccd(String? tenFile) =>
      (tenFile == null || tenFile.isEmpty) ? '' : '$baseUrl/images/cccd/$tenFile';

  /// hub SignalR của web: wss/ws theo cổng API
  static Uri hubUrl(String accessToken) {
    final ws = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = baseUrl.replaceFirst('http://', '').replaceFirst('https://', '');
    return Uri.parse('$ws://$host/chatHub?access_token=$accessToken');
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:do_an_chuyen_nganh/core/dich.dart';

/// Màn hợp đồng mới nên dịch hết. Test này đọc thẳng chuỗi `context.t('...')`
/// trong ba file screen rồi tra từ điển, không phải danh sách tự gõ.
void main() {
  test('mọi nhãn tiếng Việt của màn hợp đồng đều có bản dịch EN', () {
    Intl.defaultLocale = 'en_US';

    const cacFile = [
      'lib/features/contracts/chi_tiet_hop_dong_screen.dart',
      'lib/features/contracts/tao_hop_dong_screen.dart',
      'lib/features/contracts/hop_dong_screen.dart',
    ];

    final regex = RegExp(r"(?:context\.t|x|d)\(\s*'([^']+)'");
    final thieu = <String>{};
    var daQuet = 0;

    for (final duongDan in cacFile) {
      // Nối các chuỗi liền nhau ('a' 'b') thành một chuỗi trước khi bắt key.
      final noiDung = File(duongDan)
          .readAsStringSync()
          .replaceAllMapped(RegExp(r"'\s*\n\s*'"), (_) => '');
      for (final chuTho in regex.allMatches(noiDung).map((m) => m.group(1)!)) {
        daQuet++;
        final k = chuTho.replaceAll(r'\n', '\n').replaceAll(r"\'", "'");
        if (x(k) == k) thieu.add(k);
      }
    }

    // ignore: avoid_print
    print('Đã quét $daQuet nhãn context.t, thiếu bản dịch: $thieu');
    expect(daQuet, greaterThan(50), reason: 'Regex không đọc được gì từ file nguồn');

    expect(thieu, isEmpty, reason: 'Thiếu bản dịch EN: $thieu');
  });
}

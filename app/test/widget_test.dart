import 'dart:ui' show Locale;

import 'package:do_an_chuyen_nganh/core/dich.dart';
import 'package:do_an_chuyen_nganh/core/formatting.dart';
import 'package:do_an_chuyen_nganh/core/localization.dart';
import 'package:do_an_chuyen_nganh/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Các kiểm thử định dạng chạy ở ngôn ngữ gốc vì Intl.defaultLocale là biến toàn cục.
  setUp(() => Intl.defaultLocale = 'vi_VN');

  test('Đổi ngôn ngữ lưu vào máy và đọc lại khi mở app', () async {
    SharedPreferences.setMockInitialValues({});

    final lanDau = await NgonNgu.khoiDong();
    expect(lanDau.ma, 'vi');
    expect(x('Ví của tôi'), 'Ví của tôi');

    await lanDau.chon('en');
    expect(lanDau.laTiengAnh, isTrue);
    expect(x('Ví của tôi'), 'My wallet');

    final moLai = await NgonNgu.khoiDong();
    expect(moLai.ma, 'en');
    expect(moLai.locale, const Locale('en'));
  });

  test('Giá tiền hiển thị theo định dạng Việt Nam', () {
    // intl chèn dấu cách không ngắt (U+00A0) trước ký hiệu tiền tệ.
    expect(Fmt.tien(2500000).replaceAll('\u00a0', ' '), '2.500.000 ₫');
    expect(Fmt.tien(null), 'Chưa rõ');
  });

  test('Khoảng cách đổi sang mét khi nhỏ hơn 1 km', () {
    expect(Fmt.km(0.45), '450 m');
    expect(Fmt.km(3.2), '3,2 km');
  });

  test('Room.fromJson đọc đúng JSON của /api/phong-tro', () {
    final room = Room.fromJson({
      'id': 19,
      'moTa': 'Trọ gần ĐH Bách Khoa',
      'gia': 2500000.5,
      'diaChi': '12 Lê Lợi',
      'anh': ['a.jpg', 'b.jpg'],
      'chieuDai': 20.5,
      'chieuRong': 4.25,
      'trangThai': 'DangGiuCho',
    });

    expect(room.dienTich, closeTo(87.125, 0.001));
    expect(room.dangDuocGiU, isTrue);
    expect(room.conTrong, isFalse);
  });

  test('Tin nhắn ảnh trong chat nhận diện đúng tiền tố [IMG]:', () {
    final message = ChatMessage.fromJson({
      'noiDung': '[IMG]:/uploads/chat-images/x.png',
      'thoiGian': '2026-11-17T09:30:00',
    });
    expect(message.laHinh, isTrue);
    expect(message.duongDanHinh, '/uploads/chat-images/x.png');
  });
}

namespace Do_an_co_so.Services
{
    // Thông số VNPay sandbox dùng chung cho web (đồ án cơ sở) và API của app.
    // Khi có TMSCode/HashSecret thật, chỉ cần sửa tại đây.
    public static class VnPayOptions
    {
        public const string TmnCode = "SO3O5OQU";
        public const string HashSecret = "DAATIHR3EIIV5ZRDRIHY8XA7WZ8SDZZI";
        public const string Url = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";

        // TmnCode SO3O5OQU đã bị VNPay thu hồi: mọi giao dịch sandbox trả lỗi 71
        // "Website này chưa được phê duyệt". Bật cổng demo để vẫn test được luồng tiền
        // nội bộ; tắt (đặt false) ngay khi có TmnCode/HashSecret thật — code VNPay giữ nguyên.
        public static bool CongThanhToanDemo = true;

        public const decimal PhiDangTinVip = 50000m;
        public const decimal TienDatCocGiuCho = 500000m;
        public const decimal TyLeHoaHongAdmin = 0.10m;

        // Hủy cọc chỉ được hoàn một nửa; nửa kia giữ lại để bồi thường cho chủ trọ
        // bị giữ phòng oan, trừ khi admin xác nhận tố cáo "phòng không giống tin đăng".
        public const decimal TyLePhatHuyCoc = 0.5m;
        public const int SoNgayChoXuLyPhatCoc = 7;
    }
}

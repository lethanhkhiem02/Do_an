namespace Do_an_co_so.Services
{
    // Thông số VNPay sandbox dùng chung cho web (đồ án cơ sở) và API của app.
    // Khi có TMSCode/HashSecret thật, chỉ cần sửa tại đây.
    public static class VnPayOptions
    {
        public const string TmnCode = "SO3O5OQU";
        public const string HashSecret = "DAATIHR3EIIV5ZRDRIHY8XA7WZ8SDZZI";
        public const string Url = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";

        public const decimal PhiDangTinVip = 50000m;
        public const decimal TienDatCocGiuCho = 500000m;
        public const decimal TyLeHoaHongAdmin = 0.10m;
    }
}

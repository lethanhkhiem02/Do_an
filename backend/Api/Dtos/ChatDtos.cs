using System.ComponentModel.DataAnnotations;

namespace Do_an_co_so.Api.Dtos
{
    // ============================ CHAT ============================

    public class ConversationDto
    {
        public string UserId { get; init; } = "";
        public string HoTen { get; init; } = "";
        public string? Avatar { get; init; }
        public string? TinNganNhat { get; init; }
        public DateTime? ThoiGianNhan { get; init; }
        public int SoTinChuaDoc => 0; // App chưa có cột "đã đọc", giữ field cho ổn định JSON
    }

    public class ChatMessageDto
    {
        public int Id { get; init; }
        public string? SenderId { get; init; }
        public string? TenNguoiGui { get; init; }
        public string NoiDung { get; init; } = "";
        public DateTime ThoiGian { get; init; }
        public bool CuaMinh { get; init; }
    }

    public class SendMessageRequest
    {
        [Required]
        public string ReceiverId { get; init; } = "";

        [Required(AllowEmptyStrings = false, ErrorMessage = "Nội dung không được để trống")]
        public string Content { get; init; } = "";
    }

    public class SendGlobalMessageRequest
    {
        [Required]
        public string Type { get; init; } = "text"; // text | image

        [Required(AllowEmptyStrings = false, ErrorMessage = "Nội dung không được để trống")]
        public string Content { get; init; } = "";
    }

    public class ReportUserRequest
    {
        [Required]
        public string NguoiBiBaoCaoId { get; init; } = "";

        [Required(ErrorMessage = "Vui lòng chọn lý do báo cáo")]
        public string LyDo { get; init; } = "";

        public string? ChiTiet { get; init; }
    }

    // ============================ ADMIN ============================

    public class AdminUserDto
    {
        public string Id { get; init; } = "";
        public string Email { get; init; } = "";
        public string HoTen { get; init; } = "";
        public List<string> Roles { get; init; } = new();
        public bool TrangThaiKhoa { get; init; }
        public string TrangThaiXacThuc { get; init; } = "";
        public string? CCCDTruoc { get; init; }
        public string? CCCDSau { get; init; }
        public string? SoCCCDQuetDuoc { get; init; }
        public decimal SoDu { get; init; }
        public int SoTinDang { get; init; }
    }

    public class AdminReportDto
    {
        public int Id { get; init; }
        public string LyDo { get; init; } = "";
        public string? ChiTiet { get; init; }
        public DateTime NgayBaoCao { get; init; }
        public bool DaXuLy { get; init; }
        public string? NguoiBaoCao { get; init; }
        public string? NguoiBiBaoCao { get; init; }
        public int? PhongTroId { get; init; }
        public string? DiaChiPhong { get; init; }
        public string? ChuTroCuaPhong { get; init; }
    }

    public class DuyenCCCDRequest
    {
        // "Duyet" hoặc "TuChoi" - giống hệt trang Admin của web
        [Required]
        public string HanhDong { get; init; } = "";
    }

    // ============================ THANH TOÁN ============================

    // App không có form POST của trình duyệt nên VNPay được khởi tạo qua API:
    // API trả về paymentUrl, app mở bằng url_launcher, rồi quay lại poll trạng thái.
    public class PaymentUrlResponse
    {
        public string PaymentUrl { get; init; } = "";
        public string TxnRef { get; init; } = "";
    }

    public class PaymentStatusResponse
    {
        public int PhongTroId { get; init; }
        public string TrangThai { get; init; } = ""; // ConTrong | DangGiuCho | DaChoThue | DaHuyCoc
        public decimal? TienCoc { get; init; }
        public DateTime? HanDatCoc { get; init; }
        public decimal SoDu { get; init; }
        public string? ThongBao { get; init; }
    }

    public class NapTienRequest
    {
        [Range(10000, 1_000_000_000, ErrorMessage = "Số tiền nạp tối thiểu là 10.000đ")]
        public decimal SoTien { get; init; }
    }
}

using System;
using System.ComponentModel.DataAnnotations;

namespace Do_an_co_so.Api.Dtos
{
    /// <summary>
    /// Thông tin hiển thị trên màn "Tạo hợp đồng": chủ trọ thấy Bên B là ai trước khi lập văn bản.
    /// </summary>
    public class BenThueDto
    {
        public int PhongTroId { get; set; }
        public string? TenPhong { get; set; }
        public string DiaChiPhong { get; set; } = string.Empty;
        public decimal GiaThue { get; set; }
        public string? BenBId { get; set; }
        public string? TenBenB { get; set; }
        public DateTime? NgaySinhBenB { get; set; }
        public string? TenBenA { get; set; }
        public DateTime? NgaySinhBenA { get; set; }
    }

    public class TaoHopDongRequest
    {
        [Required]
        public int PhongTroId { get; set; }

        [Range(1, 120, ErrorMessage = "Thời hạn thuê phải từ 1 đến 120 tháng")]
        public int ThoiHanThang { get; set; } = 6;

        [Required]
        public DateTime NgayBatDau { get; set; }
    }

    public class HopDongDto
    {
        public int Id { get; set; }
        public int PhongTroId { get; set; }
        public string? TenPhong { get; set; }

        public string BenAId { get; set; } = string.Empty;
        public string TenBenA { get; set; } = string.Empty;
        public DateTime? NgaySinhBenA { get; set; }

        public string BenBId { get; set; } = string.Empty;
        public string TenBenB { get; set; } = string.Empty;
        public DateTime? NgaySinhBenB { get; set; }

        public string DiaChiPhong { get; set; } = string.Empty;
        public decimal GiaThue { get; set; }
        public int ThoiHanThang { get; set; }
        public DateTime NgayBatDau { get; set; }
        public DateTime NgayKetThuc { get; set; }

        /// <summary>ChoKy | DaKy | DaHuy — app tự đổi nhãn theo ngôn ngữ đang bật.</summary>
        public string TrangThai { get; set; } = string.Empty;

        /// <summary>"A" nếu người xem là chủ trọ, "B" nếu là sinh viên, rỗng nếu không liên quan.</summary>
        public string VaiTro { get; set; } = string.Empty;

        public DateTime? KyBenALuc { get; set; }
        public DateTime? KyBenBLuc { get; set; }
        public DateTime NgayLap { get; set; }

        public bool ConChoMinhKy { get; set; }
    }
}

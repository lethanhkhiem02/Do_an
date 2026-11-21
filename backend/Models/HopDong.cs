using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Do_an_co_so.Models
{
    /// <summary>
    /// Hợp đồng thuê phòng online: Bên A là chủ trọ, Bên B là sinh viên.
    /// Tên và ngày sinh được lưu snapshot từ hồ sơ lúc lập hợp đồng, nên sửa profile
    /// về sau không làm thay đổi nội dung văn bản đã ký.
    /// </summary>
    public class HopDong
    {
        [Key]
        public int Id { get; set; }

        public int PhongTroId { get; set; }
        [ForeignKey("PhongTroId")]
        public PhongTro PhongTro { get; set; }

        // --- BÊN A: CHỦ TRỌ ---
        public string BenAId { get; set; }
        [ForeignKey("BenAId")]
        public AppUser BenA { get; set; }

        [Display(Name = "Họ tên bên A")]
        public string TenBenA { get; set; }

        [Display(Name = "Ngày sinh bên A")]
        public DateTime? NgaySinhBenA { get; set; }

        // --- BÊN B: SINH VIÊN ---
        public string BenBId { get; set; }
        [ForeignKey("BenBId")]
        public AppUser BenB { get; set; }

        [Display(Name = "Họ tên bên B")]
        public string TenBenB { get; set; }

        [Display(Name = "Ngày sinh bên B")]
        public DateTime? NgaySinhBenB { get; set; }

        // --- THÔNG TIN THUÊ ---
        [Display(Name = "Địa chỉ phòng")]
        public string DiaChiPhong { get; set; }

        [Display(Name = "Giá thuê hàng tháng")]
        public decimal GiaThue { get; set; }

        [Display(Name = "Thời hạn (tháng)")]
        public int ThoiHanThang { get; set; } = 6;

        [Display(Name = "Ngày bắt đầu")]
        public DateTime NgayBatDau { get; set; } = DateTime.Now.Date;

        [NotMapped]
        [Display(Name = "Ngày kết thúc")]
        public DateTime NgayKetThuc => NgayBatDau.AddMonths(ThoiHanThang);

        // TrangThai: ChoKy (chờ bên còn lại) -> DaKy (đủ hai chữ ký) | DaHuy
        [Display(Name = "Trạng thái")]
        public string TrangThai { get; set; } = HopDongTrangThai.ChoKy;

        [Display(Name = "Bên A ký lúc")]
        public DateTime? KyBenALuc { get; set; }

        [Display(Name = "Bên B ký lúc")]
        public DateTime? KyBenBLuc { get; set; }

        [Display(Name = "Ngày lập")]
        public DateTime NgayLap { get; set; } = DateTime.Now;

        public string VaiTroCua(string userId)
        {
            if (userId == BenAId) return "A";
            if (userId == BenBId) return "B";
            return "";
        }
    }

    public static class HopDongTrangThai
    {
        public const string ChoKy = "ChoKy";
        public const string DaKy = "DaKy";
        public const string DaHuy = "DaHuy";
    }
}

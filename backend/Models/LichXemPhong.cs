using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Do_an_co_so.Models
{
    /// <summary>
    /// Lịch hẹn xem phòng trực tiếp do sinh viên tạo sau khi đặt cọc giữ chỗ thành công.
    /// Chủ trọ nhận thông báo rồi xác nhận hoặc từ chối.
    /// </summary>
    public class LichXemPhong
    {
        [Key]
        public int Id { get; set; }

        public int PhongTroId { get; set; }
        [ForeignKey("PhongTroId")]
        public PhongTro PhongTro { get; set; }

        // --- BÊN ĐẶT LỊCH: SINH VIÊN ---
        public string NguoiDatId { get; set; }
        [ForeignKey("NguoiDatId")]
        public AppUser NguoiDat { get; set; }

        // --- BÊN TRẢ LỜI: CHỦ BÀI ĐĂNG, lưu lại vì chủ trọ có thể đổi sau này ---
        public string ChuTroId { get; set; }
        [ForeignKey("ChuTroId")]
        public AppUser ChuTro { get; set; }

        [Required(ErrorMessage = "Vui lòng chọn thời gian xem phòng")]
        [Display(Name = "Thời gian hẹn")]
        public DateTime NgayHen { get; set; }

        [Display(Name = "Ghi chú")]
        [StringLength(300, ErrorMessage = "Ghi chú tối đa 300 ký tự")]
        public string? GhiChu { get; set; }

        /// "ChoXacNhan" | "DaXacNhan" | "DaTuChoi"
        public string TrangThai { get; set; } = "ChoXacNhan";

        public DateTime NgayTao { get; set; } = DateTime.Now;

        public DateTime? NgayPhanHoi { get; set; }
    }
}

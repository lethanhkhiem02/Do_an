using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Do_an_co_so.Models
{
    /// <summary>
    /// Bảng lưu cảnh báo bất thường khi chủ trọ đăng ảnh trùng lặp, spam nhiều bài
    /// hoặc ảnh mẫu 3D / watermark do AI Vision phát hiện.
    /// </summary>
    public class CanhBaoBatThuong
    {
        [Key]
        public int Id { get; set; }

        // Chủ trọ vi phạm
        [Required]
        public string UserId { get; set; } = string.Empty;

        [ForeignKey("UserId")]
        public virtual AppUser? User { get; set; }

        // Phòng trọ liên quan (nếu có)
        public int? PhongTroId { get; set; }

        [ForeignKey("PhongTroId")]
        public virtual PhongTro? PhongTro { get; set; }

        // LoaiViPham: 'AnhTrungLap', 'AnhMauTrenMang', 'SpamNhieuBai'
        [Required]
        [StringLength(50)]
        public string LoaiViPham { get; set; } = "AnhTrungLap";

        // Mô tả chi tiết kết quả kiểm tra hoặc tỷ lệ trùng lặp dHash
        [Required]
        public string MoTaChiTiet { get; set; } = string.Empty;

        // Đường dẫn file ảnh bằng chứng vi phạm
        public string? AnhBangChungUrl { get; set; }

        // Trạng thái admin đã xử lý cảnh báo này chưa
        public bool DaXuLy { get; set; } = false;

        public DateTime NgayTao { get; set; } = DateTime.Now;
    }
}

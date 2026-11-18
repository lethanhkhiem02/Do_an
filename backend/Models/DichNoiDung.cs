using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Do_an_co_so.Models
{
    // Bản dịch máy của một đoạn văn bản do người dùng nhập (mô tả phòng, địa chỉ...).
    // Mỗi đoạn chỉ tốn một lần gọi dịch vụ dịch; các lượt xem sau đọc lại từ bảng này.
    public class DichNoiDung
    {
        [Key]
        public int Id { get; set; }

        // Mã ngôn ngữ đích, vd "en".
        [Required, MaxLength(10)]
        public string NgonNgu { get; set; } = "en";

        // SHA-256 hex của "ngonNgu|vanBanGoc" — khóa tra cứu và chống trùng.
        [Required, MaxLength(64)]
        public string MaHash { get; set; } = "";

        [Column(TypeName = "nvarchar(max)")]
        public string VanBanGoc { get; set; } = "";

        [Column(TypeName = "nvarchar(max)")]
        public string BanDich { get; set; } = "";

        public DateTime NgayTao { get; set; } = DateTime.Now;
    }
}

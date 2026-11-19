using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Do_an_co_so.Models
{
    // Một tiện ích quanh phòng (trạm xe buýt, siêu thị, quán cafe, cây xăng,
    // cửa hàng tiện lợi). Chủ trọ lưu snapshot từ lần quét OpenStreetMap khi đăng
    // phòng, nên màn chi tiết đọc thẳng bảng này thay vì gọi lại Overpass mỗi lượt xem.
    public class TienIchXungQuanh
    {
        [Key]
        public int Id { get; set; }

        public int PhongTroId { get; set; }
        [ForeignKey("PhongTroId")]
        public PhongTro? PhongTro { get; set; }

        // Khóa ổn định để app tra icon và nhãn đã dịch: bus_stop, supermarket,
        // cafe, fuel, convenience.
        [Required]
        [StringLength(40)]
        public string Loai { get; set; } = "";

        // Tên riêng trong OpenStreetMap ("Circle K", "WinMart"...), không dịch.
        [StringLength(200)]
        public string? Ten { get; set; }

        public double ViDo { get; set; }

        public double KinhDo { get; set; }

        public int KhoangCachMet { get; set; }

        public DateTime QuetNgay { get; set; }
    }
}

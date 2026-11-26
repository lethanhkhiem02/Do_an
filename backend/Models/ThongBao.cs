using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Do_an_co_so.Models
{
    /// <summary>
    /// Hộp thư thông báo của một tài khoản (khác CanhBaoBatThuong vốn chỉ Admin xem).
    /// Không lưu câu chữ: chỉ lưu mã sự kiện rồi server dựng tiêu đề/nội dung theo ngôn
    /// ngữ của người đang xem, nhờ vậy bản tiếng Anh không bị lẫn text tiếng Việt.
    /// </summary>
    public class ThongBao
    {
        /// Sự kiện được ghi lại; câu chữ hiển thị dựng từ mã này lúc đọc.
        public const string LoaiDatLich = "DatLichXemPhong";
        public const string LoaiXacNhanLich = "XacNhanLichXemPhong";
        public const string LoaiTuChoiLich = "TuChoiLichXemPhong";

        [Key]
        public int Id { get; set; }

        public string NguoiNhanId { get; set; }
        [ForeignKey("NguoiNhanId")]
        public AppUser NguoiNhan { get; set; }

        /// "DatLichXemPhong" | "XacNhanLichXemPhong" | "TuChoiLichXemPhong"
        [Required]
        public string Loai { get; set; } = "HeThong";

        /// Tài khoản gây ra sự kiện: sinh viên vừa đặt lịch hoặc chủ trọ vừa trả lời.
        public string? TacNhanId { get; set; }
        [ForeignKey("TacNhanId")]
        public AppUser? TacNhan { get; set; }

        /// Lịch hẹn liên quan. Cố ý đặt tên khác "LichXemPhongId" để EF không sinh
        /// khóa ngoại: bảng này đã có hai đường cascade từ AppUser và PhongTro, thêm
        /// đường thứ ba nữa là SQL Server từ chối migration vì trùng luồng xóa.
        public int? MaLichXemPhong { get; set; }

        public bool DaDoc { get; set; } = false;

        public DateTime NgayTao { get; set; } = DateTime.Now;
    }
}

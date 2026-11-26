using System.ComponentModel.DataAnnotations;

namespace Do_an_co_so.Api.Dtos
{
    // ============================ LỊCH XEM PHÒNG TRỰC TIẾP ============================

    public class TaoLichXemPhongRequest
    {
        [Range(1, int.MaxValue, ErrorMessage = "Phòng trọ không hợp lệ")]
        public int PhongTroId { get; init; }

        public DateTime NgayHen { get; init; }

        [StringLength(300, ErrorMessage = "Ghi chú tối đa 300 ký tự")]
        public string? GhiChu { get; init; }
    }

    public class LichXemPhongDto
    {
        public int Id { get; init; }
        public int PhongTroId { get; init; }
        public string? DiaChiPhong { get; init; }
        public string? TenPhong { get; init; }

        public string NguoiDatId { get; init; } = "";
        public string? TenNguoiDat { get; init; }
        public string ChuTroId { get; init; } = "";

        public DateTime NgayHen { get; init; }
        public string? GhiChu { get; init; }

        /// "ChoXacNhan" | "DaXacNhan" | "DaTuChoi" - app dựa vào đây để hiện nút.
        public string TrangThai { get; init; } = "";
        public DateTime NgayTao { get; init; }
        public DateTime? NgayPhanHoi { get; init; }
    }
}

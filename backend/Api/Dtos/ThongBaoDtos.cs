namespace Do_an_co_so.Api.Dtos
{
    // ============================ THÔNG BÁO TRONG APP ============================

    public class ThongBaoDto
    {
        public int Id { get; init; }

        /// Mã sự kiện, app dùng để chọn icon và màn hình cần mở khi bấm vào.
        public string Loai { get; init; } = "";

        // Tiêu đề và nội dung đã theo ngôn ngữ của người đang xem.
        public string TieuDe { get; init; } = "";
        public string? NoiDung { get; init; }

        public int? MaLichXemPhong { get; init; }
        public int? PhongTroId { get; init; }
        public DateTime? NgayHen { get; init; }

        /// Trạng thái lịch hẹn lúc xem, để chủ trọ biết lịch còn chờ duyệt hay không.
        public string? TrangThaiLich { get; init; }

        public bool DaDoc { get; init; }
        public DateTime NgayTao { get; init; }
    }

    public class ThongBaoListResponse
    {
        public List<ThongBaoDto> DanhSach { get; init; } = new();
        public int SoChuaDoc { get; init; }
    }
}

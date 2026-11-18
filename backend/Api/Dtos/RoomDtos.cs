using System.ComponentModel.DataAnnotations;

namespace Do_an_co_so.Api.Dtos
{
    // ============================ PHÒNG TRỌ ============================

    public class RoomListItemDto
    {
        public int Id { get; init; }
        public string MoTa { get; init; } = "";
        public decimal Gia { get; init; }
        public string DiaChi { get; init; } = "";
        public List<string> Anh { get; init; } = new();
        public double? Latitude { get; init; }
        public double? Longitude { get; init; }
        public bool IsVip { get; init; }
        public bool DaChoThue { get; init; }
        public bool CoNhaVeSinh { get; init; }
        public bool CoBanCong { get; init; }
        public double? ChieuDai { get; init; }
        public double? ChieuRong { get; init; }
        public double? DienTich => (ChieuDai > 0 && ChieuRong > 0) ? ChieuDai * ChieuRong : null;
        public DateTime? NgayHetHan { get; init; }
        public int? SoNgayGiuPhong { get; init; }

        // Khoảng cách tới trường đã chọn (0 khi chưa chọn trường / phòng không có tọa độ)
        public double KhoangCach { get; init; }
        public double TrungBinhSao { get; init; }
        public int SoDanhGia { get; init; }

        public string? ChuTroId { get; init; }
        public string? TenChuTro { get; init; }

        // Trạng thái hiển thị cho app: ConTrong / DangGiuCho / DaChoThue / HetHien
        public string TrangThai { get; init; } = "ConTrong";
    }

    public class ReviewDto
    {
        public int Id { get; init; }
        public int Sao { get; init; }
        public string NoiDung { get; init; } = "";
        public DateTime NgayTao { get; init; }
        public string?NguoiDanhGia { get; init; }
        public string UserId { get; init; } = "";
    }

    public class RoomDetailDto : RoomListItemDto
    {
        public string? AvatarChuTro { get; init; }
        public string? ChuTroDienThoai { get; init; }
        public string? ChuTroDiaChi { get; init; }
        public string? ChuTroXacThuc { get; init; }
        public string? NguoiDatCocId { get; init; }
        public decimal? TienCoc { get; init; }
        public DateTime? HanDatCoc { get; init; }
        public List<ReviewDto> DanhGia { get; init; } = new();

        // Quyền của người đang gọi, để app ẩn/hiện nút
        public bool DuocDanhGia { get; init; }
        public bool DaDatCoc { get; init; }
        public bool DaThue { get; init; }
    }

    public class SearchRoomsResponse
    {
        public List<RoomListItemDto> Phong { get; init; } = new();
        public string? TruongId { get; init; }
        public string? TenTruong { get; init; }
        public double? BanKinh { get; init; }
        public string SapXep { get; init; } = "distance_asc";
    }

    public class CreateRoomRequest
    {
        [Required(ErrorMessage = "Vui lòng nhập mô tả")]
        public string MoTa { get; init; } = "";

        [Required(ErrorMessage = "Vui lòng nhập giá phòng")]
        [Range(0, 1_000_000_000, ErrorMessage = "Giá phòng không hợp lệ")]
        public decimal Gia { get; init; }

        [Required(ErrorMessage = "Vui lòng nhập địa chỉ")]
        public string DiaChi { get; init; } = "";

        public double? Latitude { get; init; }
        public double? Longitude { get; init; }
        public bool IsVip { get; init; }
        public double? ChieuDai { get; init; }
        public double? ChieuRong { get; init; }
        public bool CoNhaVeSinh { get; init; }
        public bool CoBanCong { get; init; }
        public int? SoNgayDangBai { get; init; }
        public int? SoNgayGiuPhong { get; init; }
    }

    public class CreateReviewRequest
    {
        [Range(1, 5, ErrorMessage = "Vui lòng chọn số sao từ 1 đến 5")]
        public int Sao { get; init; }

        [Required(ErrorMessage = "Vui lòng nhập nội dung đánh giá")]
        public string NoiDung { get; init; } = "";
    }

    public class CreateReportRequest
    {
        [Required(ErrorMessage = "Vui lòng chọn lý do báo cáo")]
        public string LyDo { get; init; } = "";

        public string? ChiTiet { get; init; }
    }

    public class InvoiceDto
    {
        public int Id { get; init; }
        public int PhongTroId { get; init; }
        public string? TenPhong { get; init; }
        public string? DiaChiPhong { get; init; }
        public string? ChuTro { get; init; }
        public decimal TongTien { get; init; }
        public decimal TienHoaHong { get; init; }
        public decimal TienChuTroNhan { get; init; }
        public DateTime NgayGiaoDich { get; init; }
        public string LoaiHoaDon { get; init; } = "";
        public string TrangThai { get; init; } = "";
    }

    public class WalletDto
    {
        public decimal SoDu { get; init; }
        public string TrangThaiXacThuc { get; init; } = "";
        public List<InvoiceDto> GiaoDich { get; init; } = new();
    }
}

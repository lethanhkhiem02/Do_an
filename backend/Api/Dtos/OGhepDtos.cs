using System;
using System.ComponentModel.DataAnnotations;

namespace Do_an_co_so.Api.Dtos
{
    public class PhongTroSummaryDto
    {
        public int Id { get; set; }
        public string? MoTa { get; set; }
        public string? DiaChi { get; set; }
        public decimal Gia { get; set; }
        public string? AnhDaiDien { get; set; }
    }

    public class HoSoOGhepRequest
    {
        [Required(ErrorMessage = "Vui lòng chọn giờ giấc sinh hoạt")]
        public string GioGiacSinhHoat { get; set; } = "Linh hoạt";

        public string GioiTinhUuTien { get; set; } = "Không yêu cầu";

        public bool CoNauAn { get; set; }

        public bool CoNuoiPet { get; set; }

        public bool KhongHutThuoc { get; set; }

        public bool UaSachSe { get; set; }

        [Range(0, double.MaxValue, ErrorMessage = "Ngân sách không hợp lệ")]
        public decimal NganSachToiDa { get; set; }

        [Required(ErrorMessage = "Vui lòng nhập khu vực mong muốn")]
        public string KhuVucMongMuon { get; set; } = string.Empty;

        /// <summary>
        /// true = "Đã có phòng, tìm người ở cùng để chia tiền"
        /// false = "Chưa có phòng, tìm chỗ ở ghép hoặc tìm bạn đi thuê chung"
        /// </summary>
        public bool DaCoPhong { get; set; } = false;

        public int? PhongTroId { get; set; }

        public string? DiaChiPhongHienTai { get; set; }

        public decimal? GiaChiaMoiNguoi { get; set; }

        public string? ThoiGianDonVao { get; set; }

        public string? MoTaThem { get; set; }

        public bool DangTimBan { get; set; } = true;
    }

    public class HoSoOGhepDto
    {
        public int Id { get; set; }
        public string UserId { get; set; } = string.Empty;
        public string GioGiacSinhHoat { get; set; } = "Linh hoạt";
        public string GioiTinhUuTien { get; set; } = "Không yêu cầu";
        public bool CoNauAn { get; set; }
        public bool CoNuoiPet { get; set; }
        public bool KhongHutThuoc { get; set; }
        public bool UaSachSe { get; set; }
        public decimal NganSachToiDa { get; set; }
        public string KhuVucMongMuon { get; set; } = string.Empty;

        public bool DaCoPhong { get; set; }
        public int? PhongTroId { get; set; }
        public string? DiaChiPhongHienTai { get; set; }
        public decimal? GiaChiaMoiNguoi { get; set; }
        public string? ThoiGianDonVao { get; set; }
        public PhongTroSummaryDto? PhongTro { get; set; }

        public string? MoTaThem { get; set; }
        public bool DangTimBan { get; set; } = true;
        public DateTime NgayCapNhat { get; set; }

        public string? HoTen { get; set; }
        public string? Avatar { get; set; }
        public string? PhoneNumber { get; set; }
    }

    public class GoiYOGhepDto
    {
        public int Id { get; set; }
        public string UserId { get; set; } = string.Empty;
        public string HoTen { get; set; } = string.Empty;
        public string? Avatar { get; set; }
        public string? PhoneNumber { get; set; }
        public string GioGiacSinhHoat { get; set; } = "Linh hoạt";
        public string GioiTinhUuTien { get; set; } = "Không yêu cầu";
        public bool CoNauAn { get; set; }
        public bool CoNuoiPet { get; set; }
        public bool KhongHutThuoc { get; set; }
        public bool UaSachSe { get; set; }
        public decimal NganSachToiDa { get; set; }
        public string KhuVucMongMuon { get; set; } = string.Empty;

        public bool DaCoPhong { get; set; }
        public int? PhongTroId { get; set; }
        public string? DiaChiPhongHienTai { get; set; }
        public decimal? GiaChiaMoiNguoi { get; set; }
        public string? ThoiGianDonVao { get; set; }
        public PhongTroSummaryDto? PhongTro { get; set; }

        public string? MoTaThem { get; set; }
        public bool DangTimBan { get; set; } = true;
        public DateTime NgayCapNhat { get; set; }
        public int PhanTramPhuHop { get; set; }
        public int UuTienBoTro { get; set; } // 1: Bổ trợ cao nhất, 2: Cùng thuê chung, 3: Khác

        // Các cờ đánh dấu tiêu chí trùng khớp với người xem
        public bool MatchGioiTinh { get; set; }
        public bool MatchKhuVuc { get; set; }
        public bool MatchNganSach { get; set; }
        public bool MatchGiaChia { get; set; }
        public bool MatchThoiGianDonVao { get; set; }
        public bool MatchGioGiac { get; set; }
        public bool MatchNauAn { get; set; }
        public bool MatchNuoiPet { get; set; }
        public bool MatchKhongHutThuoc { get; set; }
        public bool MatchUaSachSe { get; set; }
    }
}

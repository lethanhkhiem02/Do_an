using System;
using System.ComponentModel.DataAnnotations;

namespace Do_an_co_so.Api.Dtos
{
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
        public string? MoTaThem { get; set; }
        public bool DangTimBan { get; set; } = true;
        public DateTime NgayCapNhat { get; set; }
        public int PhanTramPhuHop { get; set; }

        // Các cờ đánh dấu tiêu chí trùng khớp với người xem
        public bool MatchGioiTinh { get; set; }
        public bool MatchKhuVuc { get; set; }
        public bool MatchNganSach { get; set; }
        public bool MatchGioGiac { get; set; }
        public bool MatchNauAn { get; set; }
        public bool MatchNuoiPet { get; set; }
        public bool MatchKhongHutThuoc { get; set; }
        public bool MatchUaSachSe { get; set; }
    }
}

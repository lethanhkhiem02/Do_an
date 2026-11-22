using System;

namespace Do_an_co_so.Api.Dtos
{
    public class CanhBaoItemDto
    {
        public int Id { get; set; }
        public string UserId { get; set; } = string.Empty;
        public string? TenChuTro { get; set; }
        public string? EmailChuTro { get; set; }
        public string? SoDienThoaiChuTro { get; set; }
        public bool TrangThaiKhoaChuTro { get; set; }

        public int? PhongTroId { get; set; }
        public string? TieuDePhongTro { get; set; }
        public decimal? GiaPhongTro { get; set; }
        public string? DiaChiPhongTro { get; set; }

        public string LoaiViPham { get; set; } = string.Empty;
        public string MoTaChiTiet { get; set; } = string.Empty;
        public string? AnhBangChungUrl { get; set; }
        public bool DaXuLy { get; set; }
        public DateTime NgayTao { get; set; }
    }

    public class XuLyCanhBaoRequest
    {
        public bool KhoaTaiKhoan { get; set; } = false;
        public string? GhiChu { get; set; }
    }
}

using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Do_an_co_so.Services
{
    // Phần tiền phạt hủy cọc nằm treo trong ví nền tảng. Hết hạn khiếu nại mà admin
    // không phân xử thì mặc định bồi thường cho chủ trọ bị giữ phòng oan.
    // Đồ án không có background job nên việc tất toán chạy lười mỗi khi có người đọc ví
    // hoặc mở danh sách báo cáo của admin.
    public class GiaiNganPhatCocService
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public GiaiNganPhatCocService(ApplicationDbContext db, UserManager<AppUser> userManager)
        {
            _db = db;
            _userManager = userManager;
        }

        public async Task<int> QuetDenHanAsync()
        {
            var moc = DateTime.Now.AddDays(-VnPayOptions.SoNgayChoXuLyPhatCoc);

            var treo = await _db.HoaDons
                .Where(h => h.LoaiHoaDon == "PhatCoc" && h.TrangThai == "ChoGiaiNgan" && h.NgayGiaoDich <= moc)
                .ToListAsync();

            if (treo.Count == 0) return 0;

            var admin = await _userManager.FindByEmailAsync("admin@gmail.com");
            if (admin == null) return 0;

            int daTatToan = 0;

            foreach (var hoaDon in treo)
            {
                var chuTroId = await _db.PhongTro
                    .Where(p => p.Id == hoaDon.PhongTroId)
                    .Select(p => p.ChuTroId)
                    .FirstOrDefaultAsync();

                var chuTro = string.IsNullOrEmpty(chuTroId)
                    ? null
                    : await _userManager.FindByIdAsync(chuTroId);

                if (chuTro == null) continue;

                admin.SoDu -= hoaDon.TienChuTroNhan;
                chuTro.SoDu += hoaDon.TienChuTroNhan;
                hoaDon.TrangThai = "PhatChoChuTro";
                daTatToan++;
            }

            if (daTatToan > 0) await _db.SaveChangesAsync();
            return daTatToan;
        }

        // Admin xác nhận tố cáo đúng: lấy phần phạt đang treo (hoặc đã trót trả chủ trọ) trả lại sinh viên.
        public async Task<(bool ThanhCong, string? Loai)> HoanVeNguoiBaoCaoAsync(int hoaDonPhatId, string nguoiBaoCaoId)
        {
            var hoaDon = await _db.HoaDons.FirstOrDefaultAsync(h =>
                h.Id == hoaDonPhatId && h.LoaiHoaDon == "PhatCoc" && h.NguoiThueId == nguoiBaoCaoId);

            if (hoaDon == null) return (false, null);
            if (hoaDon.TrangThai == "HoanChoNguoiBaoCao") return (true, hoaDon.TrangThai);
            if (hoaDon.TrangThai != "ChoGiaiNgan" && hoaDon.TrangThai != "PhatChoChuTro") return (false, hoaDon.TrangThai);

            var admin = await _userManager.FindByEmailAsync("admin@gmail.com");
            var nguoiBaoCao = await _userManager.FindByIdAsync(nguoiBaoCaoId);
            if (admin == null || nguoiBaoCao == null) return (false, hoaDon.TrangThai);

            if (hoaDon.TrangThai == "PhatChoChuTro")
            {
                var chuTroId = await _db.PhongTro
                    .Where(p => p.Id == hoaDon.PhongTroId)
                    .Select(p => p.ChuTroId)
                    .FirstOrDefaultAsync();
                var chuTro = string.IsNullOrEmpty(chuTroId) ? null : await _userManager.FindByIdAsync(chuTroId);
                if (chuTro != null) chuTro.SoDu -= hoaDon.TienChuTroNhan;
            }
            else
            {
                admin.SoDu -= hoaDon.TienChuTroNhan;
            }

            nguoiBaoCao.SoDu += hoaDon.TienChuTroNhan;
            hoaDon.TrangThai = "HoanChoNguoiBaoCao";
            await _db.SaveChangesAsync();

            return (true, hoaDon.TrangThai);
        }
    }
}

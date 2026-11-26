using Do_an_co_so.Api.Dtos;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Do_an_co_so.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Localization;

namespace Do_an_co_so.Api
{
    /// Hộp thư thông báo của tài khoản đang đăng nhập. Chuông ở app gọi
    /// api/thong-bao/chua-doc lấy số badge, mở chuông thì gọi api/thong-bao lấy danh sách.
    [Route("api/thong-bao")]
    public class ThongBaoApiController : ApiControllerBase
    {
        private const int SoLuongTienCua = 50;

        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;
        private readonly NoiDungDichService _dich;

        public ThongBaoApiController(ApplicationDbContext db, UserManager<AppUser> userManager,
            NoiDungDichService dich, IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _db = db;
            _userManager = userManager;
            _dich = dich;
        }

        [HttpGet]
        public async Task<ActionResult<ThongBaoListResponse>> DanhSach()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var danhSach = await _db.ThongBaos
                .Where(t => t.NguoiNhanId == user.Id)
                .OrderByDescending(t => t.NgayTao)
                .Take(SoLuongTienCua)
                .ToListAsync();

            var soChuaDoc = await _db.ThongBaos.CountAsync(t => t.NguoiNhanId == user.Id && !t.DaDoc);

            return Ok(new ThongBaoListResponse
            {
                DanhSach = await ToDtosAsync(danhSach),
                SoChuaDoc = soChuaDoc
            });
        }

        [HttpGet("chua-doc")]
        public async Task<IActionResult> ChuaDoc()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var soChuaDoc = await _db.ThongBaos.CountAsync(t => t.NguoiNhanId == user.Id && !t.DaDoc);
            return Ok(new { soChuaDoc });
        }

        [HttpPost("{id:int}/da-doc")]
        public async Task<IActionResult> DaDoc(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var thongBao = await _db.ThongBaos.FirstOrDefaultAsync(t => t.Id == id && t.NguoiNhanId == user.Id);
            if (thongBao == null) return NotFound(new ApiError(Localizer["Api_NotificationNotFound"]));

            thongBao.DaDoc = true;
            await _db.SaveChangesAsync();
            return Ok(new MessageResponse(Localizer["Api_MarkReadDone"]));
        }

        [HttpPost("doc-tat-ca")]
        public async Task<IActionResult> DocTatCa()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            await _db.ThongBaos
                .Where(t => t.NguoiNhanId == user.Id && !t.DaDoc)
                .ExecuteUpdateAsync(s => s.SetProperty(t => t.DaDoc, true));

            return Ok(new MessageResponse(Localizer["Api_MarkAllReadDone"]));
        }

        // ================================ TIỆN ÍCH NỘI BỘ ================================

        private async Task<AppUser?> CurrentUserAsync()
            => await _userManager.FindByIdAsync(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "");

        /// Thông báo chỉ lưu mã sự kiện, câu chữ ghép ở đây nên người xem tiếng Anh
        /// nhận bản tiếng Anh kể cả khi người tạo sự dùng tiếng Việt.
        private async Task<List<ThongBaoDto>> ToDtosAsync(List<ThongBao> danhSach)
        {
            var lichIds = danhSach.Where(t => t.MaLichXemPhong != null)
                                  .Select(t => t.MaLichXemPhong!.Value).Distinct().ToList();

            var lichs = lichIds.Count == 0
                ? new Dictionary<int, LichXemPhong>()
                : await _db.LichXemPhongs
                    .Include(l => l.PhongTro)
                    .Where(l => lichIds.Contains(l.Id))
                    .ToDictionaryAsync(l => l.Id);

            var tenIds = danhSach.Where(t => t.TacNhanId != null).Select(t => t.TacNhanId!).Distinct().ToList();
            var ten = tenIds.Count == 0
                ? new Dictionary<string, string>()
                : await _db.Users
                    .Where(u => tenIds.Contains(u.Id!))
                    .ToDictionaryAsync(u => u.Id!, u => u.HoTen ?? u.UserName ?? "");

            var diaChi = await _dich.TaoHamDichAsync(
                lichs.Values.Select(l => l.PhongTro?.DiaChi));

            return danhSach.Select(t =>
            {
                LichXemPhong? lich = t.MaLichXemPhong != null && lichs.TryGetValue(t.MaLichXemPhong.Value, out var tim) ? tim : null;
                var tenTacNhan = t.TacNhanId != null && ten.TryGetValue(t.TacNhanId, out var gia) ? gia : "";

                return new ThongBaoDto
                {
                    Id = t.Id,
                    Loai = t.Loai,
                    TieuDe = TieuDe(t.Loai),
                    NoiDung = NoiDung(t.Loai, tenTacNhan, lich == null ? null : diaChi(lich.PhongTro?.DiaChi), lich?.NgayHen),
                    MaLichXemPhong = t.MaLichXemPhong,
                    PhongTroId = lich?.PhongTroId,
                    NgayHen = lich?.NgayHen,
                    TrangThaiLich = lich?.TrangThai,
                    DaDoc = t.DaDoc,
                    NgayTao = t.NgayTao
                };
            }).ToList();
        }

        private string TieuDe(string loai) => loai switch
        {
            ThongBao.LoaiDatLich => Localizer["Noti_ViewingRequested"],
            ThongBao.LoaiXacNhanLich => Localizer["Noti_ViewingConfirmed"],
            ThongBao.LoaiTuChoiLich => Localizer["Noti_ViewingDeclined"],
            _ => Localizer["Noti_Generic"]
        };

        private string? NoiDung(string loai, string tenTacNhan, string? diaChiPhong, DateTime? ngayHen)
        {
            if (loai == ThongBao.LoaiDatLich || loai == ThongBao.LoaiXacNhanLich || loai == ThongBao.LoaiTuChoiLich)
            {
                if (string.IsNullOrEmpty(diaChiPhong) || ngayHen == null) return null;
            }

            // Câu chữ tiếng Anh ghép giới từ "on" phía trước nên mốc thời gian phải bắt
            // đầu bằng ngày ("on Dec 5, 2026 at 9:00 AM"); tiếng Việt giữ đồng hồ 24h.
            // Phải đọc CurrentUICulture vì tầng API ép CurrentCulture về InvariantCulture
            // để bind số không bị hiểu nhầm dấu chấm là phân cách hàng nghìn.
            var tiengAnh = System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "en";
            var gioHen = ngayHen?.ToString(tiengAnh ? "MMM d, yyyy 'at' h:mm tt" : "HH:mm dd/MM/yyyy");

            return loai switch
            {
                ThongBao.LoaiDatLich => Localizer["Noti_ViewingRequestedBody", tenTacNhan, diaChiPhong, gioHen],
                ThongBao.LoaiXacNhanLich => Localizer["Noti_ViewingConfirmedBody", tenTacNhan, diaChiPhong, gioHen],
                ThongBao.LoaiTuChoiLich => Localizer["Noti_ViewingDeclinedBody", tenTacNhan, diaChiPhong, gioHen],
                _ => null
            };
        }
    }
}

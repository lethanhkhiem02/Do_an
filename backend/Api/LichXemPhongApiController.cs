using Do_an_co_so.Api.Dtos;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Do_an_co_so.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Localization;

namespace Do_an_co_so.Api
{
    /// Lịch hẹn xem phòng trực tiếp. Sinh viên chỉ đặt được sau khi đặt cọc giữ chỗ
    /// thành công; chủ trọ nhận thông báo rồi xác nhận hoặc từ chối ngay trong hộp thư.
    [Route("api/lich-xem-phong")]
    public class LichXemPhongApiController : ApiControllerBase
    {
        public const string ChoXacNhan = "ChoXacNhan";
        public const string DaXacNhan = "DaXacNhan";
        public const string DaTuChoi = "DaTuChoi";

        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;
        private readonly ThongBaoService _thongBao;
        private readonly NoiDungDichService _dich;

        public LichXemPhongApiController(ApplicationDbContext db, UserManager<AppUser> userManager,
            ThongBaoService thongBao, NoiDungDichService dich,
            IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _db = db;
            _userManager = userManager;
            _thongBao = thongBao;
            _dich = dich;
        }

        // ------------------------------- SINH VIÊN ĐẶT LỊCH -------------------------------

        [Authorize(Roles = "SinhVien")]
        [HttpPost]
        public async Task<ActionResult<LichXemPhongDto>> Tao([FromBody] TaoLichXemPhongRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var room = await _db.PhongTro.FirstOrDefaultAsync(p => p.Id == request.PhongTroId);
            if (room == null) return NotFound(new ApiError(Localizer["Api_RoomNotFound"]));
            if (string.IsNullOrEmpty(room.ChuTroId))
            {
                return BadRequest(new ApiError(Localizer["Api_RoomHasNoLandlord"]));
            }

            // Đúng nghiệp vụ đề bài: chỉ người đang giữ chỗ bằng tiền cọc mới xin hẹn xem phòng.
            if (room.NguoiDatCocId != user.Id)
            {
                return StatusCode(403, new ApiError(Localizer["Api_ViewingNeedsDeposit"]));
            }

            if (request.NgayHen <= DateTime.Now)
            {
                return BadRequest(new ApiError(Localizer["Api_ViewingTimeMustBeFuture"]));
            }

            var dangChoDuyet = await _db.LichXemPhongs.AnyAsync(l =>
                l.PhongTroId == room.Id && l.NguoiDatId == user.Id && l.TrangThai == ChoXacNhan);
            if (dangChoDuyet)
            {
                return BadRequest(new ApiError(Localizer["Api_ViewingAlreadyPending"]));
            }

            var lich = new LichXemPhong
            {
                PhongTroId = room.Id,
                NguoiDatId = user.Id,
                ChuTroId = room.ChuTroId,
                NgayHen = request.NgayHen,
                GhiChu = string.IsNullOrWhiteSpace(request.GhiChu) ? null : request.GhiChu.Trim(),
                TrangThai = ChoXacNhan,
                NgayTao = DateTime.Now
            };

            _db.LichXemPhongs.Add(lich);
            await _db.SaveChangesAsync();

            await _thongBao.GhiAsync(lich.ChuTroId, ThongBao.LoaiDatLich, user.Id, lich.Id);

            var phong = await _db.PhongTro.Include(p => p.ChuTro).FirstAsync(p => p.Id == room.Id);
            lich.PhongTro = phong;
            lich.NguoiDat = user;
            return Ok(await ToDtoAsync(lich));
        }

        [Authorize(Roles = "SinhVien")]
        [HttpGet("cua-toi")]
        public async Task<ActionResult<List<LichXemPhongDto>>> CuaToi()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var danhSach = await _db.LichXemPhongs
                .Include(l => l.PhongTro)
                .Include(l => l.NguoiDat)
                .Where(l => l.NguoiDatId == user.Id)
                .OrderByDescending(l => l.NgayHen)
                .ToListAsync();

            return Ok(await ToDtosAsync(danhSach));
        }

        // ------------------------------- CHỦ TRỌ DUYỆT LỊCH -------------------------------

        [Authorize(Roles = "ChuTro")]
        [HttpGet("cua-chu-tro")]
        public async Task<ActionResult<List<LichXemPhongDto>>> CuaChuTro()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var danhSach = await _db.LichXemPhongs
                .Include(l => l.PhongTro)
                .Include(l => l.NguoiDat)
                .Where(l => l.ChuTroId == user.Id)
                .OrderByDescending(l => l.NgayHen)
                .ToListAsync();

            return Ok(await ToDtosAsync(danhSach));
        }

        [Authorize(Roles = "ChuTro")]
        [HttpPost("{id:int}/xac-nhan")]
        public async Task<IActionResult> XacNhan(int id) => await PhanHoi(id, DaXacNhan, ThongBao.LoaiXacNhanLich, "Api_AppointmentConfirmed");

        [Authorize(Roles = "ChuTro")]
        [HttpPost("{id:int}/tu-choi")]
        public async Task<IActionResult> TuChoi(int id) => await PhanHoi(id, DaTuChoi, ThongBao.LoaiTuChoiLich, "Api_AppointmentDeclined");

        private async Task<IActionResult> PhanHoi(int id, string trangThaiMoi, string loaiThongBao, string maLoiThanhCong)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            // Chỉ chủ của bài đăng mới được trả lời lịch hẹn của nó.
            var lich = await _db.LichXemPhongs.FirstOrDefaultAsync(l => l.Id == id && l.ChuTroId == user.Id);
            if (lich == null) return NotFound(new ApiError(Localizer["Api_AppointmentNotFound"]));
            if (lich.TrangThai != ChoXacNhan)
            {
                return BadRequest(new ApiError(Localizer["Api_AppointmentNotPending"]));
            }

            lich.TrangThai = trangThaiMoi;
            lich.NgayPhanHoi = DateTime.Now;
            await _db.SaveChangesAsync();

            await _thongBao.GhiAsync(lich.NguoiDatId, loaiThongBao, user.Id, lich.Id);

            return Ok(new MessageResponse(Localizer[maLoiThanhCong]));
        }

        // ================================ TIỆN ÍCH NỘI BỘ ================================

        private async Task<AppUser?> CurrentUserAsync()
            => await _userManager.FindByIdAsync(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "");

        private async Task<List<LichXemPhongDto>> ToDtosAsync(List<LichXemPhong> danhSach)
        {
            // Địa chỉ, tiêu đề và ghi chú là chữ người dùng viết tiếng Việt nên phải qua
            // máy dịch; tên người thì giữ nguyên ở mọi ngôn ngữ.
            var dich = await _dich.TaoHamDichAsync(danhSach
                .SelectMany(l => new string?[] { l.PhongTro?.DiaChi, l.PhongTro?.MoTa, l.GhiChu }));

            return danhSach.Select(l => new LichXemPhongDto
            {
                Id = l.Id,
                PhongTroId = l.PhongTroId,
                DiaChiPhong = dich(l.PhongTro?.DiaChi),
                TenPhong = dich(l.PhongTro?.MoTa),
                NguoiDatId = l.NguoiDatId,
                TenNguoiDat = l.NguoiDat?.HoTen ?? l.NguoiDat?.UserName,
                ChuTroId = l.ChuTroId,
                NgayHen = l.NgayHen,
                GhiChu = dich(l.GhiChu),
                TrangThai = l.TrangThai,
                NgayTao = l.NgayTao,
                NgayPhanHoi = l.NgayPhanHoi
            }).ToList();
        }

        private async Task<LichXemPhongDto> ToDtoAsync(LichXemPhong lich)
            => (await ToDtosAsync(new List<LichXemPhong> { lich }))[0];
    }
}

using System.Security.Claims;
using Do_an_co_so.Api.Dtos;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Localization;

namespace Do_an_co_so.Api
{
    /// <summary>
    /// Hợp đồng thuê phòng online. Chủ trọ lập hợp đồng từ phòng đang cho thuê,
    /// sinh viên xác nhận (ký) ngay trong app.
    /// </summary>
    [Route("api/hop-dong")]
    public class HopDongApiController : ApiControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public HopDongApiController(
            ApplicationDbContext db,
            UserManager<AppUser> userManager,
            IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _db = db;
            _userManager = userManager;
        }

        [HttpGet("danh-sach")]
        public async Task<ActionResult<List<HopDongDto>>> DanhSach()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var danhsach = await _db.HopDongs
                .AsNoTracking()
                .Include(h => h.PhongTro)
                .Where(h => h.BenAId == user.Id || h.BenBId == user.Id)
                .OrderByDescending(h => h.NgayLap)
                .ToListAsync();

            return Ok(danhsach.Select(h => ToDto(h, user.Id)).ToList());
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<HopDongDto>> ChiTiet(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var hopDong = await _db.HopDongs
                .AsNoTracking()
                .Include(h => h.PhongTro)
                .FirstOrDefaultAsync(h => h.Id == id);

            if (hopDong == null) return NotFound(new ApiError(Localizer["Api_ContractNotFound"]));
            if (hopDong.BenAId != user.Id && hopDong.BenBId != user.Id) return Forbid();

            return Ok(ToDto(hopDong, user.Id));
        }

        /// <summary>
        /// Cho chủ trọ xem trước Bên B (tên + ngày sinh) của phòng đang cho thuê
        /// trước khi bấm lập hợp đồng.
        /// </summary>
        [Authorize(Roles = "ChuTro")]
        [HttpGet("khach-thue/{phongTroId:int}")]
        public async Task<ActionResult<BenThueDto>> KhachThue(int phongTroId)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var room = await _db.PhongTro
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.Id == phongTroId && p.ChuTroId == user.Id);
            if (room == null) return NotFound(new ApiError(Localizer["Api_YourRoomNotFound"]));

            var khach = await TimKhachThueAsync(room);
            if (khach == null) return NotFound(new ApiError(Localizer["Api_ContractNoTenant"]));

            return Ok(new BenThueDto
            {
                PhongTroId = room.Id,
                TenPhong = room.MoTa,
                DiaChiPhong = room.DiaChi,
                GiaThue = room.Gia,
                BenBId = khach.Id,
                TenBenB = TenCua(khach),
                NgaySinhBenB = khach.NgaySinh,
                TenBenA = TenCua(user),
                NgaySinhBenA = user.NgaySinh
            });
        }

        [Authorize(Roles = "ChuTro")]
        [HttpPost]
        public async Task<ActionResult<HopDongDto>> Tao([FromBody] TaoHopDongRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var room = await _db.PhongTro
                .FirstOrDefaultAsync(p => p.Id == request.PhongTroId && p.ChuTroId == user.Id);
            if (room == null) return NotFound(new ApiError(Localizer["Api_YourRoomNotFound"]));

            var khach = await TimKhachThueAsync(room);
            if (khach == null) return NotFound(new ApiError(Localizer["Api_ContractNoTenant"]));
            if (khach.Id == user.Id) return BadRequest(new ApiError(Localizer["Api_ContractSelfRent"]));

            var conHieuLuc = await _db.HopDongs.AnyAsync(h =>
                h.PhongTroId == room.Id &&
                h.BenBId == khach.Id &&
                h.TrangThai != HopDongTrangThai.DaHuy);
            if (conHieuLuc) return BadRequest(new ApiError(Localizer["Api_ContractExists"]));

            var hopDong = new HopDong
            {
                PhongTroId = room.Id,
                BenAId = user.Id,
                TenBenA = TenCua(user),
                NgaySinhBenA = user.NgaySinh,
                BenBId = khach.Id,
                TenBenB = TenCua(khach),
                NgaySinhBenB = khach.NgaySinh,
                DiaChiPhong = room.DiaChi,
                GiaThue = room.Gia,
                ThoiHanThang = request.ThoiHanThang,
                NgayBatDau = request.NgayBatDau.Date,
                TrangThai = HopDongTrangThai.ChoKy,
                // Lập hợp đồng trên màn "Tạo hợp đồng" chính là xác nhận của Bên A.
                KyBenALuc = DateTime.Now,
                NgayLap = DateTime.Now,
            };

            _db.HopDongs.Add(hopDong);
            await _db.SaveChangesAsync();

            return Ok(ToDto(hopDong, user.Id));
        }

        /// <summary>Bên còn lại bấm "Đồng ý và ký" để hợp đồng có hiệu lực.</summary>
        [HttpPost("{id:int}/ky")]
        public async Task<IActionResult> Ky(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var hopDong = await _db.HopDongs.FirstOrDefaultAsync(h => h.Id == id);
            if (hopDong == null) return NotFound(new ApiError(Localizer["Api_ContractNotFound"]));

            var vaiTro = hopDong.VaiTroCua(user.Id);
            if (vaiTro == "") return Forbid();
            if (hopDong.TrangThai != HopDongTrangThai.ChoKy)
                return BadRequest(new ApiError(Localizer["Api_ContractNotPending"]));

            if (vaiTro == "A") hopDong.KyBenALuc = DateTime.Now;
            else hopDong.KyBenBLuc = DateTime.Now;

            if (hopDong.KyBenALuc.HasValue && hopDong.KyBenBLuc.HasValue)
                hopDong.TrangThai = HopDongTrangThai.DaKy;

            await _db.SaveChangesAsync();
            return Ok(ToDto(hopDong, user.Id));
        }

        [HttpPost("{id:int}/huy")]
        public async Task<IActionResult> Huy(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var hopDong = await _db.HopDongs.FirstOrDefaultAsync(h => h.Id == id);
            if (hopDong == null) return NotFound(new ApiError(Localizer["Api_ContractNotFound"]));
            if (hopDong.VaiTroCua(user.Id) == "") return Forbid();
            if (hopDong.TrangThai != HopDongTrangThai.ChoKy)
                return BadRequest(new ApiError(Localizer["Api_ContractNotPending"]));

            hopDong.TrangThai = HopDongTrangThai.DaHuy;
            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_ContractCancelled"]));
        }

        // ================================ NỘI BỘ ================================

        // Sinh viên của phòng = người đang giữ cọc, nếu không còn thì tìm giao dịch
        // thanh toán gần nhất vì xác nhận cho thuê đã xóa NguoiDatCocId.
        private async Task<AppUser?> TimKhachThueAsync(PhongTro room)
        {
            if (!string.IsNullOrWhiteSpace(room.NguoiDatCocId))
            {
                var giuCho = await _userManager.FindByIdAsync(room.NguoiDatCocId);
                if (giuCho != null) return giuCho;
            }

            var giaoDich = await _db.HoaDons
                .AsNoTracking()
                .Where(h => h.PhongTroId == room.Id && h.TrangThai == "HoanThanh")
                .OrderByDescending(h => h.NgayGiaoDich)
                .FirstOrDefaultAsync();

            if (giaoDich?.NguoiThueId == null) return null;
            return await _userManager.FindByIdAsync(giaoDich.NguoiThueId);
        }

        private static string TenCua(AppUser user) =>
            string.IsNullOrWhiteSpace(user.HoTen) ? (user.UserName ?? user.Email ?? "") : user.HoTen.Trim();

        internal static HopDongDto ToDto(HopDong h, string viewerId) => new()
        {
            Id = h.Id,
            PhongTroId = h.PhongTroId,
            TenPhong = h.PhongTro?.MoTa,
            BenAId = h.BenAId,
            TenBenA = h.TenBenA,
            NgaySinhBenA = h.NgaySinhBenA,
            BenBId = h.BenBId,
            TenBenB = h.TenBenB,
            NgaySinhBenB = h.NgaySinhBenB,
            DiaChiPhong = h.DiaChiPhong,
            GiaThue = h.GiaThue,
            ThoiHanThang = h.ThoiHanThang,
            NgayBatDau = h.NgayBatDau,
            NgayKetThuc = h.NgayKetThuc,
            TrangThai = h.TrangThai,
            VaiTro = h.VaiTroCua(viewerId),
            KyBenALuc = h.KyBenALuc,
            KyBenBLuc = h.KyBenBLuc,
            NgayLap = h.NgayLap,
            ConChoMinhKy = h.TrangThai == HopDongTrangThai.ChoKy &&
                           (h.VaiTroCua(viewerId) == "A" ? h.KyBenALuc == null : h.KyBenBLuc == null),
        };

        private async Task<AppUser?> CurrentUserAsync() =>
            await _userManager.FindByIdAsync(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "");
    }
}

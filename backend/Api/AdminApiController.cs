using Do_an_co_so.Api.Dtos;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Do_an_co_so.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Localization;
using System.Security.Claims;

namespace Do_an_co_so.Api
{
    // Màn quản trị của app, tương đương trang Admin (Index + QuanLyBaoCao) của web.
    [Route("api/admin")]
    [Authorize(Roles = "Admin")]
    public class AdminApiController : ApiControllerBase
    {
        private readonly UserManager<AppUser> _userManager;
        private readonly ApplicationDbContext _db;
        private readonly GiaiNganPhatCocService _phatCoc;

        public AdminApiController(UserManager<AppUser> userManager, ApplicationDbContext db,
            GiaiNganPhatCocService phatCoc,
            IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _userManager = userManager;
            _db = db;
            _phatCoc = phatCoc;
        }

        [HttpGet("nguoi-dung")]
        public async Task<ActionResult<List<AdminUserDto>>> NguoiDung(string? timKiem, string? locXacThuc)
        {
            var currentUserId = CurrentUserId();

            var query = _userManager.Users.Where(u => u.Id != currentUserId);
            if (!string.IsNullOrWhiteSpace(timKiem))
            {
                var keyword = timKiem.Trim().ToLower();
                query = query.Where(u => u.HoTen.ToLower().Contains(keyword)
                    || (u.Email != null && u.Email.ToLower().Contains(keyword)));
            }
            if (!string.IsNullOrWhiteSpace(locXacThuc))
            {
                query = query.Where(u => u.TrangThaiXacThuc == locXacThuc);
            }

            var users = await query
                .OrderByDescending(u => u.TrangThaiXacThuc == "Chờ duyệt")
                .ToListAsync();

            var ids = users.Select(u => u.Id).ToList();
            var soTinDang = await _db.PhongTro
                .Where(p => p.ChuTroId != null && ids.Contains(p.ChuTroId))
                .GroupBy(p => p.ChuTroId!)
                .Select(g => new { g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Key, x => x.Count);

            var ketQua = new List<AdminUserDto>();
            foreach (var u in users)
            {
                ketQua.Add(new AdminUserDto
                {
                    Id = u.Id,
                    Email = u.Email ?? u.UserName ?? "",
                    HoTen = u.HoTen,
                    Roles = (await _userManager.GetRolesAsync(u)).ToList(),
                    TrangThaiKhoa = u.TrangThaiKhoa,
                    TrangThaiXacThuc = u.TrangThaiXacThuc,
                    CCCDTruoc = u.CCCDTruoc,
                    CCCDSau = u.CCCDSau,
                    SoCCCDQuetDuoc = u.SoCCCDQuetDuoc,
                    SoDu = u.SoDu,
                    SoTinDang = soTinDang.TryGetValue(u.Id, out var c) ? c : 0
                });
            }

            return Ok(ketQua);
        }

        [HttpPost("nguoi-dung/{id}/khoa")]
        public async Task<ActionResult<MessageResponse>> ToggleKhoa(string id)
        {
            var user = await _userManager.FindByIdAsync(id);
            if (user == null) return NotFound(new ApiError(Localizer["Api_UserNotFound"]));

            user.TrangThaiKhoa = !user.TrangThaiKhoa;
            await _userManager.UpdateAsync(user);

            return Ok(new MessageResponse(user.TrangThaiKhoa
                ? Localizer["Api_LockedAccountMsg", user.HoTen]
                : Localizer["Api_UnlockedAccountMsg", user.HoTen]));
        }

        [HttpDelete("nguoi-dung/{id}")]
        public async Task<ActionResult<MessageResponse>> XoaNguoiDung(string id)
        {
            var user = await _userManager.FindByIdAsync(id);
            if (user == null) return NotFound(new ApiError(Localizer["Api_UserNotFound"]));
            if (user.Id == CurrentUserId()) return BadRequest(new ApiError(Localizer["Api_CannotDeleteSelf"]));

            // Dọn dữ liệu liên quan trước khi xóa tài khoản, giống trang Admin của web
            _db.DanhGias.RemoveRange(await _db.DanhGias.Where(d => d.UserId == id).ToListAsync());
            _db.Messages.RemoveRange(await _db.Messages
                .Where(m => m.SenderId == id || m.ReceiverId == id).ToListAsync());
            _db.HoaDons.RemoveRange(await _db.HoaDons.Where(h => h.NguoiThueId == id).ToListAsync());

            var userRooms = await _db.PhongTro.Where(p => p.ChuTroId == id).ToListAsync();
            var roomIds = userRooms.Select(r => r.Id).ToList();
            _db.DanhGias.RemoveRange(await _db.DanhGias.Where(d => roomIds.Contains(d.PhongTroId)).ToListAsync());
            _db.HoaDons.RemoveRange(await _db.HoaDons.Where(h => roomIds.Contains(h.PhongTroId)).ToListAsync());
            _db.BaoCaos.RemoveRange(await _db.BaoCaos.Where(b => b.PhongTroId != null && roomIds.Contains(b.PhongTroId.Value)).ToListAsync());
            _db.PhongTro.RemoveRange(userRooms);

            _db.BaoCaos.RemoveRange(await _db.BaoCaos.Where(b => b.NguoiBaoCaoId == id).ToListAsync());
            _db.BaoCaos.RemoveRange(await _db.BaoCaos.Where(b => b.NguoiBiBaoCaoId == id).ToListAsync());

            await _db.SaveChangesAsync();
            await _userManager.DeleteAsync(user);

            return Ok(new MessageResponse(Localizer["Api_AccountDeleted"]));
        }

        [HttpPost("nguoi-dung/{id}/duyet-cccd")]
        public async Task<ActionResult<MessageResponse>> DuyetCCCD(string id, [FromBody] DuyenCCCDRequest request)
        {
            var user = await _userManager.FindByIdAsync(id);
            if (user == null) return NotFound(new ApiError(Localizer["Api_UserNotFound"]));

            switch (request.HanhDong)
            {
                case "Duyet":
                    user.TrangThaiXacThuc = "Đã duyệt";

                    // Thưởng xác minh: các tin của chủ trọ này lên VIP miễn phí (như web)
                    var phongTros = await _db.PhongTro.Where(p => p.ChuTroId == user.Id).ToListAsync();
                    foreach (var phong in phongTros) phong.IsVip = true;
                    await _db.SaveChangesAsync();
                    break;

                case "TuChoi":
                    user.TrangThaiXacThuc = "Chưa xác thực";
                    user.CCCDTruoc = null;
                    user.CCCDSau = null;
                    user.SoCCCDQuetDuoc = null;
                    break;

                default:
                    return BadRequest(new ApiError(Localizer["Api_BadAction"]));
            }

            await _userManager.UpdateAsync(user);
            return Ok(new MessageResponse(request.HanhDong == "Duyet"
                ? Localizer["Api_CccdApproved"]
                : Localizer["Api_CccdRejected"]));
        }

        [HttpGet("bao-cao")]
        public async Task<ActionResult<List<AdminReportDto>>> BaoCao(bool? chiChuaXuLy)
        {
            await _phatCoc.QuetDenHanAsync();

            var query = _db.BaoCaos
                .Include(b => b.NguoiBaoCao)
                .Include(b => b.NguoiBiBaoCao)
                .Include(b => b.PhongTro).ThenInclude(p => p.ChuTro)
                .AsQueryable();

            if (chiChuaXuLy == true) query = query.Where(b => !b.DaXuLy);

            var danhSach = await query.OrderByDescending(b => b.NgayBaoCao).ToListAsync();

            // Nạp một lần các phiếu phạt hủy cọc để nối vào báo cáo theo (phòng, người báo cáo).
            var phatCoc = await _db.HoaDons
                .AsNoTracking()
                .Where(h => h.LoaiHoaDon == "PhatCoc")
                .ToListAsync();

            var traCuu = phatCoc
                .GroupBy(h => (h.PhongTroId, h.NguoiThueId))
                .ToDictionary(
                    g => g.Key,
                    g => g.OrderByDescending(h => h.NgayGiaoDich).First());

            return Ok(danhSach.Select(b =>
            {
                traCuu.TryGetValue((b.PhongTroId ?? -1, b.NguoiBaoCaoId), out var phat);
                var chuaTatToan = phat != null && phat.TrangThai != "HoanChoNguoiBaoCao";

                return new AdminReportDto
                {
                    Id = b.Id,
                    LyDo = b.LyDo,
                    ChiTiet = b.ChiTiet,
                    NgayBaoCao = b.NgayBaoCao,
                    DaXuLy = b.DaXuLy,
                    NguoiBaoCao = b.NguoiBaoCao?.HoTen ?? b.NguoiBaoCao?.UserName,
                    NguoiBiBaoCao = b.NguoiBiBaoCao?.HoTen ?? b.NguoiBiBaoCao?.UserName,
                    PhongTroId = b.PhongTroId,
                    DiaChiPhong = b.PhongTro?.DiaChi,
                    ChuTroCuaPhong = b.PhongTro?.ChuTro?.HoTen ?? b.PhongTro?.ChuTro?.UserName,
                    HoaDonPhatCocId = phat?.Id,
                    TienPhatCoc = phat?.TienChuTroNhan,
                    TrangThaiPhatCoc = phat?.TrangThai,
                    CoTheHoanCoc = chuaTatToan
                };
            }).ToList());
        }

        // Tố cáo "phòng không giống tin đăng" là đúng: lấy phần phạt hủy cọc trả lại người báo cáo.
        [HttpPost("bao-cao/{id:int}/hoan-coc")]
        public async Task<ActionResult<MessageResponse>> HoanCocNguoiBaoCao(int id)
        {
            var report = await _db.BaoCaos.FirstOrDefaultAsync(b => b.Id == id);
            if (report == null) return NotFound(new ApiError(Localizer["Api_ReportNotFound"]));
            if (report.PhongTroId == null)
            {
                return BadRequest(new ApiError(Localizer["Api_ReportHasNoRoom"]));
            }

            var phatCoc = await _db.HoaDons
                .Where(h => h.LoaiHoaDon == "PhatCoc"
                    && h.PhongTroId == report.PhongTroId
                    && h.NguoiThueId == report.NguoiBaoCaoId)
                .OrderByDescending(h => h.NgayGiaoDich)
                .FirstOrDefaultAsync();

            if (phatCoc == null) return NotFound(new ApiError(Localizer["Api_NoDepositPenalty"]));

            var (thanhCong, trangThai) = await _phatCoc.HoanVeNguoiBaoCaoAsync(phatCoc.Id, report.NguoiBaoCaoId);
            if (!thanhCong)
            {
                return BadRequest(new ApiError(Localizer["Api_PenaltyAlreadySettled", trangThai ?? ""]));
            }

            report.DaXuLy = true;
            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_PenaltyRefunded", phatCoc.TienChuTroNhan.ToString("N0")]));
        }

        [HttpPost("bao-cao/{id:int}/da-xu-ly")]
        public async Task<ActionResult<MessageResponse>> XacNhanDaXuLy(int id)
        {
            var report = await _db.BaoCaos.FindAsync(id);
            if (report == null) return NotFound(new ApiError(Localizer["Api_ReportNotFound"]));

            report.DaXuLy = true;
            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_ReportResolved"]));
        }

        private string CurrentUserId()
            => User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "";
    }
}

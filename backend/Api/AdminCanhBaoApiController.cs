using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
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
    /// API Quản lý cảnh báo bất thường dành cho Admin:
    /// Ảnh trùng lặp (dHash), ảnh mẫu trên mạng (Gemini AI Vision), spam nhiều bài.
    /// </summary>
    [Route("api/admin/canh-bao")]
    [Authorize(Roles = "Admin")]
    public class AdminCanhBaoApiController : ApiControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public AdminCanhBaoApiController(
            ApplicationDbContext db,
            UserManager<AppUser> userManager,
            IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _db = db;
            _userManager = userManager;
        }

        /// <summary>
        /// GET /api/admin/canh-bao
        /// Lấy danh sách các cảnh báo bất thường, ưu tiên chưa xử lý lên đầu
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<List<CanhBaoItemDto>>> DanhSach([FromQuery] bool? daXuLy, [FromQuery] string? loaiViPham)
        {
            var query = _db.CanhBaoBatThuongs
                .AsNoTracking()
                .Include(c => c.User)
                .Include(c => c.PhongTro)
                .AsQueryable();

            if (daXuLy.HasValue)
            {
                query = query.Where(c => c.DaXuLy == daXuLy.Value);
            }

            if (!string.IsNullOrWhiteSpace(loaiViPham))
            {
                query = query.Where(c => c.LoaiViPham == loaiViPham.Trim());
            }

            var list = await query
                .OrderBy(c => c.DaXuLy) // false (chưa xử lý) lên đầu
                .ThenByDescending(c => c.NgayTao)
                .Select(c => new CanhBaoItemDto
                {
                    Id = c.Id,
                    UserId = c.UserId,
                    TenChuTro = c.User != null ? (c.User.HoTen ?? c.User.UserName) : "Không xác định",
                    EmailChuTro = c.User != null ? c.User.Email : null,
                    SoDienThoaiChuTro = c.User != null ? c.User.PhoneNumber : null,
                    TrangThaiKhoaChuTro = c.User != null && c.User.TrangThaiKhoa,
                    PhongTroId = c.PhongTroId,
                    TieuDePhongTro = c.PhongTro != null ? c.PhongTro.MoTa : null,
                    GiaPhongTro = c.PhongTro != null ? c.PhongTro.Gia : null,
                    DiaChiPhongTro = c.PhongTro != null ? c.PhongTro.DiaChi : null,
                    LoaiViPham = c.LoaiViPham,
                    MoTaChiTiet = c.MoTaChiTiet,
                    AnhBangChungUrl = c.AnhBangChungUrl != null ? "images/" + c.AnhBangChungUrl : null,
                    DaXuLy = c.DaXuLy,
                    NgayTao = c.NgayTao
                })
                .ToListAsync();

            return Ok(list);
        }

        /// <summary>
        /// POST /api/admin/canh-bao/{id}/xu-ly
        /// Đánh dấu cảnh báo đã xử lý, kèm tùy chọn khóa tài khoản chủ trọ vi phạm
        /// </summary>
        [HttpPost("{id:int}/xu-ly")]
        public async Task<IActionResult> XuLy(int id, [FromBody] XuLyCanhBaoRequest request)
        {
            var canhBao = await _db.CanhBaoBatThuongs
                .Include(c => c.User)
                .FirstOrDefaultAsync(c => c.Id == id);

            if (canhBao == null)
            {
                return NotFound(new ApiError("Không tìm thấy cảnh báo yêu cầu."));
            }

            canhBao.DaXuLy = true;

            bool daKhoaTaiKhoan = false;
            if (request.KhoaTaiKhoan && canhBao.User != null)
            {
                canhBao.User.TrangThaiKhoa = true;
                await _userManager.UpdateAsync(canhBao.User);
                daKhoaTaiKhoan = true;
            }

            await _db.SaveChangesAsync();

            return Ok(new
            {
                success = true,
                message = "Đã cập nhật trạng thái xử lý cảnh báo thành công.",
                id = canhBao.Id,
                daXuLy = true,
                daKhoaTaiKhoan = daKhoaTaiKhoan
            });
        }
    }
}

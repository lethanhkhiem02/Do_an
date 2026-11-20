using System.Security.Claims;
using Do_an_co_so.Api.Dtos;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Localization;

namespace Do_an_co_so.Api
{
    [Route("api/oghep")]
    public class OGhepApiController : ApiControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public OGhepApiController(
            ApplicationDbContext db,
            UserManager<AppUser> userManager,
            IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _db = db;
            _userManager = userManager;
        }

        /// <summary>
        /// GET /api/oghep/my-profile
        /// Lấy hồ sơ ở ghép của người dùng đang đăng nhập
        /// </summary>
        [HttpGet("my-profile")]
        public async Task<ActionResult<HoSoOGhepDto?>> GetMyProfile()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var hoSo = await _db.HoSoOGheps
                .AsNoTracking()
                .FirstOrDefaultAsync(h => h.UserId == user.Id);

            if (hoSo == null)
            {
                return Ok(null);
            }

            return Ok(new HoSoOGhepDto
            {
                Id = hoSo.Id,
                UserId = hoSo.UserId,
                GioGiacSinhHoat = hoSo.GioGiacSinhHoat,
                GioiTinhUuTien = hoSo.GioiTinhUuTien,
                CoNauAn = hoSo.CoNauAn,
                CoNuoiPet = hoSo.CoNuoiPet,
                KhongHutThuoc = hoSo.KhongHutThuoc,
                UaSachSe = hoSo.UaSachSe,
                NganSachToiDa = hoSo.NganSachToiDa,
                KhuVucMongMuon = hoSo.KhuVucMongMuon,
                MoTaThem = hoSo.MoTaThem,
                DangTimBan = hoSo.DangTimBan,
                NgayCapNhat = hoSo.NgayCapNhat,
                HoTen = user.HoTen,
                Avatar = user.Avatar,
                PhoneNumber = user.PhoneNumber
            });
        }

        /// <summary>
        /// POST /api/oghep/my-profile
        /// Tạo mới hoặc cập nhật hồ sơ ở ghép của người dùng hiện tại
        /// </summary>
        [HttpPost("my-profile")]
        public async Task<ActionResult<HoSoOGhepDto>> UpdateMyProfile([FromBody] HoSoOGhepRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var hoSo = await _db.HoSoOGheps.FirstOrDefaultAsync(h => h.UserId == user.Id);

            if (hoSo == null)
            {
                hoSo = new HoSoOGhep
                {
                    UserId = user.Id,
                    GioGiacSinhHoat = request.GioGiacSinhHoat.Trim(),
                    GioiTinhUuTien = string.IsNullOrWhiteSpace(request.GioiTinhUuTien) ? "Không yêu cầu" : request.GioiTinhUuTien.Trim(),
                    CoNauAn = request.CoNauAn,
                    CoNuoiPet = request.CoNuoiPet,
                    KhongHutThuoc = request.KhongHutThuoc,
                    UaSachSe = request.UaSachSe,
                    NganSachToiDa = request.NganSachToiDa,
                    KhuVucMongMuon = request.KhuVucMongMuon.Trim(),
                    MoTaThem = request.MoTaThem?.Trim(),
                    DangTimBan = request.DangTimBan,
                    NgayCapNhat = DateTime.Now
                };
                _db.HoSoOGheps.Add(hoSo);
            }
            else
            {
                hoSo.GioGiacSinhHoat = request.GioGiacSinhHoat.Trim();
                hoSo.GioiTinhUuTien = string.IsNullOrWhiteSpace(request.GioiTinhUuTien) ? "Không yêu cầu" : request.GioiTinhUuTien.Trim();
                hoSo.CoNauAn = request.CoNauAn;
                hoSo.CoNuoiPet = request.CoNuoiPet;
                hoSo.KhongHutThuoc = request.KhongHutThuoc;
                hoSo.UaSachSe = request.UaSachSe;
                hoSo.NganSachToiDa = request.NganSachToiDa;
                hoSo.KhuVucMongMuon = request.KhuVucMongMuon.Trim();
                hoSo.MoTaThem = request.MoTaThem?.Trim();
                hoSo.DangTimBan = request.DangTimBan;
                hoSo.NgayCapNhat = DateTime.Now;
            }

            await _db.SaveChangesAsync();

            return Ok(new HoSoOGhepDto
            {
                Id = hoSo.Id,
                UserId = hoSo.UserId,
                GioGiacSinhHoat = hoSo.GioGiacSinhHoat,
                GioiTinhUuTien = hoSo.GioiTinhUuTien,
                CoNauAn = hoSo.CoNauAn,
                CoNuoiPet = hoSo.CoNuoiPet,
                KhongHutThuoc = hoSo.KhongHutThuoc,
                UaSachSe = hoSo.UaSachSe,
                NganSachToiDa = hoSo.NganSachToiDa,
                KhuVucMongMuon = hoSo.KhuVucMongMuon,
                MoTaThem = hoSo.MoTaThem,
                DangTimBan = hoSo.DangTimBan,
                NgayCapNhat = hoSo.NgayCapNhat,
                HoTen = user.HoTen,
                Avatar = user.Avatar,
                PhoneNumber = user.PhoneNumber
            });
        }

        /// <summary>
        /// GET /api/oghep/goi-y
        /// Gợi ý tìm bạn ở ghép dựa trên độ tương thích với hồ sơ của người dùng hiện tại
        /// </summary>
        [HttpGet("goi-y")]
        public async Task<ActionResult<List<GoiYOGhepDto>>> GetGoiY()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            // Hồ sơ của chính user đang đăng nhập
            var myProfile = await _db.HoSoOGheps
                .AsNoTracking()
                .FirstOrDefaultAsync(h => h.UserId == user.Id);

            // Danh sách các hồ sơ khác đang tìm bạn (DangTimBan == true, loại trừ chính user)
            var otherProfiles = await _db.HoSoOGheps
                .AsNoTracking()
                .Include(h => h.User)
                .Where(h => h.UserId != user.Id && h.DangTimBan)
                .ToListAsync();

            var result = new List<GoiYOGhepDto>();

            foreach (var other in otherProfiles)
            {
                int phanTram = 0;
                bool matchGioiTinh = false;
                bool matchKhuVuc = false;
                bool matchNganSach = false;
                bool matchGioGiac = false;
                bool matchNauAn = false;
                bool matchNuoiPet = false;
                bool matchKhongHutThuoc = false;
                bool matchUaSachSe = false;

                if (myProfile != null)
                {
                    // 1. Ưu tiên giới tính (15%)
                    if (KiemTraGioiTinh(myProfile.GioiTinhUuTien, other.GioiTinhUuTien))
                    {
                        matchGioiTinh = true;
                        phanTram += 15;
                    }

                    // 2. Khu vực mong muốn giống hoặc chứa nhau (15%)
                    if (KiemTraKhuVuc(myProfile.KhuVucMongMuon, other.KhuVucMongMuon))
                    {
                        matchKhuVuc = true;
                        phanTram += 15;
                    }

                    // 3. Chênh lệch ngân sách tối đa <= 500.000 VNĐ (15%)
                    if (Math.Abs(myProfile.NganSachToiDa - other.NganSachToiDa) <= 500000m)
                    {
                        matchNganSach = true;
                        phanTram += 15;
                    }

                    // 4. Giờ giấc sinh hoạt trùng khớp hoặc có linh hoạt (15%)
                    if (KiemTraGioGiac(myProfile.GioGiacSinhHoat, other.GioGiacSinhHoat))
                    {
                        matchGioGiac = true;
                        phanTram += 15;
                    }

                    // 5. Thói quen không hút thuốc (10%)
                    if (myProfile.KhongHutThuoc == other.KhongHutThuoc)
                    {
                        matchKhongHutThuoc = true;
                        phanTram += 10;
                    }

                    // 6. Ý thức ưa gọn gàng sạch sẽ (10%)
                    if (myProfile.UaSachSe == other.UaSachSe)
                    {
                        matchUaSachSe = true;
                        phanTram += 10;
                    }

                    // 7. Thói quen nấu ăn trùng khớp (10%)
                    if (myProfile.CoNauAn == other.CoNauAn)
                    {
                        matchNauAn = true;
                        phanTram += 10;
                    }

                    // 8. Thói quen nuôi thú cưng trùng khớp (10%)
                    if (myProfile.CoNuoiPet == other.CoNuoiPet)
                    {
                        matchNuoiPet = true;
                        phanTram += 10;
                    }
                }

                result.Add(new GoiYOGhepDto
                {
                    Id = other.Id,
                    UserId = other.UserId,
                    HoTen = other.User?.HoTen ?? other.User?.UserName ?? "Ẩn danh",
                    Avatar = other.User?.Avatar,
                    PhoneNumber = other.User?.PhoneNumber,
                    GioGiacSinhHoat = other.GioGiacSinhHoat,
                    GioiTinhUuTien = other.GioiTinhUuTien,
                    CoNauAn = other.CoNauAn,
                    CoNuoiPet = other.CoNuoiPet,
                    KhongHutThuoc = other.KhongHutThuoc,
                    UaSachSe = other.UaSachSe,
                    NganSachToiDa = other.NganSachToiDa,
                    KhuVucMongMuon = other.KhuVucMongMuon,
                    MoTaThem = other.MoTaThem,
                    DangTimBan = other.DangTimBan,
                    NgayCapNhat = other.NgayCapNhat,
                    PhanTramPhuHop = phanTram,
                    MatchGioiTinh = matchGioiTinh,
                    MatchKhuVuc = matchKhuVuc,
                    MatchNganSach = matchNganSach,
                    MatchGioGiac = matchGioGiac,
                    MatchNauAn = matchNauAn,
                    MatchNuoiPet = matchNuoiPet,
                    MatchKhongHutThuoc = matchKhongHutThuoc,
                    MatchUaSachSe = matchUaSachSe
                });
            }

            // Sắp xếp theo phần trăm phù hợp giảm dần, sau đó theo ngày cập nhật mới nhất
            return Ok(result
                .OrderByDescending(r => r.PhanTramPhuHop)
                .ThenByDescending(r => r.NgayCapNhat)
                .ToList());
        }

        private static bool KiemTraGioiTinh(string? gt1, string? gt2)
        {
            if (string.IsNullOrWhiteSpace(gt1) || string.IsNullOrWhiteSpace(gt2))
                return true;

            var s1 = gt1.Trim();
            var s2 = gt2.Trim();

            if (s1.Equals("Không yêu cầu", StringComparison.OrdinalIgnoreCase) ||
                s2.Equals("Không yêu cầu", StringComparison.OrdinalIgnoreCase))
                return true;

            return s1.Equals(s2, StringComparison.OrdinalIgnoreCase);
        }

        private static bool KiemTraGioGiac(string? g1, string? g2)
        {
            if (string.IsNullOrWhiteSpace(g1) || string.IsNullOrWhiteSpace(g2))
                return false;

            var s1 = g1.Trim();
            var s2 = g2.Trim();

            if (s1.Equals("Linh hoạt", StringComparison.OrdinalIgnoreCase) ||
                s2.Equals("Linh hoạt", StringComparison.OrdinalIgnoreCase))
                return true;

            return string.Equals(s1, s2, StringComparison.OrdinalIgnoreCase);
        }

        private static bool KiemTraKhuVuc(string? kv1, string? kv2)
        {
            if (string.IsNullOrWhiteSpace(kv1) || string.IsNullOrWhiteSpace(kv2))
                return false;

            var s1 = kv1.Trim();
            var s2 = kv2.Trim();

            return s1.Contains(s2, StringComparison.OrdinalIgnoreCase) ||
                   s2.Contains(s1, StringComparison.OrdinalIgnoreCase);
        }

        private async Task<AppUser?> CurrentUserAsync()
            => await _userManager.FindByIdAsync(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "");
    }
}

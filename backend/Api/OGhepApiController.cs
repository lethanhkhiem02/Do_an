using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
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
    [Route("api/oghep")]
    [Authorize]
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
                .Include(h => h.PhongTro)
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
                DaCoPhong = hoSo.DaCoPhong,
                PhongTroId = hoSo.PhongTroId,
                DiaChiPhongHienTai = hoSo.DiaChiPhongHienTai,
                GiaChiaMoiNguoi = hoSo.GiaChiaMoiNguoi,
                ThoiGianDonVao = hoSo.ThoiGianDonVao,
                PhongTro = ToPhongTroSummary(hoSo.PhongTro),
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

            // Kiểm tra phòng trọ hợp lệ nếu có truyền PhongTroId
            int? validPhongTroId = null;
            if (request.DaCoPhong && request.PhongTroId.HasValue && request.PhongTroId.Value > 0)
            {
                var roomExists = await _db.PhongTro.AnyAsync(p => p.Id == request.PhongTroId.Value);
                if (roomExists)
                {
                    validPhongTroId = request.PhongTroId.Value;
                }
            }

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
                    DaCoPhong = request.DaCoPhong,
                    PhongTroId = validPhongTroId,
                    DiaChiPhongHienTai = request.DiaChiPhongHienTai?.Trim(),
                    GiaChiaMoiNguoi = request.GiaChiaMoiNguoi,
                    ThoiGianDonVao = request.ThoiGianDonVao?.Trim(),
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
                hoSo.DaCoPhong = request.DaCoPhong;
                hoSo.PhongTroId = validPhongTroId;
                hoSo.DiaChiPhongHienTai = request.DiaChiPhongHienTai?.Trim();
                hoSo.GiaChiaMoiNguoi = request.GiaChiaMoiNguoi;
                hoSo.ThoiGianDonVao = request.ThoiGianDonVao?.Trim();
                hoSo.MoTaThem = request.MoTaThem?.Trim();
                hoSo.DangTimBan = request.DangTimBan;
                hoSo.NgayCapNhat = DateTime.Now;
            }

            await _db.SaveChangesAsync();

            PhongTro? linkedRoom = null;
            if (hoSo.PhongTroId.HasValue)
            {
                linkedRoom = await _db.PhongTro.AsNoTracking().FirstOrDefaultAsync(p => p.Id == hoSo.PhongTroId.Value);
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
                DaCoPhong = hoSo.DaCoPhong,
                PhongTroId = hoSo.PhongTroId,
                DiaChiPhongHienTai = hoSo.DiaChiPhongHienTai,
                GiaChiaMoiNguoi = hoSo.GiaChiaMoiNguoi,
                ThoiGianDonVao = hoSo.ThoiGianDonVao,
                PhongTro = ToPhongTroSummary(linkedRoom),
                MoTaThem = hoSo.MoTaThem,
                DangTimBan = hoSo.DangTimBan,
                NgayCapNhat = hoSo.NgayCapNhat,
                HoTen = user.HoTen,
                Avatar = user.Avatar,
                PhoneNumber = user.PhoneNumber
            });
        }

        /// <summary>
        /// GET /api/oghep/danh-sach-phong
        /// Tra cứu nhanh danh sách phòng trọ trên hệ thống để người dùng liên kết vào hồ sơ ở ghép
        /// </summary>
        [HttpGet("danh-sach-phong")]
        public async Task<ActionResult<List<PhongTroSummaryDto>>> GetDanhSachPhong([FromQuery] string? q)
        {
            var query = _db.PhongTro.AsNoTracking().AsQueryable();

            if (!string.IsNullOrWhiteSpace(q))
            {
                var kw = q.Trim().ToLower();
                query = query.Where(p => p.MoTa.ToLower().Contains(kw) || p.DiaChi.ToLower().Contains(kw));
            }

            var rooms = await query
                .OrderByDescending(p => p.Id)
                .Take(25)
                .ToListAsync();

            return Ok(rooms.Select(ToPhongTroSummary).Where(s => s != null).ToList());
        }

        /// <summary>
        /// GET /api/oghep/goi-y
        /// Gợi ý tìm bạn ở ghép với thuật toán tương thích bổ trợ thực tế và hỗ trợ lọc linh hoạt
        /// </summary>
        [HttpGet("goi-y")]
        public async Task<ActionResult<List<GoiYOGhepDto>>> GetGoiY(
            [FromQuery] string? loaiNhuCau,
            [FromQuery] string? khuVuc,
            [FromQuery] decimal? giaToiDa)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            // Hồ sơ của chính user đang đăng nhập
            var myProfile = await _db.HoSoOGheps
                .AsNoTracking()
                .Include(h => h.PhongTro)
                .FirstOrDefaultAsync(h => h.UserId == user.Id);

            // Query các hồ sơ khác đang tìm bạn (DangTimBan == true, loại trừ chính user)
            var query = _db.HoSoOGheps
                .AsNoTracking()
                .Include(h => h.User)
                .Include(h => h.PhongTro)
                .Where(h => h.UserId != user.Id && h.DangTimBan);

            // 1. Lọc theo loại nhu cầu: all | da_co_phong | chua_co_phong
            if (!string.IsNullOrWhiteSpace(loaiNhuCau))
            {
                var loai = loaiNhuCau.Trim().ToLowerInvariant();
                if (loai == "da_co_phong")
                {
                    query = query.Where(h => h.DaCoPhong);
                }
                else if (loai == "chua_co_phong")
                {
                    query = query.Where(h => !h.DaCoPhong);
                }
            }

            // 2. Lọc theo khu vực
            if (!string.IsNullOrWhiteSpace(khuVuc))
            {
                var kv = khuVuc.Trim().ToLower();
                query = query.Where(h =>
                    h.KhuVucMongMuon.ToLower().Contains(kv) ||
                    (h.DiaChiPhongHienTai != null && h.DiaChiPhongHienTai.ToLower().Contains(kv)) ||
                    (h.PhongTro != null && h.PhongTro.DiaChi.ToLower().Contains(kv)));
            }

            // 3. Lọc theo giá tối đa
            if (giaToiDa.HasValue && giaToiDa.Value > 0)
            {
                var maxGia = giaToiDa.Value;
                query = query.Where(h =>
                    (h.DaCoPhong && ((h.GiaChiaMoiNguoi ?? h.NganSachToiDa) <= maxGia)) ||
                    (!h.DaCoPhong && h.NganSachToiDa <= maxGia));
            }

            var otherProfiles = await query.ToListAsync();
            var result = new List<GoiYOGhepDto>();

            foreach (var other in otherProfiles)
            {
                int phanTram = 0;
                int uuTienBoTro = 2; // 1: Bổ trợ cao nhất, 2: Cùng thuê chung, 3: Cùng có phòng

                bool matchGioiTinh = false;
                bool matchKhuVuc = false;
                bool matchNganSach = false;
                bool matchGiaChia = false;
                bool matchThoiGianDonVao = false;
                bool matchGioGiac = false;
                bool matchNauAn = false;
                bool matchNuoiPet = false;
                bool matchKhongHutThuoc = false;
                bool matchUaSachSe = false;

                if (myProfile != null)
                {
                    // Xác định ưu tiên tính bổ trợ thực tế:
                    // Người chưa có phòng <-> Người đã có phòng sẵn để chia tiền
                    if (!myProfile.DaCoPhong && other.DaCoPhong)
                    {
                        uuTienBoTro = 1; // Rất lý tưởng: người tìm gặp được người đã có sẵn phòng!
                    }
                    else if (myProfile.DaCoPhong && !other.DaCoPhong)
                    {
                        uuTienBoTro = 1; // Rất lý tưởng: người có phòng tìm được người đang muốn ghép!
                    }
                    else if (!myProfile.DaCoPhong && !other.DaCoPhong)
                    {
                        uuTienBoTro = 2; // Cùng chưa có phòng -> Có thể rủ nhau đi thuê chung
                    }
                    else
                    {
                        uuTienBoTro = 3; // Cả hai đều đã có phòng riêng
                    }

                    // 1. So khớp Khu vực (20%)
                    var myArea = myProfile.DaCoPhong
                        ? (myProfile.DiaChiPhongHienTai ?? myProfile.PhongTro?.DiaChi ?? myProfile.KhuVucMongMuon)
                        : myProfile.KhuVucMongMuon;

                    var otherArea = other.DaCoPhong
                        ? (other.DiaChiPhongHienTai ?? other.PhongTro?.DiaChi ?? other.KhuVucMongMuon)
                        : other.KhuVucMongMuon;

                    if (KiemTraKhuVuc(myArea, otherArea))
                    {
                        matchKhuVuc = true;
                        phanTram += 20;
                    }

                    // 2. So khớp Ngân sách / Giá chia (20%)
                    if (myProfile.DaCoPhong != other.DaCoPhong)
                    {
                        // Một bên có phòng và một bên tìm phòng
                        var benCoPhong = myProfile.DaCoPhong ? myProfile : other;
                        var benChuaPhong = myProfile.DaCoPhong ? other : myProfile;

                        var giaChia = benCoPhong.GiaChiaMoiNguoi ?? (benCoPhong.PhongTro != null ? (benCoPhong.PhongTro.Gia / 2) : benCoPhong.NganSachToiDa);
                        var nganSach = benChuaPhong.NganSachToiDa;

                        if (giaChia <= nganSach)
                        {
                            matchNganSach = true;
                            matchGiaChia = true;
                            phanTram += 20;
                        }
                        else if (giaChia - nganSach <= 400000m)
                        {
                            matchNganSach = true;
                            phanTram += 12; // Chênh lệch rất nhỏ vẫn tính điểm tương đối
                        }
                    }
                    else if (!myProfile.DaCoPhong && !other.DaCoPhong)
                    {
                        // Cả hai cùng chưa có phòng: so sánh độ tương đồng về ngân sách dự kiến thuê chung
                        var diff = Math.Abs(myProfile.NganSachToiDa - other.NganSachToiDa);
                        if (diff <= 500000m)
                        {
                            matchNganSach = true;
                            phanTram += 20;
                        }
                        else if (diff <= 1000000m)
                        {
                            matchNganSach = true;
                            phanTram += 12;
                        }
                    }
                    else
                    {
                        // Cả hai đã có phòng
                        var diff = Math.Abs((myProfile.GiaChiaMoiNguoi ?? 0) - (other.GiaChiaMoiNguoi ?? 0));
                        if (diff <= 500000m)
                        {
                            matchGiaChia = true;
                            phanTram += 15;
                        }
                    }

                    // 3. Thời gian dọn vào (5%)
                    if (KiemTraThoiGianDonVao(myProfile.ThoiGianDonVao, other.ThoiGianDonVao))
                    {
                        matchThoiGianDonVao = true;
                        phanTram += 5;
                    }

                    // 4. Ưu tiên giới tính (15%)
                    if (KiemTraGioiTinh(myProfile.GioiTinhUuTien, other.GioiTinhUuTien))
                    {
                        matchGioiTinh = true;
                        phanTram += 15;
                    }

                    // 5. Giờ giấc sinh hoạt (15%)
                    if (KiemTraGioGiac(myProfile.GioGiacSinhHoat, other.GioGiacSinhHoat))
                    {
                        matchGioGiac = true;
                        phanTram += 15;
                    }

                    // 6. Thói quen không hút thuốc (10%)
                    if (myProfile.KhongHutThuoc == other.KhongHutThuoc)
                    {
                        matchKhongHutThuoc = true;
                        phanTram += 10;
                    }

                    // 7. Ý thức ưa gọn gàng sạch sẽ (10%)
                    if (myProfile.UaSachSe == other.UaSachSe)
                    {
                        matchUaSachSe = true;
                        phanTram += 10;
                    }

                    // 8. Thói quen nấu ăn (5%)
                    if (myProfile.CoNauAn == other.CoNauAn)
                    {
                        matchNauAn = true;
                        phanTram += 5;
                    }

                    // 9. Thói quen nuôi thú cưng (5%)
                    if (myProfile.CoNuoiPet == other.CoNuoiPet)
                    {
                        matchNuoiPet = true;
                        phanTram += 5;
                    }

                    phanTram = Math.Min(100, phanTram);
                }
                else
                {
                    // Nếu chưa thiết lập hồ sơ cá nhân, gán điểm cơ bản 50%
                    phanTram = 50;
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
                    DaCoPhong = other.DaCoPhong,
                    PhongTroId = other.PhongTroId,
                    DiaChiPhongHienTai = other.DiaChiPhongHienTai,
                    GiaChiaMoiNguoi = other.GiaChiaMoiNguoi,
                    ThoiGianDonVao = other.ThoiGianDonVao,
                    PhongTro = ToPhongTroSummary(other.PhongTro),
                    MoTaThem = other.MoTaThem,
                    DangTimBan = other.DangTimBan,
                    NgayCapNhat = other.NgayCapNhat,
                    PhanTramPhuHop = phanTram,
                    UuTienBoTro = uuTienBoTro,
                    MatchGioiTinh = matchGioiTinh,
                    MatchKhuVuc = matchKhuVuc,
                    MatchNganSach = matchNganSach,
                    MatchGiaChia = matchGiaChia,
                    MatchThoiGianDonVao = matchThoiGianDonVao,
                    MatchGioGiac = matchGioGiac,
                    MatchNauAn = matchNauAn,
                    MatchNuoiPet = matchNuoiPet,
                    MatchKhongHutThuoc = matchKhongHutThuoc,
                    MatchUaSachSe = matchUaSachSe
                });
            }

            // Sắp xếp ưu tiên:
            // 1. Tính bổ trợ cao nhất (UuTienBoTro: 1 -> 2 -> 3)
            // 2. Phần trăm phù hợp giảm dần (PhanTramPhuHop desc)
            // 3. Ngày cập nhật mới nhất (NgayCapNhat desc)
            var sorted = result
                .OrderBy(r => r.UuTienBoTro)
                .ThenByDescending(r => r.PhanTramPhuHop)
                .ThenByDescending(r => r.NgayCapNhat)
                .ToList();

            return Ok(sorted);
        }

        private static PhongTroSummaryDto? ToPhongTroSummary(PhongTro? p)
        {
            if (p == null) return null;
            string? anh = null;
            if (!string.IsNullOrWhiteSpace(p.HinhAnh))
            {
                var parts = p.HinhAnh.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                if (parts.Length > 0)
                {
                    anh = parts[0].StartsWith("images/") ? parts[0] : "images/" + parts[0];
                }
            }

            return new PhongTroSummaryDto
            {
                Id = p.Id,
                MoTa = p.MoTa,
                DiaChi = p.DiaChi,
                Gia = p.Gia,
                AnhDaiDien = anh
            };
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

        private static bool KiemTraThoiGianDonVao(string? tg1, string? tg2)
        {
            if (string.IsNullOrWhiteSpace(tg1) || string.IsNullOrWhiteSpace(tg2))
                return true;

            var s1 = tg1.Trim();
            var s2 = tg2.Trim();

            if (s1.Equals("Linh hoạt", StringComparison.OrdinalIgnoreCase) ||
                s2.Equals("Linh hoạt", StringComparison.OrdinalIgnoreCase))
                return true;

            return s1.Equals(s2, StringComparison.OrdinalIgnoreCase);
        }

        private async Task<AppUser?> CurrentUserAsync()
            => await _userManager.FindByIdAsync(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "");
    }
}

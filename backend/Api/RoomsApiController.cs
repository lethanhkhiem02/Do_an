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
    // API phòng trọ cho app: danh sách, tìm kiếm theo trường + bán kính, chi tiết,
    // đăng bài và quản lý bài đăng của Chủ trọ. Logic bám theo Home/Index,
    // PhongTroController.TimKiem, Details, Create, QuanLyPhong của web.
    [Route("api/phong-tro")]
    [Route("api/rooms")]
    public class RoomsApiController : ApiControllerBase
    {
        private static readonly string[] DuocDinhDang = { ".jpg", ".jpeg", ".png", ".webp", ".gif" };

        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;
        private readonly RoomQueryService _search;
        private readonly IWebHostEnvironment _env;
        private readonly NoiDungDichService _dich;
        private readonly TienIchQuetService _quetTienIch;
        private readonly ImageModerationService _imageModeration;
        private readonly AiRoomSearchService _aiSearch;

        public RoomsApiController(ApplicationDbContext db, UserManager<AppUser> userManager,
            RoomQueryService search, IWebHostEnvironment env,
            IStringLocalizer<SharedResource> localizer, NoiDungDichService dich,
            TienIchQuetService quetTienIch, ImageModerationService imageModeration,
            AiRoomSearchService aiSearch) : base(localizer)
        {
            _db = db;
            _userManager = userManager;
            _search = search;
            _env = env;
            _dich = dich;
            _quetTienIch = quetTienIch;
            _imageModeration = imageModeration;
            _aiSearch = aiSearch;
        }

        // ------------------------------- ĐỌC (khách chưa cần đăng nhập vẫn xem được như trên web) -------------------------------

        [AllowAnonymous]
        [HttpGet("danh-sach")]
        public async Task<ActionResult<SearchRoomsResponse>> DanhSach()
        {
            var ketQua = await _search.SearchAsync(null, null, null, null, "newest");
            var dich = await _dich.TaoHamDichAsync(LayNoiDungPhong(ketQua));
            return Ok(new SearchRoomsResponse
            {
                Phong = ketQua.Select(k => ToListItem(k, dich)).ToList()
            });
        }

        [AllowAnonymous]
        [HttpGet("tim-kiem")]
        public async Task<ActionResult<SearchRoomsResponse>> TimKiem(
            string? truongId, double? radius, decimal? minPrice, decimal? maxPrice, string? sortBy,
            string? loaiHinh)
        {
            var ketQua = await _search.SearchAsync(truongId, radius, minPrice, maxPrice, sortBy,
                loaiHinh: loaiHinh);
            var truong = TruongData.GetAll().FirstOrDefault(t => t.Id == truongId);
            var dich = await _dich.TaoHamDichAsync(LayNoiDungPhong(ketQua));

            return Ok(new SearchRoomsResponse
            {
                Phong = ketQua.Select(k => ToListItem(k, dich)).ToList(),
                TruongId = truongId,
                TenTruong = truong?.TenTruong,
                BanKinh = radius,
                SapXep = string.IsNullOrEmpty(sortBy) ? "distance_asc" : sortBy
            });
        }

        [AllowAnonymous]
        [HttpPost("ai-search")]
        public async Task<ActionResult<AiRoomSearchResponse>> AiSearch([FromBody] AiRoomSearchRequest? request)
        {
            var moTa = request?.MoTa?.Trim() ?? "";
            if (string.IsNullOrWhiteSpace(moTa))
            {
                return BadRequest(new ApiError("Vui lòng nhập mô tả nhu cầu tìm phòng."));
            }

            try
            {
                var ketQuaAi = await _aiSearch.SearchAsync(moTa);
                var dich = await _dich.TaoHamDichAsync(LayNoiDungPhong(ketQuaAi.Matches));

                return Ok(new AiRoomSearchResponse
                {
                    CacTieuChi = ketQuaAi.CacTieuChi,
                    ThongBao = ketQuaAi.ThongBao,
                    DanhSachPhong = ketQuaAi.Matches.Select(k => ToListItem(k, dich)).ToList()
                });
            }
            catch (Exception)
            {
                return Ok(new AiRoomSearchResponse
                {
                    CacTieuChi = new List<string>(),
                    ThongBao = "Không thể hoàn tất tìm kiếm AI lúc này, vui lòng thử lại sau.",
                    DanhSachPhong = new List<RoomListItemDto>()
                });
            }
        }

        // Mô tả + địa chỉ là văn bản Chủ trọ viết bằng tiếng Việt, chỉ hai trường này
        // cần đưa qua máy dịch; tên riêng (tên chủ trọ) giữ nguyên ở mọi ngôn ngữ.
        private static IEnumerable<string> LayNoiDungPhong(IEnumerable<RoomMatch> ketQua)
            => ketQua.SelectMany(k => new[] { k.PhongTro.MoTa ?? "", k.PhongTro.DiaChi ?? "" });

        [AllowAnonymous]
        [HttpGet("truong")]
        public async Task<ActionResult<List<TruongDaiHoc>>> Truong()
            => Ok(TruongData.GetAll());

        [AllowAnonymous]
        [HttpGet("{id:int}")]
        public async Task<ActionResult<RoomDetailDto>> ChiTiet(int id)
        {
            var currentUser = await TryCurrentUserAsync();
            if (currentUser != null && currentUser.TrangThaiKhoa)
            {
                return StatusCode(403, new ApiError(Localizer["Api_LockedViewRoom"]));
            }

            var room = await _db.PhongTro.Include(p => p.ChuTro).FirstOrDefaultAsync(m => m.Id == id);
            if (room == null) return NotFound(new ApiError(Localizer["Api_RoomDetailNotFound"]));

            await XoaCocHetHanAsync(room);

            var danhGia = await _db.DanhGias
                .Include(d => d.User)
                .Where(d => d.PhongTroId == id)
                .OrderByDescending(d => d.NgayTao)
                .ToListAsync();

            var sao = danhGia.Count > 0 ? danhGia.Average(d => d.Sao) : 0;

            var dich = await _dich.TaoHamDichAsync(new[] { room.MoTa, room.DiaChi });

            bool duocDanhGia = false, daThue = false;
            if (currentUser != null)
            {
                duocDanhGia = await _db.HoaDons.AnyAsync(h =>
                    h.PhongTroId == id && h.NguoiThueId == currentUser.Id &&
                    h.LoaiHoaDon == "ThuePhong" && h.TrangThai == "HoanThanh");
                daThue = duocDanhGia;
            }

            return Ok(new RoomDetailDto
            {
                Id = room.Id,
                MoTa = dich(room.MoTa),
                Gia = room.Gia,
                GiaDien = room.GiaDien,
                GiaNuoc = room.GiaNuoc,
                DiaChi = dich(room.DiaChi),
                Anh = TachAnh(room.HinhAnh),
                Latitude = room.Latitude,
                Longitude = room.Longitude,
                IsVip = room.IsVip,
                DaChoThue = room.DaChoThue,
                CoNhaVeSinh = room.CoNhaVeSinh,
                CoBanCong = room.CoBanCong,
                ChieuDai = room.ChieuDai,
                ChieuRong = room.ChieuRong,
                NgayHetHan = room.NgayHetHan,
                SoNgayGiuPhong = room.SoNgayGiuPhong,
                LoaiHinh = room.LoaiHinh.ToString(),
                TrungBinhSao = Math.Round(sao, 1),
                SoDanhGia = danhGia.Count,
                ChuTroId = room.ChuTroId,
                TenChuTro = room.ChuTro?.HoTen ?? room.ChuTro?.UserName,
                AvatarChuTro = room.ChuTro?.Avatar,
                ChuTroDienThoai = room.ChuTro?.PhoneNumber,
                ChuTroDiaChi = room.ChuTro?.DiaChi,
                ChuTroXacThuc = room.ChuTro?.TrangThaiXacThuc,
                NguoiDatCocId = room.NguoiDatCocId,
                TienCoc = room.TienCoc,
                HanDatCoc = room.HanDatCoc,
                TrangThai = TrangThaiCua(room),
                DanhGia = danhGia.Select(d => new ReviewDto
                {
                    Id = d.Id,
                    Sao = d.Sao,
                    NoiDung = d.NoiDung,
                    NgayTao = d.NgayTao,
                    UserId = d.UserId ?? "",
                    NguoiDanhGia = d.User?.HoTen ?? d.User?.UserName
                }).ToList(),
                DuocDanhGia = duocDanhGia,
                DaDatCoc = currentUser != null && room.NguoiDatCocId == currentUser.Id,
                DaThue = daThue
            });
        }

        [AllowAnonymous]
        [HttpGet("chu-tro/{userId}")]
        public async Task<ActionResult<object>> TrangCaNhanChuTro(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound(new ApiError(Localizer["Api_UserNotFound"]));

            var phong = await _db.PhongTro.Where(p => p.ChuTroId == userId).ToListAsync();
            var dich = await _dich.TaoHamDichAsync(phong.SelectMany(p => new[] { p.MoTa, p.DiaChi }));

            return Ok(new
            {
                chuTro = new
                {
                    id = user.Id,
                    hoTen = user.HoTen,
                    avatar = user.Avatar,
                    soDienThoai = user.PhoneNumber,
                    diaChi = user.DiaChi,
                    trangThaiXacThuc = user.TrangThaiXacThuc
                },
                danhSachPhong = phong.Select(p => new RoomListItemDto
                {
                    Id = p.Id,
                    MoTa = dich(p.MoTa),
                    Gia = p.Gia,
                    GiaDien = p.GiaDien,
                    GiaNuoc = p.GiaNuoc,
                    DiaChi = dich(p.DiaChi),
                    Anh = TachAnh(p.HinhAnh),
                    Latitude = p.Latitude,
                    Longitude = p.Longitude,
                    IsVip = p.IsVip,
                    DaChoThue = p.DaChoThue,
                    CoNhaVeSinh = p.CoNhaVeSinh,
                    CoBanCong = p.CoBanCong,
                    ChieuDai = p.ChieuDai,
                    ChieuRong = p.ChieuRong,
                    NgayHetHan = p.NgayHetHan,
                    SoNgayGiuPhong = p.SoNgayGiuPhong,
                    LoaiHinh = p.LoaiHinh.ToString(),
                    TrangThai = TrangThaiCua(p)
                }).ToList()
            });
        }

        // ------------------------------- CHỦ TRỌ ĐĂNG & QUẢN LÝ -------------------------------

        [Authorize(Roles = "ChuTro")]
        [HttpPost]
        [Consumes("multipart/form-data")]
        public async Task<ActionResult<RoomListItemDto>> Tao([FromForm] CreateRoomRequest request,
            List<IFormFile>? images)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa)
            {
                return StatusCode(403, new ApiError(Localizer["Api_LockedPostRoom"]));
            }

            var room = new PhongTro
            {
                MoTa = request.MoTa,
                Gia = request.Gia,
                GiaDien = request.GiaDien,
                GiaNuoc = request.GiaNuoc,
                DiaChi = request.DiaChi,
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                IsVip = request.IsVip,
                ChieuDai = request.ChieuDai,
                ChieuRong = request.ChieuRong,
                CoNhaVeSinh = request.CoNhaVeSinh,
                CoBanCong = request.CoBanCong,
                ChuTroId = user.Id,
                NgayHetHan = DateTime.Now.AddDays(request.SoNgayDangBai ?? 30),
                SoNgayGiuPhong = request.SoNgayGiuPhong ?? 7,
                LoaiHinh = ParseLoaiHinh(request.LoaiHinh)
            };

            if (room.IsVip)
            {
                if (user.SoDu < VnPayOptions.PhiDangTinVip)
                {
                    return BadRequest(new ApiError(Localizer["Api_NotEnoughForVip", VnPayOptions.PhiDangTinVip.ToString("N0")]));
                }
            }

            ModerationCheckResult? modResult = null;
            if (images != null && images.Count > 0)
            {
                var thuMuc = Path.Combine(_env.WebRootPath, "images");
                modResult = await _imageModeration.ProcessAndModerateImagesAsync(images, user.Id, null, thuMuc);
                if (!modResult.IsSuccess)
                {
                    return BadRequest(new ApiError(modResult.ErrorMessage ?? "Ảnh tải lên không hợp lệ hoặc bị trùng lặp."));
                }

                if (modResult.ProcessedFileNames.Count > 0)
                {
                    room.HinhAnh = string.Join(",", modResult.ProcessedFileNames);
                    room.ImageHash = string.Join(",", modResult.ProcessedHashes);
                }
            }

            if (room.IsVip)
            {
                user.SoDu -= VnPayOptions.PhiDangTinVip;
                await _userManager.UpdateAsync(user);
            }

            _db.Add(room);
            await _db.SaveChangesAsync();

            if (modResult != null && modResult.Warnings.Count > 0)
            {
                foreach (var w in modResult.Warnings)
                {
                    w.PhongTroId = room.Id;
                }
                await _db.SaveChangesAsync();
            }

            return CreatedAtAction(nameof(ChiTiet), new { id = room.Id }, ToListItem(new RoomMatch(room, 0, 0, 0)));
        }

        [Authorize(Roles = "ChuTro")]
        [HttpGet("quan-ly")]
        public async Task<ActionResult<List<RoomListItemDto>>> QuanLy()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var danhSach = await _db.PhongTro
                .Where(p => p.ChuTroId == user.Id)
                .OrderByDescending(p => p.IsVip)
                .ToListAsync();

            var ids = danhSach.Select(p => p.Id).ToList();
            var sao = await _db.DanhGias
                .Where(d => ids.Contains(d.PhongTroId))
                .GroupBy(d => d.PhongTroId)
                .Select(g => new { g.Key, Avg = g.Average(d => d.Sao), Count = g.Count() })
                .ToDictionaryAsync(x => x.Key, x => (x.Avg, x.Count));

            return Ok(danhSach.Select(p =>
            {
                var (avg, count) = sao.TryGetValue(p.Id, out var v) ? v : (0d, 0);
                return ToListItem(new RoomMatch(p, 0, avg, count));
            }).ToList());
        }

        [Authorize(Roles = "ChuTro")]
        [HttpPost("{id:int}/xac-nhan-cho-thue")]
        public async Task<IActionResult> XacNhanChoThue(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var room = await _db.PhongTro.FirstOrDefaultAsync(p => p.Id == id && p.ChuTroId == user.Id);
            if (room == null) return NotFound(new ApiError(Localizer["Api_YourRoomNotFound"]));

            room.DaChoThue = true;
            room.NguoiDatCocId = null;
            room.TienCoc = null;
            room.HanDatCoc = null;
            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_MarkRentedDone"]));
        }

        [Authorize(Roles = "ChuTro")]
        [HttpPost("{id:int}/mo-lai")]
        public async Task<IActionResult> MoLai(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var room = await _db.PhongTro.FirstOrDefaultAsync(p => p.Id == id && p.ChuTroId == user.Id);
            if (room == null) return NotFound(new ApiError(Localizer["Api_YourRoomNotFound"]));

            room.DaChoThue = false;
            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_ReopenedRoom"]));
        }

        [Authorize(Roles = "ChuTro")]
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Xoa(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var room = await _db.PhongTro.FindAsync(id);
            if (room == null) return NotFound(new ApiError(Localizer["Api_RoomNotFound"]));
            if (room.ChuTroId != user.Id) return Forbid();

            _db.PhongTro.Remove(room);
            await _db.SaveChangesAsync();
            return Ok(new MessageResponse(Localizer["Api_RoomDeleted"]));
        }

        // ------------------------------- TIỆN ÍCH XUNG QUANH -------------------------------

        [AllowAnonymous]
        [HttpGet("{id:int}/tien-ich")]
        public async Task<ActionResult<AmenityListResponse>> TienIch(int id)
        {
            var danhSach = await _db.TienIchXungQuanh
                .Where(t => t.PhongTroId == id)
                .OrderBy(t => t.Loai)
                .ThenBy(t => t.KhoangCachMet)
                .ToListAsync();

            return Ok(new AmenityListResponse
            {
                DaQuet = danhSach.Count > 0,
                QuetNgay = danhSach.Count > 0 ? danhSach.Max(t => t.QuetNgay) : null,
                // Bảng chỉ lưu tiện ích chứ không lưu bán kính đã quét; app không
                // tự chọn bán kính nên vòng tròn luôn là mức mặc định của server.
                BanKinhMet = TienIchQuetService.BanKinhMacDinhMet,
                TienIch = danhSach.Select(ToAmenity).ToList()
            });
        }

        // Chủ trọ bấm "Quét tiện ích xung quanh" lúc đăng phòng (hoặc quét lại).
        // Chạy phía server chứ không cho app gọi thẳng Overpass: app Android gửi
        // request ngoài luồng sẽ bị nhà mạng chặn/chậm, và server mới là nơi giữ
        // kết quả vào database.
        [Authorize(Roles = "ChuTro,Admin")]
        [HttpPost("{id:int}/tien-ich/quet")]
        public async Task<ActionResult<AmenityListResponse>> QuetTienIch(int id, int? banKinhMet)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var room = await _db.PhongTro.FirstOrDefaultAsync(p => p.Id == id);
            if (room == null) return NotFound(new ApiError(Localizer["Api_RoomNotFound"]));

            var roles = await _userManager.GetRolesAsync(user);
            if (room.ChuTroId != user.Id && !roles.Contains("Admin")) return Forbid();

            if (room.Latitude == null || room.Longitude == null)
            {
                return BadRequest(new ApiError(Localizer["Api_RoomHasNoLocation"]));
            }

            var banKinh = banKinhMet ?? TienIchQuetService.BanKinhMacDinhMet;
            var ketQua = await _quetTienIch.QuetAsync(
                room.Latitude.Value, room.Longitude.Value, banKinh);

            // Overpass đang bảo trì hoặc khu vực thật sự không có gì: giữ nguyên
            // snapshot cũ thay vì xóa sạch, để lần quét lỗi không làm mất dữ liệu.
            if (ketQua.Count == 0)
            {
                return StatusCode(503, new ApiError(Localizer["Api_AmenityScanFailed"]));
            }

            var cu = await _db.TienIchXungQuanh.Where(t => t.PhongTroId == id).ToListAsync();
            _db.TienIchXungQuanh.RemoveRange(cu);
            foreach (var tienIch in ketQua)
            {
                tienIch.PhongTroId = id;
                _db.TienIchXungQuanh.Add(tienIch);
            }
            await _db.SaveChangesAsync();

            return Ok(new AmenityListResponse
            {
                DaQuet = true,
                QuetNgay = DateTime.Now,
                BanKinhMet = banKinh,
                TienIch = ketQua.Select(ToAmenity).ToList()
            });
        }

        // ------------------------------- ĐÁNH GIÁ & BÁO CÁO -------------------------------

        [HttpPost("{id:int}/danh-gia")]
        public async Task<IActionResult> DanhGia(int id, [FromBody] CreateReviewRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            // Chỉ đánh giá được sau khi đã thuê và thanh toán xong (chống spam như web)
            var daThue = await _db.HoaDons.AnyAsync(h =>
                h.PhongTroId == id && h.NguoiThueId == user.Id &&
                h.LoaiHoaDon == "ThuePhong" && h.TrangThai == "HoanThanh");
            if (!daThue)
            {
                return BadRequest(new ApiError(Localizer["Api_ReviewAfterPaidOnly"]));
            }

            _db.DanhGias.Add(new DanhGia
            {
                PhongTroId = id,
                UserId = user.Id,
                Sao = request.Sao,
                NoiDung = request.NoiDung,
                NgayTao = DateTime.Now
            });
            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_ThanksReview"]));
        }

        [HttpPost("{id:int}/bao-cao")]
        public async Task<IActionResult> BaoCao(int id, [FromBody] CreateReportRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_NoPermission"]));

            if (!await _db.PhongTro.AnyAsync(p => p.Id == id))
            {
                return NotFound(new ApiError(Localizer["Api_RoomNotFound"]));
            }

            _db.BaoCaos.Add(new BaoCao
            {
                PhongTroId = id,
                NguoiBaoCaoId = user.Id,
                LyDo = request.LyDo,
                ChiTiet = request.ChiTiet ?? "",
                NgayBaoCao = DateTime.Now,
                DaXuLy = false
            });
            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_ReportRoomSent"]));
        }

        // ------------------------------- PHÒNG SINH VIÊN ĐÃ THUÊ -------------------------------

        [Authorize(Roles = "SinhVien")]
        [HttpGet("phong-da-thue")]
        public async Task<ActionResult<List<InvoiceDto>>> PhongDaThue()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var hoaDon = await _db.HoaDons
                .Include(h => h.PhongTro).ThenInclude(p => p.ChuTro)
                .Where(h => h.NguoiThueId == user.Id)
                .OrderByDescending(h => h.NgayGiaoDich)
                .ToListAsync();

            return Ok(hoaDon.Select(ToInvoice).ToList());
        }

        // ================================ TIỆN ÍCH NỘI BỘ ================================

        internal static InvoiceDto ToInvoice(HoaDon h) => new()
        {
            Id = h.Id,
            PhongTroId = h.PhongTroId,
            TenPhong = h.PhongTro?.MoTa,
            DiaChiPhong = h.PhongTro?.DiaChi,
            ChuTro = h.PhongTro?.ChuTro?.HoTen ?? h.PhongTro?.ChuTro?.UserName,
            TongTien = h.TongTien,
            TienHoaHong = h.TienHoaHong,
            TienChuTroNhan = h.TienChuTroNhan,
            NgayGiaoDich = h.NgayGiaoDich,
            LoaiHoaDon = h.LoaiHoaDon,
            TrangThai = h.TrangThai
        };

        private async Task<AppUser?> CurrentUserAsync()
            => await _userManager.FindByIdAsync(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "");

        private async Task<AppUser?> TryCurrentUserAsync()
            => User.Identity?.IsAuthenticated == true ? await CurrentUserAsync() : null;

        // Phòng đang bị giữ chỗ nhưng quá hạn thì nhả ra cho người khác (giống trang Details của web)
        private async Task XoaCocHetHanAsync(PhongTro room)
        {
            if (!string.IsNullOrEmpty(room.NguoiDatCocId) && room.HanDatCoc.HasValue && room.HanDatCoc.Value < DateTime.Now)
            {
                room.NguoiDatCocId = null;
                room.TienCoc = null;
                room.HanDatCoc = null;
                await _db.SaveChangesAsync();
            }
        }

        private static string TrangThaiCua(PhongTro p)
        {
            if (p.DaChoThue) return "DaChoThue";
            if (!string.IsNullOrEmpty(p.NguoiDatCocId) && p.HanDatCoc > DateTime.Now) return "DangGiuCho";
            if (p.NgayHetHan.HasValue && p.NgayHetHan.Value < DateTime.Now) return "HetHienThi";
            return "ConTrong";
        }

        private static List<string> TachAnh(string? hinhAnh) => string.IsNullOrEmpty(hinhAnh)
            ? new List<string>()
            : hinhAnh.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                     .Select(t => "images/" + t)
                     .ToList();

        // App gửi "KyTucXa"/"PhongRieng" (hoặc không gửi). Giá trị lạ hiểu là phòng
        // riêng chứ không từ chối cả bài đăng.
        private static LoaiHinhPhong ParseLoaiHinh(string? giaTri) =>
            Enum.TryParse<LoaiHinhPhong>(giaTri, ignoreCase: true, out var loaiHinh)
                ? loaiHinh
                : LoaiHinhPhong.PhongRieng;

        private static AmenityDto ToAmenity(TienIchXungQuanh t) => new()
        {
            Loai = t.Loai,
            Ten = t.Ten,
            ViDo = t.ViDo,
            KinhDo = t.KinhDo,
            KhoangCachMet = t.KhoangCachMet
        };

        private RoomListItemDto ToListItem(RoomMatch match, Func<string?, string>? dich = null)
        {
            var p = match.PhongTro;
            Func<string?, string> layBanDich = dich ?? (nguyenVan => nguyenVan ?? "");
            return new RoomListItemDto
            {
                Id = p.Id,
                MoTa = layBanDich(p.MoTa),
                Gia = p.Gia,
                GiaDien = p.GiaDien,
                GiaNuoc = p.GiaNuoc,
                DiaChi = layBanDich(p.DiaChi),
                Anh = TachAnh(p.HinhAnh),
                Latitude = p.Latitude,
                Longitude = p.Longitude,
                IsVip = p.IsVip,
                DaChoThue = p.DaChoThue,
                CoNhaVeSinh = p.CoNhaVeSinh,
                CoBanCong = p.CoBanCong,
                ChieuDai = p.ChieuDai,
                ChieuRong = p.ChieuRong,
                NgayHetHan = p.NgayHetHan,
                SoNgayGiuPhong = p.SoNgayGiuPhong,
                LoaiHinh = p.LoaiHinh.ToString(),
                KhoangCach = Math.Round(match.KhoangCach, 2),
                TrungBinhSao = Math.Round(match.TrungBinhSao, 1),
                SoDanhGia = match.SoDanhGia,
                ChuTroId = p.ChuTroId,
                TenChuTro = p.ChuTro?.HoTen ?? p.ChuTro?.UserName,
                TrangThai = TrangThaiCua(p)
            };
        }
    }
}

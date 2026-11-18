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
    // VNPay trên web chạy bằng form POST + redirect, app di động không làm được vậy nên
    // API chỉ tạo URL thanh toán; app mở URL đó bằng trình duyệt rồi quay lại poll
    // /trang-thai-phong/{id} để biết giao dịch đã ghi nhận chưa.
    [Route("api/thanhtoan")]
    public class PaymentApiController : ApiControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;

        public PaymentApiController(ApplicationDbContext db, UserManager<AppUser> userManager,
            IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _db = db;
            _userManager = userManager;
        }

        // ============================ THUÊ PHÒNG ============================

        [HttpPost("thue-phong/{id:int}")]
        [Authorize(Roles = "SinhVien")]
        public async Task<ActionResult<PaymentUrlResponse>> ThuePhong(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var phong = await _db.PhongTro.FirstOrDefaultAsync(p => p.Id == id);
            if (phong == null) return NotFound(new ApiError(Localizer["Api_RoomNotFound"]));

            if (phong.DaChoThue || (!string.IsNullOrEmpty(phong.NguoiDatCocId) && phong.NguoiDatCocId != user.Id))
            {
                return BadRequest(new ApiError(Localizer["Api_RentTakenOrHeld"]));
            }

            var url = TaoUrlThanhToan("callback-thue-phong", (long)Math.Round(phong.Gia * 100),
                $"Thanh toan thue phong {phong.Id}", $"{user.Id}_{phong.Id}_{DateTime.Now.Ticks}");

            return Ok(new PaymentUrlResponse { PaymentUrl = url, TxnRef = $"{user.Id}_{phong.Id}" });
        }

        [AllowAnonymous]
        [HttpGet("callback-thue-phong")]
        public async Task<IActionResult> CallbackThuePhong()
        {
            var (hopLe, maPhong, phanTu) = TraKetQua("Verb_ThanhToan");
            if (!hopLe) return KetQuaHtml(false, phanTu);

            var phong = await _db.PhongTro.Include(p => p.ChuTro).FirstOrDefaultAsync(p => p.Id == maPhong!.Value);
            var nguoiThue = await TimNguoiTuTxnRefAsync();
            var admin = await _userManager.FindByEmailAsync("admin@gmail.com");

            if (phong == null || phong.DaChoThue)
            {
                return KetQuaHtml(false, Localizer["Api_RoomGone"]);
            }

            decimal tongTien = phong.Gia;
            decimal tienHoaHong = tongTien * VnPayOptions.TyLeHoaHongAdmin;
            decimal tienChuTro = tongTien - tienHoaHong;

            if (admin != null) admin.SoDu += tienHoaHong;
            if (phong.ChuTro != null) phong.ChuTro.SoDu += tienChuTro;

            phong.DaChoThue = true;
            phong.NguoiDatCocId = null;
            phong.TienCoc = null;
            phong.HanDatCoc = null;

            _db.HoaDons.Add(new HoaDon
            {
                PhongTroId = phong.Id,
                NguoiThueId = nguoiThue?.Id,
                TongTien = tongTien,
                TienHoaHong = tienHoaHong,
                TienChuTroNhan = tienChuTro,
                NgayGiaoDich = DateTime.Now,
                LoaiHoaDon = "ThuePhong",
                TrangThai = "HoanThanh"
            });
            await _db.SaveChangesAsync();

            return KetQuaHtml(true, Localizer["Api_RentSuccess"]);
        }

        // ============================ ĐẶT CỌC GIỮ CHỖ ============================

        [HttpPost("dat-coc/{id:int}")]
        [Authorize(Roles = "SinhVien")]
        public async Task<ActionResult<PaymentUrlResponse>> DatCoc(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var phong = await _db.PhongTro.FirstOrDefaultAsync(p => p.Id == id);
            if (phong == null) return NotFound(new ApiError(Localizer["Api_RoomNotFound"]));

            if (phong.DaChoThue || !string.IsNullOrEmpty(phong.NguoiDatCocId))
            {
                return BadRequest(new ApiError(Localizer["Api_RentTakenOrDeposited"]));
            }

            if (phong.Gia <= VnPayOptions.TienDatCocGiuCho)
            {
                return BadRequest(new ApiError(Localizer["Api_RentTooCheapToDeposit"]));
            }

            // VNPay tính theo đơn vị trăm đồng: 500.000đ -> 50000000
            var url = TaoUrlThanhToan("callback-dat-coc", (long)(VnPayOptions.TienDatCocGiuCho * 100),
                $"Dat coc giu phong {phong.Id}", $"{user.Id}_{phong.Id}_{DateTime.Now.Ticks}");

            return Ok(new PaymentUrlResponse { PaymentUrl = url, TxnRef = $"{user.Id}_{phong.Id}" });
        }

        [AllowAnonymous]
        [HttpGet("callback-dat-coc")]
        public async Task<IActionResult> CallbackDatCoc()
        {
            var (hopLe, maPhong, phanTu) = TraKetQua("Verb_DatCoc");
            if (!hopLe) return KetQuaHtml(false, phanTu);

            var phong = await _db.PhongTro.Include(p => p.ChuTro).FirstOrDefaultAsync(p => p.Id == maPhong!.Value);
            var nguoiThue = await TimNguoiTuTxnRefAsync();
            var admin = await _userManager.FindByEmailAsync("admin@gmail.com");

            if (phong == null || phong.DaChoThue)
            {
                return KetQuaHtml(false, Localizer["Api_RoomGone"]);
            }

            if (admin != null) admin.SoDu += VnPayOptions.TienDatCocGiuCho;

            phong.NguoiDatCocId = nguoiThue?.Id;
            phong.TienCoc = VnPayOptions.TienDatCocGiuCho;
            int soNgayGiu = phong.SoNgayGiuPhong ?? 7;
            phong.HanDatCoc = DateTime.Now.AddDays(soNgayGiu);

            _db.HoaDons.Add(new HoaDon
            {
                PhongTroId = phong.Id,
                NguoiThueId = nguoiThue?.Id,
                TongTien = VnPayOptions.TienDatCocGiuCho,
                TienHoaHong = 0,
                TienChuTroNhan = 0,
                NgayGiaoDich = DateTime.Now,
                LoaiHoaDon = "DatCoc",
                TrangThai = "TamGiu"
            });
            await _db.SaveChangesAsync();

            return KetQuaHtml(true,
                Localizer["Api_DepositDone", VnPayOptions.TienDatCocGiuCho.ToString("N0"), soNgayGiu]);
        }

        // ============================ THANH TOÁN PHẦN CÒN LẠI ============================

        [HttpPost("phan-con-lai/{id:int}")]
        [Authorize(Roles = "SinhVien")]
        public async Task<ActionResult<PaymentUrlResponse>> PhanConLai(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var phong = await _db.PhongTro.FirstOrDefaultAsync(p => p.Id == id);
            if (phong == null) return NotFound(new ApiError(Localizer["Api_RoomNotFound"]));
            if (phong.NguoiDatCocId != user.Id)
            {
                return BadRequest(new ApiError(Localizer["Api_NoDepositForRoom"]));
            }

            decimal conLai = phong.Gia - (phong.TienCoc ?? VnPayOptions.TienDatCocGiuCho);
            var url = TaoUrlThanhToan("callback-phan-con-lai", (long)Math.Round(conLai * 100),
                $"Thanh toan phan con lai phong {phong.Id}", $"{user.Id}_{phong.Id}_{DateTime.Now.Ticks}");

            return Ok(new PaymentUrlResponse { PaymentUrl = url, TxnRef = $"{user.Id}_{phong.Id}" });
        }

        [AllowAnonymous]
        [HttpGet("callback-phan-con-lai")]
        public async Task<IActionResult> CallbackPhanConLai()
        {
            var (hopLe, maPhong, phanTu) = TraKetQua("Verb_ThanhToanConLai");
            if (!hopLe) return KetQuaHtml(false, phanTu);

            var phong = await _db.PhongTro.Include(p => p.ChuTro).FirstOrDefaultAsync(p => p.Id == maPhong!.Value);
            var nguoiThue = await TimNguoiTuTxnRefAsync();
            var admin = await _userManager.FindByEmailAsync("admin@gmail.com");

            if (phong == null || phong.DaChoThue)
            {
                return KetQuaHtml(false, Localizer["Api_RoomGone"]);
            }

            decimal conLai = phong.Gia - (phong.TienCoc ?? VnPayOptions.TienDatCocGiuCho);
            decimal tienHoaHong = phong.Gia * VnPayOptions.TyLeHoaHongAdmin;
            decimal tienChuTro = phong.Gia - tienHoaHong;

            if (admin != null)
            {
                admin.SoDu += conLai;
                admin.SoDu -= tienChuTro;
            }
            if (phong.ChuTro != null) phong.ChuTro.SoDu += tienChuTro;

            phong.DaChoThue = true;
            phong.NguoiDatCocId = null;
            phong.TienCoc = null;
            phong.HanDatCoc = null;

            var hoaDonCoc = await _db.HoaDons.FirstOrDefaultAsync(h =>
                h.PhongTroId == phong.Id && h.NguoiThueId == nguoiThue!.Id && h.TrangThai == "TamGiu");
            if (hoaDonCoc != null) hoaDonCoc.TrangThai = "GiaiNgan";

            _db.HoaDons.Add(new HoaDon
            {
                PhongTroId = phong.Id,
                NguoiThueId = nguoiThue?.Id,
                TongTien = conLai,
                TienHoaHong = tienHoaHong,
                TienChuTroNhan = tienChuTro,
                NgayGiaoDich = DateTime.Now,
                LoaiHoaDon = "ThuePhong",
                TrangThai = "HoanThanh"
            });
            await _db.SaveChangesAsync();

            return KetQuaHtml(true, Localizer["Api_RentPaidSuccess"]);
        }

        // ============================ HỦY CỌC (HOÀN TIỀN VÀO VÍ) ============================

        [HttpPost("huy-coc/{id:int}")]
        [Authorize(Roles = "SinhVien")]
        public async Task<IActionResult> HuyDatCoc(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var phong = await _db.PhongTro.FirstOrDefaultAsync(p => p.Id == id);
            var admin = await _userManager.FindByEmailAsync("admin@gmail.com");

            if (phong == null || phong.NguoiDatCocId != user.Id)
            {
                return BadRequest(new ApiError(Localizer["Api_NoCancelDepositRight"]));
            }

            decimal tienCoc = phong.TienCoc ?? VnPayOptions.TienDatCocGiuCho;
            if (admin != null) admin.SoDu -= tienCoc;
            user.SoDu += tienCoc;

            phong.NguoiDatCocId = null;
            phong.TienCoc = null;
            phong.HanDatCoc = null;

            var hoaDonCoc = await _db.HoaDons.FirstOrDefaultAsync(h =>
                h.PhongTroId == phong.Id && h.NguoiThueId == user.Id && h.TrangThai == "TamGiu");
            if (hoaDonCoc != null) hoaDonCoc.TrangThai = "HoanTien";

            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_DepositRefunded", tienCoc.ToString("N0")]));
        }

        // ============================ NẠP TIỀN VÀO VÍ ============================

        [HttpPost("nap-tien")]
        [Authorize(Roles = "ChuTro")]
        public async Task<ActionResult<PaymentUrlResponse>> NapTien([FromBody] NapTienRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa) return StatusCode(403, new ApiError(Localizer["Api_AccountLocked"]));

            var url = TaoUrlThanhToan("callback-nap-tien", (long)Math.Round(request.SoTien * 100),
                $"Nap tien vao vi VIP - {user.UserName}", $"{user.Id}_{DateTime.Now.Ticks}", "topup");

            return Ok(new PaymentUrlResponse { PaymentUrl = url, TxnRef = user.Id });
        }

        [AllowAnonymous]
        [HttpGet("callback-nap-tien")]
        public async Task<IActionResult> CallbackNapTien()
        {
            var vnpay = new VnPayLibrary();
            foreach (string key in Request.Query.Keys)
            {
                if (!string.IsNullOrEmpty(key) && key.StartsWith("vnp_")) vnpay.AddResponseData(key, Request.Query[key]);
            }

            bool thanhCong = vnpay.ValidateSignature(Request.Query["vnp_SecureHash"], VnPayOptions.HashSecret)
                             && Request.Query["vnp_ResponseCode"] == "00";
            if (!thanhCong) return KetQuaHtml(false, Localizer["Api_TopUpFailed"]);

            var userId = vnpay.GetResponseData("vnp_TxnRef").Split('_')[0];
            decimal soTienNap = decimal.Parse(vnpay.GetResponseData("vnp_Amount")) / 100;

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return KetQuaHtml(false, Localizer["Api_TopUpAccountUnknown"]);

            user.SoDu += soTienNap;
            await _userManager.UpdateAsync(user);

            return KetQuaHtml(true, Localizer["Api_TopUpDone", soTienNap.ToString("N0")]);
        }

        // ============================ VÍ & TRẠNG THÁI GIAO DỊCH ============================

        [HttpGet("vi")]
        public async Task<ActionResult<WalletDto>> Vi()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var hoaDon = await _db.HoaDons
                .Include(h => h.PhongTro).ThenInclude(p => p.ChuTro)
                .Where(h => h.NguoiThueId == user.Id)
                .OrderByDescending(h => h.NgayGiaoDich)
                .Take(50)
                .ToListAsync();

            return Ok(new WalletDto
            {
                SoDu = user.SoDu,
                TrangThaiXacThuc = user.TrangThaiXacThuc,
                GiaoDich = hoaDon.Select(RoomsApiController.ToInvoice).ToList()
            });
        }

        // App poll endpoint này sau khi mở link VNPay để biết giao dịch đã ghi nhận chưa.
        [HttpGet("trang-thai-phong/{id:int}")]
        public async Task<ActionResult<PaymentStatusResponse>> TrangThaiPhong(int id)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var phong = await _db.PhongTro.FirstOrDefaultAsync(p => p.Id == id);
            if (phong == null) return NotFound(new ApiError(Localizer["Api_RoomNotFound"]));

            string trangThai;
            if (phong.DaChoThue) trangThai = "DaChoThue";
            else if (phong.NguoiDatCocId == user.Id && phong.HanDatCoc > DateTime.Now) trangThai = "DaDatCoc";
            else if (!string.IsNullOrEmpty(phong.NguoiDatCocId) && phong.HanDatCoc > DateTime.Now) trangThai = "DangGiuCho";
            else trangThai = "ConTrong";

            return Ok(new PaymentStatusResponse
            {
                PhongTroId = phong.Id,
                TrangThai = trangThai,
                TienCoc = phong.TienCoc,
                HanDatCoc = phong.HanDatCoc,
                SoDu = user.SoDu
            });
        }

        // ================================ TIỆN ÍCH NỘI BỘ ================================

        private string TaoUrlThanhToan(string tenCallback, long soTienBotThap, string noiDung, string txnRef, string loai = "other")
        {
            var returnUrl = $"{Request.Scheme}://{Request.Host}/api/thanhtoan/{tenCallback}";

            var vnpay = new VnPayLibrary();
            vnpay.AddRequestData("vnp_Version", "2.1.0");
            vnpay.AddRequestData("vnp_Command", "pay");
            vnpay.AddRequestData("vnp_TmnCode", VnPayOptions.TmnCode);
            vnpay.AddRequestData("vnp_Amount", soTienBotThap.ToString());
            vnpay.AddRequestData("vnp_CreateDate", DateTime.Now.ToString("yyyyMMddHHmmss"));
            vnpay.AddRequestData("vnp_CurrCode", "VND");
            vnpay.AddRequestData("vnp_IpAddr", HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1");
            vnpay.AddRequestData("vnp_Locale", "vn");
            vnpay.AddRequestData("vnp_OrderInfo", noiDung);
            vnpay.AddRequestData("vnp_OrderType", loai);
            vnpay.AddRequestData("vnp_ReturnUrl", returnUrl);
            vnpay.AddRequestData("vnp_TxnRef", txnRef);

            return vnpay.CreateRequestUrl(VnPayOptions.Url, VnPayOptions.HashSecret);
        }

        // (chữ ký hợp lệ, mã phòng, mô tả lỗi)
        private (bool HopLe, int? MaPhong, string? PhanTu) TraKetQua(string tenGiaoDichKey)
        {
            var vnpay = new VnPayLibrary();
            foreach (string key in Request.Query.Keys)
            {
                if (!string.IsNullOrEmpty(key) && key.StartsWith("vnp_")) vnpay.AddResponseData(key, Request.Query[key]);
            }

            bool chuKyDung = vnpay.ValidateSignature(Request.Query["vnp_SecureHash"], VnPayOptions.HashSecret);
            if (!chuKyDung) return (false, null, Localizer["Api_BadSignature"]);

            if (Request.Query["vnp_ResponseCode"] != "00")
            {
                return (false, null, Localizer["Api_TransactionFailed", Localizer[tenGiaoDichKey].Value]);
            }

            // TxnRef có dạng {userId}_{phongId}_{ticks}
            var parts = vnpay.GetResponseData("vnp_TxnRef").Split('_');
            if (parts.Length < 2 || !int.TryParse(parts[1], out var phongId))
            {
                return (false, null, Localizer["Api_TransactionNoRoom"]);
            }

            return (true, phongId, null);
        }

        private async Task<AppUser?> TimNguoiTuTxnRefAsync()
        {
            var vnpay = new VnPayLibrary();
            foreach (string key in Request.Query.Keys)
            {
                if (!string.IsNullOrEmpty(key) && key.StartsWith("vnp_")) vnpay.AddResponseData(key, Request.Query[key]);
            }
            var userId = vnpay.GetResponseData("vnp_TxnRef").Split('_')[0];
            return await _userManager.FindByIdAsync(userId);
        }

        private async Task<AppUser?> CurrentUserAsync()
            => await _userManager.FindByIdAsync(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "");

        private IActionResult KetQuaHtml(bool thanhCong, string? noiDung)
        {
            string bieuTuong = thanhCong ? "&#9989;" : "&#10060;";
            string mau = thanhCong ? "#198754" : "#dc3545";
            string tieuDe = thanhCong ? "Giao dịch thành công" : "Giao dịch chưa hoàn tất";
            string thongDiep = noiDung ?? (thanhCong ? "Giao dịch thành công." : "Giao dịch không thành công.");

            return Content($"""
                <!doctype html>
                <html lang="vi"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>RoomFinder - Kết quả thanh toán</title></head>
                <body style="font-family:system-ui,sans-serif;background:#f5f6fa;display:flex;align-items:center;
                             justify-content:center;min-height:100vh;margin:0">
                  <div style="background:#fff;padding:32px 24px;border-radius:16px;max-width:420px;width:90%;
                              box-shadow:0 10px 30px rgba(0,0,0,.08);text-align:center;border-top:5px solid {mau}">
                    <div style="font-size:42px">{bieuTuong}</div>
                    <h2 style="margin:12px 0 8px;color:{mau}">
                      {tieuDe}
                    </h2>
                    <p style="color:#495057;margin:0 0 20px">{thongDiep}</p>
                    <p style="color:#6c757d;font-size:14px;margin:0">Quay lại ứng dụng RoomFinder để tiếp tục.</p>
                  </div>
                </body></html>
                """, "text/html; charset=utf-8");
        }
    }
}

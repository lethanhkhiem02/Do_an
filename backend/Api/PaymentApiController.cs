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
        private readonly GiaiNganPhatCocService _phatCoc;

        public PaymentApiController(ApplicationDbContext db, UserManager<AppUser> userManager,
            GiaiNganPhatCocService phatCoc,
            IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _db = db;
            _userManager = userManager;
            _phatCoc = phatCoc;
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

            // Cọc đã giải ngân (phòng chốt cho thuê / đã ký hợp đồng) thì không còn gì để hủy.
            if (phong.DaChoThue)
            {
                return BadRequest(new ApiError(Localizer["Api_DepositAlreadySettled"]));
            }

            decimal tienCoc = phong.TienCoc ?? VnPayOptions.TienDatCocGiuCho;
            decimal tienHoan = Math.Round(tienCoc * (1 - VnPayOptions.TyLePhatHuyCoc), 0, MidpointRounding.AwayFromZero);
            decimal tienPhat = tienCoc - tienHoan;

            // Chỉ phần hoàn rời khỏi ví nền tảng; phần phạt vẫn nằm ở admin, treo chờ phân xử.
            if (admin != null) admin.SoDu -= tienHoan;
            user.SoDu += tienHoan;

            var hoaDonCoc = await _db.HoaDons.FirstOrDefaultAsync(h =>
                h.PhongTroId == phong.Id && h.NguoiThueId == user.Id && h.TrangThai == "TamGiu");
            if (hoaDonCoc != null) hoaDonCoc.TrangThai = "HoanTien";

            _db.HoaDons.Add(new HoaDon
            {
                PhongTroId = phong.Id,
                NguoiThueId = user.Id,
                TongTien = tienPhat,
                TienHoaHong = 0,
                TienChuTroNhan = tienPhat,
                NgayGiaoDich = DateTime.Now,
                LoaiHoaDon = "PhatCoc",
                TrangThai = "ChoGiaiNgan"
            });

            int soNgayCho = VnPayOptions.SoNgayChoXuLyPhatCoc;
            var hanCho = DateTime.Now.AddDays(soNgayCho);

            phong.NguoiDatCocId = null;
            phong.TienCoc = null;
            phong.HanDatCoc = null;

            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_DepositCancelled",
                tienHoan.ToString("N0"), tienPhat.ToString("N0"),
                soNgayCho.ToString(), hanCho.ToString("dd/MM/yyyy")]));
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

            await _phatCoc.QuetDenHanAsync();

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

        // ============================ CỔNG THANH TOÁN DEMO ============================

        // TmnCode sandbox của đồ án đã bị VNPay thu hồi (lỗi 71), nên trang này đóng vai
        // cổng thanh toán: hiển thị đúng số tiền rồi ký sẵn một callback thành công gửi về
        // vnp_ReturnUrl. Không có đường tắt nào — mọi luồng tiền vẫn đi qua callback thật,
        // kể cả bước kiểm chữ ký. Tắt bằng VnPayOptions.CongThanhToanDemo.
        [AllowAnonymous]
        [HttpGet("demo")]
        public IActionResult CongDemo()
        {
            if (!VnPayOptions.CongThanhToanDemo) return NotFound();

            var boDem = new Dictionary<string, string>();
            foreach (string key in Request.Query.Keys)
            {
                if (!string.IsNullOrEmpty(key) && key.StartsWith("vnp_")) boDem[key] = Request.Query[key];
            }

            var kiemTra = new VnPayLibrary();
            foreach (var kv in boDem) kiemTra.AddResponseData(kv.Key, kv.Value);
            if (boDem.Count == 0
                || !kiemTra.ValidateSignature(
                    boDem.GetValueOrDefault("vnp_SecureHash", ""), VnPayOptions.HashSecret))
            {
                return KetQuaHtml(false, Localizer["Api_BadSignature"]);
            }

            // Trang này mở bằng trình duyệt nên Accept-Language của Chrome không phản ánh
            // ngôn ngữ chọn trong app; vnp_Locale do backend ghi lúc phát hành URL mới đúng.
            var tenVanHoa = boDem.GetValueOrDefault("vnp_Locale") == "en" ? "en-US" : "vi-VN";
            var vanHoaGoc = System.Globalization.CultureInfo.CurrentCulture;
            var ngonNhuGoc = System.Globalization.CultureInfo.CurrentUICulture;
            System.Globalization.CultureInfo.CurrentCulture =
                System.Globalization.CultureInfo.CurrentUICulture =
                    new System.Globalization.CultureInfo(tenVanHoa);
            try
            {
                decimal soTien = decimal.Parse(boDem.GetValueOrDefault("vnp_Amount", "0")) / 100;

                // Dấu & trong href phải thành &amp; để HTML hợp lệ; TxnRef thì hiển thẳng ra
                // trang, nên cả hai đều mã hóa trước khi render.
                string duongDanTraVe = System.Net.WebUtility.HtmlEncode(
                    $"{boDem.GetValueOrDefault("vnp_ReturnUrl", "")}?{KyCallbackThanhCong(boDem)}");
                string maGiaoDich = System.Net.WebUtility.HtmlEncode(boDem.GetValueOrDefault("vnp_TxnRef", ""));

                string noiDung = $"""
                    <h2 style="margin:0 0 4px;color:#0d6efd">{Localizer["Api_DemoTitle"]}</h2>
                    <p style="color:#495057;margin:0 0 18px;font-size:15px">{Localizer["Api_DemoNote"]}</p>
                    <div style="background:#f1f3f9;border-radius:10px;padding:14px 16px;margin:0 0 18px;
                                text-align:left;font-size:14px;color:#495057">
                      <div>{Localizer["Api_DemoAmount", soTien.ToString("N0")]}</div>
                      <div style="margin-top:6px">{Localizer["Api_DemoRef", maGiaoDich]}</div>
                    </div>
                    <a href="{duongDanTraVe}"
                       style="display:block;background:#0d6efd;color:#fff;text-decoration:none;
                              padding:14px;border-radius:10px;font-weight:600;margin:0 0 10px">
                      {Localizer["Api_DemoConfirm"]}
                    </a>
                    <a href="javascript:history.back()"
                       style="display:block;color:#6c757d;text-decoration:none;padding:10px">
                      {Localizer["Api_DemoCancel"]}
                    </a>
                    """;

                return Content(TrangKhung(noiDung, tenVanHoa.Split('-')[0]), "text/html; charset=utf-8");
            }
            finally
            {
                System.Globalization.CultureInfo.CurrentCulture = vanHoaGoc;
                System.Globalization.CultureInfo.CurrentUICulture = ngonNhuGoc;
            }
        }

        // Bổ sung các trường VNPay sẽ gửi khi thanh toán thành công rồi ký lại, để callback
        // đi qua đúng TraKetQua như một giao dịch thật.
        private string KyCallbackThanhCong(Dictionary<string, string> thamSo)
        {
            thamSo.Remove("vnp_SecureHash");
            thamSo["vnp_ResponseCode"] = "00";
            thamSo["vnp_TransactionStatus"] = "00";
            thamSo["vnp_TransactionNo"] = DateTime.Now.ToString("HHmmss");
            thamSo["vnp_PayDate"] = DateTime.Now.ToString("yyyyMMddHHmmss");

            var vnpay = new VnPayLibrary();
            foreach (var kv in thamSo) vnpay.AddResponseData(kv.Key, kv.Value);
            return vnpay.CreateCallbackQuery(VnPayOptions.HashSecret);
        }

        // ================================ TIỆN ÍCH NỘI BỘ ================================

        private string TaoUrlThanhToan(string tenCallback, long soTienBotThap, string noiDung, string txnRef, string loai = "other")
        {
            var returnUrl = $"{Request.Scheme}://{Request.Host}/api/thanhtoan/{tenCallback}";

            var thamSo = new SortedDictionary<string, string>
            {
                ["vnp_Version"] = "2.1.0",
                ["vnp_Command"] = "pay",
                ["vnp_TmnCode"] = VnPayOptions.TmnCode,
                ["vnp_Amount"] = soTienBotThap.ToString(),
                ["vnp_CreateDate"] = DateTime.Now.ToString("yyyyMMddHHmmss"),
                ["vnp_CurrCode"] = "VND",
                ["vnp_IpAddr"] = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1",
                // App gửi "Accept-Language: en" thì trang thanh toán cũng phải tiếng Anh.
                ["vnp_Locale"] = System.Globalization.CultureInfo.CurrentCulture.TwoLetterISOLanguageName == "en"
                    ? "en" : "vn",
                ["vnp_OrderInfo"] = noiDung,
                ["vnp_OrderType"] = loai,
                ["vnp_ReturnUrl"] = returnUrl,
                ["vnp_TxnRef"] = txnRef,
            };

            if (VnPayOptions.CongThanhToanDemo)
            {
                // Trang demo nhận đúng bộ tham số VNPay sẽ nhận, kèm chữ ký thật, nên nó
                // chỉ hoạt động khi URL này do chính backend phát hành.
                var vnpayKy = new VnPayLibrary();
                foreach (var kv in thamSo) vnpayKy.AddResponseData(kv.Key, kv.Value);
                return $"{Request.Scheme}://{Request.Host}/api/thanhtoan/demo?"
                     + vnpayKy.CreateCallbackQuery(VnPayOptions.HashSecret);
            }

            var vnpay = new VnPayLibrary();
            foreach (var kv in thamSo) vnpay.AddRequestData(kv.Key, kv.Value);
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

            return Content(TrangKhung($"""
                <div style="font-size:42px">{bieuTuong}</div>
                <h2 style="margin:12px 0 8px;color:{mau}">{tieuDe}</h2>
                <p style="color:#495057;margin:0 0 20px">{thongDiep}</p>
                <p style="color:#6c757d;font-size:14px;margin:0">Quay lại ứng dụng RoomFinder để tiếp tục.</p>
                """, "vi"), "text/html; charset=utf-8");
        }

        private static string TrangKhung(string noiDung, string maNgonNgu) => $"""
            <!doctype html>
            <html lang="{maNgonNgu}"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>RoomFinder</title></head>
            <body style="font-family:system-ui,sans-serif;background:#f5f6fa;display:flex;align-items:center;
                         justify-content:center;min-height:100vh;margin:0">
              <div style="background:#fff;padding:32px 24px;border-radius:16px;max-width:420px;width:90%;
                          box-shadow:0 10px 30px rgba(0,0,0,.08);text-align:center">
                {noiDung}
              </div>
            </body></html>
            """;
    }
}

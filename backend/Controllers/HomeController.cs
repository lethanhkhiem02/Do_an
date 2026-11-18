using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Localization;
using System;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;

namespace Do_an_co_so.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;
        private readonly ApplicationDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly IStringLocalizer<SharedResource> _localizer;
        private static readonly Random _rand = new Random();

        public HomeController(ILogger<HomeController> logger, ApplicationDbContext context, IConfiguration configuration,
            IStringLocalizer<SharedResource> localizer)
        {
            _logger = logger;
            _context = context;
            _configuration = configuration;
            _localizer = localizer;
        }

        public async Task<IActionResult> Index()
        {
            // Ẩn phòng đã thuê VÀ ẩn bài đăng đã hết hạn hiển thị công khai trên hệ thống
            var danhSachPhong = await _context.PhongTro
                .Where(p => p.DaChoThue == false && (p.NgayHetHan == null || p.NgayHetHan >= DateTime.Now))
                .OrderByDescending(p => p.IsVip)
                .ThenByDescending(p => p.Id)
                .ToListAsync();

            // Lấy toàn bộ dữ liệu đánh giá truyền ra giao diện
            ViewBag.AllDanhGias = await _context.DanhGias.ToListAsync();

            return View(danhSachPhong);
        }

        public IActionResult Privacy() { return View(); }
        public IActionResult AboutUs() { return View(); }
        public IActionResult Terms() { return View(); }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }

        // ====================================================================
        // 🔥 BỘ NÃO TRỢ LÝ TỰ ĐỘNG - BÁM SÁT 100% DATABASE CỦA ĐỒ ÁN 🔥
        // ====================================================================
        // Toàn bộ câu trả lời nằm trong Resources/SharedResource.*.resx nên đổi
        // ngôn ngữ (cookie .AspNetCore.Culture của web, Accept-Language của app)
        // là câu trả lời đổi theo, không phải sửa code.
        [HttpGet]
        public IActionResult ChatWithAI(string message)
        {
            if (string.IsNullOrEmpty(message)) return Json(new { reply = _localizer["Chat_NeedHelp"] });

            string msg = message.ToLower().Trim();
            string reply = "";
            Random rand = new Random();

            // 1. KỊCH BẢN CHÀO HỎI
            if (CóTừ(msg, "chào", "hi", "hello", "xin chào", "hey", "good morning", "good evening"))
            {
                reply = ChonNgau(_localizer["Chat_Greet1"], _localizer["Chat_Greet2"], _localizer["Chat_Greet3"]);
            }

            // 2. KỊCH BẢN BẤT NGỜ / TỪ LÓNG
            else if (msg == "hả" || msg.Contains("vailon") || msg == "m" || msg == "gì" || msg == "sao" || msg.Contains("vaiinho")
                     || msg == "huh" || msg == "what" || msg == "why" || msg == "pardon")
            {
                reply = ChonNgau(_localizer["Chat_Slang1"], _localizer["Chat_Slang2"]);
            }

            // 3. KỊCH BẢN TÌM TRỌ / BẢN ĐỒ / VỊ TRÍ
            else if (CóTừ(msg, "tìm", "kiếm trọ", "bản đồ", "quanh trường", "vị trí", "search", "find", "map", "near", "location", "distance"))
            {
                reply = _localizer["Chat_Map"];
            }

            // 4. KỊCH BẢN ĐẶT CỌC / GIỮ CHỖ (Dựa trên NguoiDatCocId, TienCoc, HanDatCoc, SoNgayGiuPhong)
            else if (CóTừ(msg, "cọc", "đặt cọc", "giữ chỗ", "giữ phòng", "vnpay", "deposit", "hold", "booking", "reserve"))
            {
                reply = _localizer["Chat_Deposit"];
            }

            // 5. KỊCH BẢN GIÁ CẢ & DIỆN TÍCH & TIỆN ÍCH (Dựa trên Gia, ChieuDai, ChieuRong, CoNhaVeSinh, CoBanCong)
            else if (CóTừ(msg, "giá", "bao nhiêu", "tiền", "rẻ", "diện tích", "rộng", "tiện ích", "ban công", "vệ sinh",
                           "price", "rent", "cost", "cheap", "area", "size", "amenit", "balcony", "bathroom", "toilet"))
            {
                reply = ChonNgau(_localizer["Chat_Price1"], _localizer["Chat_Price2"]);
            }

            // 6. KỊCH BẢN PHÒNG CHỐNG LỪA ĐẢO / HẾT HẠN (Dựa trên DaChoThue, NgayHetHan)
            else if (CóTừ(msg, "lừa đảo", "uy tín", "an toàn", "báo cáo", "hết hạn", "phòng ảo",
                           "scam", "fraud", "safe", "report", "expire", "fake", "trust"))
            {
                reply = _localizer["Chat_Fraud"];
            }

            // 7. KỊCH BẢN ĐĂNG TIN VIP (Dựa trên IsVip)
            else if (CóTừ(msg, "vip", "đăng tin vip", "phí tin", "featured", "pin"))
            {
                reply = _localizer["Chat_Vip"];
            }

            // 8. KỊCH BẢN THÔNG TIN TÁC GIẢ
            else if (CóTừ(msg, "tác giả", "ai làm", "phát triển", "roomfinder", "who made", "who built", "developer", "author"))
            {
                reply = _localizer["Chat_Author"];
            }

            // 9. TỪ CHỐI KHÉO CÂU HỎI NGOÀI LỀ
            else if (CóTừ(msg, "toán", "lập trình", "code", "thơ", "lịch sử", "văn", "math", "poem", "history", "literature"))
            {
                reply = _localizer["Chat_OffTopic"];
            }

            // 10. KỊCH BẢN DỰ PHÒNG (FALLBACK)
            else
            {
                reply = ChonNgau(_localizer["Chat_Fallback1"], _localizer["Chat_Fallback2"], _localizer["Chat_Fallback3"]);
            }

            return Json(new { reply = reply });
        }

        // So khớp từ khóa dạng "chứa chuỗi", áp dụng cho cả phụ đề tiếng Anh
        // ("price", "deposit", "near"...) để câu hỏi tiếng Anh vẫn đúng kịch bản.
        private static bool CóTừ(string msg, params string[] tuKhoa)
        {
            foreach (var tu in tuKhoa)
            {
                if (msg.Contains(tu)) return true;
            }
            return false;
        }

        private static string ChonNgau(params LocalizedString[] answers)
        {
            return answers[_rand.Next(answers.Length)].Value;
        }
    }
}
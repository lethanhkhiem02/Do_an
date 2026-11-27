using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Do_an_co_so.Services
{
    public record AiRoomSearchResult(
        List<RoomMatch> Matches,
        List<string> CacTieuChi,
        string ThongBao,
        bool UsedFallback);

    /// <summary>
    /// Phân tích mô tả tự nhiên bằng Gemini 2.5 Flash (kèm fallback regex/từ khóa tiếng Việt)
    /// rồi truy vấn PhongTro theo cơ chế 3 tầng (lọc vô nghĩa -> khớp chính xác -> nới lỏng thông minh).
    /// </summary>
    public class AiRoomSearchService
    {
        private static readonly CultureInfo ViCulture = new("vi-VN");

        private const string ThongBaoKhongHopLe =
            "Chưa nhận diện được tiêu chí tìm phòng cụ thể từ mô tả của bạn. Dưới đây là các phòng nổi bật gợi ý:";

        private const string ThongBaoNoiLong =
            "Không có phòng khớp 100% mọi tiêu chí, hệ thống gợi ý các phòng gần nhất với nhu cầu của bạn:";

        // Danh sách quận/khu vực/viết tắt phổ biến tại TP.HCM dùng cho fallback và chuẩn hóa địa chỉ.
        private static readonly (string Pattern, string TenChuan)[] KhuVucPatterns =
        {
            (@"\b(khu\s*cong\s*nghe\s*cao|kcnc)\b", "Khu Công Nghệ Cao"),
            (@"\b(thu\s*duc|td|lang\s*dai\s*hoc|linh\s*trung|linh\s*chieu|linh\s*tay|truong\s*tho|hiep\s*binh|hiep\s*phu|tang\s*nhon\s*phu|vo\s*van\s*ngan|hoang\s*dieu\s*2|cho\s*thu\s*duc|kha\s*van\s*can)\b", "Thủ Đức"),
            (@"\b(binh\s*thanh|bt|dien\s*bien\s*phu|ung\s*van\s*khiem|xo\s*viet\s*nghe\s*tinh|nguyen\s*gia\s*tri)\b", "Bình Thạnh"),
            (@"\b(go\s*vap|gv|nguyen\s*van\s*bao)\b", "Gò Vấp"),
            (@"\b(tan\s*binh)\b", "Tân Bình"),
            (@"\b(tan\s*phu)\b", "Tân Phú"),
            (@"\b(phu\s*nhuan)\b", "Phú Nhuận"),
            (@"\b(binh\s*tan)\b", "Bình Tân"),
            (@"\b(nha\s*be)\b", "Nhà Bè"),
            (@"\b(binh\s*chanh)\b", "Bình Chánh"),
            (@"\b(hoc\s*mon)\b", "Hóc Môn"),
            (@"\b(cu\s*chi)\b", "Củ Chi"),
            (@"\b(can\s*gio)\b", "Cần Giờ"),
            (@"\b(?:quan|q\.?)\s*12\b", "Quận 12"),
            (@"\b(?:quan|q\.?)\s*11\b", "Quận 11"),
            (@"\b(?:quan|q\.?)\s*10\b", "Quận 10"),
            (@"\b(?:quan|q\.?)\s*9\b", "Quận 9"),
            (@"\b(?:quan|q\.?)\s*8\b", "Quận 8"),
            (@"\b(?:quan|q\.?)\s*7\b", "Quận 7"),
            (@"\b(?:quan|q\.?)\s*6\b", "Quận 6"),
            (@"\b(?:quan|q\.?)\s*5\b", "Quận 5"),
            (@"\b(?:quan|q\.?)\s*4\b", "Quận 4"),
            (@"\b(?:quan|q\.?)\s*3\b", "Quận 3"),
            (@"\b(?:quan|q\.?)\s*2\b", "Quận 2"),
            (@"\b(?:quan|q\.?)\s*1\b", "Quận 1"),
        };

        // Ánh xạ trường đại học -> ID trường, danh sách khu vực chuẩn và từ khóa địa danh tương ứng.
        private static readonly (string Keyword, string[] SchoolIds, string[] DefaultAreas, string[] AreaAliases)[] TruongMappings =
        {
            ("hutech", new[] { "hutech_dbp", "hutech_uvk", "hutech_td" }, new[] { "Bình Thạnh", "Thủ Đức", "Quận 9" }, new[] { "binh thanh", "thu duc", "quan 9", "khu cong nghe cao", "dien bien phu", "ung van khiem" }),
            ("van lang", new[] { "vlu_cs2", "vlu_cs3" }, new[] { "Bình Thạnh", "Gò Vấp" }, new[] { "binh thanh", "go vap" }),
            ("hong bang", new[] { "hiu" }, new[] { "Bình Thạnh" }, new[] { "binh thanh" }),
            ("giao thong van tai", new[] { "gtvt" }, new[] { "Bình Thạnh" }, new[] { "binh thanh" }),
            ("ngoai thuong", new[] { "ftu2" }, new[] { "Bình Thạnh" }, new[] { "binh thanh" }),
            ("uef", new[] { "uef" }, new[] { "Bình Thạnh" }, new[] { "binh thanh" }),
            ("su pham ky thuat", new[] { "spkt" }, new[] { "Thủ Đức" }, new[] { "thu duc", "vo van ngan" }),
            ("spkt", new[] { "spkt" }, new[] { "Thủ Đức" }, new[] { "thu duc", "vo van ngan" }),
            ("nong lam", new[] { "nlu" }, new[] { "Thủ Đức" }, new[] { "thu duc" }),
            ("uit", new[] { "uit" }, new[] { "Thủ Đức" }, new[] { "thu duc", "lang dai hoc" }),
            ("cong nghe thong tin", new[] { "uit" }, new[] { "Thủ Đức" }, new[] { "thu duc", "lang dai hoc" }),
            ("ngan hang", new[] { "buh" }, new[] { "Thủ Đức" }, new[] { "thu duc" }),
            ("kinh te luat", new[] { "uel" }, new[] { "Thủ Đức" }, new[] { "thu duc", "lang dai hoc" }),
            ("uel", new[] { "uel" }, new[] { "Thủ Đức" }, new[] { "thu duc", "lang dai hoc" }),
            ("fpt", new[] { "fpt_hcm" }, new[] { "Thủ Đức", "Quận 9", "Khu Công Nghệ Cao" }, new[] { "thu duc", "quan 9", "khu cong nghe cao" }),
            ("cong nghiep", new[] { "iuh" }, new[] { "Gò Vấp" }, new[] { "go vap", "nguyen van bao" }),
            ("iuh", new[] { "iuh" }, new[] { "Gò Vấp" }, new[] { "go vap", "nguyen van bao" }),
            ("ueh", new[] { "ueh_q3" }, new[] { "Quận 3" }, new[] { "quan 3" }),
            ("kien truc", new[] { "uah" }, new[] { "Quận 3" }, new[] { "quan 3" }),
            ("hoa sen", new[] { "hsu" }, new[] { "Quận 1" }, new[] { "quan 1" }),
            ("ton duc thang", new[] { "tdt" }, new[] { "Quận 7" }, new[] { "quan 7" }),
            ("tdtu", new[] { "tdt" }, new[] { "Quận 7" }, new[] { "quan 7" }),
            ("rmit", new[] { "rmit" }, new[] { "Quận 7" }, new[] { "quan 7" }),
            ("bach khoa", new[] { "hcmut_q10", "hcmut_td" }, new[] { "Quận 10", "Thủ Đức" }, new[] { "quan 10", "thu duc" }),
            ("huflit", new[] { "huflit" }, new[] { "Quận 10" }, new[] { "quan 10" }),
            ("huit", new[] { "huit" }, new[] { "Tân Phú" }, new[] { "tan phu" }),
            ("cong thuong", new[] { "huit" }, new[] { "Tân Phú" }, new[] { "tan phu" }),
            ("cao thang", new[] { "caothang" }, new[] { "Quận 1" }, new[] { "quan 1" }),
        };

        // Thứ tự ưu tiên cụm dài trước để tránh trích xuất trùng lặp (VD: "giờ giấc tự do" vs "tự do").
        private static readonly string[] ExtraAmenityKeywords =
        {
            "không chung chủ", "giờ giấc tự do", "gần chợ", "full nội thất",
            "máy giặt", "tủ lạnh", "nội thất", "cửa sổ", "thang máy",
            "tự do", "an ninh", "wifi", "kệ bếp", "nấu ăn",
            "thú cưng", "nuôi mèo", "nuôi chó", "giếng trời", "yên tĩnh"
        };

        private readonly IConfiguration _configuration;
        private readonly ApplicationDbContext _db;
        private readonly IHttpClientFactory _httpFactory;
        private readonly ILogger<AiRoomSearchService> _logger;

        public AiRoomSearchService(
            IConfiguration configuration,
            ApplicationDbContext db,
            IHttpClientFactory httpFactory,
            ILogger<AiRoomSearchService> logger)
        {
            _configuration = configuration;
            _db = db;
            _httpFactory = httpFactory;
            _logger = logger;
        }

        public async Task<AiRoomSearchResult> SearchAsync(string moTa)
        {
            var trimmed = (moTa ?? "").Trim();
            AiCriteria criteria;
            bool usedFallback;

            try
            {
                (criteria, usedFallback) = await ExtractCriteriaWithFallbackAsync(trimmed);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Lỗi không mong muốn khi trích xuất tiêu chí AI, dùng fallback.");
                criteria = SafeParseFallback(trimmed);
                usedFallback = true;
            }

            var (matches, cacTieuChi, thongBao) = await QueryRoomsAsync(criteria, trimmed);
            return new AiRoomSearchResult(matches, cacTieuChi, thongBao, usedFallback);
        }

        private async Task<(AiCriteria Criteria, bool UsedFallback)> ExtractCriteriaWithFallbackAsync(string moTa)
        {
            var apiKey = _configuration["Gemini:ApiKey"] ?? _configuration["GeminiApiKey"];
            if (!string.IsNullOrWhiteSpace(apiKey))
            {
                var geminiCriteria = await TryExtractWithGeminiAsync(moTa, apiKey.Trim());
                if (geminiCriteria != null)
                {
                    NormalizeCriteria(geminiCriteria);
                    return (geminiCriteria, false);
                }
            }

            var fallback = SafeParseFallback(moTa);
            return (fallback, true);
        }

        private static AiCriteria SafeParseFallback(string moTa)
        {
            try
            {
                var fallback = ParseFallback(moTa);
                NormalizeCriteria(fallback);
                return fallback;
            }
            catch
            {
                return new AiCriteria();
            }
        }

        private async Task<AiCriteria?> TryExtractWithGeminiAsync(string moTa, string apiKey)
        {
            try
            {
                var prompt =
                    "Bạn là bộ phân tích truy vấn tìm phòng trọ sinh viên tại TP.HCM cho hệ thống RoomFinder.\n" +
                    "Bảng PhongTro có các cột: MoTa (mô tả tự do: máy lạnh, gác lửng, chỗ để xe, không chung chủ, giờ giấc tự do, full nội thất...), " +
                    "DiaChi (địa chỉ gồm đường, phường, quận/TP Thủ Đức), Gia (VNĐ/tháng), ChieuDai & ChieuRong (mét -> diện tích = ChieuDai * ChieuRong), " +
                    "LoaiHinh ('PhongRieng' hoặc 'KyTucXa'), CoNhaVeSinh (bool: vệ sinh riêng), CoBanCong (bool: ban công).\n\n" +
                    $"Hãy phân tích câu mô tả của người dùng: \"{moTa}\"\n\n" +
                    "Trả về DUY NHẤT 1 JSON object hợp lệ (không markdown) theo schema sau:\n" +
                    "{\n" +
                    "  \"laYeuCauHopLe\": boolean,\n" +
                    "  \"khuVuc\": string[],\n" +
                    "  \"giaMin\": number | null,\n" +
                    "  \"giaMax\": number | null,\n" +
                    "  \"dienTichMin\": number | null,\n" +
                    "  \"loaiHinh\": \"PhongRieng\" | \"KyTucXa\" | null,\n" +
                    "  \"coNhaVeSinh\": boolean | null,\n" +
                    "  \"coBanCong\": boolean | null,\n" +
                    "  \"coMayLanh\": boolean | null,\n" +
                    "  \"coGacLung\": boolean | null,\n" +
                    "  \"coChoDeXe\": boolean | null,\n" +
                    "  \"sapXep\": \"gia_giam\" | \"gia_tang\" | \"moi_nhat\" | \"mac_dinh\",\n" +
                    "  \"tuKhoa\": string | null,\n" +
                    "  \"cacTieuChi\": string[]\n" +
                    "}\n" +
                    "Quy tắc bắt buộc:\n" +
                    "- 'laYeuCauHopLe': đặt false nếu người dùng nhập ký tự vô nghĩa ('asdf', '12345', '???') hoặc nội dung hoàn toàn không liên quan thuê phòng/trọ/ký túc xá ('tìm người yêu', 'ăn gì hôm nay', 'sao Hỏa'). Đặt true nếu liên quan tìm chỗ ở hoặc có tiêu chí phòng.\n" +
                    "- 'khuVuc': mảng các khu vực chuẩn. Giải mã viết tắt & địa danh sinh viên: 'TĐ' -> ['Thủ Đức'], 'BT' -> ['Bình Thạnh'], 'Q9' -> ['Quận 9'], 'GV' -> ['Gò Vấp'], 'KCNC' -> ['Khu Công Nghệ Cao'], 'HUTECH' (khi không nói rõ cơ sở) -> ['Bình Thạnh', 'Thủ Đức', 'Quận 9'].\n" +
                    "- Quy đổi tiền Việt sang VNĐ đầy đủ: '2 củ' / '3 đồng' / '3tr' -> 2000000 / 3000000; '2tr5 quay đầu' -> giaMax = 2500000; '1 xị' = 100000 (VD: '3 xị' -> 300000, '25 xị' -> 2500000); 'dưới X' -> giaMax = X; 'trên X' -> giaMin = X; 'từ A đến B' -> giaMin = A, giaMax = B; 'khoảng/tầm X' -> giaMin = max(0, X - 500000), giaMax = X + 500000.\n" +
                    "- Tính từ giá mơ hồ (không kèm số): 'rẻ', 'giá rẻ', 'giá mềm', 'hạt dẻ', 'sinh viên nghèo', 'bình dân' -> giaMax = 2500000 và sapXep = 'gia_tang'.\n" +
                    "- 'dienTichMin': suy luận từ mô tả nếu không có số m2 cụ thể ('rộng rãi', 'ở 3-4 người' -> 25).\n" +
                    "- 'loaiHinh': xử lý cả câu phủ định ('không ở ký túc xá', 'ở 1 mình riêng tư', 'không ở ghép' -> 'PhongRieng'; 'giường tầng', 'sleepbox', 'ktx', 'ký túc xá' -> 'KyTucXa').\n" +
                    "- Suy luận ngầm định 5 tiện ích (chỉ đặt true khi có nhu cầu trực tiếp hoặc gián tiếp, không thì null): 'nóng quá'/'cần điều hòa' -> coMayLanh = true; 'cần chỗ phơi đồ thoáng mát'/'ban công' -> coBanCong = true; 'ngại dùng chung toilet'/'vệ sinh riêng' -> coNhaVeSinh = true; 'gác lửng' -> coGacLung = true; 'có xe máy'/'chỗ để xe' -> coChoDeXe = true.\n" +
                    "- 'sapXep': 'gia_giam' ('đắt nhất', 'xịn nhất', 'cao cấp'), 'gia_tang' ('rẻ nhất', 'tiết kiệm nhất', 'bèo nhất', hoặc tính từ giá rẻ mơ hồ), 'moi_nhat' ('mới đăng', 'mới nhất'), còn lại là 'mac_dinh'.\n" +
                    "- 'tuKhoa': chuỗi gọn gồm các yêu cầu phụ cách nhau bởi dấu phẩy (VD: 'không chung chủ, giờ giấc tự do, gần chợ'), không lặp lại khu vực, loại hình hay 5 tiện ích ở trên.\n" +
                    "- 'cacTieuChi': danh sách chuỗi tiếng Việt ngắn gọn tóm tắt tiêu chí đã nhận diện.";

                var payload = new
                {
                    contents = new[]
                    {
                        new
                        {
                            parts = new object[]
                            {
                                new { text = prompt }
                            }
                        }
                    },
                    generationConfig = new
                    {
                        response_mime_type = "application/json",
                        temperature = 0.1
                    }
                };

                var client = _httpFactory.CreateClient("gemini");
                var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={apiKey}";
                using var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
                using var response = await client.PostAsync(url, content);

                if (!response.IsSuccessStatusCode)
                {
                    var err = await response.Content.ReadAsStringAsync();
                    _logger.LogWarning("Gemini AI Search trả mã {StatusCode}: {Error}", response.StatusCode, err);
                    return null;
                }

                var body = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(body);
                if (!doc.RootElement.TryGetProperty("candidates", out var candidates) ||
                    candidates.ValueKind != JsonValueKind.Array ||
                    candidates.GetArrayLength() == 0)
                {
                    return null;
                }

                var firstCandidate = candidates[0];
                if (!firstCandidate.TryGetProperty("content", out var contentEl) ||
                    !contentEl.TryGetProperty("parts", out var partsEl) ||
                    partsEl.ValueKind != JsonValueKind.Array ||
                    partsEl.GetArrayLength() == 0 ||
                    !partsEl[0].TryGetProperty("text", out var textEl))
                {
                    return null;
                }

                var text = textEl.GetString();
                if (string.IsNullOrWhiteSpace(text)) return null;

                text = StripMarkdownCodeFence(text);
                if (string.IsNullOrWhiteSpace(text)) return null;

                using var parsed = JsonDocument.Parse(text);
                var root = parsed.RootElement;
                if (root.ValueKind != JsonValueKind.Object) return null;

                return new AiCriteria
                {
                    LaYeuCauHopLe = GetBool(root, "laYeuCauHopLe") ?? true,
                    KhuVuc = GetStringOrList(root, "khuVuc"),
                    GiaMin = GetDecimal(root, "giaMin") ?? GetDecimal(root, "giaToiThieu"),
                    GiaMax = GetDecimal(root, "giaMax") ?? GetDecimal(root, "giaToiDa"),
                    DienTichMin = GetDouble(root, "dienTichMin") ?? GetDouble(root, "dienTichToiThieu"),
                    LoaiHinh = GetString(root, "loaiHinh"),
                    CoNhaVeSinh = GetBool(root, "coNhaVeSinh"),
                    CoBanCong = GetBool(root, "coBanCong"),
                    CoMayLanh = GetBool(root, "coMayLanh"),
                    CoGacLung = GetBool(root, "coGacLung"),
                    CoChoDeXe = GetBool(root, "coChoDeXe"),
                    SapXep = GetString(root, "sapXep") ?? "mac_dinh",
                    TuKhoa = GetJoinedKeywords(root, "tuKhoa"),
                    GeminiCacTieuChi = GetStringList(root, "cacTieuChi")
                };
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Gọi hoặc parse JSON từ Gemini AI Search thất bại, chuyển sang fallback regex.");
                return null;
            }
        }

        private static string StripMarkdownCodeFence(string raw)
        {
            var text = raw.Trim();
            if (text.StartsWith("```", StringComparison.Ordinal))
            {
                var start = text.IndexOf('{');
                var end = text.LastIndexOf('}');
                if (start >= 0 && end > start)
                {
                    return text.Substring(start, end - start + 1);
                }
            }
            return text;
        }

        internal static AiCriteria ParseFallback(string moTa)
        {
            var criteria = new AiCriteria();
            var norm = NormalizeText(moTa);

            if (string.IsNullOrWhiteSpace(norm))
            {
                criteria.LaYeuCauHopLe = false;
                return criteria;
            }

            // 1. Khu vực / Quận / Viết tắt sinh viên TP.HCM (thu thập tất cả khu vực được nhắc)
            foreach (var (pattern, tenChuan) in KhuVucPatterns)
            {
                if (Regex.IsMatch(norm, pattern) &&
                    !criteria.KhuVuc.Any(k => k.Equals(tenChuan, StringComparison.OrdinalIgnoreCase)))
                {
                    criteria.KhuVuc.Add(tenChuan);
                }
            }

            // Nếu nhắc trường đại học mà chưa chỉ định khu vực cụ thể, tự suy ra các khu vực cơ sở trường (VD: HUTECH -> Bình Thạnh, Thủ Đức, Quận 9).
            var matchedSchoolKeywords = new List<string>();
            foreach (var (kw, _, defaultAreas, _) in TruongMappings)
            {
                if (ContainsWholePhrase(norm, kw))
                {
                    matchedSchoolKeywords.Add(kw);
                    if (criteria.KhuVuc.Count == 0)
                    {
                        foreach (var area in defaultAreas)
                        {
                            if (!criteria.KhuVuc.Any(k => k.Equals(area, StringComparison.OrdinalIgnoreCase)))
                                criteria.KhuVuc.Add(area);
                        }
                    }
                }
            }

            // 2. Giá thuê + Sắp xếp theo mức giá/thời gian
            ExtractSortFallback(norm, criteria);
            ExtractPricesFallback(norm, criteria);

            // 3. Diện tích tối thiểu (số m2 hoặc suy luận từ "rộng rãi", "ở 3-4 người")
            var areaMatch = Regex.Match(norm, @"(\d+(?:[.,]\d+)?)\s*(?:m2|met\s*vuong)\b");
            if (areaMatch.Success &&
                double.TryParse(areaMatch.Groups[1].Value.Replace(',', '.'), NumberStyles.Any, CultureInfo.InvariantCulture, out var dt) &&
                dt > 0 && dt <= 500)
            {
                criteria.DienTichMin = dt;
            }
            else if (Regex.IsMatch(norm, @"\b(rong\s*rai|phong\s*rong|khong\s*gian\s*rong)\b") ||
                     Regex.IsMatch(norm, @"\b(?:o|nhom|cho)\s*(?:[3-9]|\d+\s*[-den\s]+\s*[3-9])\s*(?:nguoi|ban|sv|sinh\s*vien)\b") ||
                     Regex.IsMatch(norm, @"\b[3-9]\s*(?:[-den\s]+\s*[4-9])?\s*(?:nguoi|ban)\s*o\b"))
            {
                criteria.DienTichMin = 25;
            }

            // 4. Loại hình phòng (hỗ trợ cả phủ định và từ lóng sinh viên)
            if (Regex.IsMatch(norm, @"\b(khong|ko|k|khong\s*muon|khong\s*thich|tranh|bo|ngoai\s*tru)\s*(?:o\s*|thue\s*|tim\s*)?(ky\s*tuc\s*xa|ktx|o\s*ghep|giuong\s*tang|sleep\s*box|sleepbox|dorm)\b"))
            {
                criteria.LoaiHinh = nameof(LoaiHinhPhong.PhongRieng);
            }
            else if (Regex.IsMatch(norm, @"\b(phong\s*rieng|can\s*ho\s*mini|chmn|studio|nguyen\s*can|khep\s*kin|o\s*(?:1|mot)\s*minh|rieng\s*tu|o\s*rieng|khong\s*o\s*ghep|ko\s*o\s*ghep)\b"))
            {
                criteria.LoaiHinh = nameof(LoaiHinhPhong.PhongRieng);
            }
            else if (Regex.IsMatch(norm, @"\b(ky\s*tuc\s*xa|ktx|giuong\s*tang|sleep\s*box|sleepbox|o\s*ghep|dorm)\b"))
            {
                criteria.LoaiHinh = nameof(LoaiHinhPhong.KyTucXa);
            }

            // 5. Tiện ích suy luận trực tiếp + gián tiếp
            var ngaiDungChungToilet =
                Regex.IsMatch(norm, @"\b(ngai|khong|ko|tranh|so)\s*(?:phai\s*)?(?:dung\s*chung|xai\s*chung|o\s*chung|share)\s*(?:nha\s*)?(?:ve\s*sinh|vs|wc|toilet)\b") ||
                Regex.IsMatch(norm, @"\b(khong|ko)\s*(?:nha\s*)?(?:ve\s*sinh|vs|wc|toilet)\s*chung\b");
            var vsRieng = Regex.IsMatch(norm, @"\b(ve\s*sinh\s*rieng|vs\s*rieng|wc\s*rieng|toilet\s*rieng|nha\s*ve\s*sinh\s*rieng|nvs\s*rieng|nha\s*tam\s*rieng|khep\s*kin|co\s*nha\s*ve\s*sinh|co\s*wc\s*rieng)\b");
            if (ngaiDungChungToilet || (vsRieng && !Regex.IsMatch(norm, @"\b(ve\s*sinh\s*chung|vs\s*chung|wc\s*chung|toilet\s*chung)\b")))
            {
                criteria.CoNhaVeSinh = true;
            }

            if (Regex.IsMatch(norm, @"\b(ban\s*cong|lo\s*gia|phoi\s*do|cho\s*phoi|phoi\s*quan\s*ao|hong\s*gio)\b") &&
                !Regex.IsMatch(norm, @"\b(khong\s*ban\s*cong|ko\s*ban\s*cong|khong\s*can\s*ban\s*cong)\b"))
            {
                criteria.CoBanCong = true;
            }

            if (Regex.IsMatch(norm, @"\b(may\s*lanh|dieu\s*hoa|inverter|nong\s*qua|troi\s*nong|so\s*nong|chong\s*nong|lam\s*mat)\b") &&
                !Regex.IsMatch(norm, @"\b(khong\s*may\s*lanh|ko\s*may\s*lanh|khong\s*dieu\s*hoa|khong\s*can\s*may\s*lanh)\b"))
            {
                criteria.CoMayLanh = true;
            }

            if (Regex.IsMatch(norm, @"\b(gac\s*lung|co\s*gac|gac\s*xep|gac\s*cao|tang\s*lung)\b") &&
                !Regex.IsMatch(norm, @"\b(khong\s*gac|ko\s*gac)\b"))
            {
                criteria.CoGacLung = true;
            }

            if (Regex.IsMatch(norm, @"\b(cho\s*de\s*xe|de\s*xe|gui\s*xe|bai\s*xe|nha\s*xe|ham\s*xe|cho\s*xe|co\s*xe\s*may|xe\s*may|di\s*xe|chay\s*xe|xe\s*dap\s*dien)\b") &&
                !Regex.IsMatch(norm, @"\b(khong\s*co\s*xe|ko\s*co\s*xe|khong\s*can\s*cho\s*de\s*xe)\b"))
            {
                criteria.CoChoDeXe = true;
            }

            // 6. Từ khóa bổ sung (không chung chủ, giờ giấc tự do, gần chợ...)
            var extractedKeywords = new List<string>();
            foreach (var kw in ExtraAmenityKeywords)
            {
                var kwNorm = NormalizeText(kw);
                if (ContainsWholePhrase(norm, kwNorm) &&
                    !extractedKeywords.Any(existing => NormalizeText(existing).Contains(kwNorm)))
                {
                    extractedKeywords.Add(kw);
                }
            }

            if (extractedKeywords.Count > 0)
            {
                criteria.TuKhoa = string.Join(", ", extractedKeywords.Take(5));
            }

            // 7. Đánh giá tính hợp lệ của yêu cầu (LaYeuCauHopLe)
            criteria.LaYeuCauHopLe = IsValidSearchQuery(norm, criteria, matchedSchoolKeywords.Count > 0);
            return criteria;
        }

        private static bool IsValidSearchQuery(string norm, AiCriteria c, bool hasMatchedSchool)
        {
            var hasHousingIntent = Regex.IsMatch(
                norm,
                @"\b(phong|tro|phong\s*tro|nha\s*tro|ktx|ky\s*tuc\s*xa|can\s*ho|chmn|studio|sleep\s*box|sleepbox|giuong\s*tang|o\s*ghep|nguyen\s*can|cho\s*o|thue|chung\s*chu|gio\s*giac|gac|ban\s*cong|may\s*lanh|dieu\s*hoa|ve\s*sinh|toilet|wc|de\s*xe|noi\s*that)\b");

            var isExplicitOffTopic = Regex.IsMatch(
                norm,
                @"\b(nguoi\s*yeu|an\s*gi|uong\s*gi|sao\s*hoa|thoi\s*tiet|xo\s*so|bong\s*da|giai\s*toan|viet\s*van|kiem\s*ban\s*gai|kiem\s*ban\s*trai)\b");

            if (isExplicitOffTopic && !hasHousingIntent)
                return false;

            if (hasHousingIntent || hasMatchedSchool)
                return true;

            var hasAnyStructuredFilter =
                c.KhuVuc.Count > 0 ||
                c.GiaMin.HasValue ||
                c.GiaMax.HasValue ||
                c.DienTichMin.HasValue ||
                !string.IsNullOrWhiteSpace(c.LoaiHinh) ||
                c.CoNhaVeSinh == true ||
                c.CoBanCong == true ||
                c.CoMayLanh == true ||
                c.CoGacLung == true ||
                c.CoChoDeXe == true ||
                c.SapXep != "mac_dinh" ||
                !string.IsNullOrWhiteSpace(c.TuKhoa);

            return hasAnyStructuredFilter;
        }

        private static void ExtractSortFallback(string norm, AiCriteria criteria)
        {
            if (Regex.IsMatch(norm, @"\b(dat\s*nhat|mac\s*nhat|xin\s*nhat|cao\s*cap|gia\s*cao\s*nhat|gia\s*giam|tu\s*cao\s*den\s*thap|sang\s*nhat)\b"))
            {
                criteria.SapXep = "gia_giam";
            }
            else if (Regex.IsMatch(norm, @"\b(re\s*nhat|gia\s*thap\s*nhat|thap\s*nhat|tiet\s*kiem\s*nhat|beo\s*nhat|gia\s*tang|tu\s*thap\s*den\s*cao)\b"))
            {
                criteria.SapXep = "gia_tang";
            }
            else if (Regex.IsMatch(norm, @"\b(moi\s*dang|moi\s*nhat|vua\s*dang|gan\s*day\s*nhat)\b"))
            {
                criteria.SapXep = "moi_nhat";
            }
        }

        private static void ExtractPricesFallback(string norm, AiCriteria criteria)
        {
            var rangeMatch = Regex.Match(
                norm,
                @"(?:tu\s+)?(\d+(?:[.,]\d+)?(?:\s*(?:tr|trieu|cu|chai|dong|m|xi|k)(?!\s*(?:2|et)))?(?:\s*(?:ruoi|\d{1,3}))?)\s*(?:-|den|toi)\s*(\d+(?:[.,]\d+)?\s*(?:tr|trieu|cu|chai|dong|m|xi|k)(?!\s*(?:2|et))(?:\s*(?:ruoi|\d{1,3}))?|\d{6,8})\b");

            if (rangeMatch.Success)
            {
                var minStr = rangeMatch.Groups[1].Value;
                var maxStr = rangeMatch.Groups[2].Value;
                var maxVal = ParseVietnameseMoney(maxStr);
                var minVal = ParseVietnameseMoney(minStr);
                if (minVal.HasValue && minVal.Value < 100 && maxVal.HasValue)
                {
                    if (Regex.IsMatch(maxStr, @"\bxi\b"))
                        minVal = minVal.Value * 100_000m;
                    else if (maxVal.Value >= 500_000m)
                        minVal = minVal.Value * 1_000_000m;
                }

                if (minVal.HasValue && maxVal.HasValue && minVal >= 100_000m && maxVal >= 100_000m)
                {
                    if (minVal > maxVal) (minVal, maxVal) = (maxVal, minVal);
                    criteria.GiaMin = minVal;
                    criteria.GiaMax = maxVal;
                    return;
                }
            }

            var priceMatches = Regex.Matches(
                norm,
                @"(?:(duoi|toi\s*da|khong\s*qua|nho\s*hon|re\s*hon|<=|<|tren|toi\s*thieu|tu|lon\s*hon|>=|>|hon|khoang|tam|chung|gia)\s*)?(\d+(?:[.,]\d+)?\s*(?:tr|trieu|cu|chai|dong|m)(?!\s*(?:2|et))(?:\s*(?:ruoi|\d{1,3}))?|\d+(?:[.,]\d+)?\s*(?:xi|k)|\d{1,2}(?:[.,]\d{3}){2}|\d{6,8})\b(?:\s*(quay\s*dau|tro\s*xuong|tro\s*lai|do\s*lai|tro\s*len))?");

            foreach (Match m in priceMatches)
            {
                var prefix = m.Groups[1].Value.Trim();
                var rawAmount = m.Groups[2].Value.Trim();
                var suffix = m.Groups[3].Value.Trim();
                var amount = ParseVietnameseMoney(rawAmount);
                if (!amount.HasValue || amount.Value < 100_000m || amount.Value > 100_000_000m) continue;

                if (suffix == "tro len" || prefix is "tren" or "toi thieu" or "tu" or "lon hon" or "hon" or ">=" or ">")
                {
                    criteria.GiaMin = amount.Value;
                }
                else if (suffix is "quay dau" or "tro xuong" or "tro lai" or "do lai" ||
                         prefix is "duoi" or "toi da" or "khong qua" or "nho hon" or "re hon" or "<=" or "<")
                {
                    criteria.GiaMax = amount.Value;
                }
                else if (prefix is "khoang" or "tam" or "chung")
                {
                    criteria.GiaMin = Math.Max(0m, amount.Value - 500_000m);
                    criteria.GiaMax = amount.Value + 500_000m;
                }
                else
                {
                    criteria.GiaMax = amount.Value;
                }
            }

            // Tính từ mô tả giá rẻ mơ hồ: "rẻ", "giá mềm", "hạt dẻ", "sinh viên nghèo", "bình dân"
            // -> GiaMax = 2.500.000 và SapXep = "gia_tang" (trừ khi người dùng chỉ nói "rẻ nhất" để so sánh hoặc đã chọn sort khác).
            if (!criteria.GiaMin.HasValue && !criteria.GiaMax.HasValue &&
                Regex.IsMatch(norm, @"\b(gia\s*re|gia\s*mem|hat\s*de|binh\s*dan|sinh\s*vien\s*ngheo|tiet\s*kiem|beo|re)\b") &&
                !Regex.IsMatch(norm, @"\b(re\s*nhat|tiet\s*kiem\s*nhat|beo\s*nhat)\b"))
            {
                criteria.GiaMax = 2_500_000m;
                if (criteria.SapXep == "mac_dinh")
                {
                    criteria.SapXep = "gia_tang";
                }
            }
        }

        private static decimal? ParseVietnameseMoney(string raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return null;
            var s = raw.Trim();

            var splitUnit = Regex.Match(s, @"^(\d+(?:[.,]\d+)?)\s*(tr|trieu|cu|chai|dong|m)(?:\s*(ruoi|\d{1,3}))?$");
            if (splitUnit.Success)
            {
                if (!decimal.TryParse(splitUnit.Groups[1].Value.Replace(',', '.'), NumberStyles.Any, CultureInfo.InvariantCulture, out var baseNum))
                    return null;

                var extra = splitUnit.Groups[3].Value;
                if (extra == "ruoi")
                {
                    baseNum += 0.5m;
                }
                else if (!string.IsNullOrEmpty(extra) && decimal.TryParse(extra, NumberStyles.Any, CultureInfo.InvariantCulture, out var extraNum))
                {
                    var divisor = extra.Length == 1 ? 10m : (decimal)Math.Pow(10, extra.Length);
                    baseNum += extraNum / divisor;
                }

                return Math.Round(baseNum * 1_000_000m);
            }

            var xiMatch = Regex.Match(s, @"^(\d+(?:[.,]\d+)?)\s*xi$");
            if (xiMatch.Success &&
                decimal.TryParse(xiMatch.Groups[1].Value.Replace(',', '.'), NumberStyles.Any, CultureInfo.InvariantCulture, out var xiVal))
            {
                return Math.Round(xiVal * 100_000m);
            }

            var kMatch = Regex.Match(s, @"^(\d+(?:[.,]\d+)?)\s*k$");
            if (kMatch.Success &&
                decimal.TryParse(kMatch.Groups[1].Value.Replace(',', '.'), NumberStyles.Any, CultureInfo.InvariantCulture, out var kVal))
            {
                return Math.Round(kVal * 1_000m);
            }

            var digits = Regex.Replace(s, @"[.,\s]", "");
            if (decimal.TryParse(digits, NumberStyles.Any, CultureInfo.InvariantCulture, out var plain))
            {
                return plain;
            }

            return null;
        }

        private static void NormalizeCriteria(AiCriteria c)
        {
            if (!c.LaYeuCauHopLe)
            {
                c.KhuVuc.Clear();
                c.GiaMin = null;
                c.GiaMax = null;
                c.DienTichMin = null;
                c.LoaiHinh = null;
                c.CoNhaVeSinh = null;
                c.CoBanCong = null;
                c.CoMayLanh = null;
                c.CoGacLung = null;
                c.CoChoDeXe = null;
                c.SapXep = "mac_dinh";
                c.TuKhoa = null;
                return;
            }

            c.KhuVuc = NormalizeAreas(c.KhuVuc);

            if (c.GiaMin.HasValue)
            {
                if (c.GiaMin.Value > 0 && c.GiaMin.Value < 1000m)
                    c.GiaMin = c.GiaMin.Value * 1_000_000m;
                else if (c.GiaMin.Value >= 1000m && c.GiaMin.Value < 50_000m)
                    c.GiaMin = c.GiaMin.Value * 1_000m;
            }

            if (c.GiaMax.HasValue)
            {
                if (c.GiaMax.Value > 0 && c.GiaMax.Value < 1000m)
                    c.GiaMax = c.GiaMax.Value * 1_000_000m;
                else if (c.GiaMax.Value >= 1000m && c.GiaMax.Value < 50_000m)
                    c.GiaMax = c.GiaMax.Value * 1_000m;
            }

            if (c.GiaMin.HasValue && c.GiaMax.HasValue && c.GiaMin > c.GiaMax)
            {
                (c.GiaMin, c.GiaMax) = (c.GiaMax, c.GiaMin);
            }

            if (!string.IsNullOrWhiteSpace(c.LoaiHinh))
            {
                var lhNorm = NormalizeText(c.LoaiHinh);
                if (lhNorm.Contains("ky tuc") || lhNorm.Contains("ktx"))
                    c.LoaiHinh = nameof(LoaiHinhPhong.KyTucXa);
                else if (lhNorm.Contains("phong rieng") || lhNorm.Contains("phongrieng"))
                    c.LoaiHinh = nameof(LoaiHinhPhong.PhongRieng);
                else if (!Enum.TryParse<LoaiHinhPhong>(c.LoaiHinh, true, out _))
                    c.LoaiHinh = null;
            }

            var sapXepNorm = NormalizeText(c.SapXep ?? "").Replace(" ", "_");
            c.SapXep = sapXepNorm switch
            {
                "gia_giam" => "gia_giam",
                "gia_tang" => "gia_tang",
                "moi_nhat" => "moi_nhat",
                _ => "mac_dinh"
            };

            var khuVucNorms = c.KhuVuc.Select(NormalizeText).Where(x => !string.IsNullOrEmpty(x)).ToList();
            var redundant = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
            {
                "phong", "phong tro", "nha tro", "tro", "gia re", "sinh vien",
                "ve sinh rieng", "nha ve sinh", "ban cong", "may lanh", "dieu hoa",
                "gac lung", "cho de xe", "de xe", "gui xe", "ky tuc xa", "phong rieng",
                "hutech", "kcnc", "td", "bt", "gv", "q9"
            };

            var cleanKeywords = SplitKeywords(c.TuKhoa)
                .Where(k =>
                {
                    var kn = NormalizeText(k);
                    if (kn.Length < 2) return false;
                    if (redundant.Contains(kn)) return false;
                    if (khuVucNorms.Any(kv => kn == kv || kv.Contains(kn))) return false;
                    return true;
                })
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Take(5)
                .ToList();

            c.TuKhoa = cleanKeywords.Count > 0 ? string.Join(", ", cleanKeywords) : null;
        }

        private static List<string> NormalizeAreas(IEnumerable<string> areas)
        {
            var result = new List<string>();
            void AddUnique(string val)
            {
                if (!string.IsNullOrWhiteSpace(val) &&
                    !result.Any(x => x.Equals(val, StringComparison.OrdinalIgnoreCase)))
                {
                    result.Add(val);
                }
            }

            foreach (var raw in areas)
            {
                if (string.IsNullOrWhiteSpace(raw)) continue;
                var norm = NormalizeText(raw);
                if (norm == "hutech")
                {
                    AddUnique("Bình Thạnh");
                    AddUnique("Thủ Đức");
                    AddUnique("Quận 9");
                    continue;
                }
                if (norm is "td" or "thu duc") { AddUnique("Thủ Đức"); continue; }
                if (norm is "bt" or "binh thanh") { AddUnique("Bình Thạnh"); continue; }
                if (norm is "gv" or "go vap") { AddUnique("Gò Vấp"); continue; }
                if (norm is "kcnc" or "khu cong nghe cao") { AddUnique("Khu Công Nghệ Cao"); continue; }

                var qMatch = Regex.Match(norm, @"^(?:quan|q)\s*(\d{1,2})$");
                if (qMatch.Success)
                {
                    AddUnique($"Quận {qMatch.Groups[1].Value}");
                    continue;
                }

                AddUnique(raw.Trim());
            }

            return result;
        }

        private static List<string> BuildCriteriaChips(AiCriteria c, bool daNoiLong = false)
        {
            var chips = new List<string>();

            if (c.KhuVuc.Count > 0)
                chips.Add($"Khu vực: {string.Join(", ", c.KhuVuc)}");

            if (c.GiaMin.HasValue && c.GiaMax.HasValue)
                chips.Add($"Giá: {FormatVnd(c.GiaMin.Value)} - {FormatVnd(c.GiaMax.Value)}");
            else if (c.GiaMax.HasValue)
                chips.Add($"Giá ≤ {FormatVnd(c.GiaMax.Value)}");
            else if (c.GiaMin.HasValue)
                chips.Add($"Giá ≥ {FormatVnd(c.GiaMin.Value)}");

            if (c.DienTichMin.HasValue && c.DienTichMin.Value > 0)
                chips.Add($"Diện tích ≥ {c.DienTichMin.Value:0.##} m²");

            if (c.LoaiHinh == nameof(LoaiHinhPhong.KyTucXa))
                chips.Add("Loại: Ký túc xá");
            else if (c.LoaiHinh == nameof(LoaiHinhPhong.PhongRieng))
                chips.Add("Loại: Phòng riêng");

            if (c.CoNhaVeSinh == true) chips.Add("Vệ sinh riêng");
            if (c.CoBanCong == true) chips.Add("Có ban công");
            if (c.CoMayLanh == true) chips.Add("Máy lạnh");
            if (c.CoGacLung == true) chips.Add("Gác lửng");
            if (c.CoChoDeXe == true) chips.Add("Chỗ để xe");

            if (c.SapXep == "gia_giam") chips.Add("Sắp xếp: Giá cao → thấp");
            else if (c.SapXep == "gia_tang") chips.Add("Sắp xếp: Giá thấp → cao");
            else if (c.SapXep == "moi_nhat") chips.Add("Sắp xếp: Mới nhất");

            foreach (var tk in SplitKeywords(c.TuKhoa))
                chips.Add($"Từ khóa: {tk}");

            if (chips.Count == 0 && c.GeminiCacTieuChi.Count > 0)
            {
                chips.AddRange(c.GeminiCacTieuChi.Where(x => !string.IsNullOrWhiteSpace(x)).Distinct().Take(6));
            }

            if (daNoiLong && !chips.Contains("Đã nới lỏng tiêu chí"))
            {
                chips.Add("Đã nới lỏng tiêu chí");
            }

            return chips;
        }

        private async Task<(List<RoomMatch> Matches, List<string> CacTieuChi, string ThongBao)> QueryRoomsAsync(
            AiCriteria c,
            string rawQuery)
        {
            var now = DateTime.Now;
            var allAvailable = await _db.PhongTro
                .Include(p => p.ChuTro)
                .AsNoTracking()
                .Where(p => p.DaChoThue == false)
                .ToListAsync();

            allAvailable = allAvailable
                .Where(p => !p.NgayHetHan.HasValue || p.NgayHetHan.Value >= now)
                .ToList();

            var matchedSchools = FindMatchedSchools(c.KhuVuc, c.TuKhoa, rawQuery);

            // Tầng 1: Mô tả vô nghĩa hoặc ngoài lề thuê trọ -> gợi ý mặc định chống trắng màn hình
            if (!c.LaYeuCauHopLe)
            {
                var suggested = SortRooms(allAvailable, "mac_dinh").Take(6).ToList();
                var tier1Matches = await BuildRoomMatchesAsync(suggested, matchedSchools);
                return (tier1Matches, new List<string> { "Gợi ý phòng nổi bật" }, ThongBaoKhongHopLe);
            }

            // Tầng 2: Lọc chính xác theo toàn bộ tiêu chí và sắp xếp đúng SapXep
            var exactRooms = FilterRoomsExact(allAvailable, c, matchedSchools);
            if (exactRooms.Count > 0)
            {
                var sortedExact = SortRooms(exactRooms, c.SapXep);
                var tier2Matches = await BuildRoomMatchesAsync(sortedExact, matchedSchools);
                var chips = BuildCriteriaChips(c);
                var thongBao = $"Tìm thấy {tier2Matches.Count} phòng phù hợp với mô tả của bạn.";
                return (tier2Matches, chips, thongBao);
            }

            // Tầng 3: Nới lỏng thông minh khi Tầng 2 ra 0 kết quả
            var relaxedRooms = FilterRoomsRelaxed(allAvailable, c, matchedSchools);
            var sortedRelaxed = SortRelaxedRooms(relaxedRooms, c).Take(6).ToList();
            var tier3Matches = await BuildRoomMatchesAsync(sortedRelaxed, matchedSchools);
            var tier3Chips = BuildCriteriaChips(c, daNoiLong: true);
            var tier3ThongBao = tier3Matches.Count > 0
                ? ThongBaoNoiLong
                : "Hiện hệ thống chưa có phòng trọ nào đang mở cho thuê.";

            return (tier3Matches, tier3Chips, tier3ThongBao);
        }

        private static List<PhongTro> FilterRoomsExact(
            List<PhongTro> rooms,
            AiCriteria c,
            MatchedSchoolGroup matchedSchools)
        {
            var hasLoaiHinh = Enum.TryParse<LoaiHinhPhong>(c.LoaiHinh, ignoreCase: true, out var loaiHinhPhong);
            var keywords = SplitKeywords(c.TuKhoa);
            var filtered = new List<PhongTro>();

            foreach (var p in rooms)
            {
                if (c.GiaMin.HasValue && p.Gia < c.GiaMin.Value)
                    continue;

                if (c.GiaMax.HasValue && p.Gia > c.GiaMax.Value)
                    continue;

                if (hasLoaiHinh && p.LoaiHinh != loaiHinhPhong)
                    continue;

                if (c.DienTichMin.HasValue && c.DienTichMin.Value > 0)
                {
                    if (!p.ChieuDai.HasValue || !p.ChieuRong.HasValue ||
                        (p.ChieuDai.Value * p.ChieuRong.Value) < c.DienTichMin.Value)
                    {
                        continue;
                    }
                }

                if (c.CoNhaVeSinh == true && !p.CoNhaVeSinh)
                    continue;

                if (c.CoBanCong == true && !p.CoBanCong)
                    continue;

                var diaChiNorm = NormalizeText(p.DiaChi);
                var moTaNorm = NormalizeText(p.MoTa);
                var combinedNorm = $"{diaChiNorm} {moTaNorm}";

                if (!MatchesArea(c.KhuVuc, diaChiNorm, moTaNorm, p, matchedSchools))
                    continue;

                if (c.CoMayLanh == true &&
                    !ContainsAny(moTaNorm, "may lanh", "dieu hoa", "inverter"))
                    continue;

                if (c.CoGacLung == true &&
                    !ContainsAny(moTaNorm, "gac lung", "co gac", "gac xep") &&
                    !Regex.IsMatch(moTaNorm, @"\bgac\b"))
                    continue;

                if (c.CoChoDeXe == true &&
                    !ContainsAny(moTaNorm, "de xe", "gui xe", "bai xe", "nha xe", "ham xe", "cho xe"))
                    continue;

                if (!MatchesKeywords(keywords, combinedNorm, p, matchedSchools))
                    continue;

                filtered.Add(p);
            }

            return filtered;
        }

        private static List<PhongTro> FilterRoomsRelaxed(
            List<PhongTro> rooms,
            AiCriteria c,
            MatchedSchoolGroup matchedSchools)
        {
            var hasArea = c.KhuVuc.Count > 0;
            var hasLoaiHinh = Enum.TryParse<LoaiHinhPhong>(c.LoaiHinh, ignoreCase: true, out var loaiHinhPhong);

            // Bước 3a: Giữ cả KhuVuc và LoaiHinh, bỏ các ràng buộc giá/diện tích/tiện ích/từ khóa chặt
            if (hasArea && hasLoaiHinh)
            {
                var byAreaAndType = rooms.Where(p =>
                    p.LoaiHinh == loaiHinhPhong &&
                    MatchesArea(c.KhuVuc, NormalizeText(p.DiaChi), NormalizeText(p.MoTa), p, matchedSchools)).ToList();
                if (byAreaAndType.Count > 0) return byAreaAndType;
            }

            // Bước 3b: Chỉ giữ KhuVuc
            if (hasArea)
            {
                var byArea = rooms.Where(p =>
                    MatchesArea(c.KhuVuc, NormalizeText(p.DiaChi), NormalizeText(p.MoTa), p, matchedSchools)).ToList();
                if (byArea.Count > 0) return byArea;
            }

            // Bước 3c: Chỉ giữ LoaiHinh
            if (hasLoaiHinh)
            {
                var byType = rooms.Where(p => p.LoaiHinh == loaiHinhPhong).ToList();
                if (byType.Count > 0) return byType;
            }

            // Bước 3d: Trả toàn bộ phòng khả dụng để chọn top 6 gần nhất
            return rooms;
        }

        private static List<PhongTro> SortRooms(List<PhongTro> rooms, string sapXep)
        {
            return sapXep switch
            {
                "gia_giam" => rooms.OrderByDescending(p => p.Gia).ThenByDescending(p => p.IsVip).ThenByDescending(p => p.Id).ToList(),
                "gia_tang" => rooms.OrderBy(p => p.Gia).ThenByDescending(p => p.IsVip).ThenByDescending(p => p.Id).ToList(),
                "moi_nhat" => rooms.OrderByDescending(p => p.Id).ToList(),
                _ => rooms.OrderByDescending(p => p.IsVip).ThenByDescending(p => p.Id).ToList()
            };
        }

        private static List<PhongTro> SortRelaxedRooms(List<PhongTro> rooms, AiCriteria c)
        {
            if (c.SapXep != "mac_dinh")
                return SortRooms(rooms, c.SapXep);

            if (c.GiaMax.HasValue)
            {
                return rooms
                    .OrderBy(p => Math.Abs(p.Gia - c.GiaMax.Value))
                    .ThenByDescending(p => p.IsVip)
                    .ThenByDescending(p => p.Id)
                    .ToList();
            }

            return SortRooms(rooms, "mac_dinh");
        }

        private async Task<List<RoomMatch>> BuildRoomMatchesAsync(
            List<PhongTro> rooms,
            MatchedSchoolGroup matchedSchools)
        {
            var ids = rooms.Select(p => p.Id).ToList();
            var sao = ids.Count == 0
                ? new Dictionary<int, (double Avg, int Count)>()
                : await _db.DanhGias
                    .Where(d => ids.Contains(d.PhongTroId))
                    .GroupBy(d => d.PhongTroId)
                    .Select(g => new { g.Key, Avg = g.Average(d => d.Sao), Count = g.Count() })
                    .ToDictionaryAsync(x => x.Key, x => (x.Avg, x.Count));

            return rooms.Select(p =>
            {
                var (avg, count) = sao.TryGetValue(p.Id, out var v) ? v : (0d, 0);
                var dist = 0d;
                if (matchedSchools.Schools.Count > 0 && p.Latitude.HasValue && p.Longitude.HasValue)
                {
                    dist = matchedSchools.Schools.Min(s =>
                        TruongData.HaversineKm(s.Latitude, s.Longitude, p.Latitude.Value, p.Longitude.Value));
                }
                return new RoomMatch(p, dist, avg, count);
            }).ToList();
        }

        private static bool MatchesArea(
            List<string> khuVucs,
            string diaChiNorm,
            string moTaNorm,
            PhongTro room,
            MatchedSchoolGroup matchedSchools)
        {
            if (khuVucs.Count == 0) return true;

            foreach (var khuVuc in khuVucs)
            {
                if (MatchesSingleArea(khuVuc, diaChiNorm, moTaNorm, room, matchedSchools))
                    return true;
            }

            return false;
        }

        private static bool MatchesSingleArea(
            string khuVuc,
            string diaChiNorm,
            string moTaNorm,
            PhongTro room,
            MatchedSchoolGroup matchedSchools)
        {
            if (string.IsNullOrWhiteSpace(khuVuc)) return true;

            var kvNorm = NormalizeText(khuVuc);
            var variants = new HashSet<string>(StringComparer.Ordinal) { kvNorm };

            var qMatch = Regex.Match(kvNorm, @"^(?:quan|q)\s*(\d{1,2})$");
            if (qMatch.Success)
            {
                var so = qMatch.Groups[1].Value;
                variants.Add($"quan {so}");
                variants.Add($"q{so}");
                variants.Add($"q {so}");
            }

            if (kvNorm.Contains("khu cong nghe cao") || kvNorm == "kcnc")
            {
                variants.Add("khu cong nghe cao");
                variants.Add("kcnc");
                variants.Add("duong d1");
                variants.Add("hiep phu");
                variants.Add("tang nhon phu");
            }
            else if (kvNorm.Contains("quan 9") || kvNorm == "q9")
            {
                variants.Add("quan 9");
                variants.Add("q9");
                variants.Add("khu cong nghe cao");
                variants.Add("hiep phu");
                variants.Add("tang nhon phu");
                variants.Add("duong d1");
            }
            else if (kvNorm.Contains("thu duc") || kvNorm.Contains("quan 2"))
            {
                variants.Add("thu duc");
                variants.Add("quan 9");
                variants.Add("q9");
                variants.Add("linh trung");
                variants.Add("linh chieu");
                variants.Add("linh tay");
                variants.Add("truong tho");
                variants.Add("hiep phu");
                variants.Add("hiep binh");
                variants.Add("tang nhon phu");
                variants.Add("vo van ngan");
                variants.Add("hoang dieu 2");
                variants.Add("khu cong nghe cao");
                variants.Add("cho thu duc");
                variants.Add("kha van can");
            }

            if (variants.Any(v => ContainsWholePhrase(diaChiNorm, v) || ContainsWholePhrase(moTaNorm, v)))
                return true;

            if (matchedSchools.Schools.Count > 0 && room.Latitude.HasValue && room.Longitude.HasValue)
            {
                // Chỉ xét khoảng cách theo các cơ sở trường có quận khớp với khuVuc đang kiểm tra (nếu trường có nhiều cơ sở).
                var scopedSchools = matchedSchools.Schools
                    .Where(s =>
                    {
                        var sq = NormalizeText(s.Quan);
                        return sq == kvNorm || variants.Any(v => sq.Contains(v) || v.Contains(sq));
                    })
                    .ToList();

                var schoolsToCheck = scopedSchools.Count > 0 ? scopedSchools : matchedSchools.Schools;
                if (schoolsToCheck.Any(s =>
                    TruongData.HaversineKm(s.Latitude, s.Longitude, room.Latitude.Value, room.Longitude.Value) <= 5.0))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool MatchesKeywords(
            List<string> tuKhoa,
            string combinedNorm,
            PhongTro room,
            MatchedSchoolGroup matchedSchools)
        {
            foreach (var rawKw in tuKhoa)
            {
                var kwNorm = NormalizeText(rawKw);
                if (string.IsNullOrEmpty(kwNorm)) continue;

                if (ContainsWholePhrase(combinedNorm, kwNorm)) continue;

                // Tránh trùng chữ "cho" (cho thuê/sinh viên) với "chợ" khi người dùng tìm "gần chợ".
                if (kwNorm is "gan cho" or "cho")
                {
                    var hasCho =
                        (room.DiaChi?.Contains("chợ", StringComparison.OrdinalIgnoreCase) ?? false) ||
                        (room.MoTa?.Contains("chợ", StringComparison.OrdinalIgnoreCase) ?? false);
                    if (hasCho) continue;
                }

                var isSchoolKw = matchedSchools.MatchedKeywords.Any(k => kwNorm.Contains(k) || k.Contains(kwNorm));
                if (isSchoolKw)
                {
                    if (matchedSchools.AreaAliases.Any(alias => ContainsWholePhrase(combinedNorm, alias)))
                        continue;

                    if (room.Latitude.HasValue && room.Longitude.HasValue &&
                        matchedSchools.Schools.Any(s =>
                            TruongData.HaversineKm(s.Latitude, s.Longitude, room.Latitude.Value, room.Longitude.Value) <= 5.0))
                        continue;
                }

                return false;
            }
            return true;
        }

        private static MatchedSchoolGroup FindMatchedSchools(List<string> khuVuc, string? tuKhoa, string rawQuery)
        {
            var probe = NormalizeText($"{string.Join(" ", khuVuc)} {tuKhoa} {rawQuery}");
            var allSchools = TruongData.GetAll();

            var schools = new List<TruongDaiHoc>();
            var aliases = new HashSet<string>(StringComparer.Ordinal);
            var keywords = new HashSet<string>(StringComparer.Ordinal);

            foreach (var (kw, schoolIds, _, areaAliases) in TruongMappings)
            {
                if (ContainsWholePhrase(probe, kw))
                {
                    keywords.Add(kw);
                    foreach (var id in schoolIds)
                    {
                        var found = allSchools.FirstOrDefault(t => t.Id == id);
                        if (found != null && schools.All(s => s.Id != found.Id))
                        {
                            schools.Add(found);
                        }
                    }
                    foreach (var a in areaAliases) aliases.Add(a);
                }
            }

            return new MatchedSchoolGroup(schools, aliases, keywords);
        }

        private static List<string> SplitKeywords(string? tuKhoa)
        {
            if (string.IsNullOrWhiteSpace(tuKhoa)) return new List<string>();
            return tuKhoa
                .Split(new[] { ',', ';', '\n' }, StringSplitOptions.RemoveEmptyEntries)
                .Select(k => k.Trim())
                .Where(k => !string.IsNullOrWhiteSpace(k))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();
        }

        private static bool ContainsAny(string haystackNorm, params string[] needles)
            => needles.Any(n => ContainsWholePhrase(haystackNorm, n));

        private static bool ContainsWholePhrase(string haystackNorm, string needleNorm)
        {
            if (string.IsNullOrEmpty(haystackNorm) || string.IsNullOrEmpty(needleNorm)) return false;
            return Regex.IsMatch(haystackNorm, $@"(?<![a-z0-9]){Regex.Escape(needleNorm)}(?![a-z0-9])");
        }

        internal static string NormalizeText(string? input)
        {
            if (string.IsNullOrWhiteSpace(input)) return "";
            var normalized = input.Normalize(NormalizationForm.FormD);
            var sb = new StringBuilder(normalized.Length);
            foreach (var ch in normalized)
            {
                if (CharUnicodeInfo.GetUnicodeCategory(ch) == UnicodeCategory.NonSpacingMark) continue;
                sb.Append(ch switch
                {
                    'đ' => 'd',
                    'Đ' => 'd',
                    '²' => '2',
                    '.' or ',' or ';' or ':' or '/' or '\\' or '(' or ')' or '[' or ']' => ' ',
                    _ => char.ToLowerInvariant(ch)
                });
            }
            return Regex.Replace(sb.ToString(), @"\s+", " ").Trim();
        }

        private static string FormatVnd(decimal amount) => $"{amount.ToString("N0", ViCulture)}đ";

        private static string? GetString(JsonElement obj, string prop)
        {
            if (!obj.TryGetProperty(prop, out var el) || el.ValueKind != JsonValueKind.String) return null;
            var s = el.GetString()?.Trim();
            return string.IsNullOrWhiteSpace(s) ? null : s;
        }

        private static decimal? GetDecimal(JsonElement obj, string prop)
        {
            if (!obj.TryGetProperty(prop, out var el) || el.ValueKind == JsonValueKind.Null) return null;
            if (el.ValueKind == JsonValueKind.Number && el.TryGetDecimal(out var num)) return num;
            if (el.ValueKind == JsonValueKind.String &&
                decimal.TryParse(el.GetString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed))
                return parsed;
            return null;
        }

        private static double? GetDouble(JsonElement obj, string prop)
        {
            if (!obj.TryGetProperty(prop, out var el) || el.ValueKind == JsonValueKind.Null) return null;
            if (el.ValueKind == JsonValueKind.Number && el.TryGetDouble(out var num)) return num;
            if (el.ValueKind == JsonValueKind.String &&
                double.TryParse(el.GetString(), NumberStyles.Any, CultureInfo.InvariantCulture, out var parsed))
                return parsed;
            return null;
        }

        private static bool? GetBool(JsonElement obj, string prop)
        {
            if (!obj.TryGetProperty(prop, out var el)) return null;
            return el.ValueKind switch
            {
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                _ => null
            };
        }

        private static List<string> GetStringOrList(JsonElement obj, string prop)
        {
            if (!obj.TryGetProperty(prop, out var el)) return new List<string>();
            if (el.ValueKind == JsonValueKind.Array) return GetStringList(obj, prop);
            if (el.ValueKind == JsonValueKind.String)
            {
                var s = el.GetString()?.Trim();
                if (!string.IsNullOrWhiteSpace(s))
                {
                    return s.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
                        .Select(x => x.Trim())
                        .Where(x => !string.IsNullOrWhiteSpace(x))
                        .ToList();
                }
            }
            return new List<string>();
        }

        private static string? GetJoinedKeywords(JsonElement obj, string prop)
        {
            if (!obj.TryGetProperty(prop, out var el)) return null;
            if (el.ValueKind == JsonValueKind.String)
            {
                var s = el.GetString()?.Trim();
                return string.IsNullOrWhiteSpace(s) ? null : s;
            }
            if (el.ValueKind == JsonValueKind.Array)
            {
                var list = GetStringList(obj, prop);
                return list.Count > 0 ? string.Join(", ", list) : null;
            }
            return null;
        }

        private static List<string> GetStringList(JsonElement obj, string prop)
        {
            if (!obj.TryGetProperty(prop, out var el) || el.ValueKind != JsonValueKind.Array) return new List<string>();
            var list = new List<string>();
            foreach (var item in el.EnumerateArray())
            {
                if (item.ValueKind == JsonValueKind.String)
                {
                    var s = item.GetString()?.Trim();
                    if (!string.IsNullOrWhiteSpace(s)) list.Add(s);
                }
            }
            return list;
        }

        private sealed record MatchedSchoolGroup(
            List<TruongDaiHoc> Schools,
            HashSet<string> AreaAliases,
            HashSet<string> MatchedKeywords);

        internal sealed class AiCriteria
        {
            public bool LaYeuCauHopLe { get; set; } = true;
            public List<string> KhuVuc { get; set; } = new();
            public decimal? GiaMin { get; set; }
            public decimal? GiaMax { get; set; }
            public double? DienTichMin { get; set; }
            public string? LoaiHinh { get; set; }
            public bool? CoNhaVeSinh { get; set; }
            public bool? CoBanCong { get; set; }
            public bool? CoMayLanh { get; set; }
            public bool? CoGacLung { get; set; }
            public bool? CoChoDeXe { get; set; }
            public string SapXep { get; set; } = "mac_dinh";
            public string? TuKhoa { get; set; }
            public List<string> GeminiCacTieuChi { get; set; } = new();
        }
    }
}

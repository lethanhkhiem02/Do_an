using System.Globalization;
using System.Text;
using System.Text.Json;
using Do_an_co_so.Models;

namespace Do_an_co_so.Services
{
    // Quét tiện ích xung quanh một tọa độ bằng Overpass API (dữ liệu OpenStreetMap).
    //
    // Chọn Overpass vì app vốn vẽ bản đồ bằng tile OSM, nên tiện ích lấy từ OSM là
    // khớp nhau tuyệt đối và không cần API key như Google Places.
    //
    // Mọi lỗi mạng/parse đều trả danh sách rỗng chứ không ném exception: chủ trọ
    // vẫn đăng được phòng bình thường khi Overpass đang bảo trì.
    public class TienIchQuetService
    {
        public const int BanKinhMacDinhMet = 1000;
        private const int SoLuongToiDaMotNhom = 8;

        // Overpass có nhiều mirror công cộng; hết cái này thì thử cái kế tiếp.
        private static readonly string[] MayChu =
        {
            "https://overpass-api.de/api/interpreter",
            "https://overpass.kumi.systems/api/interpreter"
        };

        private readonly IHttpClientFactory _httpFactory;
        private readonly ILogger<TienIchQuetService> _logger;

        public TienIchQuetService(IHttpClientFactory httpFactory, ILogger<TienIchQuetService> logger)
        {
            _httpFactory = httpFactory;
            _logger = logger;
        }

        /// <summary>
        /// Trả tiện ích gần (viDo, kinhDo), đã sắp theo khoảng cách và cắt còn
        /// 8 phần tử mỗi nhóm. Rỗng khi không quét được.
        /// </summary>
        public async Task<List<TienIchXungQuanh>> QuetAsync(double viDo, double kinhDo,
            int banKinhMet = BanKinhMacDinhMet)
        {
            var query = TaoTruyVan(viDo, kinhDo, banKinhMet);

            foreach (var mayChu in MayChu)
            {
                try
                {
                    var client = _httpFactory.CreateClient("overpass");
                    using var noiDung = new FormUrlEncodedContent(new[]
                    {
                        new KeyValuePair<string, string>("data", query)
                    });

                    using var resp = await client.PostAsync(mayChu, noiDung);
                    if (!resp.IsSuccessStatusCode)
                    {
                        _logger.LogWarning("Overpass {MayChu} trả {MaThongBao}", mayChu, (int)resp.StatusCode);
                        continue;
                    }

                    await using var stream = await resp.Content.ReadAsStreamAsync();
                    using var root = await JsonDocument.ParseAsync(stream);
                    var ketQua = ChuanHoa(root, viDo, kinhDo);
                    if (ketQua.Count > 0) return ketQua;
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Quét tiện ích qua Overpass thất bại");
                }
            }

            return new List<TienIchXungQuanh>();
        }

        private static string TaoTruyVan(double viDo, double kinhDo, int banKinhMet)
        {
            var tam = $"{viDo.ToString("0.0000000", CultureInfo.InvariantCulture)},{kinhDo.ToString("0.0000000", CultureInfo.InvariantCulture)}";
            var sb = new StringBuilder();
            sb.Append("[out:json][timeout:25];\n(\n");
            foreach (var loc in CacBoLoc)
                sb.Append($"  nwr[{loc}](around:{banKinhMet},{tam});\n");
            sb.Append(");\nout center;");
            return sb.ToString();
        }

        // Bộ lọc Overpass, mỗi bộ tương ứng một nhóm tiện ích hiển thị trong app.
        private static readonly string[] CacBoLoc =
        {
            "\"amenity\"=\"bus_station\"", "\"highway\"=\"bus_stop\"",
            "\"shop\"=\"supermarket\"", "\"amenity\"=\"marketplace\"",
            "\"amenity\"=\"cafe\"",
            "\"amenity\"=\"fuel\"",
            "\"shop\"=\"convenience\"", "\"shop\"=\"kiosk\""
        };

        private static List<TienIchXungQuanh> ChuanHoa(JsonDocument root, double viDo, double kinhDo)
        {
            var ketQua = new List<TienIchXungQuanh>();

            if (!root.RootElement.TryGetProperty("elements", out var elements)) return ketQua;

            foreach (var e in elements.EnumerateArray())
            {
                if (!e.TryGetProperty("tags", out var tags)) continue;
                var loai = PhanLoai(tags);
                if (loai == null) continue;

                // Node có lat/lon sẵn; way và relation chỉ có tọa độ sau "out center".
                if (!LayDoDo(e, "lat", out var vi) || !LayDoDo(e, "lon", out var kinh)) continue;

                ketQua.Add(new TienIchXungQuanh
                {
                    Loai = loai,
                    Ten = tags.TryGetProperty("name", out var ten) ? CắtChuoi(ten.GetString(), 200) : null,
                    ViDo = vi,
                    KinhDo = kinh,
                    KhoangCachMet = (int)Math.Round(TruongData.HaversineKm(viDo, kinhDo, vi, kinh) * 1000),
                    QuetNgay = DateTime.Now
                });
            }

            // Cắt theo từng nhóm: giữ 8 nơi gần nhất của mỗi loại, không phải 8 nơi
            // gần nhất toàn bộ, nếu không nhóm cafe đông đúc sẽ nuốt hết các nhóm khác.
            return ketQua
                .GroupBy(t => t.Loai)
                .SelectMany(g => g.OrderBy(t => t.KhoangCachMet).Take(SoLuongToiDaMotNhom))
                .OrderBy(t => t.Loai).ThenBy(t => t.KhoangCachMet)
                .ToList();
        }

        private static string? PhanLoai(JsonElement tags)
        {
            var amenity = GiaTriTag(tags, "amenity");
            var shop = GiaTriTag(tags, "shop");
            var highway = GiaTriTag(tags, "highway");

            if (amenity == "bus_station" || highway == "bus_stop") return "bus_stop";
            if (shop == "supermarket" || amenity == "marketplace") return "supermarket";
            if (amenity == "cafe") return "cafe";
            if (amenity == "fuel") return "fuel";
            if (shop == "convenience" || shop == "kiosk") return "convenience";
            return null;
        }

        private static string? GiaTriTag(JsonElement tags, string key) =>
            tags.TryGetProperty(key, out var v) && v.ValueKind == JsonValueKind.String
                ? v.GetString()
                : null;

        private static bool LayDoDo(JsonElement e, string key, out double value)
        {
            if (e.TryGetProperty(key, out var trucTiep) && trucTiep.ValueKind == JsonValueKind.Number)
            {
                value = trucTiep.GetDouble();
                return true;
            }

            if (e.TryGetProperty("center", out var center) && center.TryGetProperty(key, out var trongTam))
            {
                value = trongTam.GetDouble();
                return true;
            }

            value = 0;
            return false;
        }

        private static string? CắtChuoi(string? giaTri, int toiDa)
        {
            if (string.IsNullOrWhiteSpace(giaTri)) return null;
            var tam = giaTri.Trim();
            return tam.Length <= toiDa ? tam : tam.Substring(0, toiDa);
        }
    }
}

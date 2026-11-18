using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Do_an_co_so.Services
{
    // Dịch máy nội dung do người dùng viết (mô tả phòng, địa chỉ) sang ngôn ngữ
    // của request rồi tra cứu lại trong bảng DichNoiDung, nên mỗi đoạn văn bản
    // chỉ tốn đúng một lần gọi dịch vụ.
    //
    // Nguồn dịch là endpoint web công khai của Google Translate (không cần API
    // key, không tính tiền). Dịch lỗi -> trả nguyên văn tiếng Việt, app vẫn chạy.
    public class NoiDungDichService
    {
        // Giới hạn số đoạn phải dịch trong một request để app không phải chờ lâu khi
        // bật tiếng Anh lần đầu trên một danh sách dài.
        private const int MaxLanDichMotRequest = 40;

        private static readonly SemaphoreSlim GanTiepDien = new SemaphoreSlim(8);

        private readonly IHttpClientFactory _httpFactory;
        private readonly ApplicationDbContext _db;
        private readonly ILogger<NoiDungDichService> _logger;

        public NoiDungDichService(IHttpClientFactory httpFactory, ApplicationDbContext db,
            ILogger<NoiDungDichService> logger)
        {
            _httpFactory = httpFactory;
            _db = db;
            _logger = logger;
        }

        // Ngôn ngữ của request hiện tại, lấy từ Accept-Language (app) hoặc cookie (web).
        private static string MaDich => CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;

        public static bool CanDich => MaDich != "vi";

        /// <summary>
        /// Trả về hàm đổi văn bản tiếng Việt sang ngôn ngữ đang yêu cầu.
        /// Khi app đang ở tiếng Việt (hoặc dịch vụ lỗi) thì hàm chỉ trả nguyên văn.
        /// </summary>
        public async Task<Func<string?, string>> TaoHamDichAsync(IEnumerable<string?> vanBans)
        {
            if (!CanDich) return noiDung => noiDung ?? "";

            var banDich = await LayHoacLuuDichAsync(vanBans);
            return noiDung =>
                noiDung != null && banDich.TryGetValue(noiDung, out var da) && !string.IsNullOrWhiteSpace(da)
                    ? da
                    : noiDung ?? "";
        }

        private async Task<Dictionary<string, string>> LayHoacLuuDichAsync(IEnumerable<string?> vanBans)
        {
            var ketQua = new Dictionary<string, string>();
            var maNgonNgu = MaDich;
            var canTra = vanBans
                .Where(v => !string.IsNullOrWhiteSpace(v))
                .Select(v => v!)
                .Distinct()
                .ToList();
            if (canTra.Count == 0) return ketQua;

            var hashCua = (string vanBan) => TinhHash(maNgonNgu, vanBan);
            var cacHash = canTra.Select(hashCua).ToList();

            var daLuu = await _db.DichNoiDungs
                .Where(d => d.NgonNgu == maNgonNgu && cacHash.Contains(d.MaHash))
                .Select(d => new { d.MaHash, d.BanDich })
                .ToDictionaryAsync(d => d.MaHash, d => d.BanDich);

            var conThieu = new List<string>();
            foreach (var vanBan in canTra)
            {
                if (daLuu.TryGetValue(hashCua(vanBan), out var banDichLuu)) ketQua[vanBan] = banDichLuu;
                else if (conThieu.Count < MaxLanDichMotRequest) conThieu.Add(vanBan);
            }

            if (conThieu.Count == 0) return ketQua;

            // Dịch song song (có giới hạn) vì một danh sách phòng có thể cần
            // dịch vài chục đoạn; làm tuần tự thì request đầu tiên mất cả phút.
            var ketQuaDich = await Task.WhenAll(conThieu.Select(async vanBan =>
                (vanBan, banDich: await DichQuaGoogleAsync(vanBan, maNgonNgu))));

            var moi = new List<DichNoiDung>();
            foreach (var (vanBan, banDich) in ketQuaDich)
            {
                if (string.IsNullOrWhiteSpace(banDich)) continue; // mạng lỗi thì để nguyên tiếng Việt
                ketQua[vanBan] = banDich!;
                moi.Add(new DichNoiDung
                {
                    NgonNgu = maNgonNgu,
                    MaHash = hashCua(vanBan),
                    VanBanGoc = vanBan,
                    BanDich = banDich!
                });
            }

            if (moi.Count > 0)
            {
                _db.DichNoiDungs.AddRange(moi);
                try { await _db.SaveChangesAsync(); }
                catch (DbUpdateException ex)
                {
                    // Request khác vừa ghi cùng một đoạn văn bản: bỏ cache lần này,
                    // không vì một dòng trùng mà làm hỏng cả danh sách phòng.
                    _logger.LogWarning(ex, "Không lưu được cache dịch thuật");
                    _db.ChangeTracker.Clear();
                }
            }

            return ketQua;
        }

        private static string TinhHash(string ngonNgu, string vanBan)
        {
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(ngonNgu + "|" + vanBan));
            return Convert.ToHexString(bytes);
        }

        private async Task<string?> DichQuaGoogleAsync(string vanBan, string maDen)
        {
            try
            {
                await GanTiepDien.WaitAsync();
                var client = _httpFactory.CreateClient("translate");
                var url = "https://translate.googleapis.com/translate_a/single" +
                          "?client=gtx&sl=vi&tl=" + Uri.EscapeDataString(maDen) +
                          "&dt=t&q=" + Uri.EscapeDataString(vanBan);

                using var resp = await client.GetAsync(url);
                if (!resp.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Dịch vụ dịch trả {Ma}, bỏ qua đoạn văn bản", (int)resp.StatusCode);
                    return null;
                }

                await using var stream = await resp.Content.ReadAsStreamAsync();
                using var root = await JsonDocument.ParseAsync(stream);

                // Đáp án là [[["đã dịch","gốc",...], ...], ...] -> nối các đoạn con lại.
                var sb = new StringBuilder();
                foreach (var doan in root.RootElement[0].EnumerateArray())
                {
                    if (doan.ValueKind == JsonValueKind.Array && doan[0].ValueKind == JsonValueKind.String)
                        sb.Append(doan[0].GetString());
                }

                var ketQua = sb.ToString().Trim();
                return ketQua.Length == 0 ? null : ketQua;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Gọi dịch vụ dịch thất bại");
                return null;
            }
            finally
            {
                GanTiepDien.Release();
            }
        }
    }
}

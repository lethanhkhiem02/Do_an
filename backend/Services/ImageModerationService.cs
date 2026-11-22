using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Numerics;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Do_an_co_so.Services
{
    public class AiVisionResult
    {
        public bool IsStockOrFake { get; set; }
        public string Reason { get; set; } = string.Empty;
        public int Confidence { get; set; }
    }

    public class ModerationCheckResult
    {
        public bool IsSuccess { get; set; } = true;
        public string? ErrorMessage { get; set; }

        public List<string> ProcessedFileNames { get; set; } = new();
        public List<string> ProcessedHashes { get; set; } = new();

        public List<CanhBaoBatThuong> Warnings { get; set; } = new();
    }

    public class ImageModerationService
    {
        private readonly IConfiguration _configuration;
        private readonly ApplicationDbContext _db;
        private readonly HttpClient _httpClient;
        private readonly ILogger<ImageModerationService> _logger;

        private static readonly HashSet<string> DuocPhep = new(StringComparer.OrdinalIgnoreCase)
        {
            ".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif"
        };

        public ImageModerationService(
            IConfiguration configuration,
            ApplicationDbContext db,
            HttpClient httpClient,
            ILogger<ImageModerationService> logger)
        {
            _configuration = configuration;
            _db = db;
            _httpClient = httpClient;
            _logger = logger;
        }

        #region 1. Tính dHash 64-bit & Khoảng cách Hamming

        /// <summary>
        /// Tính mã băm dHash (Difference Hash) 64-bit:
        /// Thu nhỏ ảnh về 9 cột x 8 dòng (thang xám), so sánh chênh lệch ánh sáng các pixel liền kề.
        /// </summary>
        public ulong ComputeDHash(Stream stream)
        {
            if (stream.CanSeek) stream.Position = 0;

            using var original = new Bitmap(stream);
            using var resized = new Bitmap(9, 8, PixelFormat.Format24bppRgb);
            using (var g = Graphics.FromImage(resized))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBilinear;
                g.DrawImage(original, 0, 0, 9, 8);
            }

            int[,] gray = new int[9, 8];
            for (int y = 0; y < 8; y++)
            {
                for (int x = 0; x < 9; x++)
                {
                    var p = resized.GetPixel(x, y);
                    gray[x, y] = (int)(p.R * 0.299 + p.G * 0.587 + p.B * 0.114);
                }
            }

            ulong hash = 0;
            int bit = 0;
            for (int y = 0; y < 8; y++)
            {
                for (int x = 0; x < 8; x++)
                {
                    if (gray[x, y] > gray[x + 1, y])
                    {
                        hash |= (1UL << bit);
                    }
                    bit++;
                }
            }

            return hash;
        }

        /// <summary>
        /// Tính phần trăm tương đồng giữa hai chuỗi dHash 64-bit dựa trên khoảng cách Hamming (0 - 100%).
        /// </summary>
        public double CalculateSimilarity(ulong hash1, ulong hash2)
        {
            int distance = BitOperations.PopCount(hash1 ^ hash2);
            return ((64.0 - distance) / 64.0) * 100.0;
        }

        public string HashToHex(ulong hash) => hash.ToString("x16");

        public bool TryParseHex(string? hex, out ulong hash)
        {
            hash = 0;
            if (string.IsNullOrWhiteSpace(hex)) return false;
            return ulong.TryParse(hex.Trim(), NumberStyles.HexNumber, CultureInfo.InvariantCulture, out hash);
        }

        #endregion

        #region 2. Tích hợp AI Vision (Gemini 2.5 Flash)

        /// <summary>
        /// Gửi ảnh lên Gemini 2.5 Flash kiểm tra 2 dấu hiệu bất thường:
        /// 1. Ảnh mẫu, 3D render kiến trúc, ảnh catalog quảng cáo từ internet, dính logo/watermark/số điện thoại sàn khác.
        /// 2. Ảnh giả, không liên quan đến phòng trọ/nhà ở thực tế (động vật, meme, selfie, phong cảnh, đồ ăn...).
        /// </summary>
        public async Task<AiVisionResult> AnalyzeImageWithGeminiAsync(Stream stream, string mimeType = "image/jpeg")
        {
            var apiKey = _configuration["Gemini:ApiKey"] ?? _configuration["GeminiApiKey"];
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                _logger.LogInformation("Gemini API Key chưa được cấu hình. Bỏ qua kiểm tra AI Vision.");
                return new AiVisionResult
                {
                    IsStockOrFake = false,
                    Reason = "Chưa cấu hình Gemini API Key (chế độ an toàn)",
                    Confidence = 0
                };
            }

            try
            {
                if (stream.CanSeek) stream.Position = 0;
                using var ms = new MemoryStream();
                await stream.CopyToAsync(ms);
                var base64 = Convert.ToBase64String(ms.ToArray());

                var prompt = "Bạn là hệ thống AI kiểm duyệt hình ảnh phòng trọ, nhà ở cho thuê. "
                           + "Hãy phân tích kỹ bức ảnh này và kiểm tra 2 dấu hiệu bất thường sau:\n"
                           + "1. Dấu hiệu ảnh mẫu/mạng: Ảnh phối cảnh 3D render kiến trúc, ảnh catalog quảng cáo tải từ internet, ảnh stock thương mại, hoặc ảnh dính logo, watermark, số điện thoại của website/sàn bất động sản khác.\n"
                           + "2. Dấu hiệu ảnh giả/không liên quan: Bức ảnh hoàn toàn không liên quan đến phòng trọ, nhà ở, nội thất căn hộ thực tế (như ảnh thú cưng động vật, ảnh meme hài hước, ảnh selfie chân dung, phong cảnh thiên nhiên, đồ ăn, xe cộ, đồ họa ảo).\n\n"
                           + "Nếu vi phạm một trong hai dấu hiệu trên, hãy đặt isStockOrFake = true và giải thích lý do cụ thể bằng Tiếng Việt vào trường reason.\n"
                           + "Nếu là ảnh chụp thực tế không gian phòng trọ, căn hộ, nhà vệ sinh, ban công, lối đi hoặc tiện ích nhà ở thì đặt isStockOrFake = false.\n"
                           + "Trả về DUY NHẤT một chuỗi JSON thuần túy (không dùng markdown ```json) theo cấu trúc: {\"isStockOrFake\": bool, \"reason\": string, \"confidence\": int (thang điểm 0-100)}.";

                var requestPayload = new
                {
                    contents = new[]
                    {
                        new
                        {
                            parts = new object[]
                            {
                                new { text = prompt },
                                new
                                {
                                    inline_data = new
                                    {
                                        mime_type = string.IsNullOrWhiteSpace(mimeType) ? "image/jpeg" : mimeType,
                                        data = base64
                                    }
                                }
                            }
                        }
                    },
                    generationConfig = new
                    {
                        response_mime_type = "application/json"
                    }
                };

                var url = $"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={apiKey}";
                var content = new StringContent(JsonSerializer.Serialize(requestPayload), Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync(url, content);
                if (!response.IsSuccessStatusCode)
                {
                    var errBody = await response.Content.ReadAsStringAsync();
                    _logger.LogWarning("Gemini API trả mã {StatusCode}: {Error}", response.StatusCode, errBody);
                    return new AiVisionResult
                    {
                        IsStockOrFake = false,
                        Reason = $"Lỗi phản hồi Gemini API ({response.StatusCode})",
                        Confidence = 0
                    };
                }

                var json = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(json);
                var text = doc.RootElement
                    .GetProperty("candidates")[0]
                    .GetProperty("content")
                    .GetProperty("parts")[0]
                    .GetProperty("text")
                    .GetString();

                if (string.IsNullOrWhiteSpace(text))
                {
                    return new AiVisionResult { IsStockOrFake = false, Reason = "Phản hồi AI rỗng", Confidence = 0 };
                }

                // Loại bỏ markdown nếu AI tự bọc ```json
                text = text.Trim();
                if (text.StartsWith("```"))
                {
                    int start = text.IndexOf('{');
                    int end = text.LastIndexOf('}');
                    if (start >= 0 && end > start)
                    {
                        text = text.Substring(start, end - start + 1);
                    }
                }

                using var resultDoc = JsonDocument.Parse(text);
                var isStockOrFake = resultDoc.RootElement.TryGetProperty("isStockOrFake", out var p1) && p1.GetBoolean();
                var reason = resultDoc.RootElement.TryGetProperty("reason", out var p2) ? p2.GetString() ?? "" : "";
                var confidence = resultDoc.RootElement.TryGetProperty("confidence", out var p3) ? p3.GetInt32() : 0;

                return new AiVisionResult
                {
                    IsStockOrFake = isStockOrFake,
                    Reason = reason,
                    Confidence = confidence
                };
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Không thể hoàn thành kiểm duyệt Gemini AI Vision: {Message}", ex.Message);
                return new AiVisionResult
                {
                    IsStockOrFake = false,
                    Reason = "Lỗi xử lý AI: " + ex.Message,
                    Confidence = 0
                };
            }
        }

        #endregion

        #region 3. Quy trình Kiểm duyệt toàn diện khi Upload / Đăng bài

        /// <summary>
        /// Kiểm tra danh sách ảnh upload:
        /// 1. Kiểm tra trùng lặp nội bộ (intra-post): Nếu >= 90% thì từ chối ngay.
        /// 2. So sánh với toàn bộ ảnh của các phòng trọ khác trong CSDL: Nếu >= 90% thì TẠO CẢNH BÁO CHO ADMIN VÀ HỦY ĐĂNG BÀI NGAY LẬP TỨC.
        /// 3. Lưu ảnh hợp lệ và gọi Gemini Vision phát hiện ảnh mẫu/3D/watermark: Tự động tạo CanhBaoBatThuong (AnhMauTrenMang).
        /// </summary>
        public async Task<ModerationCheckResult> ProcessAndModerateImagesAsync(
            List<IFormFile> files,
            string userId,
            int? currentRoomId,
            string uploadsFolder)
        {
            var result = new ModerationCheckResult();

            if (files == null || files.Count == 0)
            {
                return result;
            }

            Directory.CreateDirectory(uploadsFolder);

            // Bước 1: Tính dHash trước cho toàn bộ file và kiểm tra trùng lặp trong cùng bài đăng
            var fileHashes = new List<(IFormFile File, ulong Hash, string Hex)>();

            for (int i = 0; i < files.Count; i++)
            {
                var file = files[i];
                if (file.Length == 0) continue;

                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (!DuocPhep.Contains(ext))
                {
                    result.IsSuccess = false;
                    result.ErrorMessage = $"Định dạng ảnh '{ext}' không được hỗ trợ. Vui lòng chỉ tải lên ảnh JPG, PNG, WEBP.";
                    return result;
                }

                ulong hash;
                try
                {
                    using var stream = file.OpenReadStream();
                    hash = ComputeDHash(stream);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Lỗi đọc file ảnh {FileName}", file.FileName);
                    continue;
                }

                // So sánh với các ảnh trước đó trong cùng đợt upload (trùng nội bộ)
                for (int j = 0; j < fileHashes.Count; j++)
                {
                    var prev = fileHashes[j];
                    double sim = CalculateSimilarity(hash, prev.Hash);
                    if (sim >= 90.0)
                    {
                        result.IsSuccess = false;
                        result.ErrorMessage = $"Ảnh '{file.FileName}' bị trùng lặp với ảnh '{prev.File.FileName}' trong cùng bài đăng (Độ tương đồng: {sim:F1}%). Hệ thống đã hủy đăng bài, vui lòng loại bỏ ảnh trùng và thử lại.";
                        return result;
                    }
                }

                fileHashes.Add((file, hash, HashToHex(hash)));
            }

            // Bước 2: So sánh dHash của các ảnh mới với toàn bộ ảnh của các phòng trọ đã có trong CSDL
            var existingRooms = await _db.PhongTro
                .AsNoTracking()
                .Where(p => (currentRoomId == null || p.Id != currentRoomId) && !string.IsNullOrEmpty(p.ImageHash))
                .Select(p => new { p.Id, p.ChuTroId, p.MoTa, p.HinhAnh, p.ImageHash })
                .ToListAsync();

            var existingHashes = new List<(int RoomId, string TieuDe, string? ChuTroId, ulong Hash)>();
            foreach (var r in existingRooms)
            {
                if (string.IsNullOrWhiteSpace(r.ImageHash)) continue;
                var rawHashes = r.ImageHash.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                foreach (var rh in rawHashes)
                {
                    if (TryParseHex(rh, out var parsedHash))
                    {
                        existingHashes.Add((r.Id, r.MoTa ?? $"Phòng trọ #{r.Id}", r.ChuTroId, parsedHash));
                    }
                }
            }

            // Kiểm tra chéo (Cross-post duplicate check):
            // Nếu phát hiện trùng lặp >= 90% với bài khác: Lưu cảnh báo cho Admin và HỦY BÀI ĐĂNG NGAY LẬP TỨC
            foreach (var item in fileHashes)
            {
                foreach (var ex in existingHashes)
                {
                    double sim = CalculateSimilarity(item.Hash, ex.Hash);
                    if (sim >= 90.0)
                    {
                        // Lưu riêng bức ảnh vi phạm này vào thư mục làm bằng chứng cảnh báo cho Admin
                        var evidenceFileName = Guid.NewGuid().ToString() + "_evidence_" + Path.GetFileName(item.File.FileName);
                        var evidencePath = Path.Combine(uploadsFolder, evidenceFileName);
                        try
                        {
                            await using (var fileStream = new FileStream(evidencePath, FileMode.Create))
                            {
                                using var readStream = item.File.OpenReadStream();
                                await readStream.CopyToAsync(fileStream);
                            }
                        }
                        catch (Exception exSave)
                        {
                            _logger.LogWarning(exSave, "Không thể lưu file bằng chứng: {FileName}", item.File.FileName);
                            evidenceFileName = item.File.FileName;
                        }

                        var loaiViPham = (ex.ChuTroId == userId) ? "SpamNhieuBai" : "AnhTrungLap";
                        var tieuDeRutGon = (ex.TieuDe.Length > 50) ? ex.TieuDe.Substring(0, 50) + "..." : ex.TieuDe;
                        var thongBaoChiTiet = $"Ảnh '{item.File.FileName}' bị trùng lặp với bài đăng phòng trọ '#{ex.RoomId} - {tieuDeRutGon}' đã tồn tại trên hệ thống (Độ tương đồng: {sim:F1}%). Hệ thống đã hủy đăng bài và gửi cảnh báo bất thường cho Admin.";

                        var warning = new CanhBaoBatThuong
                        {
                            UserId = userId,
                            PhongTroId = ex.RoomId,
                            LoaiViPham = loaiViPham,
                            MoTaChiTiet = thongBaoChiTiet,
                            AnhBangChungUrl = evidenceFileName,
                            DaXuLy = false,
                            NgayTao = DateTime.Now
                        };

                        _db.CanhBaoBatThuongs.Add(warning);
                        await _db.SaveChangesAsync();

                        // Bắt buộc từ chối và hủy việc đăng bài ngay lập tức
                        result.IsSuccess = false;
                        result.ErrorMessage = thongBaoChiTiet;
                        return result;
                    }
                }
            }

            // Bước 3: Tất cả ảnh đều hợp lệ và không trùng lặp -> Lưu ảnh chính thức
            foreach (var item in fileHashes)
            {
                var file = item.File;
                var uniqueName = Guid.NewGuid().ToString() + "_" + Path.GetFileName(file.FileName);
                var filePath = Path.Combine(uploadsFolder, uniqueName);

                await using (var fileStream = new FileStream(filePath, FileMode.Create))
                {
                    await file.CopyToAsync(fileStream);
                }

                result.ProcessedFileNames.Add(uniqueName);
                result.ProcessedHashes.Add(item.Hex);

                // Kiểm tra AI Vision (Gemini 2.5 Flash) phát hiện ảnh mẫu, 3D render hoặc ảnh không liên quan
                try
                {
                    using var stream = file.OpenReadStream();
                    var aiResult = await AnalyzeImageWithGeminiAsync(stream, file.ContentType);
                    if (aiResult.IsStockOrFake)
                    {
                        var aiWarning = new CanhBaoBatThuong
                        {
                            UserId = userId,
                            PhongTroId = currentRoomId,
                            LoaiViPham = "AnhMauTrenMang",
                            MoTaChiTiet = $"AI Vision phát hiện bất thường: {aiResult.Reason} (Độ tin cậy: {aiResult.Confidence}%).",
                            AnhBangChungUrl = uniqueName,
                            DaXuLy = false,
                            NgayTao = DateTime.Now
                        };
                        result.Warnings.Add(aiWarning);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Lỗi kiểm tra AI cho ảnh {FileName}", file.FileName);
                }
            }

            // Lưu các cảnh báo AI (nếu có phát hiện ảnh mẫu)
            if (result.Warnings.Count > 0)
            {
                _db.CanhBaoBatThuongs.AddRange(result.Warnings);
                await _db.SaveChangesAsync();
            }

            return result;
        }

        #endregion
    }
}

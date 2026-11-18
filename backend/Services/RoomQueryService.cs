using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.EntityFrameworkCore;

namespace Do_an_co_so.Services
{
    public record RoomMatch(PhongTro PhongTro, double KhoangCach, double TrungBinhSao, int SoDanhGia);

    // Lọc/sắp xếp phòng trọ cho tầng API của app. Web giữ logic riêng trong
    // PhongTroController.TimKiem để không ảnh hưởng đồ án cơ sở đã chạy.
    public class RoomQueryService
    {
        private readonly ApplicationDbContext _db;

        public RoomQueryService(ApplicationDbContext db) => _db = db;

        public async Task<List<RoomMatch>> SearchAsync(
            string? truongId, double? radiusKm, decimal? minPrice, decimal? maxPrice,
            string? sortBy, bool chiHienPhongConTrong = true, bool boQuaBanKinh = false)
        {
            var query = _db.PhongTro.Include(p => p.ChuTro).AsQueryable();

            if (chiHienPhongConTrong)
            {
                query = query.Where(p => p.DaChoThue == false
                    && (p.NgayHetHan == null || p.NgayHetHan >= DateTime.Now));
            }

            if (minPrice.HasValue) query = query.Where(p => p.Gia >= minPrice.Value);
            if (maxPrice.HasValue) query = query.Where(p => p.Gia <= maxPrice.Value);

            var rooms = await query.ToListAsync();

            var ids = rooms.Select(p => p.Id).ToList();
            var sao = await _db.DanhGias
                .Where(d => ids.Contains(d.PhongTroId))
                .GroupBy(d => d.PhongTroId)
                .Select(g => new { g.Key, Avg = g.Average(d => d.Sao), Count = g.Count() })
                .ToDictionaryAsync(x => x.Key, x => (x.Avg, x.Count));

            var truong = TruongData.GetAll().FirstOrDefault(t => t.Id == truongId);

            var results = new List<RoomMatch>();
            foreach (var room in rooms)
            {
                var khoangCach = (truong != null && room.Latitude.HasValue && room.Longitude.HasValue)
                    ? TruongData.HaversineKm(truong.Latitude, truong.Longitude, room.Latitude.Value, room.Longitude.Value)
                    : 0;

                // Khoảng cách 0 nghĩa là phòng không có tọa độ -> không được loại vì lọc bán kính.
                if (!boQuaBanKinh && radiusKm.HasValue && khoangCach > radiusKm.Value && khoangCach > 0) continue;

                var (avg, count) = sao.TryGetValue(room.Id, out var v) ? v : (0d, 0);
                results.Add(new RoomMatch(room, khoangCach, avg, count));
            }

            results = sortBy switch
            {
                "price_asc" => results.OrderByDescending(r => r.PhongTro.IsVip).ThenBy(r => r.PhongTro.Gia).ToList(),
                "price_desc" => results.OrderByDescending(r => r.PhongTro.IsVip).ThenByDescending(r => r.PhongTro.Gia).ToList(),
                "rating_desc" => results.OrderByDescending(r => r.PhongTro.IsVip).ThenByDescending(r => r.TrungBinhSao).ToList(),
                "newest" => results.OrderByDescending(r => r.PhongTro.IsVip).ThenByDescending(r => r.PhongTro.Id).ToList(),
                _ => results.OrderByDescending(r => r.PhongTro.IsVip).ThenBy(r => r.KhoangCach).ToList()
            };

            return results;
        }
    }
}

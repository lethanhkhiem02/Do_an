using Do_an_co_so.Data;
using Do_an_co_so.Hubs;
using Do_an_co_so.Models;
using Microsoft.AspNetCore.SignalR;

namespace Do_an_co_so.Services
{
    /// <summary>
    /// Ghi thông báo vào hộp thư của một tài khoản rồi báo cho người đó qua hub
    /// /chatHub. Sự kiện đẩy đi chỉ mang mã loại, không mang câu chữ, vì ngôn ngữ
    /// hiển thị phải theo người nhận (app sẽ gọi lại api/thong-bao để lấy bản dịch
    /// đúng theo Accept-Language của chính họ).
    /// </summary>
    public class ThongBaoService
    {
        private readonly ApplicationDbContext _db;
        private readonly IHubContext<ChatHub> _hub;

        public ThongBaoService(ApplicationDbContext db, IHubContext<ChatHub> hub)
        {
            _db = db;
            _hub = hub;
        }

        public async Task<ThongBao> GhiAsync(string nguoiNhanId, string loai, string? tacNhanId, int? maLichXemPhong)
        {
            var thongBao = new ThongBao
            {
                NguoiNhanId = nguoiNhanId,
                Loai = loai,
                TacNhanId = tacNhanId,
                MaLichXemPhong = maLichXemPhong,
                DaDoc = false,
                NgayTao = DateTime.Now
            };

            _db.ThongBaos.Add(thongBao);
            await _db.SaveChangesAsync();

            await _hub.Clients.User(nguoiNhanId).SendAsync("ReceiveThongBao", new
            {
                id = thongBao.Id,
                loai = thongBao.Loai,
                maLichXemPhong = thongBao.MaLichXemPhong,
                ngayTao = thongBao.NgayTao
            });

            return thongBao;
        }
    }
}

using Do_an_co_so.Api.Dtos;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Do_an_co_so.Hubs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Localization;
using System.Security.Claims;

namespace Do_an_co_so.Api
{
    // Chat cho app. Tin nhắn 1-1 và chat tổng dùng chung bảng Messages + cùng
    // mã định dạng "[GLOBAL_...]" / "[IMG]:..." như web đang lưu, nên hai bên
    // đọc được hội thoại của nhau. Realtime đi qua SignalR /chatHub (task #5),
    // còn ở đây là danh sách hội thoại, lịch sử, upload ảnh và báo cáo người dùng.
    // Kế thừa [Authorize(scheme Bearer)] từ ApiControllerBase, không khai báo lại
    // để tránh xung đột với scheme cookie của web.
    [Route("api/chat")]
    public class ChatApiController : ApiControllerBase
    {
        private readonly ApplicationDbContext _db;
        private readonly UserManager<AppUser> _userManager;
        private readonly IHubContext<ChatHub> _hub;
        private readonly IWebHostEnvironment _env;

        public ChatApiController(ApplicationDbContext db, UserManager<AppUser> userManager,
            IHubContext<ChatHub> hub, IWebHostEnvironment env,
            IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _db = db;
            _userManager = userManager;
            _hub = hub;
            _env = env;
        }

        [HttpGet("hoi-thoai")]
        public async Task<ActionResult<List<ConversationDto>>> DanhSachHoiThoai()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var thamSo = await _db.Messages
                .Where(m => m.SenderId == user.Id || m.ReceiverId == user.Id)
                .Where(m => !m.Content.StartsWith("[GLOBAL_"))
                .Select(m => new { m.SenderId, m.ReceiverId, m.Content, m.Timestamp })
                .ToListAsync();

            var cacLoai = thamSo
                .Select(m => new
                {
                    DoiPhuongId = m.SenderId == user.Id ? m.ReceiverId : m.SenderId,
                    m.Content,
                    m.Timestamp
                })
                .Where(x => x.DoiPhuongId != null)
                .GroupBy(x => x.DoiPhuongId!)
                .Select(g => new
                {
                    UserId = g.Key,
                    MoiNhat = g.OrderByDescending(x => x.Timestamp).First()
                })
                .ToList();

            var ids = cacLoai.Select(c => c.UserId).ToList();
            var nguoiDung = await _db.Users.Where(u => ids.Contains(u.Id)).ToListAsync();

            var ketQua = cacLoai
                .Select(c =>
                {
                    var doiPhuong = nguoiDung.FirstOrDefault(u => u.Id == c.UserId);
                    string noiDung = doiPhuong == null
                        ? Localizer["Api_DeletedAccount"]
                        : (c.MoiNhat.Content.StartsWith("[IMG]:") ? Localizer["Api_ImagePlaceholder"] : c.MoiNhat.Content);
                    return new ConversationDto
                    {
                        UserId = c.UserId,
                        HoTen = doiPhuong?.HoTen ?? doiPhuong?.UserName ?? "Ẩn danh",
                        Avatar = doiPhuong?.Avatar,
                        TinNganNhat = noiDung.Length > 60 ? noiDung[..60] + "..." : noiDung,
                        ThoiGianNhan = c.MoiNhat.Timestamp
                    };
                })
                .OrderByDescending(c => c.ThoiGianNhan)
                .ToList();

            return Ok(ketQua);
        }

        [HttpGet("lich-su/{receiverId}")]
        public async Task<ActionResult<List<ChatMessageDto>>> LichSu(string receiverId)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var doiPhuong = await _userManager.FindByIdAsync(receiverId);
            if (doiPhuong == null) return NotFound(new ApiError(Localizer["Api_UserNotFound"]));

            var tinNhan = await _db.Messages
                .Include(m => m.Sender)
                .Where(m => (m.SenderId == user.Id && m.ReceiverId == receiverId)
                         || (m.SenderId == receiverId && m.ReceiverId == user.Id))
                .Where(m => !m.Content.StartsWith("[GLOBAL_"))
                .OrderBy(m => m.Timestamp)
                .ToListAsync();

            return Ok(tinNhan.Select(m => new ChatMessageDto
            {
                Id = m.Id,
                SenderId = m.SenderId,
                TenNguoiGui = m.Sender?.HoTen ?? m.Sender?.UserName ?? "Ẩn danh",
                NoiDung = m.Content,
                ThoiGian = m.Timestamp,
                CuaMinh = m.SenderId == user.Id
            }).ToList());
        }

        // App có thể gửi qua HTTP (an toàn, có kiểm tra khóa tài khoản) hoặc trực tiếp
        // gọi hub SendPrivateMessage để người nhận thấy ngay.
        [HttpPost("gui")]
        public async Task<ActionResult<ChatMessageDto>> Gui([FromBody] SendMessageRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa)
            {
                return StatusCode(403, new ApiError(Localizer["Api_LockedSendMsg"]));
            }

            var receiver = await _userManager.FindByIdAsync(request.ReceiverId);
            if (receiver == null) return NotFound(new ApiError(Localizer["Api_ReceiverNotFound"]));

            return await LuuVaPhatAsync(user, receiver.Id, request.Content);
        }

        [HttpGet("chat-tong")]
        public async Task<ActionResult<List<ChatMessageDto>>> ChatTong()
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var raw = await _db.Messages
                .Include(m => m.Sender)
                .Where(m => m.Content.StartsWith("[GLOBAL_"))
                .OrderByDescending(m => m.Timestamp)
                .Take(50)
                .ToListAsync();

            raw.Reverse();

            var ketQua = new List<ChatMessageDto>();
            foreach (var m in raw)
            {
                var tach = TachTinChatTong(m);
                if (tach == null) continue;

                ketQua.Add(new ChatMessageDto
                {
                    Id = m.Id,
                    SenderId = m.SenderId,
                    TenNguoiGui = tach.Value.TenHienThi,
                    NoiDung = tach.Value.NoiDung,
                    ThoiGian = m.Timestamp,
                    CuaMinh = m.SenderId == user.Id
                });
            }

            return Ok(ketQua);
        }

        [HttpPost("chat-tong")]
        public async Task<IActionResult> GuiChatTong([FromBody] SendGlobalMessageRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa)
            {
                return StatusCode(403, new ApiError(Localizer["Api_LockedSendText"]));
            }

            var loai = string.IsNullOrWhiteSpace(request.Type) ? "text" : request.Type.Trim().ToLowerInvariant();
            var content = $"[GLOBAL_{loai.ToUpperInvariant()}]: {request.Content}";

            var msg = new Message
            {
                SenderId = user.Id,
                ReceiverId = user.Id,
                Content = content,
                Timestamp = DateTime.Now
            };
            _db.Messages.Add(msg);
            await _db.SaveChangesAsync();

            var data = new
            {
                User = string.IsNullOrEmpty(user.HoTen) ? (user.UserName?.Split('@')[0] ?? "Ẩn danh") : user.HoTen,
                Type = loai,
                Content = request.Content,
                Time = DateTime.Now.ToString("HH:mm")
            };
            await _hub.Clients.All.SendAsync("ReceiveGlobalMessage", data);

            return Ok(new MessageResponse(Localizer["Api_Sent"]));
        }

        [HttpPost("upload-anh")]
        [Consumes("multipart/form-data")]
        public async Task<IActionResult> UploadAnh(IFormFile file)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa)
            {
                return StatusCode(403, new ApiError(Localizer["Api_LockedSendImage"]));
            }
            if (file == null || file.Length == 0) return BadRequest(new ApiError(Localizer["Api_NoFileUploaded"]));

            var duoi = Path.GetExtension(file.FileName).ToLowerInvariant();
            var duocPhep = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
            if (!duocPhep.Contains(duoi)) return BadRequest(new ApiError(Localizer["Api_OnlyImageFiles"]));

            var tenFile = Guid.NewGuid() + duoi;
            var thuMuc = Path.Combine(_env.WebRootPath, "uploads", "chat-images");
            Directory.CreateDirectory(thuMuc);

            await using (var stream = new FileStream(Path.Combine(thuMuc, tenFile), FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            return Ok(new { success = true, imageUrl = $"/uploads/chat-images/{tenFile}" });
        }

        [HttpPost("bao-cao-nguoi-dung")]
        public async Task<IActionResult> BaoCaoNguoiDung([FromBody] ReportUserRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (user.TrangThaiKhoa)
            {
                return StatusCode(403, new ApiError(Localizer["Api_NoPermission"]));
            }

            var biBaoCao = await _userManager.FindByIdAsync(request.NguoiBiBaoCaoId);
            if (biBaoCao == null) return NotFound(new ApiError(Localizer["Api_ReportedUserNotFound"]));

            _db.BaoCaos.Add(new BaoCao
            {
                NguoiBiBaoCaoId = request.NguoiBiBaoCaoId,
                PhongTroId = null,
                NguoiBaoCaoId = user.Id,
                LyDo = request.LyDo,
                ChiTiet = request.ChiTiet ?? "",
                NgayBaoCao = DateTime.Now,
                DaXuLy = false
            });
            await _db.SaveChangesAsync();

            return Ok(new MessageResponse(Localizer["Api_ReportUserSent"]));
        }

        // ================================ TIỆN ÍCH NỘI BỘ ================================

        private async Task<ChatMessageDto> LuuVaPhatAsync(AppUser sender, string receiverId, string content)
        {
            var msg = new Message
            {
                SenderId = sender.Id,
                ReceiverId = receiverId,
                Content = content,
                Timestamp = DateTime.Now
            };
            _db.Messages.Add(msg);
            await _db.SaveChangesAsync();

            // Đẩy realtime tới người nhận (app nào đang mở hub sẽ nhận được ngay)
            await _hub.Clients.User(receiverId).SendAsync(
                "ReceivePrivateMessage", sender.Id, content, DateTime.Now.ToString("HH:mm"));

            return new ChatMessageDto
            {
                Id = msg.Id,
                SenderId = sender.Id,
                TenNguoiGui = sender.HoTen ?? sender.UserName,
                NoiDung = content,
                ThoiGian = msg.Timestamp,
                CuaMinh = true
            };
        }

        // Web lưu chat tổng dạng "[GLOBAL_TEXT]: nội dung" -> tách lại cho app hiển thị
        private static (string TenHienThi, string Loai, string NoiDung)? TachTinChatTong(Message m)
        {
            var ten = !string.IsNullOrEmpty(m.Sender?.HoTen)
                ? m.Sender.HoTen
                : (m.Sender?.UserName?.Split('@')[0] ?? "Ẩn danh");

            var dau = m.Content.IndexOf("]:", StringComparison.Ordinal);
            if (dau < 0) return null;

            var loai = m.Content[("[GLOBAL_").Length..dau].ToLowerInvariant();
            var noiDung = m.Content[(dau + 2)..].Trim();
            return (ten, loai, noiDung);
        }

        private async Task<AppUser?> CurrentUserAsync()
            => await _userManager.FindByIdAsync(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "");
    }
}

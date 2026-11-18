using Microsoft.AspNetCore.SignalR;
using Do_an_co_so.Data;
using Do_an_co_so.Models;
using Microsoft.AspNetCore.Identity;
using System;
using System.Threading.Tasks;

namespace Do_an_co_so.Hubs
{
    public class ChatHub : Hub
    {
        private readonly ApplicationDbContext _context;

        public ChatHub(ApplicationDbContext context)
        {
            _context = context;
        }

        // =========================================================================
        // 1. HÀM DÀNH CHO CHAT TỔNG (GLOBAL CHAT)
        // =========================================================================
        public async Task SendGlobalMessage(string userId, string userName, string messageType, string messageContent)
        {
            // App gửi token JWT kèm kết nối nên userId thật nằm ở Context.UserIdentifier.
            // Dùng nó thay cho tham số client tự khai để tránh mạo danh người khác.
            userId = Context.UserIdentifier ?? userId;

            // CHỐT KIỂM TRA: Nếu tài khoản bị khóa -> Chặn không cho gửi tin lên Server
            var user = await _context.Users.FindAsync(userId);
            if (user != null && user.TrangThaiKhoa) return;

            // Lấy tên hiển thị từ hồ sơ đã xác thực thay vì tin chuỗi client gửi lên
            if (!string.IsNullOrEmpty(user?.HoTen)) userName = user.HoTen;

            // 1. Lưu vào Database
            var msg = new Message
            {
                SenderId = userId,
                ReceiverId = userId,
                Content = $"[GLOBAL_{messageType.ToUpper()}]: {messageContent}",
                Timestamp = DateTime.Now
            };

            _context.Messages.Add(msg);
            await _context.SaveChangesAsync();

            // 2. Gửi cho tất cả mọi người đang online thấy
            var data = new
            {
                User = userName,
                Type = messageType,
                Content = messageContent,
                Time = DateTime.Now.ToString("HH:mm")
            };
            await Clients.All.SendAsync("ReceiveGlobalMessage", data);
        }

        // =========================================================================
        // 2. CÁC HÀM DÀNH CHO CHAT RIÊNG (PRIVATE CHAT 1-1)
        // =========================================================================
        public async Task SendPrivateMessage(string senderId, string receiverId, string message)
        {
            senderId = Context.UserIdentifier ?? senderId;

            // CHỐT KIỂM TRA: Bị khóa thì không cho gửi tin nhắn riêng
            var sender = await _context.Users.FindAsync(senderId);
            if (sender != null && sender.TrangThaiKhoa) return;

            // 1. Lưu tin nhắn vào Database
            var msg = new Message
            {
                SenderId = senderId,
                ReceiverId = receiverId,
                Content = message,
                Timestamp = DateTime.Now
            };

            _context.Messages.Add(msg);
            await _context.SaveChangesAsync();

            // 2. Gửi tin nhắn thẳng tới màn hình của người nhận
            await Clients.User(receiverId).SendAsync("ReceivePrivateMessage", senderId, message, DateTime.Now.ToString("HH:mm"));

            // 3. Phản hồi lại cho chính người gửi
            await Clients.Caller.SendAsync("ReceivePrivateMessage", senderId, message, DateTime.Now.ToString("HH:mm"));
        }

        public async Task SendTypingState(string senderId, string receiverId, bool isTyping)
        {
            senderId = Context.UserIdentifier ?? senderId;

            // CHỐT KIỂM TRA: Bị khóa thì chặn luôn hiệu ứng "Đang gõ..."
            var sender = await _context.Users.FindAsync(senderId);
            if (sender != null && sender.TrangThaiKhoa) return;

            await Clients.User(receiverId).SendAsync("ReceiveTypingState", senderId, isTyping);
        }
    }
}
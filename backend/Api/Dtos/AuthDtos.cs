using System.ComponentModel.DataAnnotations;

namespace Do_an_co_so.Api.Dtos
{
    public record ApiError(string Message);

    public record MessageResponse(string Message);

    // ============================ AUTH / TÀI KHOẢN ============================

    public class LoginRequest
    {
        [Required(ErrorMessage = "Vui lòng nhập email")]
        public string Email { get; init; } = "";

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
        public string Password { get; init; } = "";
    }

    public class RegisterRequest
    {
        [Required(ErrorMessage = "Vui lòng nhập họ tên")]
        public string HoTen { get; init; } = "";

        [Required(ErrorMessage = "Vui lòng nhập email")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ")]
        public string Email { get; init; } = "";

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu")]
        [MinLength(6, ErrorMessage = "Mật khẩu tối thiểu 6 ký tự")]
        public string Password { get; init; } = "";

        // "SinhVien" hoặc "ChuTro" (Admin chỉ tạo từ web, không cho tự đăng ký)
        [Required(ErrorMessage = "Vui lòng chọn vai trò")]
        public string Role { get; init; } = "SinhVien";
    }

    public class AuthResult
    {
        public string Token { get; init; } = "";
        public DateTime ExpiresAt { get; init; }
        public ProfileDto User { get; init; } = new();
        public List<string> Roles { get; init; } = new();
    }

    public class ProfileDto
    {
        public string Id { get; init; } = "";
        public string Email { get; init; } = "";
        public string HoTen { get; init; } = "";
        public string? Avatar { get; init; }
        public string? SoDienThoai { get; init; }
        public DateTime? NgaySinh { get; init; }
        public string? DiaChi { get; init; }
        public decimal SoDu { get; init; }
        public bool TrangThaiKhoa { get; init; }
        public string TrangThaiXacThuc { get; init; } = "";
        public string? CCCDTruoc { get; init; }
        public string? CCCDSau { get; init; }
        public string? SoCCCDQuetDuoc { get; init; }
    }

    public class UpdateProfileRequest
    {
        [Required(ErrorMessage = "Vui lòng nhập họ tên")]
        public string HoTen { get; init; } = "";
        public string? SoDienThoai { get; init; }
        public DateTime? NgaySinh { get; init; }
        public string? DiaChi { get; init; }
    }

    public class ChangePasswordRequest
    {
        [Required(ErrorMessage = "Vui lòng nhập mật khẩu hiện tại")]
        public string CurrentPassword { get; init; } = "";

        [Required(ErrorMessage = "Vui lòng nhập mật khẩu mới")]
        [MinLength(6, ErrorMessage = "Mật khẩu mới tối thiểu 6 ký tự")]
        public string NewPassword { get; init; } = "";
    }
}

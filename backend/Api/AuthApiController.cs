using System.Text.RegularExpressions;
using Do_an_co_so.Api.Dtos;
using Do_an_co_so.Models;
using Do_an_co_so.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Localization;
using Tesseract;

namespace Do_an_co_so.Api
{
    // Đăng nhập / đăng ký / hồ sơ cá nhân cho app di động.
    // Trang web vẫn dùng các trang Identity Razor cũ, ở đây chỉ thêm đường dẫn /api/auth/*.
    [Route("api/auth")]
    public class AuthApiController : ApiControllerBase
    {
        private static readonly string[] ChoPhepTaoTaiKhoan = { "SinhVien", "ChuTro" };

        private readonly UserManager<AppUser> _userManager;
        private readonly TokenService _tokens;
        private readonly IWebHostEnvironment _env;

        public AuthApiController(UserManager<AppUser> userManager, TokenService tokens, IWebHostEnvironment env,
            IStringLocalizer<SharedResource> localizer) : base(localizer)
        {
            _userManager = userManager;
            _tokens = tokens;
            _env = env;
        }

        [AllowAnonymous]
        [HttpPost("login")]
        public async Task<ActionResult<AuthResult>> Login([FromBody] LoginRequest request)
        {
            var user = await _userManager.FindByEmailAsync(request.Email.Trim());
            if (user == null || !await _userManager.CheckPasswordAsync(user, request.Password))
            {
                return BadRequest(new ApiError(Localizer["Api_BadCredentials"]));
            }

            return await BuildAuthResult(user);
        }

        [AllowAnonymous]
        [HttpPost("register")]
        public async Task<ActionResult<AuthResult>> Register([FromBody] RegisterRequest request)
        {
            var role = request.Role?.Trim();
            if (role == null || !ChoPhepTaoTaiKhoan.Contains(role))
            {
                return BadRequest(new ApiError(Localizer["Api_BadRole"]));
            }

            var email = request.Email.Trim();
            var user = new AppUser
            {
                UserName = email,
                Email = email,
                HoTen = request.HoTen.Trim()
            };

            var created = await _userManager.CreateAsync(user, request.Password);
            if (!created.Succeeded)
            {
                return BadRequest(new ApiError(GopLoai(created)));
            }

            await _userManager.AddToRoleAsync(user, role);
            return await BuildAuthResult(user);
        }

        [HttpGet("me")]
        public async Task<ActionResult<AuthResult>> Me()
        {
            var user = await CurrentUserAsync();
            return user == null ? Unauthorized() : await BuildAuthResult(user);
        }

        [HttpPut("profile")]
        public async Task<ActionResult<ProfileDto>> UpdateProfile([FromBody] UpdateProfileRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            user.HoTen = request.HoTen.Trim();
            user.NgaySinh = request.NgaySinh;
            user.DiaChi = request.DiaChi;

            if (!string.IsNullOrWhiteSpace(request.SoDienThoai))
            {
                var phone = request.SoDienThoai.Trim();
                if (new System.ComponentModel.DataAnnotations.PhoneAttribute().IsValid(phone))
                {
                    await _userManager.SetPhoneNumberAsync(user, phone);
                }
                else
                {
                    return BadRequest(new ApiError(Localizer["Api_BadPhone"]));
                }
            }

            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded) return BadRequest(new ApiError(GopLoai(result)));

            return ToProfile(user, await _userManager.GetPhoneNumberAsync(user));
        }

        [HttpPost("avatar")]
        [Consumes("multipart/form-data")]
        public async Task<ActionResult<ProfileDto>> UploadAvatar(IFormFile file)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();
            if (file == null || file.Length == 0) return BadRequest(new ApiError(Localizer["Api_NoImageChosen"]));

            var tenFile = await LuuAnhAsync(file, Path.Combine(_env.WebRootPath, "images", "avatars"));
            user.Avatar = tenFile;
            await _userManager.UpdateAsync(user);

            return ToProfile(user, await _userManager.GetPhoneNumberAsync(user));
        }

        // eKYC: chụp 2 mặt CCCD gửi lên, server quét số CCCD bằng Tesseract rồi chuyển sang "Chờ duyệt"
        // giống hệt trang Hồ sơ của web. Admin sẽ duyệt ở màn hình quản trị.
        [HttpPost("cccd")]
        [Consumes("multipart/form-data")]
        public async Task<ActionResult<ProfileDto>> UploadCCCD(IFormFile? truoc, IFormFile? sau)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            if ((truoc == null || truoc.Length == 0) && (sau == null || sau.Length == 0))
            {
                return BadRequest(new ApiError(Localizer["Api_CccdImagesRequired"]));
            }

            var cccdFolder = Path.Combine(_env.WebRootPath, "images", "cccd");
            string? duongDanMatTruoc = null;

            if (truoc != null && truoc.Length > 0)
            {
                duongDanMatTruoc = await LuuAnhAsync(truoc, cccdFolder, "Truoc_");
                user.CCCDTruoc = duongDanMatTruoc;
            }
            if (sau != null && sau.Length > 0)
            {
                user.CCCDSau = await LuuAnhAsync(sau, cccdFolder, "Sau_");
            }

            user.TrangThaiXacThuc = "Chờ duyệt";

            if (duongDanMatTruoc != null)
            {
                user.SoCCCDQuetDuoc = QuetSoCCCD(Path.Combine(cccdFolder, duongDanMatTruoc));
            }

            await _userManager.UpdateAsync(user);
            return ToProfile(user, await _userManager.GetPhoneNumberAsync(user));
        }

        [HttpPost("change-password")]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
        {
            var user = await CurrentUserAsync();
            if (user == null) return Unauthorized();

            var result = await _userManager.ChangePasswordAsync(user, request.CurrentPassword, request.NewPassword);
            if (!result.Succeeded) return BadRequest(new ApiError(GopLoai(result)));

            // Token cũ vẫn còn hạn nên app phải xin token mới sau khi đổi mật khẩu.
            return Ok(await BuildAuthResult(user));
        }

        // ---------------------------------------------------------------------

        private async Task<AppUser?> CurrentUserAsync()
            => await _userManager.FindByIdAsync(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "");

        private async Task<AuthResult> BuildAuthResult(AppUser user)
        {
            var (token, expiresAt) = await _tokens.CreateTokenAsync(user);
            var roles = await _userManager.GetRolesAsync(user);

            return new AuthResult
            {
                Token = token,
                ExpiresAt = expiresAt,
                Roles = roles.ToList(),
                User = ToProfile(user, await _userManager.GetPhoneNumberAsync(user))
            };
        }

        private ProfileDto ToProfile(AppUser user, string? soDienThoai) => new()
        {
            Id = user.Id,
            Email = user.Email ?? user.UserName ?? "",
            HoTen = user.HoTen,
            Avatar = user.Avatar,
            SoDienThoai = soDienThoai,
            NgaySinh = user.NgaySinh,
            DiaChi = user.DiaChi,
            SoDu = user.SoDu,
            TrangThaiKhoa = user.TrangThaiKhoa,
            TrangThaiXacThuc = user.TrangThaiXacThuc,
            CCCDTruoc = user.CCCDTruoc,
            CCCDSau = user.CCCDSau,
            SoCCCDQuetDuoc = user.SoCCCDQuetDuoc
        };

        private static string GopLoai(IdentityResult result)
            => string.Join(" | ", result.Errors.Select(e => e.Description));

        private static async Task<string> LuuAnhAsync(IFormFile file, string thuMuc, string? themTienTo = null)
        {
            Directory.CreateDirectory(thuMuc);
            var tenFile = Guid.NewGuid() + "_" + themTienTo + Path.GetFileName(file.FileName);
            await using var stream = new FileStream(Path.Combine(thuMuc, tenFile), FileMode.Create);
            await file.CopyToAsync(stream);
            return tenFile;
        }

        private string? QuetSoCCCD(string duongDanAnh)
        {
            try
            {
                var tessData = Path.Combine(_env.WebRootPath, "tessdata");
                using var engine = new TesseractEngine(tessData, "eng", EngineMode.Default);
                using var img = Pix.LoadFromFile(duongDanAnh);
                using var page = engine.Process(img);
                var match = Regex.Match(page.GetText(), @"\b\d{12}\b");
                return match.Success ? match.Value : null;
            }
            catch
            {
                // Ảnh mờ hoặc không đọc được thì vẫn lưu CCCD, Admin sẽ tự nhìn ảnh.
                return null;
            }
        }
    }
}

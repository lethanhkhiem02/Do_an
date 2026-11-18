using System.Security.Claims;
using System.Text;
using Do_an_co_so.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Do_an_co_so.Services
{
    // Token cấp cho ứng dụng di động (Flutter). Web vẫn dùng cookie của Identity.
    public class TokenService
    {
        private readonly IConfiguration _configuration;
        private readonly UserManager<AppUser> _userManager;

        public TokenService(IConfiguration configuration, UserManager<AppUser> userManager)
        {
            _configuration = configuration;
            _userManager = userManager;
        }

        public async Task<(string Token, DateTime ExpiresAt)> CreateTokenAsync(AppUser user)
        {
            var jwt = _configuration.GetSection("Jwt");
            var roles = await _userManager.GetRolesAsync(user);

            var claims = new List<Claim>
            {
                // SignalR phân phát tin nhắn 1-1 qua Clients.User(userId) nên
                // NameIdentifier bắt buộc phải là Id của AppUser.
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(ClaimTypes.Name, user.UserName ?? user.Email ?? user.Id),
                new Claim("hoTen", user.HoTen ?? "")
            };
            claims.AddRange(roles.Select(role => new Claim(ClaimTypes.Role, role)));

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt["Key"]!));
            var lifetimeMinutes = int.TryParse(jwt["LifetimeMinutes"], out var m) ? m : 720;
            var expiresAt = DateTime.UtcNow.AddMinutes(lifetimeMinutes);

            var handler = new JsonWebTokenHandler();
            var token = handler.CreateToken(new SecurityTokenDescriptor
            {
                Issuer = jwt["Issuer"],
                Audience = jwt["Audience"],
                Subject = new ClaimsIdentity(claims),
                NotBefore = DateTime.UtcNow,
                Expires = expiresAt,
                SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256)
            });

            return (token, expiresAt);
        }
    }
}

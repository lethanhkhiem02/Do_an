using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Localization;

namespace Do_an_co_so.Api
{
    // Nền tảng cho mọi controller phục vụ app di động (Flutter).
    // Web của đồ án cơ sở vẫn xác thực bằng cookie Identity, còn app phải gửi
    // "Authorization: Bearer <token>" vì Android/iOS không giữ cookie session.
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    [Produces("application/json")]
    public abstract class ApiControllerBase : ControllerBase
    {
        protected ApiControllerBase(IStringLocalizer<SharedResource> localizer)
        {
            Localizer = localizer;
        }

        // Ngôn ngữ trả về do request quyết định: app gửi header "Accept-Language: en",
        // web gửi cookie ".AspNetCore.Culture". Không có cả hai thì mặc định tiếng Việt.
        protected IStringLocalizer<SharedResource> Localizer { get; }
    }
}

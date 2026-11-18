using Do_an_co_so.Data;
using Do_an_co_so.Hubs;
using Do_an_co_so.Models;
using Do_an_co_so.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using Microsoft.AspNetCore.Localization; // Thư viện để làm Đa ngôn ngữ
using System.Globalization; // Thư viện để nhận diện văn hóa/ngôn ngữ

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddSignalR();
// ==========================================
// 1. CẤU HÌNH DATABASE VÀ IDENTITY
// ==========================================

// Lấy chuỗi kết nối từ appsettings.json
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// Đăng ký ApplicationDbContext với SQL Server
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(connectionString));

// Đăng ký Identity để quản lý User, Role và Phân quyền
builder.Services.AddIdentity<AppUser, IdentityRole>(options => {
    // Tùy chỉnh độ khó của mật khẩu
    options.Password.RequireDigit = false;
    options.Password.RequireLowercase = false;
    options.Password.RequireNonAlphanumeric = false;
    options.Password.RequireUppercase = false;
    options.Password.RequiredLength = 6;

    // Không bắt buộc xác nhận email
    options.SignIn.RequireConfirmedAccount = false;
})
.AddDefaultUI()
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();

// =======================================================
// 1b. XÁC THỰC BẰNG JWT CHO ỨNG DỤNG DI ĐỘNG (ROOMFINDER APP)
// =======================================================
// Web (đồ án cơ sở) vẫn dùng cookie của Identity như cũ.
// App mobile gọi các route /api/* và /api/* kèm "Authorization: Bearer <token>",
// nên chỉ những controller khai báo AuthenticationSchemes = "Bearer" mới dùng scheme này.
var jwtSection = builder.Configuration.GetSection("Jwt");
var jwtKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSection["Key"]
    ?? throw new InvalidOperationException("Thiếu Jwt:Key trong appsettings.json")));

builder.Services.AddAuthentication()
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtSection["Issuer"],
            ValidAudience = jwtSection["Audience"],
            IssuerSigningKey = jwtKey,
            ClockSkew = TimeSpan.FromMinutes(1)
        };

        // SignalR không tự gắn header khi bắt tay (handshake), nên app gửi
        // token qua ?access_token=... cho hub /chatHub.
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(accessToken)
                    && context.HttpContext.Request.Path.StartsWithSegments("/chatHub"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

// App Flutter chạy trên máy ảo Android (10.0.2.2) và bản debug trên trình duyệt
// cần được phép gọi sang backend.
const string MobileCorsPolicy = "AllowRoomFinderApp";
builder.Services.AddCors(options =>
{
    options.AddPolicy(MobileCorsPolicy, policy =>
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials()); // SignalR dùng credentials khi nối qua websockets
});

// =======================================================
// BƯỚC 1: CẤU HÌNH DỊCH VỤ ĐA NGÔN NGỮ (LOCALIZATION)
// =======================================================
// Báo cho hệ thống biết các file "Từ điển" (.resx) sẽ nằm trong thư mục tên là "Resources"
builder.Services.AddLocalization(options => options.ResourcesPath = "Resources");

// Bật tính năng dịch ngôn ngữ cho Controllers và Views
builder.Services.AddControllersWithViews()
    .AddViewLocalization(Microsoft.AspNetCore.Mvc.Razor.LanguageViewLocationExpanderFormat.Suffix)
    .AddDataAnnotationsLocalization(); // Bật dịch luôn cả các thông báo lỗi (vd: Vui lòng nhập giá...)
// =======================================================

// THÊM DÒNG NÀY ĐỂ HỖ TRỢ RAZOR PAGES CỦA IDENTITY
builder.Services.AddRazorPages();

// Dịch vụ dùng riêng cho tầng API của app di động
builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<RoomQueryService>();

// Máy dịch mô tả/địa chỉ phòng sang tiếng Anh, kết quả lưu lại trong bảng DichNoiDung.
builder.Services.AddScoped<NoiDungDichService>();
builder.Services.AddHttpClient("translate", client => client.Timeout = TimeSpan.FromSeconds(8));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

// Không ép chuyển HTTP -> HTTPS cho các route của app (app mobile và máy ảo
// Android gọi thẳng http://10.0.2.2:5295 và sẽ hỏng nếu bị redirect 307 sang https).
app.UseWhen(
    context => !context.Request.Path.StartsWithSegments("/api")
            && !context.Request.Path.StartsWithSegments("/chatHub"),
    branch => branch.UseHttpsRedirection());
app.UseRouting();
app.UseCors(MobileCorsPolicy);

// =======================================================
// BƯỚC 1: KÍCH HOẠT ĐƯỜNG ỐNG ĐA NGÔN NGỮ KHI WEB CHẠY
// =======================================================
// Đăng ký 2 ngôn ngữ: Tiếng Việt (vi-VN) và Tiếng Anh (en-US)
var supportedCultures = new[]
{
    new CultureInfo("vi-VN"), // Mặc định là Tiếng Việt
    new CultureInfo("en-US")
};

app.UseRequestLocalization(new RequestLocalizationOptions
{
    DefaultRequestCulture = new RequestCulture("vi-VN"),
    SupportedCultures = supportedCultures,
    SupportedUICultures = supportedCultures
});
// =======================================================

// tầng API của app luôn nhận số theo chuẩn quốc tế (10.8018 / 2500000.5).
// Nếu không có dòng này, bộ định tuyến văn hóa vi-VN phía trên sẽ coi dấu "."
// là dấu phân cách hàng nghìn và làm sai tọa độ, diện tích khi đăng phòng.
// Chỉ đổi CurrentCulture (dùng lúc bind số), giữ nguyên CurrentUICulture để
// IStringLocalizer còn đọc được Accept-Language mà app gửi lên.
app.Use(async (context, next) =>
{
    if (context.Request.Path.StartsWithSegments("/api"))
    {
        CultureInfo.CurrentCulture = CultureInfo.InvariantCulture;
    }

    await next();
});
// =======================================================

// 2. MIDDLEWARE XÁC THỰC VÀ PHÂN QUYỀN
app.UseAuthentication();
app.UseAuthorization();

app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();

// THÊM DÒNG NÀY ĐỂ ĐỊNH TUYẾN ĐƯỜNG DẪN CHO CÁC TRANG IDENTITY
app.MapRazorPages();

// ==========================================
// 2. TẠO TÀI KHOẢN ADMIN VÀ CÁC QUYỀN (ROLES) MẶC ĐỊNH
// ==========================================
using (var scope = app.Services.CreateScope())
{
    var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();
    var userManager = scope.ServiceProvider.GetRequiredService<UserManager<AppUser>>();

    // 1. Khởi tạo 3 nhóm quyền cho đồ án
    string[] roleNames = { "Admin", "ChuTro", "SinhVien" };
    foreach (var roleName in roleNames)
    {
        if (!await roleManager.RoleExistsAsync(roleName))
        {
            await roleManager.CreateAsync(new IdentityRole(roleName));
        }
    }

    // 2. Tạo tài khoản Admin mặc định
    string adminEmail = "admin@gmail.com";
    string adminPass = "admin123"; // Mật khẩu đăng nhập của Admin

    if (await userManager.FindByEmailAsync(adminEmail) == null)
    {
        var adminUser = new AppUser
        {
            UserName = adminEmail,
            Email = adminEmail,
            HoTen = "Quản Trị Viên Hệ Thống"
        };

        var result = await userManager.CreateAsync(adminUser, adminPass);
        if (result.Succeeded)
        {
            // Gán quyền Admin cho tài khoản vừa tạo
            await userManager.AddToRoleAsync(adminUser, "Admin");
        }
    }
}
// ==========================================
app.MapHub<ChatHub>("/chatHub");
app.Run();
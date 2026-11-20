# Do_an — RoomFinder (backend ASP.NET Core + app Flutter)

Repo monorepo của đồ án chuyên ngành: quản lý phòng trọ cho sinh viên.

| Thư mục | Nội dung | Chạy bằng |
|---|---|---|
| `backend/` | `Do_an_co_so.csproj` + `Do_an_co_so.slnx`: trang web MVC cũ, API JWT, SignalR chat, CSDL SQL Server | Visual Studio 2022 |
| `app/` | App di động Flutter, tiêu thụ API của `backend` (hướng dẫn chi tiết: `app/README.md`) | VS Code + Android emulator |

## Cài đặt từ đầu

1. **Yêu cầu**: .NET SDK **10** (`Do_an_co_so.csproj` đặt `TargetFramework = net10.0`; SDK 8 build không được), SQL Server Express (LocalDB cũng được), Visual Studio 2022 (workload ASP.NET), Flutter SDK + Android Studio.
2. **Sửa chuỗi kết nối** trong `backend/appsettings.json` — `Server=<TÊN_MAY>\<INSTANCE>` là máy và instance SQL **của người chạy**, không phải cổng. Giá trị trong repo trỏ tới máy người viết:
   ```
   Server=<TEN_MAY_BAN>\<INSTANCE>;Database=QuanLyPhongTro;Trusted_Connection=True;TrustServerCertificate=True
   ```
   Không commit lại dòng này kèm tên máy của mình — mỗi máy một chuỗi. Nếu muốn giữ nguyên file trong repo, đặt biến môi trường khi chạy thay vì sửa file:
   `$env:ConnectionStrings__DefaultConnection="Server=<MAY>\<INSTANCE>;Database=QuanLyPhongTro;Trusted_Connection=True;TrustServerCertificate=True"`
3. **Tạo CSDL** (app không tự migrate lúc khởi động):
   ```
   dotnet tool install --global dotnet-ef
   dotnet ef database update --project backend
   ```
   hoặc Package Manager Console: `Update-Database`.
4. **Chạy backend** với profile `mobile` để bind đúng cổng app mong đợi (`http://localhost:5295`):
   ```
   dotnet run --project backend --launch-profile mobile
   ```
5. **Chạy app**:
   ```
   cd app
   flutter pub get
   flutter run -d emulator-5554
   ```
   Mặc định app gọi `http://10.0.2.2:5295` (địa chỉ máy Windows nhìn từ máy ảo Android). Chạy trên điện thoại thật thì truyền IP LAN:
   `flutter run --dart-define=API_BASE_URL=http://192.168.1.23:5295`

## Tài khoản và dữ liệu có sẵn

`Program.cs` chỉ tự tạo **Admin** khi chạy lần đầu: `admin@gmail.com` / `admin123`. Sinh viên và chủ trọ đăng ký qua app. CSDL trong repo là CSDL trống — phòng demo, ảnh, đánh giá và dữ liệu tiện ích của người viết không nằm trong git, mỗi máy tự tạo dữ liệu của mình.

## Loại hình phòng & tiện ích xung quanh

- Mỗi phòng có `LoaiHinh` (`PhongRieng` / `KyTucXa`), hiển thị ở badge và bộ lọc.
- Tab "Tiện ích xung quanh" vẽ vòng tròn bán kính + 5 nhóm (xe buýt, siêu thị, cà phê, cây xăng, tiện lợi) từ bảng `TienIchXungQuanh`.
- Vòng tròn chỉ hiện sau khi quét: `POST /api/phong-tro/{id}/tien-ich/quet` (chỉ Admin hoặc chủ phòng đó; trên app là nút "Quét lại"). Một lần quét mất 30-50 s vì server hỏi Overpass API.
- Overpass công cộng hay trả **503** khi bị gọi dày; gặp thông báo "Dịch vụ bản đồ không phản hồi" thì chờ một phút rồi bấm lại.

## Quy ước làm việc

- Không đổi tên `Do_an_co_so.csproj`, `Do_an_co_so.slnx` hay thư mục `backend`.
- `Jwt:Key` và `GeminiApiKey` trong repo là placeholder/rỗng. Mỗi thành viên lấy key của mình từ trưởng nhóm và khai báo trên máy cá nhân, không đưa key vào commit.
- Đặt email git trùng email đã verify trên GitHub để commit được gắn vào tài khoản: `git config --global user.email "<email GitHub>"`.
- Build Flutter lần đầu báo lỗi liên quan file Gradle/CMake: phần mềm diệt virus khoá file vừa sinh — thêm thư mục repo vào danh sách loại trừ rồi build lại.

# RoomFinder - Đồ án chuyên ngành (app di động)

Repo này là **frontend**. Toàn bộ logic nghiệp vụ, CSDL và trang web vẫn nằm ở đồ án cơ sở.

## Phân công công cụ

| Công cụ | Vai trò | Thư mục |
|---|---|---|
| **Visual Studio (màu tím)** | **Backend** - ASP.NET Core MVC + API REST + SignalR + SQL Server | `C:\DACS\Do_an_co_so` |
| **VS Code (màu xanh)** | **Frontend** - app Flutter gọi API của backend | `C:\DACN\do_an_chuyen_nganh` |
| Android Studio | Máy ảo / thiết bị thật để chạy app | - |

App không có CSDL riêng. Mọi thao tác (đăng nhập, tìm trọ, đặt cọc, chat, duyệt CCCD)
đều gửi HTTP tới backend qua `/api/*` và nhận realtime qua Hub `/chatHub`.

## Chạy dự án

### 1. Backend (Visual Studio)

Mở `C:\DACS\Do_an_co_so\Do_an_co_so.slnx`, chọn profile **`mobile`** rồi chạy (Ctrl+F5),
hoặc chạy bằng lệnh:

```powershell
cd C:\DACS\Do_an_co_so
dotnet run --launch-profile mobile
```

Profile `mobile` bind `http://localhost:5295` (chỉ HTTP, không HTTPS) để máy ảo Android
gọi được mà không cần cài certificate. Trang web demo vẫn chạy bình thường ở profile `http`/`https`.

### 2. App (VS Code)

```powershell
cd C:\DACN\do_an_chuyen_nganh
flutter pub get
flutter run
```

Mặc định app trỏ tới `http://10.0.2.2:5295` - địa chỉ máy Windows chủ nhìn từ máy ảo Android.

**Chạy trên máy thật / đổi địa chỉ backend** (2 máy phải cùng mạng LAN, và backend vẫn phải
chạy ở `0.0.0.0:5295`, firewall cho phép cổng này):

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:5295
```

Địa chỉ đang dùng hiển thị ở cuối màn **Cá nhân**, để kiểm tra nhanh khi app không gọi được API.

## Cấu trúc thư mục frontend

```
lib/
  core/            # hạ tầng: AppConfig, ApiClient (JWT), Session, SignalRChat, ThanhToan, Fmt
  models/          # các lớp dữ liệu khớp JSON của API
  features/
    auth/          # đăng nhập, đăng ký (chọn vai trò Sinh viên / Chủ trọ)
    rooms/         # tìm trọ + bản đồ, chi tiết phòng, đăng phòng, quản lý phòng, phòng đã thuê
    chat/          # tin nhắn 1-1 (SignalR), chat cộng đồng
    profile/       # hồ sơ, avatar, CCCD/eKYC, đổi mật khẩu, ví + nạp tiền
    admin/         # quản lý người dùng, duyệt CCCD, báo cáo vi phạm
  shell/           # thanh điều hướng theo vai trò
  widgets/         # thẻ phòng, ảnh, bản đồ, trạng thái
```

## API mà app dùng (backend `C:\DACS\Do_an_co_so\Api`)

| Nhóm | Endpoint | Ghi chú |
|---|---|---|
| Xác thực | `POST /api/auth/login`, `/register`, `GET /api/auth/me`, `PUT /api/auth/profile`, `POST /api/auth/avatar`, `/api/auth/cccd`, `/api/auth/change-password` | JWT Bearer, token sống 720 phút, lưu trong SharedPreferences |
| Phòng trọ | `GET /api/phong-tro/danh-sach`, `/tim-kiem`, `/truong`, `/{id}`, `/chu-tro/{userId}`, `/quan-ly`, `/phong-da-thue`, `POST /api/phong-tro` (multipart), `DELETE /api/phong-tro/{id}`, `/{id}/xac-nhan-cho-thue`, `/{id}/mo-lai`, `/{id}/danh-gia`, `/{id}/bao-cao` | Tìm kiếm theo trường + bán kính dùng Haversine, tin VIP ưu tiên |
| Thanh toán | `POST /api/thanhtoan/thue-phong/{id}`, `/dat-coc/{id}`, `/phan-con-lai/{id}`, `/nap-tien`, `/huy-coc/{id}`, `GET /api/thanhtoan/vi`, `/trang-thai-phong/{id}` | App mở link VNPay bằng trình duyệt rồi poll `trang-thai-phong` |
| Chat | `GET /api/chat/hoi-thoai`, `/lich-su/{userId}`, `/chat-tong`, `POST /api/chat/gui`, `/chat-tong`, `/upload-anh`, `/bao-cao-nguoi-dung` | Kèm Hub `/chatHub` (JWT qua query `access_token`) |
| Admin | `GET /api/admin/nguoi-dung`, `/bao-cao`, `POST .../khoa`, `.../duyet-cccd`, `.../da-xu-ly`, `DELETE .../nguoi-dung/{id}` | Chỉ tài khoản role `Admin` |

Web (cookie Identity) và app (JWT Bearer) dùng song song, không ảnh hưởng nhau.

## Tài khoản test

Tạo từ trang web hoặc màn đăng ký của app. Role `Admin` chỉ có ở tài khoản seed trong
`Program.cs` (`admin@gmail.com`), app không cho tự đăng ký Admin.

## Kiểm tra nhanh

```powershell
flutter analyze
flutter test
flutter build apk --debug   # APK: build\app\outputs\flutter-apk\app-debug.apk
```

## Khác biệt so với bản web (chủ đích, không phải lỗi)

- App **chưa** có chat trợ lý AI (`ChatWithAI`) và chưa có chuyển ngôn ngữ vi/en - hai tính năng
  này chỉ tồn tại trên web.
- Thanh toán VNPay phải mở trình duyệt (không có deep link về app), nên app **chờ và hỏi lại**
  backend trạng thái giao dịch trong tối đa ~2 phút.
- Gói `signalr` trên pub.dev chưa hỗ trợ null safety, vì vậy app dùng client SignalR tự viết
  trên WebSocket (`lib/core/signalr_chat.dart`), nói chuyện trực tiếp với Hub của web.
- Ảnh đại diện/CCCD/tin nhắn dùng lại đường dẫn web đang lưu (`/images/...`, `/uploads/chat-images/...`).

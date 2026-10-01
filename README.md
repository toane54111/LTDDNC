# Trọ An — Đồ án Lập trình di động nâng cao

Ứng dụng quản lý nhà trọ bằng **Flutter**, API bằng **Dart**, dữ liệu chính dùng **MySQL**. **Sqflite** lưu bản nháp điện nước trên điện thoại.

Được chuyển từ project của nhóm: https://github.com/toane54111/QuanLyPhongTro_DesignPattern.

## Chạy ngay trên máy hiện tại

- APK debug: `build/app/outputs/flutter-apk/app-debug.apk`.
- Xem thử giao diện: http://localhost:5173 (khi preview server đang chạy).
- API: http://localhost:8080.
- MySQL riêng của project: `127.0.0.1:3307`, database `rental_flutter`, dữ liệu ở `runtime/mysql`.
- Tài khoản chủ trọ: xem `ADMIN_EMAIL` và `ADMIN_PASSWORD` trong `.env`. Mật khẩu được tạo ngẫu nhiên, không đưa vào Git.
- MySQL sẵn có trên cổng 3306 không bị thay đổi.

Nếu đã tắt các tiến trình, mở ba terminal từ thư mục project:

```powershell
# Terminal 1: khởi động instance MySQL riêng đã khởi tạo trên máy này
./scripts/start-local-mysql.ps1

# Terminal 2: API (giữ terminal này mở)
./scripts/start-api.ps1

# Terminal 3: giao diện web đã build (giữ terminal này mở)
./scripts/start-preview.ps1
```

Chế độ **Xem vai trò chủ trọ / Xem khách thuê** trên màn hình đăng nhập chỉ dùng dữ liệu mẫu. Thêm/sửa dữ liệu cần đăng nhập vào API thật.

Sau khi đăng nhập lần đầu: **Tiện ích → Khu trọ → Phòng trọ → Khách thuê → Hợp đồng → Điện nước → Hóa đơn**. Bảng giá Điện, Nước, Internet và Vệ sinh đã được khởi tạo.

## Thiết lập trên máy khác

Yêu cầu Flutter tương thích Dart 3.13+, MySQL 8.x; có thể dùng Docker Compose.

1. Sao chép `.env.example` thành `.env`, thay mật khẩu.
2. Chọn một cách chạy MySQL:
   - MySQL có sẵn: tạo database `rental_flutter` và user riêng, cấp quyền trên database đó; chỉnh `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`.
   - Docker: `docker compose up -d` từ thư mục gốc. Cổng mặc định của compose là 3306; nếu đã có MySQL tại cổng này, đổi cổng publish và `DB_PORT` tương ứng. Không dùng Docker cùng lúc với MySQL khác trên cùng cổng.
3. Khởi tạo bảng và chủ trọ:

```powershell
cd server
dart pub get
dart run bin/setup.dart
dart run bin/server.dart
```

API đọc `.env` ở thư mục gốc khi chạy từ `server`; biến môi trường được ưu tiên. Dùng TLS MySQL mặc định để hỗ trợ xác thực MySQL 8. Không chạy `bootstrap_local.dart` trên instance khác; script đó chỉ dành cho instance riêng vừa khởi tạo trắng ở cổng 3307.

4. Chạy Flutter từ thư mục gốc:

```powershell
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

- Android emulator: dùng `10.0.2.2`.
- Web: dùng `http://localhost:8080`; chạy `flutter run -d chrome --web-port=5173 --dart-define=API_URL=http://localhost:8080` để khớp CORS.
- Điện thoại thật: dùng IP LAN của máy chạy API và cấu hình `HOST=0.0.0.0`, đồng thời cho phép cổng API qua firewall. Chỉ dùng cấu hình này khi cần thử trên mạng LAN tin cậy.
- iOS Simulator: dùng `localhost`. iOS camera/PDF/sqflite chưa được kiểm tra trên máy Windows này.
- HTTP nội bộ được bật ở Android **debug**; bản release cần API HTTPS.
- Token đăng nhập giữ trong bộ nhớ, không ghi xuống sqflite. Mở lại app cần đăng nhập lại.

## Các phần chính

- Chủ trọ/khách thuê, hồ sơ, mật khẩu, khóa tài khoản.
- Khu, phòng, khách thuê, thành viên và tài sản.
- Hợp đồng tối thiểu 6 tháng; thu cọc; gia hạn; phụ lục; yêu cầu trả phòng.
- Điện nước, dịch vụ, lập hóa đơn đơn lẻ/hàng loạt, xem trước kết quả.
- Thu từng phần, báo chuyển khoản, xác nhận/từ chối giao dịch.
- Báo sự cố kèm ảnh, theo dõi xử lý, thông báo trong app.
- Thống kê thu chi, xuất/in PDF tiếng Việt.
- Nháp điện nước dùng sqflite, lưu riêng theo tài khoản và máy chủ; chỉ xóa nháp sau khi lưu lên API thành công.

`ENABLE_ONLINE_DEMO=true` chỉ bật **mô phỏng online**, không thu tiền thật. Bản `.env` cục bộ được tạo cho đồ án đã bật chế độ này; `.env.example` mặc định tắt.

## Cấu trúc

```text
lib/src/                  Giao diện Flutter, state/repository, sqflite, PDF
packages/rental_domain/   Metadata biểu mẫu, enum, validation dùng chung
server/lib/               Kết nối MySQL, phân quyền, nghiệp vụ
server/bin/               API, khởi tạo database, preview
server/database/          Schema MySQL 15 bảng từ project gốc
server/test/              Kiểm thử API + MySQL
scripts/                  Lệnh khởi động trên Windows
reference/                Hai repo gốc/tham khảo, bỏ qua khi đưa lên Git
```

SQL ghi dữ liệu được giới hạn theo metadata; dữ liệu đầu vào dùng tham số; các luồng hợp đồng/thanh toán/duyệt dùng transaction và khóa hàng. Không đưa tài khoản MySQL vào ứng dụng Flutter.

## Kiểm thử và build

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build web

cd server
dart analyze
$env:RUN_MYSQL_TESTS='true'
dart test
```

Kiểm thử MySQL cần chạy `setup.dart` trước. Fixtures nghiệp vụ rollback sau mỗi bài; kiểm thử API dùng tài khoản chủ trọ trong `.env`. Không đặt `RUN_MYSQL_TESTS` sẽ bỏ qua các bài tích hợp và chỉ kiểm thử validation.

Windows: nếu project ở ổ D và Pub cache ở ổ C, đã tắt Kotlin incremental compilation trong `android/gradle.properties` để tránh lỗi đường dẫn khác ổ. Plugin desktop có thể yêu cầu Windows Developer Mode; đây không phải yêu cầu để dùng APK đã build.

## Mức độ tương đương project cũ

Xem [bảng đối chiếu và các khác biệt còn lại](docs/PARITY.md). **Chưa gọi là clone 100% đã nghiệm thu**: cần kiểm thử camera/sqflite/in PDF trên thiết bị và đối chiếu các biểu đồ, mẫu in, luồng kết hợp của web cũ.

Nguồn giao diện GitHub và giấy phép font được ghi trong [UI_SOURCES.md](docs/UI_SOURCES.md).

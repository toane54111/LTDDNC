# Chạy Trọ An từ đầu

Ứng dụng Flutter, backend Dart, MySQL lưu nghiệp vụ; Firebase bổ sung đăng nhập Google, chat, ảnh, thông báo và Crashlytics. Sqflite lưu nháp điện nước trên điện thoại. Không cần backend Kotlin.

## A. Chạy lại trên máy đã được thiết lập

Mở PowerShell tại `D:\Toane\lttd\ck`. Máy này đã có `.env`, khóa Firebase, MySQL riêng cổng 3307 và bản build web. Nếu dịch vụ đang chạy, không khởi động thêm một bản.

1. Khởi động MySQL:

```powershell
./scripts/start-local-mysql.ps1
```

2. Mở ba terminal khác, mỗi terminal ở thư mục project, chạy lần lượt và giữ mở:

```powershell
# Terminal API
./scripts/start-api.ps1
```

```powershell
# Terminal gửi thông báo, nhắc hạn hóa đơn: chỉ chạy một worker
./scripts/start-firebase-worker.ps1
```

```powershell
# Terminal xem bản web đã build
./scripts/start-preview.ps1
```

3. Mở http://localhost:5173. Đăng nhập `admin@troan.local`, mật khẩu xem `ADMIN_PASSWORD` trong `.env`. Các nút xem vai trò mẫu không đăng nhập API thật.

Nếu PowerShell chặn script, có thể mở terminal bằng `powershell -ExecutionPolicy Bypass -File .\scripts\start-api.ps1` (thay tên script tương ứng). Không cần thay chính sách toàn máy.

## B. Thiết lập trên máy mới

### 1. Công cụ và mã nguồn

- Git; Flutter có Dart **3.13.1 trở lên trong nhánh 3.x** theo `pubspec.yaml` (máy đã kiểm tra dùng Flutter 3.47.1).
- Android Studio và Android SDK nếu chạy Android; Chrome nếu chạy web.
- MySQL 8.x hoặc Docker Desktop với Compose.
- Node/Java chỉ cần khi dùng CLI hoặc kiểm thử Firebase Emulator; backend chạy bằng Dart.

```powershell
git clone https://github.com/toane54111/LTDDNC.git
cd LTDDNC
flutter doctor
flutter pub get
Copy-Item .env.example .env
```

Chỉ sao chép `.env.example` ở lần cài mới; không ghi đè `.env` đã cấu hình. Mở `.env`, đặt mật khẩu MySQL và chủ trọ riêng. `ADMIN_PASSWORD` phải ít nhất 8 ký tự. `ENABLE_ONLINE_DEMO=true` bật thanh toán mô phỏng, không thu tiền thật.

### 2. MySQL: chọn một cách

**Docker:** giữ `DB_HOST=127.0.0.1`, `DB_PORT=3306`, `DB_NAME=rental_flutter`, `DB_USER=rental`; điền `DB_PASSWORD` và `MYSQL_ROOT_PASSWORD` trong `.env`.

```powershell
docker compose up -d
docker compose ps
```

Chờ MySQL báo healthy. Nếu 3306 đã có dịch vụ, đổi cổng bên trái của mapping trong `compose.yaml` thành cổng trống, ví dụ `127.0.0.1:3307:3306`, rồi đặt `DB_PORT=3307`. Mật khẩu trong `.env` dùng khi khởi tạo volume mới; đổi `.env` không tự đổi mật khẩu database đã tồn tại.

**MySQL cài sẵn:** đăng nhập bằng tài khoản quản trị trong MySQL Workbench hoặc MySQL CLI, chạy SQL sau với mật khẩu tự chọn, rồi đặt các giá trị tương ứng trong `.env`:

```sql
CREATE DATABASE rental_flutter CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'rental'@'localhost' IDENTIFIED BY 'THAY_BANG_MAT_KHAU_RIENG';
GRANT ALL PRIVILEGES ON rental_flutter.* TO 'rental'@'localhost';
```

Giữ `DB_TLS=true`. Script `start-local-mysql.ps1` chỉ dành cho dữ liệu riêng đã khởi tạo trên máy hiện tại; không phải script cài MySQL cho máy mới. Không dùng `bootstrap_local.dart` cho database có sẵn.

### 3. Firebase

Repo đã có cấu hình công khai Android/Web cho `ltddnc-ac280` và rules đã triển khai. Máy mới vẫn cần khóa backend riêng, vì `.env` và khóa bí mật không nằm trên GitHub.

1. Thành viên được cấp quyền project lấy khóa service account backend theo [FIREBASE.md](FIREBASE.md), lưu tại `secrets/firebase-service-account.json`. Account backend cần quyền Firestore User và Firebase Cloud Messaging Admin.
2. Đặt `FIREBASE_SERVICE_ACCOUNT` trong `.env` thành đường dẫn tuyệt đối tới file đó; dùng dấu `/` trong đường dẫn Windows.
3. Đặt `FIREBASE_WEB_API_KEY` bằng `apiKey` của cấu hình **web** trong `lib/firebase_options.dart`, cùng project Firebase.
4. Android trên máy mới có chứng chỉ debug riêng: thêm SHA-1/SHA-256 của máy đó vào Android app `com.example.ck` trên Firebase nếu muốn dùng Google Sign-In. Xem chi tiết trong [FIREBASE.md](FIREBASE.md).

Không cần tạo lại Firebase project của nhóm. Nếu dùng project khác, làm đầy đủ các bước FlutterFire, Auth, Firestore, Storage và triển khai rules trong tài liệu Firebase. Không đưa file private key vào ứng dụng hoặc Git.

### 4. Khởi tạo bảng và tài khoản

Từ thư mục gốc:

```powershell
cd server
dart pub get
dart run bin/setup.dart
cd ..
```

Lệnh tạo bảng nghiệp vụ, bảng Firebase, tài khoản chủ trọ và giá dịch vụ mẫu. Với database của bản cũ chỉ cần bổ sung Firebase, dùng `dart run bin/firebase_migrate.dart` từ `server`. Không chạy setup với email khác chỉ để đổi email tài khoản cũ, vì có thể tạo thêm chủ trọ.

### 5. Khởi động API và worker

Mở hai terminal từ thư mục gốc và giữ chạy:

```powershell
# Terminal 1
./scripts/start-api.ps1
```

```powershell
# Terminal 2
./scripts/start-firebase-worker.ps1
```

Trên macOS/Linux, chạy `dart run bin/server.dart` và `dart run bin/firebase_worker.dart` ở hai terminal trong thư mục `server`.

### 6. Chạy Flutter: chọn nền tảng

**Web khi phát triển**, từ thư mục gốc:

```powershell
flutter run -d chrome --web-port=5173 --dart-define=API_URL=http://localhost:8080
```

Giữ `CORS_ORIGIN=http://localhost:5173` trong `.env`. Không chạy preview server và `flutter run` cùng cổng 5173.

**Web bản build**, thay cho lệnh trên:

```powershell
flutter build web --dart-define=API_URL=http://localhost:8080
./scripts/start-preview.ps1
```

**Android emulator:** mở máy ảo trong Android Studio, xem ID bằng `flutter devices`, thay `EMULATOR_ID` dưới đây bằng ID thật:

```powershell
flutter devices
flutter run -d EMULATOR_ID --dart-define=API_URL=http://10.0.2.2:8080
```

**Điện thoại Android thật:** kết nối USB, bật USB debugging và chấp nhận kết nối; điện thoại và máy chủ cùng mạng LAN. Đặt `HOST=0.0.0.0` trong `.env`, khởi động lại API, cho phép cổng 8080 qua firewall trên mạng riêng. Lấy IPv4 của máy bằng `ipconfig`; thay `192.168.1.10` và `PHONE_ID` bằng giá trị thật:

```powershell
flutter run -d PHONE_ID --dart-define=API_URL=http://192.168.1.10:8080
```

Build APK debug cho điện thoại dùng cùng địa chỉ API:

```powershell
flutter build apk --debug --dart-define=API_URL=http://192.168.1.10:8080
```

APK ở `build/app/outputs/flutter-apk/app-debug.apk`. API_URL được đóng vào bản build: chuyển mạng/IP cần build lại. APK mặc định dùng địa chỉ emulator `10.0.2.2`, không phải IP LAN của máy. HTTP chỉ được bật cho Android debug; bản release cần API HTTPS. iOS cần macOS và cấu hình Firebase/APNs riêng, chưa kiểm thử trong môi trường Windows này.

## C. Kiểm tra và demo

Khi MySQL và API đã chạy, mở terminal mới:

```powershell
cd server
dart run bin/firebase_check.dart
```

Phải thấy các dòng PASS cho đăng nhập API/Firebase, Firestore, Storage và FCM. Công cụ tự xóa ảnh/document kiểm tra; FCM chỉ xác thực quyền, không gửi push thật.

Đăng nhập bằng email/mật khẩu trong `.env`, rồi tạo dữ liệu theo thứ tự: **Khu trọ → Phòng → Khách thuê → Hợp đồng → Điện nước → Hóa đơn**. Kiểm tra ảnh phòng/đại diện, sự cố, Tiện ích → Tin nhắn. Trên điện thoại, bật thông báo trong Tài khoản; cần worker chạy để nhận push từ nghiệp vụ.

Đăng nhập Google cần liên kết lần đầu từ tài khoản đang đăng nhập mật khẩu, và email MySQL phải trùng Gmail. `admin@troan.local` chưa thể liên kết Gmail; xem cách chuẩn bị tài khoản tại [FIREBASE.md](FIREBASE.md). Push thực tế, Crashlytics, camera, sqflite và in PDF cần kiểm tra trên thiết bị.

## D. Lỗi thường gặp

| Hiện tượng | Kiểm tra |
| --- | --- |
| App không gọi được API | API còn chạy, API_URL đúng nền tảng, cổng/firewall và cùng mạng khi dùng điện thoại |
| Cổng đang được sử dụng | Dùng tiến trình đang chạy hoặc dừng đúng tiến trình đó; không mở thêm bản API/preview/worker |
| Không kết nối được MySQL | Dịch vụ MySQL, DB_PORT, user/password và database trong `.env` |
| Firebase chưa kết nối | Đường dẫn service account, Web API key cùng project; khởi động lại API và worker sau khi sửa `.env` |
| Google login thất bại | Đã liên kết cùng email, Google provider bật, domain localhost và SHA debug đúng máy |
| Không nhận push | Dùng Android, cấp quyền, đăng ký thiết bị trong Tài khoản và chạy worker; web của bản này không hỗ trợ FCM |
| Web vẫn hiện bản cũ | Build web lại sau khi sửa mã, tải lại trang |
| Đăng nhập lại sau khi mở app | Token chỉ giữ trong bộ nhớ; đây là hành vi hiện tại |

Khi ngừng demo, nhấn Ctrl+C ở các terminal ứng dụng. Với MySQL Docker dùng `docker compose stop`; dữ liệu vẫn ở volume. Không xóa volume hoặc thư mục dữ liệu để xử lý lỗi đăng nhập.

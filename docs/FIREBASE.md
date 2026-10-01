# Firebase cho Trọ An

## Phần đã tích hợp

- FCM trên Android/iOS: hóa đơn, xác nhận thanh toán, sự cố và tin nhắn; thông báo trong ứng dụng khi đang mở, mở hộp thông báo khi chạm push.
- Firestore: chat chủ trọ–khách thuê, cập nhật trực tiếp, dấu chưa đọc, 100 tin nhắn gần nhất; lịch sử cũ vẫn lưu trên Firestore.
- Storage: ảnh phòng, ảnh đại diện, ảnh sự cố JPEG/PNG nhỏ hơn 3 MB.
- Firebase Auth: Google Sign-In và custom token liên kết danh tính MySQL.
- Crashlytics: lỗi Flutter và lỗi không bắt được trên Android/iOS. Web không hỗ trợ Crashlytics.

## Cấu hình đang dùng trên máy này — 01/10/2026

Project `ltddnc-ac280` (LTDDNC), Firestore `(default)` tại `asia-southeast1`, bucket `ltddnc-ac280.firebasestorage.app`. Google provider đã bật, localhost đã được cho phép. Android `com.example.ck` đã đăng ký SHA-1/SHA-256 debug; Android/Web đã có cấu hình FlutterFire thật và plugin Crashlytics.

Backend dùng service account `tro-an-api` với quyền Firestore User và Firebase Cloud Messaging Admin. Khóa ở `secrets/firebase-service-account.json`, đường dẫn và Web API key đã ghi vào `.env`; cả khóa và `.env` đều bị Git ignore. Rules đã triển khai lên project thật.

Đã kiểm tra custom authentication, truy vấn Firestore theo thành viên, quyền ghi Firestore của backend, upload Storage theo rules và FCM validate-only. Chưa xác minh push đến thiết bị hoặc báo cáo Crashlytics, vì chưa có điện thoại/emulator Android chạy. Google provider đã cấu hình nhưng người dùng cần liên kết lần đầu trong Tài khoản.

Đăng nhập ứng dụng hiện tại: email `admin@troan.local`, mật khẩu trong `ADMIN_PASSWORD` của `.env`. Đây là đăng nhập MySQL. Muốn liên kết Google cho chủ trọ, cần đổi email tài khoản demo sang Gmail tương ứng trước; không tự đổi email/mật khẩu của tài khoản hiện có.

Kiểm tra lại cloud khi API/MySQL đang chạy: từ `server`, chạy `dart run bin/firebase_check.dart`. Lệnh không in token/khóa và dọn ảnh/document chẩn đoán vừa tạo.

## 1. Tạo project và bật dịch vụ

Trong https://console.firebase.google.com tạo project `LTDDNC`, ghi lại **Project ID**. Chủ tài khoản tự liên kết Billing để nâng lên Blaze. Hạn mức miễn phí phụ thuộc sản phẩm/khu vực; đặt thông báo ngân sách (ví dụ mức thấp phù hợp đồ án). Cảnh báo ngân sách không tự chặn chi phí.

1. Authentication → Get started → Sign-in method → Google → Enable, chọn email hỗ trợ.
2. Firestore Database → Create database → **Standard edition**, Native mode, database `(default)`, chọn khu vực gần người dùng (ví dụ Singapore nếu có); bắt đầu Production mode.
3. Storage → Get started, chọn vị trí và tạo bucket mặc định. Project mới thường có tên `<project-id>.firebasestorage.app`.
4. Project settings → Cloud Messaging: kiểm tra Firebase Cloud Messaging API v1 đã bật.
5. Crashlytics → Get started.

## 2. Cấu hình Flutter

Từ thư mục project, với Firebase CLI/FlutterFire CLI chính thức:

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID --platforms=android,web
```

Lệnh configure thay `lib/firebase_options.dart` bằng cấu hình thật và thêm cấu hình Android. Chạy lại sau khi đã có các package Crashlytics để CLI thêm plugin build cần thiết. Giữ application ID Android hiện tại `com.example.ck` khi đăng ký ứng dụng, hoặc đổi đồng bộ trước khi configure.

Trong Android Studio/Gradle lấy SHA-1 và SHA-256 của debug signing key, thêm vào Firebase Project settings → Android app. Tải lại `google-services.json` vào `android/app/` nếu thay OAuth/SHA. Google Sign-In Android cần OAuth client đúng package và SHA, cùng Web client được tạo trong cấu hình.

Web: thêm `localhost` và domain triển khai vào Authentication → Settings → Authorized domains. Google đăng nhập bằng popup. FCM của bản này chỉ bật trên Android/iOS; web vẫn có chat, ảnh và Google Sign-In.

Nếu làm iOS trên macOS: chạy configure thêm `ios`, thêm `GoogleService-Info.plist`, URL scheme theo `REVERSED_CLIENT_ID`, bật Push Notifications và Background Modes → Remote notifications, tải APNs key lên Firebase, thực hiện các bước Crashlytics/dSYM do FlutterFire hướng dẫn. Chưa kiểm thử iOS trên máy Windows.

## 3. Cấu hình backend Dart

Project settings → Service accounts → Generate new private key. Lưu **trên máy chạy API** tại `secrets/firebase-service-account.json` (thư mục đã ignore). Không gửi khóa qua chat, không đưa vào Flutter/assets/GitHub.

Thêm vào `.env` (dùng đường dẫn tuyệt đối thực tế):

```dotenv
FIREBASE_SERVICE_ACCOUNT=D:/Toane/lttd/ck/secrets/firebase-service-account.json
FIREBASE_WEB_API_KEY=your_firebase_web_api_key
```

Web API key lấy trong Firebase Project settings; phải thuộc cùng project với service account. Backend dùng Firebase Auth REST để kiểm tra ID token Google, kiểm tra thêm project/provider/email xác minh.

```powershell
cd server
dart pub get
dart run bin/firebase_migrate.dart
dart run bin/server.dart
```

Migration chỉ thêm bảng Firebase, không xóa dữ liệu hiện có. Máy cài mới chạy `bin/setup.dart` sẽ tự tạo các bảng này.

Mở terminal khác tại thư mục gốc:

```powershell
./scripts/start-firebase-worker.ps1
```

Worker kiểm tra thông báo đã commit mỗi 10 giây và gửi FCM. Thiết bị chỉ nhận thông báo phát sinh sau khi đăng ký. Khi lỗi tạm thời, lần sau thử lại; token không còn hợp lệ được xóa. Chạy **một worker** cho demo. Nếu tiến trình chết đúng sau khi FCM nhận thông báo nhưng trước khi ghi trạng thái, có thể gửi trùng (at-least-once).

Worker cũng nhắc hóa đơn còn nợ mỗi ngày một lần, từ 3 ngày trước hạn đến 7 ngày sau hạn. Không nhắc hóa đơn đã trả đủ. Ngày tính theo múi giờ MySQL.

## 4. Triển khai rules

```powershell
firebase deploy --project YOUR_PROJECT_ID --only firestore:rules,storage
```

Không dùng rules mở cho mọi người. Firestore chỉ cho thành viên đọc cuộc trò chuyện, mọi thay đổi đi qua backend để kiểm tra quyền hiện tại từ MySQL. Storage cho tải ảnh lên đúng thư mục UID của mình; chặn MIME và dung lượng không hợp lệ.

Ứng dụng lưu download URL có token của ảnh trong MySQL. Người có URL đó có thể xem ảnh; URL là bearer link, không dùng để chứa giấy tờ bí mật. Chọn JPEG/PNG được kiểm tra chữ ký phía Flutter; rules giới hạn content type và size, không quét nội dung ảnh.

## 5. Chạy demo

1. Chủ trọ đăng nhập bằng mật khẩu → Tài khoản → Kết nối Firebase → Bật thông báo trên điện thoại.
2. Muốn dùng Google: tài khoản MySQL cần email Google thật. Đăng nhập bằng mật khẩu trước → Liên kết tài khoản Google → chọn Google cùng email. Các lần sau có thể dùng nút Google ở màn hình đăng nhập. Không tự tạo tài khoản hoặc cấp vai trò qua Google.

   Nếu chủ trọ hiện dùng email mẫu `admin@troan.local`, đổi email của đúng tài khoản chủ trọ trong MySQL sang Gmail của nhóm trước khi liên kết; mật khẩu giữ nguyên. Khách thuê có thể được tạo ngay với Gmail thật trong mục Khách thuê. Không chạy lại setup với email khác chỉ để đổi email, vì thao tác đó có thể tạo thêm tài khoản chủ trọ.
3. Thêm một khách thuê thử nghiệm trong MySQL, đăng nhập trên thiết bị thứ hai, bật thông báo.
4. Tiện ích → Tin nhắn → chọn người liên hệ, gửi và nhận tin hai chiều.
5. Chi tiết phòng → biểu tượng máy ảnh để đổi ảnh phòng; Tài khoản → Đổi ảnh đại diện. Form sự cố tự tải ảnh lên Storage khi Firebase đã kết nối; khi chưa cấu hình vẫn dùng ảnh đính kèm cũ.
6. Tạo hóa đơn hoặc báo sự cố → kiểm tra thiết bị bên kia nhận push; chạm push mở hộp thông báo. Thông báo hóa đơn mới/nhắc hạn có nút mở đúng hóa đơn.
7. Với Crashlytics, chạy trên Android đã cấu hình rồi tạo lỗi thử trong một bản debug riêng theo tài liệu chính thức; khởi động lại app để gửi báo cáo. Không thêm nút làm crash vào giao diện người dùng.

API vẫn là Dart, không cần thêm Node.js vào backend. Node chỉ dùng cho bộ kiểm thử Firebase Emulator.

## Kiểm thử rules cục bộ

Yêu cầu Node và Java 21+ trên PATH:

```powershell
cd firebase-tests
npm ci
npx firebase emulators:exec --config ../firebase.json --project demo-rental --only firestore,storage "npm test"
```

Test kiểm tra thành viên được đọc chat, người ngoài/ẩn danh bị từ chối, client không giả mạo tin nhắn, không tải ảnh vào thư mục người khác và không vượt 3 MB.

## Tài liệu chính thức

- https://firebase.google.com/docs/flutter/setup
- https://firebase.google.com/docs/auth/flutter/federated-auth
- https://firebase.google.com/docs/auth/admin/create-custom-tokens
- https://firebase.google.com/docs/cloud-messaging/send/v1-api
- https://firebase.google.com/docs/storage/flutter/start
- https://firebase.google.com/docs/crashlytics/flutter/get-started

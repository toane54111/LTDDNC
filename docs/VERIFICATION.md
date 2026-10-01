# Kết quả kiểm tra — 30/09/2026

## Tích hợp Firebase — 01/10/2026

- Flutter analyze (lib, test, rental_domain) và Dart analyze trong server: không có lỗi/cảnh báo.
- Flutter: 6 bài đạt. Backend: 16 bài đạt, gồm tích hợp MySQL thật và kiểm tra quyền chat/URL ảnh.
- Firestore + Storage Emulator: 5 bài đạt; chặn đọc chat ngoài cuộc, giả mạo tin nhắn, upload sai chủ sở hữu/MIME/dung lượng.
- npm audit trong firebase-tests: 0 lỗ hổng sau khi khóa các phụ thuộc vá lỗi; bộ emulator chạy lại đạt.
- Migration Firebase đã chạy trên MySQL riêng ở cổng 3307.
- Build web và APK debug cuối sau tích hợp Firebase: thành công. APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Đã nối project thật `ltddnc-ac280`, triển khai rules và kiểm tra Firebase custom authentication, truy vấn/ghi Firestore, upload Storage thật, FCM validate-only. Chưa xác minh đăng nhập Google tương tác, push đến thiết bị hay báo cáo Crashlytics từ điện thoại.
- Hướng dẫn kết nối và kịch bản demo: `docs/FIREBASE.md`.

## Cập nhật giao diện — 01/10/2026

- `flutter analyze --no-pub lib test packages/rental_domain/lib`: không có lỗi/cảnh báo.
- `flutter test --no-pub`: 6 bài đạt sau khi cập nhật bố cục chi tiết phòng.
- Build web và APK debug mới đều thành công.
- Đã kiểm tra trực quan trang tổng quan và chi tiết phòng ở kích thước 390 × 844 trong trình duyệt. Ảnh mới: `docs/preview.png`, `docs/preview-detail.png`.
- Nguồn và phạm vi tham khảo UI được ghi tại `docs/UI_SOURCES.md`.

## Kiểm tra chức năng trước đợt sửa UI

- `flutter analyze --no-pub`: không có lỗi/cảnh báo.
- `flutter test --no-pub`: 6 bài đạt.
- `flutter build apk --debug --no-pub`: thành công; APK nằm tại `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build web --no-pub`: đã build thành công; preview ở `http://localhost:5173`.
- `dart analyze` trong `server`: không có lỗi/cảnh báo.
- `RUN_MYSQL_TESTS=true dart test` trong `server`: 12 bài đạt trên MySQL 8.0.44, cổng 3307, database riêng.
- Đã mở và xem trang tổng quan Flutter trong trình duyệt; ảnh tại `docs/preview.png`.

Các bài tích hợp kiểm tra quyền truy cập của khách thuê, chống thuê trùng phòng, trạng thái phòng/hợp đồng, chuyển khoản chờ xác nhận, thanh toán từng phần, chống trả vượt nợ, chống duyệt lặp, khóa chỉ số đã xuất hóa đơn, phụ lục không tăng giá hồi tố, trả phòng và hoàn cọc, đăng nhập/đăng xuất, dữ liệu JSON sai, và trạng thái đã đọc thông báo từ MySQL BIT.

Chưa có thiết bị Android/iOS kết nối tại thời điểm kiểm tra. APK build thành công không đồng nghĩa đã kiểm tra camera, sqflite và in PDF trên điện thoại thật. Không có cổng thanh toán thật; online là mô phỏng có nhãn và công tắc cấu hình.

Docker Desktop trên máy gặp lỗi khởi động Inference manager. Đã dùng chương trình MySQL 8.0 có sẵn để tạo instance riêng tại `runtime/mysql`, chỉ lắng nghe localhost:3307. Dịch vụ MySQL cũ trên 3306 được giữ nguyên. Không cần sửa/reset Docker để chạy bản đã bàn giao.

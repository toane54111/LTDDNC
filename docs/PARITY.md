# Đối chiếu project gốc

Nguồn: https://github.com/toane54111/QuanLyPhongTro_DesignPattern
Mã nguồn tham chiếu được tải vào `reference/QuanLyPhongTro_DesignPattern`.
Đây là bản chuyển sang Flutter/Dart, không chạy nhúng các trang Java/Thymeleaf.

## Phạm vi triển khai

| Nghiệp vụ gốc | Flutter/API mới | Ghi chú |
|---|---|---|
| Đăng nhập hai vai trò | Có | bcrypt, token ngẫu nhiên hết hạn 12 giờ; khóa sau 5 lần sai; chủ trọ mở khóa khách |
| Hồ sơ, đổi mật khẩu | Có | Đổi mật khẩu hủy phiên đăng nhập |
| Khu trọ, phòng | Có | CRUD, tìm kiếm, lọc; không xóa phòng có lịch sử hợp đồng |
| Khách thuê | Có | Tạo/sửa, khóa/mở khóa; không trả hash mật khẩu về client |
| Thành viên, tài sản phòng | Có | CRUD; khách thuê chỉ đọc dữ liệu phòng của mình |
| Hợp đồng, thu cọc | Có | Giá từ phòng, tối thiểu 6 tháng, không trùng phòng/khách đang thuê |
| Gia hạn trực tiếp | Có | Ngày mới sau ngày cũ và hiện tại |
| Phụ lục thay đổi giá | Có | Chủ tạo, khách duyệt; giữ giá gốc, giá mới theo kỳ hiệu lực |
| Yêu cầu gia hạn/trả phòng | Có | Khách gửi, chủ duyệt/từ chối; không xử lý lặp |
| Chấm dứt, hoàn cọc | Có | Trả phòng ngay khi duyệt; hoàn cọc = max(cọc − dư nợ, 0), ghi nhận giao dịch |
| Điện nước, bảng giá | Có | Chỉ số không giảm; không sửa kỳ đã lập hóa đơn |
| Hóa đơn | Có | Tính tại API; giữ snapshot giá và chi phí |
| Hóa đơn hàng loạt | Có | Xem trước và kết quả từng hợp đồng; thiếu chỉ số được báo lỗi, không bỏ qua âm thầm |
| Thu tiền mặt từng phần | Có | Chỉ chủ trọ; chống thanh toán vượt dư nợ |
| Chuyển khoản | Có | Chờ chủ trọ xác nhận/từ chối |
| Online | Mô phỏng có nhãn | Chỉ bật bằng ENABLE_ONLINE_DEMO; không tích hợp cổng tiền thật |
| Sự cố | Có | Chụp/chọn ảnh JPEG, ưu tiên, cập nhật tuần tự; ảnh lưu MySQL MEDIUMTEXT |
| Thông báo | Có | Thông báo trong ứng dụng, đánh dấu đọc, cập nhật khi tải lại |
| Thống kê | Có, phạm vi cơ bản | Tổng thanh toán hóa đơn theo tháng/năm, dư nợ; chưa đối chiếu mọi biểu đồ của web cũ |
| In hợp đồng/hóa đơn/biên lai | Có PDF cơ bản | Có dấu tiếng Việt; bố cục bảng dữ liệu mới, chưa sao chép biểu mẫu pháp lý web cũ |
| Dữ liệu cũ | Giữ tên 15 bảng | Chưa tự nhập dữ liệu thật từ project cũ |
| Sqflite | Bổ sung | Nháp điện nước theo tài khoản + API, không phải nguồn dữ liệu thanh toán |

## Khác biệt cần nghiệm thu trước khi gọi là “100%”

- Đã chạy 12 bài kiểm thử API/validation/MySQL và 6 bài kiểm thử Flutter. Vẫn cần kiểm thử Android thực tế (camera, lưu nháp, PDF), rồi đi qua từng controller/use case của bản gốc.
- Màn hình đã được thiết kế lại theo mobile; không sao chép pixel giao diện web.
- Thông báo cần làm mới dữ liệu; chưa có push notification hệ điều hành.
- Tách lưu điện nước và lập hóa đơn thành hai thao tác, thay vì form gộp của bản gốc.
- Không tự động chuyển hợp đồng sang “sắp hết hạn” theo lịch nền.
- Thống kê chi tiết phía khách thuê và bố cục biểu mẫu in cần đối chiếu thêm với người dùng.
- Ảnh được lưu dữ liệu JPEG trong MySQL thay vì thư mục upload của Spring. Khi phát triển quy mô lớn nên chuyển sang kho đối tượng và phân trang danh sách.
- API hiện tải toàn bộ danh sách được cấp quyền; phù hợp dữ liệu đồ án, cần phân trang khi số bản ghi lớn.
- Cùng mô hình quyền của project gốc: các tài khoản chủ trọ dùng chung phạm vi quản lý. Chưa phân tách nhiều chủ sở hữu độc lập.
- Yêu cầu trả phòng duyệt sẽ chấm dứt ngay, không đợi ngày dự kiến (theo workflow gốc).
- Hoàn cọc chỉ ghi nhận khoản sau trừ nợ theo workflow gốc; chưa có bút toán phân bổ cọc để tự tất toán các hóa đơn còn nợ.

Các mục “Có” xác nhận đã có mã triển khai, không thay thế kết quả chạy thử end-to-end.

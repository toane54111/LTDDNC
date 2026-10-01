# Nguồn tham khảo giao diện

Đã tìm trên GitHub và tải:

- https://github.com/byMoamen/Flutter-rental-app → `reference/flutter-rental-ui`
- Tham khảo thêm: https://github.com/abdulazizahwan/flutter-home-rent-app
- Tham khảo thêm: https://github.com/Nidhal-Khazene/HomeSpace-Real-Estate

Mẫu đầu có README công bố MIT nhưng không kèm file LICENSE trong bản tải này. Đã xem trực tiếp demo `preview/rent.gif` và các file `home_screen.dart`, `details_screen.dart`, `house_card.dart`, `search_feild.dart`, `select_category.dart`, `suggestion_list.dart`.

## Bản UI sửa ngày 01/10/2026

Bám theo mẫu: nền trắng, xanh dương sáng (#2388EF), ô tìm kiếm xám nhạt, hàng danh mục icon xanh, thẻ phòng có ảnh kéo ngang, thông tin theo thứ tự ảnh → loại phòng → tên → địa điểm → giá. Trang chi tiết có ảnh lớn đầu trang. Thanh điều hướng trắng, icon xanh khi chọn. Đã bỏ khối tổng quan xanh lá và nền kem của bản đầu.

Các widget được viết để nối với dữ liệu/quyền của project, giữ thứ bậc và bố cục của mẫu. Các màn hình hóa đơn, hợp đồng, điện nước và sự cố áp dụng cùng màu sắc và phong cách.

Ảnh mẫu tải từ đúng hai URL Pexels trong `item_model.dart` của repo:
- https://images.pexels.com/photos/271624/pexels-photo-271624.jpeg
- https://images.pexels.com/photos/276724/pexels-photo-276724.jpeg

Ảnh chỉ gắn với bản ghi ở chế độ xem trước, không tự gán thành ảnh thật cho phòng của người dùng. Phòng thật chưa có ảnh hiển thị trạng thái “Chưa có ảnh phòng”.

Font PDF: Noto Sans từ https://github.com/google/fonts/tree/main/ofl/notosans, giấy phép SIL Open Font License được giữ tại `assets/fonts/OFL.txt`.

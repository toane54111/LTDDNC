typedef Record = Map<String, dynamic>;

class Field {
  const Field(
    this.key,
    this.label, {
    this.kind = 'text',
    this.required = true,
    this.options = const [],
    this.reference,
    this.defaultValue,
  });
  final String key, label, kind;
  final bool required;
  final List<String> options;
  final String? reference;
  final dynamic defaultValue;
}

class Module {
  const Module(
    this.table,
    this.id,
    this.label,
    this.title,
    this.fields, {
    this.tenant = false,
    this.tenantCreate = false,
    this.editable = true,
    this.deletable = false,
    this.creatable = true,
  });
  final String table, id, label, title;
  final List<Field> fields;
  final bool tenant, tenantCreate, editable, deletable, creatable;
}

const modules = <Module>[
  Module('khu_tro', 'khu_tro_id', 'Khu trọ', 'ten_khu', [
    Field('ten_khu', 'Tên khu trọ'),
    Field('dia_chi', 'Địa chỉ'),
    Field('so_tang', 'Số tầng', kind: 'int'),
    Field('mo_ta', 'Mô tả', required: false),
  ], deletable: true),
  Module(
    'phong_tro',
    'phong_id',
    'Phòng trọ',
    'so_phong',
    [
      Field('khu_tro_id', 'Khu trọ', reference: 'khu_tro'),
      Field('so_phong', 'Số phòng'),
      Field('tang', 'Tầng', kind: 'int'),
      Field('dien_tich', 'Diện tích (m²)', kind: 'number'),
      Field('gia_thue', 'Giá thuê (đ/tháng)', kind: 'int'),
      Field(
        'trang_thai',
        'Trạng thái',
        options: ['TRONG', 'BAO_TRI'],
        defaultValue: 'TRONG',
      ),
      Field('mo_ta', 'Mô tả', required: false),
    ],
    tenant: true,
    deletable: true,
  ),
  Module('nguoi_dung', 'user_id', 'Khách thuê', 'ho_ten', [
    Field('ho_ten', 'Họ và tên'),
    Field('email', 'Email', kind: 'email'),
    Field('mat_khau', 'Mật khẩu ban đầu', kind: 'password', required: false),
    Field('sdt', 'Số điện thoại', required: false),
    Field('cccd', 'CCCD', required: false),
  ]),
  Module(
    'hop_dong',
    'hop_dong_id',
    'Hợp đồng',
    'hop_dong_id',
    [
      Field('phong_id', 'Phòng', reference: 'phong_tro'),
      Field('khach_thue_id', 'Khách thuê', reference: 'nguoi_dung'),
      Field('ngay_bat_dau', 'Ngày bắt đầu', kind: 'date'),
      Field('ngay_ket_thuc', 'Ngày kết thúc', kind: 'date'),
      Field('tien_coc', 'Tiền cọc (đ)', kind: 'int'),
      Field('ghi_chu', 'Ghi chú', required: false),
    ],
    tenant: true,
    editable: false,
  ),
  Module(
    'hoa_don',
    'hoa_don_id',
    'Hóa đơn',
    'ky_thanh_toan',
    [
      Field('hop_dong_id', 'Hợp đồng', reference: 'hop_dong'),
      Field('ky_thanh_toan', 'Kỳ thanh toán (YYYY-MM)', kind: 'month'),
      Field('han_thanh_toan', 'Hạn thanh toán', kind: 'date'),
    ],
    tenant: true,
    editable: false,
  ),
  Module('chi_so_dien_nuoc', 'chi_so_id', 'Điện nước', 'ky_ghi', [
    Field('phong_id', 'Phòng', reference: 'phong_tro'),
    Field('ky_ghi', 'Kỳ ghi (YYYY-MM)', kind: 'month'),
    Field('dien_cu', 'Điện cũ (kWh)', kind: 'int'),
    Field('dien_moi', 'Điện mới (kWh)', kind: 'int'),
    Field('nuoc_cu', 'Nước cũ (m³)', kind: 'int'),
    Field('nuoc_moi', 'Nước mới (m³)', kind: 'int'),
    Field('ngay_ghi', 'Ngày ghi', kind: 'date'),
  ], tenant: true),
  Module(
    'dich_vu',
    'dich_vu_id',
    'Dịch vụ',
    'ten_dv',
    [
      Field('ten_dv', 'Tên dịch vụ'),
      Field('don_gia', 'Đơn giá (đ)', kind: 'number'),
      Field('don_vi_tinh', 'Đơn vị tính'),
    ],
    deletable: true,
    tenant: true,
  ),
  Module(
    'tai_san_phong_tro',
    'tai_san_id',
    'Tài sản',
    'ten_tai_san',
    [
      Field('phong_id', 'Phòng', reference: 'phong_tro'),
      Field('ten_tai_san', 'Tên tài sản'),
      Field('tinh_trang', 'Tình trạng'),
    ],
    deletable: true,
    tenant: true,
  ),
  Module(
    'thanh_vien_phong_tro',
    'thanh_vien_id',
    'Thành viên',
    'ho_ten',
    [
      Field('phong_id', 'Phòng', reference: 'phong_tro'),
      Field('ho_ten', 'Họ tên'),
      Field('sdt', 'Điện thoại', required: false),
      Field('cccd', 'CCCD', required: false),
      Field('ngay_bat_dau', 'Ngày bắt đầu', kind: 'date'),
      Field(
        'trang_thai',
        'Trạng thái',
        options: ['Đang ở', 'Đã rời đi'],
        defaultValue: 'Đang ở',
      ),
    ],
    tenant: true,
    deletable: true,
  ),
  Module(
    'yeu_cau_su_co',
    'ticket_id',
    'Sự cố',
    'loai_su_co',
    [
      Field('phong_id', 'Phòng', reference: 'phong_tro'),
      Field(
        'loai_su_co',
        'Loại sự cố',
        options: ['Điện', 'Nước', 'Nội thất', 'Khác'],
      ),
      Field('mo_ta', 'Mô tả sự cố'),
      Field(
        'muc_do_uu_tien',
        'Ưu tiên',
        options: ['THAP', 'TRUNG_BINH', 'CAO'],
        defaultValue: 'TRUNG_BINH',
      ),
      Field('hinh_anh', 'Hình ảnh sự cố', required: false),
    ],
    tenant: true,
    tenantCreate: true,
    editable: false,
  ),
  Module(
    'yeu_cau_gia_han',
    'yeu_cau_id',
    'Yêu cầu gia hạn',
    'hop_dong_id',
    [
      Field('hop_dong_id', 'Hợp đồng', reference: 'hop_dong'),
      Field('thoi_gian_gia_han', 'Số tháng gia hạn', kind: 'int'),
      Field('ghi_chu', 'Ghi chú', required: false),
    ],
    tenant: true,
    tenantCreate: true,
    editable: false,
  ),
  Module(
    'yeu_cau_cham_dut',
    'yeu_cau_id',
    'Yêu cầu trả phòng',
    'hop_dong_id',
    [
      Field('hop_dong_id', 'Hợp đồng', reference: 'hop_dong'),
      Field('ngay_du_kien_tra', 'Ngày dự kiến trả', kind: 'date'),
      Field('ly_do', 'Lý do'),
    ],
    tenant: true,
    tenantCreate: true,
    editable: false,
  ),
  Module(
    'phu_luc_hop_dong',
    'phu_luc_id',
    'Phụ lục hợp đồng',
    'hop_dong_id',
    [
      Field('hop_dong_id', 'Hợp đồng', reference: 'hop_dong'),
      Field('gia_thue_mmoi', 'Giá thuê mới (đ)', kind: 'int'),
      Field('ngay_ket_thuc_moi', 'Ngày kết thúc mới', kind: 'date'),
      Field('ghi_chu', 'Ghi chú', required: false),
    ],
    tenant: true,
    editable: false,
  ),
  Module(
    'giao_dich',
    'giao_dich_id',
    'Giao dịch',
    'ghi_chu',
    [],
    tenant: true,
    editable: false,
    creatable: false,
  ),
  Module(
    'thong_bao',
    'thong_bao_id',
    'Thông báo',
    'tieu_de',
    [
      Field('nguoi_nhan_id', 'Người nhận', reference: 'nguoi_dung'),
      Field('tieu_de', 'Tiêu đề'),
      Field('noi_dung', 'Nội dung'),
    ],
    tenant: true,
    editable: false,
  ),
];

Module moduleOf(String table) => modules.firstWhere((m) => m.table == table);
const labels = <String, String>{
  'TRONG': 'Còn trống',
  'DA_THUE': 'Đang thuê',
  'BAO_TRI': 'Bảo trì',
  'CHU_TRO': 'Chủ trọ',
  'KHACH_THUE': 'Khách thuê',
  'HOAT_DONG': 'Hoạt động',
  'BI_KHOA': 'Bị khóa',
  'DANG_HIEU_LUC': 'Đang hiệu lực',
  'SAP_HET_HAN': 'Sắp hết hạn',
  'DA_CHAM_DUT': 'Đã chấm dứt',
  'CHUA_THANH_TOAN': 'Chưa thanh toán',
  'DA_THANH_TOAN': 'Đã thanh toán',
  'THANH_TOAN_MOT_PHAN': 'Thanh toán một phần',
  'CHO_PHE_DUYET': 'Chờ phê duyệt',
  'DA_PHE_DUYET': 'Đã phê duyệt',
  'DA_TU_CHOI': 'Đã từ chối',
  'MOI': 'Mới tiếp nhận',
  'DA_TIEP_NHAN': 'Đã tiếp nhận',
  'DANG_SUA': 'Đang sửa',
  'DA_XONG': 'Đã xử lý',
  'THAP': 'Thấp',
  'TRUNG_BINH': 'Trung bình',
  'CAO': 'Cao',
  'TIEN_MAT': 'Tiền mặt',
  'CHUYEN_KHOAN': 'Chuyển khoản',
  'ONLINE': 'Online (mô phỏng)',
  'CHO_XAC_NHAN': 'Chờ xác nhận',
  'DA_XAC_NHAN': 'Đã xác nhận',
  'DA_HUY': 'Đã hủy',
  'gia_thue': 'Giá thuê',
  'tong_tien': 'Tổng tiền',
  'tien_phong': 'Tiền phòng',
  'tien_dien': 'Tiền điện',
  'tien_nuoc': 'Tiền nước',
  'phi_dich_vu': 'Phí dịch vụ',
  'trang_thai': 'Trạng thái',
  'trang_thaigd': 'Trạng thái giao dịch',
  'so_tien': 'Số tiền',
  'phuong_thuc': 'Phương thức',
  'ngay_tao': 'Ngày tạo',
  'ngay_giao_dich': 'Ngày giao dịch',
  'ghi_chu': 'Ghi chú',
  'ngay_hieu_luc': 'Ngày hiệu lực',
  'ly_do_tu_choi': 'Lý do từ chối',
  'ghi_chu_xu_ly': 'Ghi chú xử lý',
  'noi_dung': 'Nội dung',
  'da_doc': 'Đã đọc',
  'da_thanh_toan': 'Đã thanh toán',
  'con_no': 'Còn nợ',
};
String label(String value) => labels[value] ?? value;
int integer(dynamic value) => num.tryParse('$value')?.round() ?? 0;

DateTime addMonths(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, date.day > last ? last : date.day);
}

String? validateField(Field field, dynamic value) {
  final s = value?.toString().trim() ?? '';
  if (s.isEmpty) {
    return field.required ? 'Vui lòng nhập ${field.label.toLowerCase()}' : null;
  }
  if (s.length > (field.key == 'hinh_anh' ? 4500000 : 4000)) {
    return 'Nội dung quá dài';
  }
  if (field.options.isNotEmpty && !field.options.contains(s)) {
    return 'Lựa chọn không hợp lệ';
  }
  if (field.reference != null &&
      (int.tryParse(s) == null || int.parse(s) < 1)) {
    return 'Vui lòng chọn ${field.label.toLowerCase()}';
  }
  if (field.kind == 'int' || field.kind == 'number') {
    final n = num.tryParse(s);
    if (n == null ||
        !n.isFinite ||
        n < 0 ||
        n > 999999999999 ||
        (field.kind == 'int' && n != n.round())) {
      return 'Nhập số không âm hợp lệ';
    }
  }
  if (field.kind == 'email' &&
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
    return 'Email không hợp lệ';
  }
  if (field.kind == 'password' && s.length < 8) {
    return 'Mật khẩu cần ít nhất 8 ký tự';
  }
  if (field.kind == 'month' &&
      !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(s)) {
    return 'Dùng định dạng YYYY-MM';
  }
  if (field.kind == 'date') {
    final date = DateTime.tryParse(s);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) ||
        date == null ||
        date.toIso8601String().substring(0, 10) != s) {
      return 'Ngày không hợp lệ (YYYY-MM-DD)';
    }
  }
  return null;
}

void validateMeters(Record data) {
  if (integer(data['dien_moi']) < integer(data['dien_cu']) ||
      integer(data['nuoc_moi']) < integer(data['nuoc_cu'])) {
    throw ArgumentError('Chỉ số mới phải lớn hơn hoặc bằng chỉ số cũ');
  }
}

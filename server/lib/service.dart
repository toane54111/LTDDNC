import 'dart:math';
import 'dart:convert';
import 'package:bcrypt/bcrypt.dart';
import 'package:rental_domain/rental_domain.dart';
import 'database.dart';
import 'firebase_gateway.dart';

class RentalService {
  RentalService(this.db, this.user);
  final Database db;
  final Record user;
  bool get owner => user['vai_tro'] == 'CHU_TRO';
  String get uid => '${user['user_id']}';
  String get today => DateTime.now().toIso8601String().substring(0, 10);
  void landlord() =>
      require(owner, 'Chỉ chủ trọ được thực hiện thao tác này', 403);

  Future<List<Record>> list(String table) async {
    final m = moduleOf(table);
    if (!owner) require(m.tenant, 'Không có quyền truy cập', 403);
    String scope = '1=1';
    if (table == 'nguoi_dung') scope = "t.vai_tro='KHACH_THUE'";
    if (table == 'thong_bao') scope = 't.nguoi_nhan_id=:uid';
    if (!owner) {
      const contractScope =
          'SELECT hop_dong_id FROM hop_dong WHERE khach_thue_id=:uid';
      const roomScope =
          "SELECT phong_id FROM hop_dong WHERE khach_thue_id=:uid AND trang_thai<>'DA_CHAM_DUT'";
      if (table == 'hop_dong' || table.startsWith('yeu_cau_')) {
        scope = 't.khach_thue_id=:uid';
      }
      if (['hoa_don', 'phu_luc_hop_dong'].contains(table)) {
        scope = 't.hop_dong_id IN ($contractScope)';
      }
      if ([
        'phong_tro',
        'tai_san_phong_tro',
        'thanh_vien_phong_tro',
        'chi_so_dien_nuoc',
      ].contains(table)) {
        scope = 't.phong_id IN ($roomScope)';
      }
      if (table == 'giao_dich') {
        scope =
            't.hoa_don_id IN (SELECT hoa_don_id FROM hoa_don WHERE hop_dong_id IN ($contractScope))';
      }
    }
    final selection = table == 'thong_bao'
        ? 't.thong_bao_id,t.nguoi_nhan_id,t.tieu_de,t.noi_dung,t.link,CAST(t.da_doc AS UNSIGNED) AS da_doc,t.ngay_tao'
        : 't.*';
    final rows = await db.query(
      'SELECT $selection FROM `$table` t WHERE $scope ORDER BY t.`${m.id}` DESC',
      {'uid': uid},
    );
    for (final row in rows) {
      row.remove('mat_khau');
      row.remove('so_lan_sai_mat_khau');
      if (table == 'phong_tro' && FirebaseGateway.instance.enabled) {
        final photos = await db.query(
          'SELECT photo_url FROM firebase_room_photos WHERE room_id=:id',
          {'id': row['phong_id']},
        );
        if (photos.isNotEmpty) row['photo_url'] = photos.first['photo_url'];
      }
      if (table == 'hoa_don') {
        row['da_thanh_toan'] = await paid(row['hoa_don_id']);
        row['con_no'] = max(
          0,
          integer(row['tong_tien']) - integer(row['da_thanh_toan']),
        );
      }
    }
    return rows;
  }

  Future<Record> accessible(String table, dynamic id) async {
    final rows = await list(table);
    final m = moduleOf(table);
    for (final r in rows) {
      if ('${r[m.id]}' == '$id') return r;
    }
    throw ApiError(404, 'Không tìm thấy dữ liệu thuộc tài khoản này');
  }

  Future<void> notify(
    dynamic recipient,
    String title,
    String body, {
    String? link,
  }) => db
      .insert('thong_bao', {
        'nguoi_nhan_id': recipient,
        'tieu_de': title,
        'noi_dung': body,
        'link': ?link,
      })
      .then((_) {});
  Future<void> notifyOwners(String title, String body) async {
    for (final r in await db.query(
      "SELECT user_id FROM nguoi_dung WHERE vai_tro='CHU_TRO'",
    )) {
      await notify(r['user_id'], title, body);
    }
  }

  Future<int> paid(dynamic id) async {
    final rows = await db.query(
      "SELECT COALESCE(SUM(so_tien),0) amount FROM giao_dich WHERE hoa_don_id=:id AND trang_thaigd='DA_XAC_NHAN'",
      {'id': id},
    );
    return integer(rows.first['amount']);
  }

  Future<void> refreshInvoice(dynamic id) async {
    final invoice = await db.row('hoa_don', id, lock: true);
    final amount = await paid(id);
    await db.update(moduleOf('hoa_don'), id, {
      'trang_thai': amount >= integer(invoice['tong_tien'])
          ? 'DA_THANH_TOAN'
          : amount > 0
          ? 'THANH_TOAN_MOT_PHAN'
          : 'CHUA_THANH_TOAN',
    });
  }

  Future<Record> save(String table, Record input, {dynamic id}) async {
    final m = moduleOf(table);
    require(
      id == null ? m.creatable : m.editable,
      'Thao tác không được hỗ trợ',
    );
    require(
      owner || (m.tenantCreate && id == null),
      'Không có quyền chỉnh sửa',
      403,
    );
    if (m.tenantCreate) {
      require(!owner, 'Yêu cầu này phải do khách thuê gửi', 403);
    }
    final data = <String, dynamic>{};
    for (final f in m.fields) {
      if (id != null &&
          f.kind == 'password' &&
          (input[f.key] ?? '').toString().isEmpty) {
        continue;
      }
      final value = input[f.key] ?? f.defaultValue;
      final error = validateField(f, value);
      require(error == null, error ?? '');
      data[f.key] = (value?.toString().trim().isEmpty ?? true) ? null : value;
    }
    if (id != null) await db.row(table, id, lock: true);
    if (table == 'nguoi_dung') {
      if (id != null) {
        require(
          (await db.row(table, id))['vai_tro'] == 'KHACH_THUE',
          'Không thể sửa chủ trọ tại đây',
        );
      }
      if (id == null) {
        require(data['mat_khau'] != null, 'Cần nhập mật khẩu ban đầu');
      }
      if (data['mat_khau'] != null) {
        data['mat_khau'] = BCrypt.hashpw(
          '${data['mat_khau']}',
          BCrypt.gensalt(),
        );
      }
      data['email'] = '${data['email']}'.toLowerCase();
      data['vai_tro'] = 'KHACH_THUE';
    }
    if (table == 'phong_tro') {
      await db.row('khu_tro', data['khu_tro_id'], lock: true);
      if (id != null) {
        final active = await db.query(
          "SELECT hop_dong_id FROM hop_dong WHERE phong_id=:id AND trang_thai<>'DA_CHAM_DUT'",
          {'id': id},
        );
        if (active.isNotEmpty) data['trang_thai'] = 'DA_THUE';
      }
    }
    if (table == 'hop_dong') {
      final room = await db.row('phong_tro', data['phong_id'], lock: true);
      final tenant = await db.row(
        'nguoi_dung',
        data['khach_thue_id'],
        lock: true,
      );
      require(room['trang_thai'] == 'TRONG', 'Phòng đã thuê hoặc đang bảo trì');
      require(
        tenant['vai_tro'] == 'KHACH_THUE' &&
            tenant['trang_thai'] == 'HOAT_DONG',
        'Khách thuê không hoạt động',
      );
      require(
        (await db.query(
          "SELECT hop_dong_id FROM hop_dong WHERE khach_thue_id=:id AND trang_thai<>'DA_CHAM_DUT'",
          {'id': data['khach_thue_id']},
        )).isEmpty,
        'Khách đã có hợp đồng còn hiệu lực',
      );
      final start = DateTime.parse(data['ngay_bat_dau']);
      require(
        !DateTime.parse(data['ngay_ket_thuc']).isBefore(addMonths(start, 6)),
        'Hợp đồng phải ít nhất 6 tháng',
      );
      data['gia_thue'] = room['gia_thue'];
      data['trang_thai'] = 'DANG_HIEU_LUC';
      await db.update(moduleOf('phong_tro'), data['phong_id'], {
        'trang_thai': 'DA_THUE',
      });
    }
    if (table == 'chi_so_dien_nuoc') {
      validateMeters(data);
      require(
        '${data['ky_ghi']}'.compareTo(today.substring(0, 7)) <= 0,
        'Không ghi chỉ số kỳ tương lai',
      );
      await db.row('phong_tro', data['phong_id'], lock: true);
      final invoices = await db.query(
        'SELECT h.hoa_don_id FROM hoa_don h JOIN hop_dong d ON d.hop_dong_id=h.hop_dong_id WHERE d.phong_id=:room AND h.ky_thanh_toan=:period',
        {'room': data['phong_id'], 'period': data['ky_ghi']},
      );
      require(
        invoices.isEmpty,
        'Kỳ này đã lập hóa đơn, không được thay đổi chỉ số',
      );
      if (id != null) {
        final old = await db.row(table, id);
        require(
          '${old['phong_id']}' == '${data['phong_id']}' &&
              old['ky_ghi'] == data['ky_ghi'],
          'Không đổi phòng/kỳ của bản ghi chỉ số',
        );
      }
    }
    if (table == 'hoa_don') return createInvoice(data);
    if (table == 'phu_luc_hop_dong' ||
        table == 'yeu_cau_gia_han' ||
        table == 'yeu_cau_cham_dut') {
      final contract = await db.row(
        'hop_dong',
        data['hop_dong_id'],
        lock: true,
      );
      require(
        owner || '${contract['khach_thue_id']}' == uid,
        'Không có quyền với hợp đồng',
        403,
      );
      require(contract['trang_thai'] != 'DA_CHAM_DUT', 'Hợp đồng đã chấm dứt');
      require(
        (await db.query(
          "SELECT ${m.id} FROM `$table` WHERE hop_dong_id=:id AND trang_thai='CHO_PHE_DUYET'",
          {'id': data['hop_dong_id']},
        )).isEmpty,
        'Đã có yêu cầu chờ duyệt',
      );
      if (table == 'phu_luc_hop_dong') {
        require(
          '${data['ngay_ket_thuc_moi']}'.compareTo(
                '${contract['ngay_ket_thuc']}',
              ) >
              0,
          'Ngày kết thúc mới phải sau ngày cũ',
        );
        data['ngay_hieu_luc'] = '${contract['ngay_ket_thuc']}'.substring(0, 10);
      } else {
        data['khach_thue_id'] = uid;
      }
      if (table == 'yeu_cau_gia_han') {
        require(
          integer(data['thoi_gian_gia_han']) > 0 &&
              integer(data['thoi_gian_gia_han']) <= 120,
          'Số tháng gia hạn từ 1 đến 120',
        );
      }
      if (table == 'yeu_cau_cham_dut') {
        require(
          '${data['ngay_du_kien_tra']}'.compareTo(today) >= 0,
          'Ngày trả phòng không được trong quá khứ',
        );
      }
      if (owner) {
        await notify(
          contract['khach_thue_id'],
          'Phụ lục cần xác nhận',
          'Chủ trọ đã gửi đề nghị gia hạn kèm giá thuê mới.',
        );
      } else {
        await notifyOwners(
          m.label,
          'Khách thuê đã gửi ${m.label.toLowerCase()} cho hợp đồng #${data['hop_dong_id']}.',
        );
      }
    }
    if (table == 'yeu_cau_su_co') {
      await accessible('phong_tro', data['phong_id']);
      data['khach_thue_id'] = uid;
      final url = '${data['hinh_anh'] ?? ''}';
      if (url.startsWith('data:image/jpeg;base64,') ||
          url.startsWith('data:image/png;base64,')) {
        final bytes = base64Decode(url.split(',').last);
        final valid = url.startsWith('data:image/png;')
            ? bytes.length > 8 &&
                  bytes[0] == 137 &&
                  bytes[1] == 80 &&
                  bytes[2] == 78 &&
                  bytes[3] == 71
            : bytes.length > 3 &&
                  bytes[0] == 255 &&
                  bytes[1] == 216 &&
                  bytes[2] == 255;
        require(
          bytes.length <= 3 * 1024 * 1024 && valid,
          'Ảnh JPEG/PNG không hợp lệ hoặc vượt 3 MB',
        );
      } else {
        require(
          url.isEmpty || Uri.tryParse(url)?.scheme == 'https',
          'Ảnh không hợp lệ',
        );
      }
      await notifyOwners(
        'Sự cố mới',
        '${data['loai_su_co']}: ${data['mo_ta']}',
      );
    }
    if (table == 'khu_tro' && id != null) {
      await db.row('khu_tro', id, lock: true);
    }
    if (id == null) {
      id = await db.insert(table, data);
    } else {
      await db.update(m, id, data);
    }
    if (table == 'hop_dong') {
      if (integer(data['tien_coc']) > 0) {
        await db.insert('giao_dich', {
          'so_tien': data['tien_coc'],
          'phuong_thuc': 'TIEN_MAT',
          'trang_thaigd': 'DA_XAC_NHAN',
          'ghi_chu': 'Thu cọc hợp đồng #$id',
        });
      }
      await notify(
        data['khach_thue_id'],
        'Hợp đồng mới',
        'Hợp đồng #$id đã được tạo.',
      );
    }
    final result = await db.row(table, id);
    result.remove('mat_khau');
    result.remove('so_lan_sai_mat_khau');
    return result;
  }

  Future<Record> invoicePreview(Record data) async {
    final contract = await db.row('hop_dong', data['hop_dong_id'], lock: true);
    require(contract['trang_thai'] != 'DA_CHAM_DUT', 'Hợp đồng đã chấm dứt');
    final period = '${data['ky_thanh_toan']}';
    require(
      validateField(const Field('period', 'Kỳ', kind: 'month'), period) == null,
      'Kỳ không hợp lệ',
    );
    require(
      period.compareTo(today.substring(0, 7)) <= 0,
      'Không lập hóa đơn tương lai',
    );
    require(
      period.compareTo('${contract['ngay_bat_dau']}'.substring(0, 7)) >= 0 &&
          period.compareTo('${contract['ngay_ket_thuc']}'.substring(0, 7)) <= 0,
      'Kỳ nằm ngoài thời hạn hợp đồng',
    );
    require(
      (await db.query(
        'SELECT hoa_don_id FROM hoa_don WHERE hop_dong_id=:id AND ky_thanh_toan=:period',
        {'id': data['hop_dong_id'], 'period': period},
      )).isEmpty,
      'Hóa đơn kỳ này đã tồn tại',
    );
    final readings = await db.query(
      'SELECT * FROM chi_so_dien_nuoc WHERE phong_id=:id AND ky_ghi=:period',
      {'id': contract['phong_id'], 'period': period},
    );
    require(
      readings.isNotEmpty,
      'Chưa ghi điện nước phòng #${contract['phong_id']} kỳ $period',
    );
    final meter = readings.first;
    final services = await db.query('SELECT * FROM dich_vu');
    int electricity = 0, water = 0, fee = 0;
    require(
      services.any((s) => s['ten_dv'] == 'Điện') &&
          services.any((s) => s['ten_dv'] == 'Nước'),
      'Cần khai báo dịch vụ Điện và Nước',
    );
    for (final s in services) {
      final rate = num.parse('${s['don_gia']}');
      if (s['ten_dv'] == 'Điện') {
        electricity =
            ((integer(meter['dien_moi']) - integer(meter['dien_cu'])) * rate)
                .round();
      } else if (s['ten_dv'] == 'Nước') {
        water =
            ((integer(meter['nuoc_moi']) - integer(meter['nuoc_cu'])) * rate)
                .round();
      } else {
        fee += rate.round();
      }
    }
    int rent = integer(contract['gia_thue']);
    final annexes = await db.query(
      "SELECT * FROM phu_luc_hop_dong WHERE hop_dong_id=:id AND trang_thai='DA_PHE_DUYET' AND DATE_FORMAT(ngay_hieu_luc,'%Y-%m')<=:period ORDER BY ngay_hieu_luc DESC,phu_luc_id DESC",
      {'id': data['hop_dong_id'], 'period': period},
    );
    if (annexes.isNotEmpty) rent = integer(annexes.first['gia_thue_mmoi']);
    return {
      ...data,
      'tien_phong': rent,
      'tien_dien': electricity,
      'tien_nuoc': water,
      'phi_dich_vu': fee,
      'tong_tien': rent + electricity + water + fee,
    };
  }

  Future<Record> createInvoice(Record data) async {
    final values = await invoicePreview(data);
    final id = await db.insert('hoa_don', values);
    final contract = await db.row('hop_dong', data['hop_dong_id']);
    await notify(
      contract['khach_thue_id'],
      'Hóa đơn mới',
      'Kỳ ${data['ky_thanh_toan']}: ${values['tong_tien']} đ.',
      link: 'hoa_don/$id',
    );
    return db.row('hoa_don', id);
  }

  Future<Record> action(
    String table,
    dynamic id,
    String action,
    Record data, {
    bool onlineDemo = false,
  }) async {
    final m = moduleOf(table);
    await accessible(table, id);
    final row = await db.row(table, id, lock: true);
    if (table == 'thong_bao' && action == 'read') {
      await db.update(m, id, {'da_doc': 1});
    } else if (table == 'nguoi_dung' && action == 'toggle') {
      landlord();
      require(row['vai_tro'] == 'KHACH_THUE', 'Không thể khóa chủ trọ');
      await db.update(m, id, {
        'trang_thai': row['trang_thai'] == 'HOAT_DONG'
            ? 'BI_KHOA'
            : 'HOAT_DONG',
        'so_lan_sai_mat_khau': 0,
      });
    } else if (table == 'hoa_don' && action == 'pay') {
      require(
        validateField(
              const Field('amount', 'Số tiền', kind: 'int'),
              data['so_tien'],
            ) ==
            null,
        'Số tiền phải là số nguyên không âm',
      );
      final amount = integer(data['so_tien']);
      final method = '${data['phuong_thuc']}';
      require(
        ['TIEN_MAT', 'CHUYEN_KHOAN', 'ONLINE'].contains(method),
        'Phương thức không hợp lệ',
      );
      if (method == 'TIEN_MAT') landlord();
      if (method == 'ONLINE') {
        require(onlineDemo, 'Thanh toán online mô phỏng chưa được bật');
      }
      require(
        amount > 0 && amount <= integer(row['tong_tien']) - await paid(id),
        'Số tiền phải dương và không vượt dư nợ',
      );
      final pending = await db.query(
        "SELECT COALESCE(SUM(so_tien),0) amount FROM giao_dich WHERE hoa_don_id=:id AND trang_thaigd='CHO_XAC_NHAN'",
        {'id': id},
      );
      require(
        amount + integer(pending.first['amount']) <=
            integer(row['tong_tien']) - await paid(id),
        'Đã có khoản chuyển chờ xác nhận; kiểm tra giao dịch trước',
      );
      final transaction = await db.insert('giao_dich', {
        'hoa_don_id': id,
        'so_tien': amount,
        'phuong_thuc': method,
        'trang_thaigd': method == 'CHUYEN_KHOAN'
            ? 'CHO_XAC_NHAN'
            : 'DA_XAC_NHAN',
        'ghi_chu': method == 'ONLINE'
            ? 'MÔ PHỎNG — không thu tiền thật'
            : data['ghi_chu'] ?? 'Thanh toán hóa đơn #$id',
      });
      await refreshInvoice(id);
      final contract = await db.row('hop_dong', row['hop_dong_id']);
      await notify(
        contract['khach_thue_id'],
        'Giao dịch hóa đơn #$id',
        '${label(method)}: $amount đ.',
      );
      if (method == 'CHUYEN_KHOAN') {
        await notifyOwners(
          'Chuyển khoản chờ xác nhận',
          'Giao dịch #$transaction, hóa đơn #$id: $amount đ.',
        );
      }
    } else if (table == 'giao_dich' && ['approve', 'reject'].contains(action)) {
      landlord();
      require(row['trang_thaigd'] == 'CHO_XAC_NHAN', 'Giao dịch đã xử lý');
      final invoice = await db.row('hoa_don', row['hoa_don_id'], lock: true);
      if (action == 'approve') {
        require(
          integer(row['so_tien']) <=
              integer(invoice['tong_tien']) - await paid(row['hoa_don_id']),
          'Khoản thanh toán vượt dư nợ',
        );
      }
      await db.update(m, id, {
        'trang_thaigd': action == 'approve' ? 'DA_XAC_NHAN' : 'DA_HUY',
      });
      await refreshInvoice(row['hoa_don_id']);
      final contract = await db.row('hop_dong', invoice['hop_dong_id']);
      await notify(
        contract['khach_thue_id'],
        'Kết quả giao dịch #$id',
        action == 'approve'
            ? 'Chủ trọ đã xác nhận thanh toán.'
            : 'Chủ trọ đã từ chối giao dịch.',
      );
    } else if (table == 'yeu_cau_su_co' && action == 'status') {
      landlord();
      const states = ['MOI', 'DA_TIEP_NHAN', 'DANG_SUA', 'DA_XONG'];
      final next = '${data['trang_thai']}';
      require(
        states.indexOf(next) == states.indexOf('${row['trang_thai']}') + 1,
        'Trạng thái phải chuyển sang bước kế tiếp',
      );
      await db.update(m, id, {
        'trang_thai': next,
        'ghi_chu_xu_ly': data['ghi_chu_xu_ly'] ?? '',
      });
      await notify(row['khach_thue_id'], 'Cập nhật sự cố #$id', label(next));
    } else if ([
          'yeu_cau_gia_han',
          'yeu_cau_cham_dut',
          'phu_luc_hop_dong',
        ].contains(table) &&
        ['approve', 'reject'].contains(action)) {
      if (table == 'phu_luc_hop_dong') {
        require(!owner, 'Phụ lục phải do khách thuê xác nhận', 403);
      } else {
        landlord();
      }
      require(row['trang_thai'] == 'CHO_PHE_DUYET', 'Yêu cầu đã được xử lý');
      final contract = await db.row('hop_dong', row['hop_dong_id'], lock: true);
      require(contract['trang_thai'] != 'DA_CHAM_DUT', 'Hợp đồng đã chấm dứt');
      final changes = <String, dynamic>{
        'trang_thai': action == 'approve' ? 'DA_PHE_DUYET' : 'DA_TU_CHOI',
      };
      if (action == 'reject') {
        require(
          '${data['ly_do'] ?? ''}'.trim().isNotEmpty,
          'Cần nhập lý do từ chối',
        );
        changes[table == 'phu_luc_hop_dong' ? 'ghi_chu' : 'ly_do_tu_choi'] =
            data['ly_do'];
      } else if (table == 'yeu_cau_cham_dut') {
        await terminate(contract);
      } else {
        final end = table == 'phu_luc_hop_dong'
            ? '${row['ngay_ket_thuc_moi']}'.substring(0, 10)
            : addMonths(
                DateTime.parse(contract['ngay_ket_thuc']),
                integer(row['thoi_gian_gia_han']),
              ).toIso8601String().substring(0, 10);
        require(
          end.compareTo('${contract['ngay_ket_thuc']}'.substring(0, 10)) > 0,
          'Ngày gia hạn không còn phù hợp',
        );
        await db.update(moduleOf('hop_dong'), contract['hop_dong_id'], {
          'ngay_ket_thuc': end,
          'trang_thai': 'DANG_HIEU_LUC',
        });
      }
      await db.update(m, id, changes);
      await notify(
        contract['khach_thue_id'],
        m.label,
        label(changes['trang_thai']),
      );
      await notifyOwners(
        m.label,
        'Yêu cầu #$id: ${label(changes['trang_thai'])}',
      );
    } else if (table == 'hop_dong' && action == 'terminate') {
      landlord();
      await terminate(row);
    } else if (table == 'hop_dong' && action == 'extend') {
      landlord();
      require(row['trang_thai'] != 'DA_CHAM_DUT', 'Hợp đồng đã chấm dứt');
      final end = '${data['ngay_ket_thuc']}';
      require(
        validateField(const Field('end', 'Ngày', kind: 'date'), end) == null &&
            end.compareTo('${row['ngay_ket_thuc']}'.substring(0, 10)) > 0 &&
            end.compareTo(today) > 0,
        'Ngày mới phải sau ngày hiện tại và ngày kết thúc cũ',
      );
      await db.update(m, id, {
        'ngay_ket_thuc': end,
        'trang_thai': 'DANG_HIEU_LUC',
      });
    } else {
      throw ApiError(404, 'Thao tác không tồn tại');
    }
    return {'ok': true};
  }

  Future<void> terminate(Record contract) async {
    require(contract['trang_thai'] != 'DA_CHAM_DUT', 'Hợp đồng đã chấm dứt');
    final id = contract['hop_dong_id'];
    final invoices = await db.query(
      'SELECT * FROM hoa_don WHERE hop_dong_id=:id FOR UPDATE',
      {'id': id},
    );
    int debt = 0;
    for (final invoice in invoices) {
      debt += max(
        0,
        integer(invoice['tong_tien']) - await paid(invoice['hoa_don_id']),
      );
    }
    final refund = max(0, integer(contract['tien_coc']) - debt);
    await db.update(moduleOf('hop_dong'), id, {'trang_thai': 'DA_CHAM_DUT'});
    await db.update(moduleOf('phong_tro'), contract['phong_id'], {
      'trang_thai': 'TRONG',
    });
    if (refund > 0) {
      await db.insert('giao_dich', {
        'so_tien': refund,
        'phuong_thuc': 'TIEN_MAT',
        'trang_thaigd': 'DA_XAC_NHAN',
        'ghi_chu': 'Hoàn cọc hợp đồng #$id; nợ: $debt',
      });
    }
    await notify(
      contract['khach_thue_id'],
      'Hợp đồng đã chấm dứt',
      'Hoàn cọc dự kiến: $refund đ; dư nợ hóa đơn: $debt đ.',
    );
  }

  Future<void> delete(String table, dynamic id) async {
    landlord();
    final m = moduleOf(table);
    require(m.deletable, 'Không cho phép xóa dữ liệu này');
    await db.row(table, id, lock: true);
    if (table == 'khu_tro') {
      require(
        (await db.query('SELECT phong_id FROM phong_tro WHERE khu_tro_id=:id', {
          'id': id,
        })).isEmpty,
        'Chỉ xóa khu chưa có phòng',
      );
    }
    if (table == 'phong_tro') {
      require(
        (await db.query('SELECT hop_dong_id FROM hop_dong WHERE phong_id=:id', {
          'id': id,
        })).isEmpty,
        'Phòng đã có lịch sử hợp đồng',
      );
    }
    await db.query('DELETE FROM `$table` WHERE `${m.id}`=:id', {'id': id});
  }
}

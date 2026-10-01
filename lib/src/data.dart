import 'dart:convert';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_services.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:rental_domain/rental_domain.dart';
import 'package:sqflite/sqflite.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RentalStore extends ChangeNotifier {
  RentalStore({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  String baseUrl = const String.fromEnvironment(
    'API_URL',
    defaultValue: kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080',
  );
  String? token;
  Record? user;
  bool demo = false, onlineDemo = false;
  bool firebaseConnected = false;
  String? firebaseError, avatarUrl;
  final notificationTap = ValueNotifier<String?>(null);
  final foregroundNotification = ValueNotifier<String?>(null);
  StreamSubscription<String>? deviceSubscription;
  StreamSubscription<RemoteMessage>? messageSubscription, tapSubscription;
  String? deviceToken;

  @override
  void dispose() {
    deviceSubscription?.cancel();
    messageSubscription?.cancel();
    tapSubscription?.cancel();
    notificationTap.dispose();
    foregroundNotification.dispose();
    client.close();
    super.dispose();
  }

  Future<void> connectFirebase() async {
    if (!FirebaseServices.ready || demo || token == null) return;
    try {
      final result = await request('POST', 'firebase/session');
      await FirebaseAuth.instance.signInWithCustomToken(result['customToken']);
      firebaseConnected = true;
      firebaseError = null;
      avatarUrl = (await request('GET', 'firebase/avatar'))['avatar_url'];
      await messageSubscription?.cancel();
      await tapSubscription?.cancel();
      messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        foregroundNotification.value =
            message.notification?.title ?? 'Bạn có thông báo mới';
        unawaited(refresh().catchError((_) {}));
      });
      tapSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        notificationTap.value = message.data['notificationId'] ?? 'latest';
      });
      if (FirebaseServices.mobile) {
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) {
          notificationTap.value = initial.data['notificationId'] ?? 'latest';
        }
      }
    } catch (_) {
      firebaseConnected = false;
      firebaseError =
          'Chưa kết nối được Firebase. Kiểm tra cấu hình rồi thử lại.';
    }
    notifyListeners();
  }

  Future<void> enablePush() async {
    writable();
    if (!firebaseConnected) await connectFirebase();
    if (!firebaseConnected) {
      throw ApiException(firebaseError ?? 'Firebase chưa được cấu hình.');
    }
    if (!FirebaseServices.mobile) {
      throw ApiException('Bản demo nhận thông báo đẩy trên Android/iOS.');
    }
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      throw ApiException('Hãy cho phép thông báo trong cài đặt điện thoại.');
    }
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: true,
        );
    deviceToken = await FirebaseMessaging.instance.getToken();
    if (deviceToken == null) {
      throw ApiException(
        'Thiết bị chưa nhận được mã thông báo. Hãy thử lại sau.',
      );
    }
    if (deviceToken != null) {
      await request('POST', 'firebase/devices', {'token': deviceToken});
    }
    await deviceSubscription?.cancel();
    deviceSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
      value,
    ) async {
      deviceToken = value;
      try {
        await request('POST', 'firebase/devices', {'token': value});
      } catch (_) {}
    });
  }

  Future<void> googleLogin() async {
    try {
      final idToken = await FirebaseServices.googleToken();
      final result = await request('POST', 'google-login', {
        'idToken': idToken,
      });
      token = result['token'];
      user = Map<String, dynamic>.from(result['user']);
      demo = false;
      onlineDemo = result['onlineDemo'] == true;
      records.clear();
      await connectFirebase();
      notifyListeners();
    } catch (_) {
      if (FirebaseServices.ready) await FirebaseAuth.instance.signOut();
      rethrow;
    }
  }

  Future<void> linkGoogle() async {
    writable();
    try {
      final idToken = await FirebaseServices.googleToken();
      await request('POST', 'firebase/google-link', {'idToken': idToken});
    } finally {
      await connectFirebase();
    }
  }

  final Map<String, List<Record>> records = {};
  bool get owner => user?['vai_tro'] == 'CHU_TRO';
  List<Record> rows(String table) => records[table] ?? [];
  Future<dynamic> request(String method, String path, [Record? data]) async {
    final req = http.Request(method, Uri.parse('$baseUrl/api/$path'))
      ..headers.addAll({
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      });
    if (data != null) req.body = jsonEncode(data);
    try {
      final response = await http.Response.fromStream(
        await client.send(req).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode >= 400) {
        if (response.statusCode == 401) {
          firebaseConnected = false;
          deviceSubscription?.cancel();
          messageSubscription?.cancel();
          tapSubscription?.cancel();
          if (FirebaseServices.ready) {
            unawaited(FirebaseAuth.instance.signOut());
          }
          token = null;
          user = null;
          records.clear();
          notifyListeners();
        }
        throw ApiException(
          decoded is Map ? '${decoded['error']}' : 'Lỗi kết nối máy chủ',
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Không kết nối được máy chủ. Kiểm tra địa chỉ API và mạng.',
      );
    }
  }

  Future<void> login(String email, String password) async {
    final result = await request('POST', 'login', {
      'email': email,
      'password': password,
    });
    token = result['token'];
    user = Map<String, dynamic>.from(result['user']);
    onlineDemo = result['onlineDemo'] == true;
    demo = false;
    records.clear();
    await connectFirebase();
    notifyListeners();
  }

  Future<void> refresh() async {
    if (demo) return;
    final available = modules.where((m) => owner || m.tenant).toList();
    final values = await Future.wait(
      available.map((m) => request('GET', m.table)),
    );
    for (var i = 0; i < available.length; i++) {
      records[available[i].table] = (values[i] as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }
    notifyListeners();
  }

  void writable() {
    if (demo) {
      throw ApiException(
        'Đây là dữ liệu xem trước. Hãy đăng nhập API để lưu thay đổi.',
      );
    }
  }

  Future<void> save(Module m, Record data, [Record? original]) async {
    writable();
    await request(
      original == null ? 'POST' : 'PUT',
      '${m.table}${original == null ? '' : '/${original[m.id]}'}',
      data,
    );
    await refresh();
  }

  Future<void> action(
    Module m,
    Record row,
    String action, [
    Record data = const {},
  ]) async {
    writable();
    await request('POST', '${m.table}/${row[m.id]}/$action', data);
    await refresh();
  }

  Future<void> delete(Module m, Record row) async {
    writable();
    await request('DELETE', '${m.table}/${row[m.id]}');
    await refresh();
  }

  Future<void> logout() async {
    await deviceSubscription?.cancel();
    await messageSubscription?.cancel();
    await tapSubscription?.cancel();
    if (!demo && token != null && deviceToken != null) {
      try {
        await request('DELETE', 'firebase/devices', {'token': deviceToken});
      } catch (_) {}
    }
    if (FirebaseServices.ready) {
      try {
        if (FirebaseServices.mobile) {
          await FirebaseMessaging.instance.deleteToken();
        }
      } catch (_) {}
      await FirebaseAuth.instance.signOut();
    }
    firebaseConnected = false;
    avatarUrl = null;
    deviceToken = null;
    notificationTap.value = null;
    foregroundNotification.value = null;
    if (!demo && token != null) {
      try {
        await request('POST', 'logout');
      } catch (_) {
        /* Local logout still completes. */
      }
    }
    token = null;
    user = null;
    records.clear();
    demo = false;
    notifyListeners();
  }

  String display(String table, dynamic id) {
    final m = moduleOf(table);
    final matches = rows(table).where((r) => '${r[m.id]}' == '$id');
    if (matches.isEmpty) return '#$id';
    final row = matches.first;
    if (table == 'hop_dong') {
      return 'HĐ #$id · ${display('phong_tro', row['phong_id'])}';
    }
    if (table == 'phong_tro') return 'Phòng ${row['so_phong']}';
    return '${row[m.title] ?? '#$id'}';
  }

  void preview({bool tenant = false}) {
    demo = true;
    user = {
      'user_id': tenant ? 2 : 1,
      'ho_ten': tenant ? 'Nguyễn Minh Anh' : 'Nguyễn Hoàng An',
      'vai_tro': tenant ? 'KHACH_THUE' : 'CHU_TRO',
      'email': 'xemtruoc@example.com',
    };
    records.clear();
    records.addAll({
      'khu_tro': [
        {
          'khu_tro_id': 1,
          'ten_khu': 'An Nhiên House',
          'dia_chi': 'Thủ Đức, TP. Hồ Chí Minh',
          'so_tang': 3,
        },
      ],
      'phong_tro': [
        {
          'phong_id': 1,
          'khu_tro_id': 1,
          'so_phong': 'A101',
          'preview_photo': 'assets/images/room-bedroom.jpg',
          'tang': 1,
          'dien_tich': 28,
          'gia_thue': 3200000,
          'trang_thai': 'DA_THUE',
          'mo_ta': 'Phòng sáng, có ban công và bếp riêng.',
        },
        if (!tenant) ...[
          {
            'phong_id': 2,
            'khu_tro_id': 1,
            'so_phong': 'A102',
            'preview_photo': 'assets/images/room-living.jpg',
            'tang': 1,
            'dien_tich': 25,
            'gia_thue': 2800000,
            'trang_thai': 'TRONG',
            'mo_ta': 'Không gian gọn gàng cho một người.',
          },
          {
            'phong_id': 3,
            'khu_tro_id': 1,
            'so_phong': 'B201',
            'preview_photo': 'assets/images/room-bedroom.jpg',
            'tang': 2,
            'dien_tich': 32,
            'gia_thue': 3800000,
            'trang_thai': 'TRONG',
          },
          {
            'phong_id': 4,
            'khu_tro_id': 1,
            'so_phong': 'B202',
            'preview_photo': 'assets/images/room-living.jpg',
            'tang': 2,
            'dien_tich': 30,
            'gia_thue': 3500000,
            'trang_thai': 'BAO_TRI',
          },
        ],
      ],
      'nguoi_dung': [
        {
          'user_id': 2,
          'ho_ten': 'Nguyễn Minh Anh',
          'email': 'minhanh@example.com',
          'sdt': '0901234567',
          'trang_thai': 'HOAT_DONG',
        },
      ],
      'hop_dong': [
        {
          'hop_dong_id': 1,
          'phong_id': 1,
          'khach_thue_id': 2,
          'ngay_bat_dau': '2026-06-01',
          'ngay_ket_thuc': '2027-06-01',
          'gia_thue': 3200000,
          'tien_coc': 3200000,
          'trang_thai': 'DANG_HIEU_LUC',
        },
      ],
      'hoa_don': [
        {
          'hoa_don_id': 1,
          'hop_dong_id': 1,
          'ky_thanh_toan': '2026-09',
          'tien_phong': 3200000,
          'tien_dien': 245000,
          'tien_nuoc': 90000,
          'phi_dich_vu': 130000,
          'tong_tien': 3665000,
          'da_thanh_toan': 1000000,
          'con_no': 2665000,
          'han_thanh_toan': '2026-10-05',
          'trang_thai': 'THANH_TOAN_MOT_PHAN',
        },
      ],
      'dich_vu': [
        {
          'dich_vu_id': 1,
          'ten_dv': 'Điện',
          'don_gia': 3500,
          'don_vi_tinh': 'kWh',
        },
        {
          'dich_vu_id': 2,
          'ten_dv': 'Nước',
          'don_gia': 18000,
          'don_vi_tinh': 'm³',
        },
      ],
      'yeu_cau_su_co': [
        {
          'ticket_id': 1,
          'phong_id': 1,
          'khach_thue_id': 2,
          'loai_su_co': 'Nước',
          'mo_ta': 'Vòi nước bồn rửa bị rò, cần kiểm tra gioăng.',
          'muc_do_uu_tien': 'TRUNG_BINH',
          'trang_thai': 'MOI',
          'ngay_tao': '2026-09-30',
        },
      ],
      'giao_dich': [
        {
          'giao_dich_id': 1,
          'hoa_don_id': 1,
          'so_tien': 1000000,
          'phuong_thuc': 'TIEN_MAT',
          'trang_thaigd': 'DA_XAC_NHAN',
          'ngay_giao_dich': '2026-09-28',
          'ghi_chu': 'Thanh toán một phần hóa đơn #1',
        },
      ],
      'thong_bao': [
        {
          'thong_bao_id': 1,
          'tieu_de': 'Chào mừng đến với Trọ An',
          'noi_dung': 'Quản lý nhà trọ, gọn trong một ứng dụng.',
          'da_doc': 0,
          'ngay_tao': '2026-09-30',
        },
      ],
    });
    notifyListeners();
  }
}

class MeterDrafts {
  Database? _db;
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
  Future<Database> get database async => _db ??= await openDatabase(
    p.join(await getDatabasesPath(), 'tro_an_drafts.db'),
    version: 1,
    onCreate: (db, _) => db.execute(
      'CREATE TABLE drafts (account TEXT PRIMARY KEY, payload TEXT NOT NULL)',
    ),
  );
  Future<void> save(String account, Record data) async {
    if (supported) {
      await (await database).insert('drafts', {
        'account': account,
        'payload': jsonEncode(data),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Record?> read(String account) async {
    if (!supported) return null;
    final rows = await (await database).query(
      'drafts',
      where: 'account = ?',
      whereArgs: [account],
    );
    return rows.isEmpty
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(rows.first['payload'] as String),
          );
  }

  Future<void> remove(String account) async {
    if (supported) {
      await (await database).delete(
        'drafts',
        where: 'account = ?',
        whereArgs: [account],
      );
    }
  }
}

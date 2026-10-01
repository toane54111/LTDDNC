import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:rental_domain/rental_domain.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:rental_server/database.dart';
import 'package:rental_server/service.dart';
import 'package:rental_server/config.dart';

final sessions = <String, ({String uid, DateTime expires})>{};
String digest(String token) => sha256.convert(utf8.encode(token)).toString();
Response jsonResponse(Object value, [int status = 200]) => Response(
  status,
  body: jsonEncode(value),
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  },
);

Future<Record> body(Request request) async {
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    bytes.addAll(chunk);
    require(bytes.length <= 5 * 1024 * 1024, 'Nội dung quá lớn', 413);
  }
  if (bytes.isEmpty) return {};
  final parsed = jsonDecode(utf8.decode(bytes));
  require(parsed is Map<String, dynamic>, 'Cần gửi JSON object');
  return Map<String, dynamic>.from(parsed);
}

Future<Response> handle(Request request) async {
  Database? db;
  try {
    final parts = request.url.pathSegments;
    if (parts.join('/') == 'health') return jsonResponse({'status': 'ok'});
    require(
      parts.isNotEmpty && parts.first == 'api',
      'Không tìm thấy API',
      404,
    );
    final data = ['POST', 'PUT', 'PATCH'].contains(request.method)
        ? await body(request)
        : <String, dynamic>{};
    db = await Database.open();
    if (parts.join('/') == 'api/login' && request.method == 'POST') {
      final email = '${data['email'] ?? ''}'.trim().toLowerCase();
      final rows = await db.query(
        'SELECT * FROM nguoi_dung WHERE email=:email',
        {'email': email},
      );
      require(rows.isNotEmpty, 'Email hoặc mật khẩu không đúng', 401);
      final user = rows.first;
      require(
        user['trang_thai'] == 'HOAT_DONG',
        'Tài khoản đã bị khóa; liên hệ chủ trọ',
        403,
      );
      if (!BCrypt.checkpw('${data['password'] ?? ''}', '${user['mat_khau']}')) {
        await db.query(
          "UPDATE nguoi_dung SET so_lan_sai_mat_khau=so_lan_sai_mat_khau+1, trang_thai=IF(so_lan_sai_mat_khau>=5,'BI_KHOA',trang_thai) WHERE user_id=:id",
          {'id': user['user_id']},
        );
        throw ApiError(401, 'Email hoặc mật khẩu không đúng');
      }
      await db.query(
        'UPDATE nguoi_dung SET so_lan_sai_mat_khau=0 WHERE user_id=:id',
        {'id': user['user_id']},
      );
      sessions.removeWhere((_, s) => s.expires.isBefore(DateTime.now()));
      final random = Random.secure();
      final token = base64UrlEncode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      sessions[digest(token)] = (
        uid: '${user['user_id']}',
        expires: DateTime.now().add(const Duration(hours: 12)),
      );
      user.remove('mat_khau');
      user.remove('so_lan_sai_mat_khau');
      return jsonResponse({
        'token': token,
        'user': user,
        'onlineDemo': config['ENABLE_ONLINE_DEMO'] == 'true',
      });
    }
    final auth = request.headers['authorization'] ?? '';
    require(auth.startsWith('Bearer '), 'Vui lòng đăng nhập', 401);
    final key = digest(auth.substring(7));
    final session = sessions[key];
    require(
      session != null && session.expires.isAfter(DateTime.now()),
      'Phiên đăng nhập đã hết hạn',
      401,
    );
    final user = await db.row('nguoi_dung', session!.uid);
    require(user['trang_thai'] == 'HOAT_DONG', 'Tài khoản đã bị khóa', 403);
    if (parts.join('/') == 'api/logout') {
      sessions.remove(key);
      return jsonResponse({'ok': true});
    }
    if (parts.join('/') == 'api/profile' && request.method == 'PUT') {
      final name = '${data['ho_ten'] ?? ''}'.trim();
      require(name.isNotEmpty && name.length <= 100, 'Họ tên không hợp lệ');
      await db.update(moduleOf('nguoi_dung'), user['user_id'], {
        'ho_ten': name,
        'sdt': data['sdt'],
        'cccd': data['cccd'],
      });
      final updated = await db.row('nguoi_dung', user['user_id']);
      updated.remove('mat_khau');
      updated.remove('so_lan_sai_mat_khau');
      return jsonResponse(updated);
    }
    if (parts.join('/') == 'api/password' && request.method == 'POST') {
      require(
        BCrypt.checkpw('${data['old_password'] ?? ''}', user['mat_khau']),
        'Mật khẩu hiện tại không đúng',
      );
      require(
        '${data['new_password'] ?? ''}'.length >= 8 &&
            '${data['new_password']}'.length <= 72,
        'Mật khẩu mới cần 8–72 ký tự',
      );
      await db.update(moduleOf('nguoi_dung'), user['user_id'], {
        'mat_khau': BCrypt.hashpw(data['new_password'], BCrypt.gensalt()),
      });
      sessions.removeWhere((_, s) => s.uid == session.uid);
      return jsonResponse({'ok': true});
    }
    final service = RentalService(db, user);
    if (parts.join('/') == 'api/batch-invoices' && request.method == 'POST') {
      service.landlord();
      require(
        validateField(
              const Field('due', 'Hạn', kind: 'date'),
              data['han_thanh_toan'],
            ) ==
            null,
        'Hạn thanh toán không hợp lệ',
      );
      final contracts = await db.query(
        "SELECT * FROM hop_dong WHERE trang_thai<>'DA_CHAM_DUT'",
      );
      final result = <Record>[];
      for (final c in contracts) {
        try {
          final item = await db.transaction(
            () => data['preview'] == true
                ? service.invoicePreview({
                    'hop_dong_id': c['hop_dong_id'],
                    'ky_thanh_toan': data['ky_thanh_toan'],
                    'han_thanh_toan': data['han_thanh_toan'],
                  })
                : service.createInvoice({
                    'hop_dong_id': c['hop_dong_id'],
                    'ky_thanh_toan': data['ky_thanh_toan'],
                    'han_thanh_toan': data['han_thanh_toan'],
                  }),
          );
          result.add({'hop_dong_id': c['hop_dong_id'], 'ok': true, ...item});
        } on ApiError catch (e) {
          result.add({
            'hop_dong_id': c['hop_dong_id'],
            'ok': false,
            'error': e.message,
          });
        }
      }
      return jsonResponse(result);
    }
    require(
      parts.length >= 2 && modules.any((m) => m.table == parts[1]),
      'Không tìm thấy tài nguyên',
      404,
    );
    final table = parts[1];
    if (parts.length == 2 && request.method == 'GET') {
      return jsonResponse(await service.list(table));
    }
    if (parts.length == 2 && request.method == 'POST') {
      return jsonResponse(
        await db.transaction(() => service.save(table, data)),
        201,
      );
    }
    require(
      parts.length >= 3 && int.tryParse(parts[2]) != null,
      'Mã không hợp lệ',
      404,
    );
    final id = int.parse(parts[2]);
    if (parts.length == 3 && request.method == 'GET') {
      return jsonResponse(await service.accessible(table, id));
    }
    if (parts.length == 3 && request.method == 'PUT') {
      return jsonResponse(
        await db.transaction(() => service.save(table, data, id: id)),
      );
    }
    if (parts.length == 3 && request.method == 'DELETE') {
      await db.transaction(() => service.delete(table, id));
      return jsonResponse({'ok': true});
    }
    if (parts.length == 4 && request.method == 'POST') {
      return jsonResponse(
        await db.transaction(
          () => service.action(
            table,
            id,
            parts[3],
            data,
            onlineDemo: config['ENABLE_ONLINE_DEMO'] == 'true',
          ),
        ),
      );
    }
    throw ApiError(404, 'Không tìm thấy API');
  } on ApiError catch (e) {
    return jsonResponse({'error': e.message}, e.status);
  } on ArgumentError catch (e) {
    return jsonResponse({'error': '${e.message}'}, 422);
  } on FormatException {
    return jsonResponse({'error': 'Dữ liệu gửi lên không hợp lệ'}, 400);
  } catch (e) {
    stderr.writeln('Request failed: ${e.runtimeType}');
    if (e.toString().contains('1062')) {
      return jsonResponse({
        'error': 'Dữ liệu đã tồn tại (email, CCCD, phòng hoặc kỳ)',
      }, 409);
    }
    if (e.toString().contains('1451') || e.toString().contains('1452')) {
      return jsonResponse({
        'error': 'Dữ liệu liên quan không tồn tại hoặc đang được sử dụng',
      }, 409);
    }
    return jsonResponse({
      'error': 'Không thể xử lý. Kiểm tra API/MySQL rồi thử lại.',
    }, 503);
  } finally {
    await db?.close();
  }
}

Future<void> main() async {
  final allowed = config['CORS_ORIGIN'] ?? 'http://localhost:5173';
  final server = await io.serve(
    (Request request) async {
      final origin = request.headers['origin'];
      final cors = <String, String>{
        if (origin == allowed) 'access-control-allow-origin': allowed,
        'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'access-control-allow-headers': 'Content-Type, Authorization',
        'vary': 'Origin',
      };
      if (request.method == 'OPTIONS') return Response(204, headers: cors);
      return (await handle(request)).change(headers: cors);
    },
    config['HOST'] ?? '127.0.0.1',
    int.parse(config['PORT'] ?? '8080'),
  );
  stdout.writeln('Rental API: http://${server.address.host}:${server.port}');
}

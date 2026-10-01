import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:rental_server/database.dart';
import 'package:rental_server/config.dart';

Future<void> main(List<String> args) async {
  final db = await Database.open();
  try {
    final schema = await File('database/schema.sql').readAsString();
    final clean = schema
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('--'))
        .join('\n');
    for (final statement in clean.split(';')) {
      if (statement.trim().isNotEmpty) await db.query(statement);
    }
    final email = config['ADMIN_EMAIL'];
    final password = config['ADMIN_PASSWORD'];
    require(
      email != null && password != null && password.length >= 8,
      'Đặt ADMIN_EMAIL và ADMIN_PASSWORD (ít nhất 8 ký tự)',
    );
    final existing = await db.query(
      'SELECT user_id FROM nguoi_dung WHERE email=:email',
      {'email': email},
    );
    if (existing.isEmpty) {
      await db.insert('nguoi_dung', {
        'ho_ten': 'Chủ trọ',
        'email': email!.toLowerCase(),
        'mat_khau': BCrypt.hashpw(password!, BCrypt.gensalt()),
        'vai_tro': 'CHU_TRO',
      });
    }
    for (final service in [
      {'ten_dv': 'Điện', 'don_gia': 3500, 'don_vi_tinh': 'kWh'},
      {'ten_dv': 'Nước', 'don_gia': 18000, 'don_vi_tinh': 'm³'},
      {'ten_dv': 'Internet', 'don_gia': 100000, 'don_vi_tinh': 'tháng'},
      {'ten_dv': 'Vệ sinh', 'don_gia': 30000, 'don_vi_tinh': 'tháng'},
    ]) {
      if ((await db.query('SELECT dich_vu_id FROM dich_vu WHERE ten_dv=:name', {
        'name': service['ten_dv'],
      })).isEmpty) {
        await db.insert('dich_vu', service);
      }
    }
    stdout.writeln('Đã tạo schema, tài khoản chủ trọ và dịch vụ mặc định.');
  } finally {
    await db.close();
  }
}

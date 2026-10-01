import 'dart:async';
import 'dart:io';
import 'package:rental_server/database.dart';
import 'package:rental_server/firebase_gateway.dart';
import 'package:rental_server/firebase_reminders.dart';

/// Polls committed MySQL notifications only. Successful deliveries are tracked
/// per device; transient failures retry on the next pass (at-least-once).
Future<void> main() async {
  final gateway = FirebaseGateway.instance;
  if (!gateway.enabled) {
    stderr.writeln('Configure FIREBASE_SERVICE_ACCOUNT first.');
    exitCode = 1;
    return;
  }
  while (true) {
    Database? db;
    try {
      db = await Database.open();
      await queueInvoiceReminders(db);
      final rows = await db.query(
        '''SELECT n.*,d.token,d.token_hash FROM thong_bao n
        JOIN firebase_devices d ON d.user_id=n.nguoi_nhan_id
        JOIN nguoi_dung u ON u.user_id=d.user_id AND u.trang_thai='HOAT_DONG'
        LEFT JOIN firebase_push_delivery p ON p.notification_id=n.thong_bao_id AND p.token_hash=d.token_hash
        WHERE p.notification_id IS NULL AND n.ngay_tao>=d.updated_at
        ORDER BY n.thong_bao_id LIMIT 100''',
      );
      for (final row in rows) {
        try {
          await gateway.sendPush(
            '${row['token']}',
            '${row['tieu_de']}',
            '${row['noi_dung']}',
            {'notificationId': row['thong_bao_id']},
          );
          await db.query(
            'INSERT IGNORE INTO firebase_push_delivery (notification_id,token_hash) VALUES (:id,:hash)',
            {'id': row['thong_bao_id'], 'hash': row['token_hash']},
          );
        } on InvalidDeviceToken {
          await db.query(
            'DELETE FROM firebase_devices WHERE token_hash=:hash',
            {'hash': row['token_hash']},
          );
        } catch (_) {
          stderr.writeln('Push deferred; will retry.');
        }
      }
    } catch (_) {
      stderr.writeln('Worker unavailable; check MySQL/Firebase configuration.');
    } finally {
      await db?.close();
    }
    await Future<void>.delayed(const Duration(seconds: 10));
  }
}

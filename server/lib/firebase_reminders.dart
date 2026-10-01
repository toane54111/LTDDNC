import 'database.dart';

Future<void> queueInvoiceReminders(Database db) async {
  final invoices = await db.query(
    '''SELECT h.hoa_don_id,h.han_thanh_toan,d.khach_thue_id
    FROM hoa_don h JOIN hop_dong d ON d.hop_dong_id=h.hop_dong_id
    WHERE h.han_thanh_toan BETWEEN DATE_SUB(CURDATE(),INTERVAL 7 DAY) AND DATE_ADD(CURDATE(),INTERVAL 3 DAY)
      AND h.tong_tien > (SELECT COALESCE(SUM(g.so_tien),0) FROM giao_dich g
        WHERE g.hoa_don_id=h.hoa_don_id AND g.trang_thaigd='DA_XAC_NHAN')''',
  );
  for (final invoice in invoices) {
    await db.transaction(() async {
      final inserted = await db.connection.execute(
        'INSERT IGNORE INTO firebase_invoice_reminders (invoice_id,reminder_date) VALUES (:id,CURDATE())',
        {'id': invoice['hoa_don_id']},
      );
      if (inserted.affectedRows.toInt() == 0) return;
      await db.insert('thong_bao', {
        'nguoi_nhan_id': invoice['khach_thue_id'],
        'tieu_de': 'Nhắc thanh toán hóa đơn',
        'noi_dung':
            'Hóa đơn #${invoice['hoa_don_id']} còn dư nợ, hạn ${invoice['han_thanh_toan']}.',
        'link': 'hoa_don/${invoice['hoa_don_id']}',
      });
    });
  }
}

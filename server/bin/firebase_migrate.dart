import 'dart:io';
import 'package:rental_server/database.dart';

Future<void> main() async {
  final db = await Database.open();
  try {
    for (final sql in (await File(
      'database/firebase.sql',
    ).readAsString()).split(';')) {
      if (sql.trim().isNotEmpty) await db.query(sql);
    }
    stdout.writeln('Firebase tables ready. Existing rental data preserved.');
  } finally {
    await db.close();
  }
}

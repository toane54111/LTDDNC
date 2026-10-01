import 'config.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:rental_domain/rental_domain.dart';

class Database {
  Database(this.connection);
  final MySQLConnection connection;
  static Future<Database> open() async {
    final e = config;
    final c = await MySQLConnection.createConnection(
      host: e['DB_HOST'] ?? '127.0.0.1',
      port: int.parse(e['DB_PORT'] ?? '3306'),
      userName: e['DB_USER'] ?? 'rental',
      password: e['DB_PASSWORD'] ?? '',
      databaseName: e['DB_NAME'] ?? 'rental_flutter',
      secure: e['DB_TLS'] != 'false',
    );
    await c.connect();
    await c.execute('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED');
    return Database(c);
  }

  Future<List<Record>> query(String sql, [Record params = const {}]) async {
    final result = await connection.execute(sql, params);
    return result.rows.map((r) => <String, dynamic>{...r.assoc()}).toList();
  }

  Future<int> insert(String table, Record data) async {
    final keys = data.keys.toList();
    final result = await connection.execute(
      'INSERT INTO `$table` (${keys.map((k) => '`$k`').join(',')}) VALUES (${keys.map((k) => ':$k').join(',')})',
      data,
    );
    return result.lastInsertID.toInt();
  }

  Future<void> update(Module m, dynamic id, Record data) async {
    if (data.isEmpty) return;
    await query(
      'UPDATE `${m.table}` SET ${data.keys.map((k) => '`$k`=:$k').join(',')} WHERE `${m.id}`=:_id',
      {...data, '_id': id},
    );
  }

  Future<Record> row(String table, dynamic id, {bool lock = false}) async {
    final m = moduleOf(table);
    final rows = await query(
      'SELECT * FROM `$table` WHERE `${m.id}`=:id${lock ? ' FOR UPDATE' : ''}',
      {'id': id},
    );
    if (rows.isEmpty) throw ApiError(404, 'Không tìm thấy dữ liệu');
    return rows.first;
  }

  Future<T> transaction<T>(Future<T> Function() body) async {
    await query('START TRANSACTION');
    try {
      final result = await body();
      await query('COMMIT');
      return result;
    } catch (_) {
      await query('ROLLBACK');
      rethrow;
    }
  }

  Future<void> close() => connection.close();
}

class ApiError implements Exception {
  ApiError(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

void require(bool ok, String message, [int status = 422]) {
  if (!ok) throw ApiError(status, message);
}

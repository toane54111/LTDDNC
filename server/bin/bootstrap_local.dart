import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:rental_server/config.dart';

/// Only for the new isolated instance initialized with --initialize-insecure.
/// Never point this command at an existing MySQL installation's data directory.
Future<void> main() async {
  final connection = await MySQLConnection.createConnection(
    host: '127.0.0.1',
    port: 3307,
    userName: 'root',
    password: '',
    secure: true,
  );
  await connection.connect();
  try {
    await connection.execute(
      'CREATE DATABASE IF NOT EXISTS rental_flutter CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci',
    );
    await connection.execute(
      "CREATE USER IF NOT EXISTS 'rental'@'localhost' IDENTIFIED BY :password",
      {'password': config['DB_PASSWORD']},
    );
    await connection.execute(
      "GRANT ALL PRIVILEGES ON rental_flutter.* TO 'rental'@'localhost'",
    );
    await connection.execute(
      "ALTER USER 'root'@'localhost' IDENTIFIED BY :password",
      {'password': config['MYSQL_ROOT_PASSWORD']},
    );
  } finally {
    await connection.close();
  }
}

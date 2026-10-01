import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:rental_server/config.dart';
import '../bin/server.dart' as api;

void main() {
  group(
    'API authentication with real MySQL',
    () {
      late String token;
      setUp(() async {
        final response = await api.handle(
          Request(
            'POST',
            Uri.parse('http://localhost/api/login'),
            body: jsonEncode({
              'email': config['ADMIN_EMAIL'],
              'password': config['ADMIN_PASSWORD'],
            }),
          ),
        );
        expect(response.statusCode, 200);
        final data = jsonDecode(await response.readAsString());
        expect(data['user'].containsKey('mat_khau'), isFalse);
        token = data['token'];
      });
      tearDown(() => api.sessions.clear());
      test(
        'rejects missing token and hides password hashes in lists',
        () async {
          final anonymous = await api.handle(
            Request('GET', Uri.parse('http://localhost/api/phong_tro')),
          );
          expect(anonymous.statusCode, 401);
          final users = await api.handle(
            Request(
              'GET',
              Uri.parse('http://localhost/api/nguoi_dung'),
              headers: {'authorization': 'Bearer $token'},
            ),
          );
          expect(users.statusCode, 200);
          expect(await users.readAsString(), isNot(contains('mat_khau')));
        },
      );
      test('logout invalidates the bearer token', () async {
        final response = await api.handle(
          Request(
            'POST',
            Uri.parse('http://localhost/api/logout'),
            headers: {'authorization': 'Bearer $token'},
          ),
        );
        expect(response.statusCode, 200);
        final again = await api.handle(
          Request(
            'GET',
            Uri.parse('http://localhost/api/hop_dong'),
            headers: {'authorization': 'Bearer $token'},
          ),
        );
        expect(again.statusCode, 401);
      });
      test('malformed JSON and unknown resources are rejected', () async {
        final invalid = await api.handle(
          Request(
            'POST',
            Uri.parse('http://localhost/api/login'),
            body: '{invalid',
          ),
        );
        expect(invalid.statusCode, 400);
        final missing = await api.handle(
          Request(
            'GET',
            Uri.parse('http://localhost/api/not-a-table'),
            headers: {'authorization': 'Bearer $token'},
          ),
        );
        expect(missing.statusCode, 404);
      });
    },
    skip: Platform.environment['RUN_MYSQL_TESTS'] != 'true'
        ? 'Requires configured MySQL'
        : false,
  );
}

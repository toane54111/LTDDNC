import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:rental_server/config.dart';
import 'package:rental_server/database.dart';
import 'package:rental_server/firebase_gateway.dart';

/// Live smoke check. Creates and removes only its uniquely named diagnostic
/// image/document; never prints tokens, passwords or service-account contents.
Future<void> main() async {
  final db = await Database.open();
  final gateway = FirebaseGateway.instance;
  final client = http.Client();
  String? imageUrl, docUrl, idToken;
  try {
    final users = await db.query(
      'SELECT * FROM nguoi_dung WHERE email=:email',
      {'email': config['ADMIN_EMAIL']},
    );
    require(users.isNotEmpty, 'Configured owner not found');
    final user = users.first;
    final apiLogin = await client.post(
      Uri.parse('http://127.0.0.1:${config['PORT'] ?? '8080'}/api/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'email': config['ADMIN_EMAIL'],
        'password': config['ADMIN_PASSWORD'],
      }),
    );
    require(apiLogin.statusCode == 200, 'Application API login failed');
    final apiToken = jsonDecode(apiLogin.body)['token'];
    try {
      final session = await client.post(
        Uri.parse(
          'http://127.0.0.1:${config['PORT'] ?? '8080'}/api/firebase/session',
        ),
        headers: {
          'authorization': 'Bearer $apiToken',
          'content-type': 'application/json',
        },
        body: '{}',
      );
      require(
        session.statusCode == 200 &&
            jsonDecode(session.body)['customToken'] is String,
        'Application Firebase session failed',
      );
      stdout.writeln('PASS Application API login and Firebase session');
    } finally {
      await client.post(
        Uri.parse('http://127.0.0.1:${config['PORT'] ?? '8080'}/api/logout'),
        headers: {'authorization': 'Bearer $apiToken'},
      );
    }
    final login = await client.post(
      Uri.https(
        'identitytoolkit.googleapis.com',
        '/v1/accounts:signInWithCustomToken',
        {'key': config['FIREBASE_WEB_API_KEY']!},
      ),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'token': gateway.customToken(user),
        'returnSecureToken': true,
      }),
    );
    require(
      login.statusCode == 200,
      'Firebase custom authentication failed (${login.statusCode})',
    );
    idToken = jsonDecode(login.body)['idToken'];
    stdout.writeln('PASS Firebase custom authentication');
    final headers = {
      'authorization': 'Bearer $idToken',
      'content-type': 'application/json',
    };
    final chats = await client.post(
      Uri.parse('${gateway.root}:runQuery'),
      headers: headers,
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': 'conversations'},
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'members'},
              'op': 'ARRAY_CONTAINS',
              'value': {'stringValue': 'rental_${user['user_id']}'},
            },
          },
          'limit': 1,
        },
      }),
    );
    require(
      chats.statusCode == 200,
      'Firestore member query failed (${chats.statusCode})',
    );
    stdout.writeln('PASS Firestore authenticated query and deployed rules');
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final document = 'diagnostics/check_$nonce';
    await gateway.putDocument(document, {
      'purpose': 'temporary connectivity check',
    });
    docUrl = '${gateway.root}/$document';
    stdout.writeln('PASS Backend Firestore write permission');
    final bucket = '${gateway.project}.firebasestorage.app';
    final object = 'uploads/rental_${user['user_id']}/check_$nonce.png';
    final upload = await client.post(
      Uri.https('firebasestorage.googleapis.com', '/v0/b/$bucket/o', {
        'name': object,
        'uploadType': 'media',
      }),
      headers: {
        'authorization': 'Firebase $idToken',
        'content-type': 'image/png',
      },
      body: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j8WQAAAAASUVORK5CYII=',
      ),
    );
    require(
      upload.statusCode == 200,
      'Storage upload failed (${upload.statusCode})',
    );
    imageUrl =
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(object)}';
    stdout.writeln('PASS Firebase Storage upload and deployed rules');
    final fcm = await (await gateway.client).post(
      Uri.parse(
        'https://fcm.googleapis.com/v1/projects/${gateway.project}/messages:send',
      ),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'validateOnly': true,
        'message': {
          'topic': 'rental-connectivity-check',
          'notification': {
            'title': 'Connectivity check',
            'body': 'Validation only; no message delivered',
          },
        },
      }),
    );
    require(fcm.statusCode == 200, 'FCM validation failed (${fcm.statusCode})');
    stdout.writeln('PASS FCM send permission (validation only; no push sent)');
  } catch (e) {
    stderr.writeln(
      e is ApiError ? e.message : 'Check failed: ${e.runtimeType}',
    );
    exitCode = 1;
  } finally {
    if (imageUrl != null) {
      final r = await client.delete(
        Uri.parse(imageUrl),
        headers: {'authorization': 'Firebase $idToken'},
      );
      if (r.statusCode >= 300) {
        stderr.writeln('Diagnostic image cleanup failed');
        exitCode = 1;
      }
    }
    if (docUrl != null) {
      final r = await (await gateway.client).delete(Uri.parse(docUrl));
      if (r.statusCode >= 300) {
        stderr.writeln('Diagnostic document cleanup failed');
        exitCode = 1;
      }
    }
    client.close();
    await db.close();
    if (gateway.enabled) (await gateway.client).close();
  }
}

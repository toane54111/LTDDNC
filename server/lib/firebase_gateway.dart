import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:googleapis_auth/auth_io.dart' hide RSAPrivateKey;
import 'package:http/http.dart' as http;
import 'package:rental_domain/rental_domain.dart';
import 'config.dart';
import 'database.dart';

/// Server credentials never leave the API host. Flutter receives a short-lived
/// custom token with a canonical MySQL identity, including after Google login.
class FirebaseGateway {
  static final instance = FirebaseGateway();
  http.Client? _client;
  Future<http.Client>? _opening;
  Record? _credentials;
  bool get enabled => (config['FIREBASE_SERVICE_ACCOUNT'] ?? '').isNotEmpty;
  Record get credentials => _credentials ??= Map<String, dynamic>.from(
    jsonDecode(File(config['FIREBASE_SERVICE_ACCOUNT']!).readAsStringSync()),
  );
  String get project => '${credentials['project_id']}';
  String get root =>
      'https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents';
  Future<http.Client> get client async {
    require(enabled, 'Firebase chưa được cấu hình trên máy chủ', 503);
    if (_client != null) return _client!;
    _opening ??= clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(credentials),
      [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/firebase.messaging',
      ],
    );
    try {
      return _client = await _opening!;
    } finally {
      _opening = null;
    }
  }

  String customToken(Record user) {
    require(enabled, 'Firebase chưa được cấu hình trên máy chủ', 503);
    final email = '${credentials['client_email']}';
    return JWT(
      {
        'uid': 'rental_${user['user_id']}',
        'claims': {
          'rentalId': '${user['user_id']}',
          'owner': user['vai_tro'] == 'CHU_TRO',
        },
      },
      issuer: email,
      subject: email,
      audience: Audience([
        'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
      ]),
    ).sign(
      RSAPrivateKey('${credentials['private_key']}'),
      algorithm: JWTAlgorithm.RS256,
      expiresIn: const Duration(minutes: 30),
    );
  }

  Future<Record> googleIdentity(String idToken) async {
    require(enabled, 'Firebase chưa được cấu hình', 503);
    final key = config['FIREBASE_WEB_API_KEY'];
    require(
      key != null && key.isNotEmpty,
      'Thiếu Firebase Web API key trên máy chủ',
      503,
    );
    final response = await http
        .post(
          Uri.https('identitytoolkit.googleapis.com', '/v1/accounts:lookup', {
            'key': key!,
          }),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 15));
    require(response.statusCode == 200, 'Phiên Google không hợp lệ', 401);
    // Lookup validates the signature/revocation; also bind the token explicitly
    // to this project and require the Google provider, not another login type.
    final payload = JWT.decode(idToken).payload as Map;
    require(
      payload['aud'] == project &&
          payload['iss'] == 'https://securetoken.google.com/$project' &&
          (payload['firebase'] as Map?)?['sign_in_provider'] == 'google.com',
      'Sai dự án hoặc nhà cung cấp đăng nhập',
      401,
    );
    final result = Map<String, dynamic>.from(
      (jsonDecode(response.body)['users'] as List).single,
    );
    require(
      result['emailVerified'] == true && result['disabled'] != true,
      'Email Google chưa xác minh hoặc đã bị khóa',
      403,
    );
    return result;
  }

  Future<void> putDocument(String path, Record fields) async {
    final response = await (await client).patch(
      Uri.parse('$root/$path?currentDocument.exists=false'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'fields': fields.map((k, v) => MapEntry(k, encode(v))),
      }),
    );
    require(
      response.statusCode < 300 || response.statusCode == 409,
      'Không thể lưu dữ liệu chat trên Firebase',
      503,
    );
  }

  static Record encode(dynamic value) {
    if (value is List) {
      return {
        'arrayValue': {'values': value.map(encode).toList()},
      };
    }
    if (value is Map) {
      return {
        'mapValue': {'fields': value.map((k, v) => MapEntry('$k', encode(v)))},
      };
    }
    if (value is int) return {'integerValue': '$value'};
    if (value is bool) return {'booleanValue': value};
    return {'stringValue': '$value'};
  }

  Future<void> sendPush(
    String token,
    String title,
    String body,
    Record data,
  ) async {
    final response = await (await client).post(
      Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$project/messages:send',
      ),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'message': {
          'token': token,
          'notification': {'title': title, 'body': body},
          'data': data.map((k, v) => MapEntry(k, '$v')),
          'android': {'priority': 'high'},
        },
      }),
    );
    if (response.statusCode >= 300) {
      final error = jsonDecode(response.body)['error'];
      final details = error is Map ? error['details'] : null;
      if (details is List &&
          details.any((e) => e is Map && e['errorCode'] == 'UNREGISTERED')) {
        throw const InvalidDeviceToken();
      }
      throw ApiError(503, 'Gửi thông báo chưa thành công');
    }
  }
}

class InvalidDeviceToken implements Exception {
  const InvalidDeviceToken();
}

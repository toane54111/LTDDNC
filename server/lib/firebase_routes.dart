import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:rental_domain/rental_domain.dart';
import 'database.dart';
import 'firebase_gateway.dart';
import 'service.dart';

class FirebaseRoutes {
  FirebaseRoutes(this.db, this.user, {FirebaseGateway? firebase})
    : gateway = firebase ?? FirebaseGateway.instance;
  final Database db;
  final Record user;
  final FirebaseGateway gateway;
  String get uid => '${user['user_id']}';
  Future<Record> peer(dynamic id) async {
    final other = await db.row('nguoi_dung', id);
    require(
      '${other['user_id']}' != uid &&
          other['trang_thai'] == 'HOAT_DONG' &&
          (user['vai_tro'] == 'CHU_TRO' || other['vai_tro'] == 'CHU_TRO'),
      'Không thể nhắn tài khoản này',
      403,
    );
    return other;
  }

  String roomId(Record other) {
    final ids = [int.parse(uid), int.parse('${other['user_id']}')]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  void validatePhoto(dynamic value) {
    final uri = Uri.tryParse('$value');
    final bucket = '${gateway.credentials['project_id']}.firebasestorage.app';
    final legacy = '${gateway.credentials['project_id']}.appspot.com';
    require(
      uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'firebasestorage.googleapis.com' &&
          uri.pathSegments.length == 5 &&
          uri.pathSegments[0] == 'v0' &&
          uri.pathSegments[1] == 'b' &&
          [bucket, legacy].contains(uri.pathSegments[2]) &&
          uri.pathSegments[3] == 'o' &&
          uri.pathSegments[4].startsWith('uploads/rental_$uid/'),
      'Ảnh phải được tải lên tài khoản hiện tại',
    );
  }

  Future<dynamic> handle(String path, String method, Record data) async {
    require(gateway.enabled, 'Firebase chưa được cấu hình trên máy chủ', 503);
    final service = RentalService(db, user);
    if (path == 'session' && method == 'POST') {
      return {'customToken': gateway.customToken(user)};
    }
    if (path == 'google-link' && method == 'POST') {
      final identity = await gateway.googleIdentity('${data['idToken'] ?? ''}');
      final email = '${identity['email']}'.toLowerCase();
      require(
        email == '${user['email']}'.toLowerCase(),
        'Email Google phải trùng email tài khoản nhà trọ',
        403,
      );
      final existing = await db.query(
        'SELECT * FROM firebase_google_links WHERE google_uid=:google OR user_id=:uid',
        {'google': identity['localId'], 'uid': uid},
      );
      require(
        existing.isEmpty ||
            existing.every(
              (r) =>
                  '${r['user_id']}' == uid &&
                  r['google_uid'] == identity['localId'],
            ),
        'Tài khoản Google đã liên kết với tài khoản khác',
        409,
      );
      await db.query(
        'INSERT IGNORE INTO firebase_google_links (google_uid,user_id) VALUES (:google,:uid)',
        {'google': identity['localId'], 'uid': uid},
      );
      return {'ok': true};
    }
    if (path == 'devices' && ['POST', 'DELETE'].contains(method)) {
      final token = '${data['token'] ?? ''}';
      require(
        token.isNotEmpty && token.length <= 4096,
        'Device token không hợp lệ',
      );
      final hash = sha256.convert(utf8.encode(token)).toString();
      if (method == 'DELETE') {
        await db.query(
          'DELETE FROM firebase_devices WHERE token_hash=:hash AND user_id=:uid',
          {'hash': hash, 'uid': uid},
        );
      } else {
        await db.query(
          'INSERT INTO firebase_devices (token_hash,user_id,token) VALUES (:hash,:uid,:token) ON DUPLICATE KEY UPDATE user_id=:uid,token=:token',
          {'hash': hash, 'uid': uid, 'token': token},
        );
      }
      return {'ok': true};
    }
    if (path == 'contacts' && method == 'GET') {
      return db.query(
        "SELECT user_id,ho_ten,vai_tro FROM nguoi_dung WHERE user_id<>:uid AND trang_thai='HOAT_DONG' ${service.owner ? '' : "AND vai_tro='CHU_TRO'"}",
        {'uid': uid},
      );
    }
    if (path == 'chat' && method == 'POST') {
      final other = await peer(data['recipient']);
      final id = roomId(other);
      // Read metadata to preserve messages and read receipts on reopening.
      final response = await (await gateway.client).get(
        Uri.parse('${gateway.root}/conversations/$id'),
      );
      if (response.statusCode == 404) {
        await gateway.putDocument('conversations/$id', {
          'members': ['rental_$uid', 'rental_${other['user_id']}'],
          'names': {
            'rental_$uid': user['ho_ten'],
            'rental_${other['user_id']}': other['ho_ten'],
          },
          'lastMessage': '',
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
          'lastSender': '',
        });
      } else {
        require(
          response.statusCode == 200,
          'Không thể mở cuộc trò chuyện',
          503,
        );
      }
      return {'id': id};
    }
    if (path == 'chat/send' && method == 'POST') {
      final other = await peer(data['recipient']);
      final text = '${data['text'] ?? ''}'.trim();
      final messageId = '${data['messageId'] ?? ''}';
      require(
        text.isNotEmpty &&
            text.length <= 2000 &&
            RegExp(r'^[a-zA-Z0-9_-]{10,80}$').hasMatch(messageId),
        'Tin nhắn không hợp lệ',
      );
      final id = roomId(other);
      final now = DateTime.now().toUtc().toIso8601String();
      // Atomic Firestore commit: metadata and message appear together.
      final fields = {'sender': 'rental_$uid', 'text': text, 'createdAt': now};
      final metadata = {
        'lastMessage': text,
        'lastSender': 'rental_$uid',
        'updatedAt': now,
      };
      final prefix =
          'projects/${gateway.project}/databases/(default)/documents';
      final result = await (await gateway.client).post(
        Uri.parse('${gateway.root}:commit'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'writes': [
            {
              'update': {
                'name': '$prefix/conversations/$id/messages/$messageId',
                'fields': fields.map(
                  (k, v) => MapEntry(k, FirebaseGateway.encode(v)),
                ),
              },
              'currentDocument': {'exists': false},
            },
            {
              'update': {
                'name': '$prefix/conversations/$id',
                'fields': metadata.map(
                  (k, v) => MapEntry(k, FirebaseGateway.encode(v)),
                ),
              },
              'updateMask': {'fieldPaths': metadata.keys.toList()},
              'currentDocument': {'exists': true},
            },
          ],
        }),
      );
      if (result.statusCode == 409) {
        return {'ok': true}; // Retry of same message.
      }
      require(
        result.statusCode < 300,
        'Không gửi được tin nhắn. Hãy mở lại cuộc trò chuyện.',
        503,
      );
      await service.notify(
        other['user_id'],
        'Tin nhắn mới từ ${user['ho_ten']}',
        text,
      );
      return {'ok': true};
    }
    if (path == 'chat/read' && method == 'POST') {
      final other = await peer(data['recipient']);
      final field = 'read_$uid';
      final response = await (await gateway.client).patch(
        Uri.parse(
          '${gateway.root}/conversations/${roomId(other)}?updateMask.fieldPaths=$field',
        ),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'fields': {
            field: FirebaseGateway.encode(
              DateTime.now().toUtc().toIso8601String(),
            ),
          },
        }),
      );
      require(
        response.statusCode < 300,
        'Không cập nhật được trạng thái đã đọc',
        503,
      );
      return {'ok': true};
    }
    if (path == 'avatar' && method == 'PUT') {
      validatePhoto(data['url']);
      await db.query(
        'INSERT INTO firebase_profiles (user_id,avatar_url) VALUES (:uid,:url) ON DUPLICATE KEY UPDATE avatar_url=:url',
        {'uid': uid, 'url': data['url']},
      );
      return {'ok': true};
    }
    if (path == 'avatar' && method == 'GET') {
      final rows = await db.query(
        'SELECT avatar_url FROM firebase_profiles WHERE user_id=:uid',
        {'uid': uid},
      );
      return rows.isEmpty ? <String, dynamic>{} : rows.first;
    }
    if (path == 'room-photo' && method == 'PUT') {
      service.landlord();
      await service.accessible('phong_tro', data['roomId']);
      validatePhoto(data['url']);
      await db.query(
        'INSERT INTO firebase_room_photos (room_id,photo_url) VALUES (:id,:url) ON DUPLICATE KEY UPDATE photo_url=:url',
        {'id': data['roomId'], 'url': data['url']},
      );
      return {'ok': true};
    }
    throw ApiError(404, 'Không tìm thấy Firebase API');
  }
}

import 'package:rental_domain/rental_domain.dart';
import 'package:rental_server/database.dart';
import 'package:rental_server/firebase_gateway.dart';
import 'package:rental_server/firebase_routes.dart';
import 'package:test/test.dart';

class FakeDatabase implements Database {
  FakeDatabase(this.other);
  final Record other;
  @override
  Future<Record> row(String table, dynamic id, {bool lock = false}) async =>
      other;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFirebase extends FirebaseGateway {
  @override
  Record get credentials => {'project_id': 'test-rental'};
}

void main() {
  final tenant = {'user_id': 2, 'vai_tro': 'KHACH_THUE'};
  final owner = {'user_id': 1, 'vai_tro': 'CHU_TRO', 'trang_thai': 'HOAT_DONG'};
  test('tenant can chat with owner but not another tenant', () async {
    await FirebaseRoutes(FakeDatabase(owner), tenant).peer(1);
    final other = {
      'user_id': 3,
      'vai_tro': 'KHACH_THUE',
      'trang_thai': 'HOAT_DONG',
    };
    await expectLater(
      FirebaseRoutes(FakeDatabase(other), tenant).peer(3),
      throwsA(isA<ApiError>().having((e) => e.status, 'status', 403)),
    );
  });
  test('inactive accounts cannot be selected as chat recipient', () async {
    await expectLater(
      FirebaseRoutes(
        FakeDatabase({...owner, 'trang_thai': 'BI_KHOA'}),
        tenant,
      ).peer(1),
      throwsA(isA<ApiError>()),
    );
  });
  test('self-chat is rejected', () async {
    await expectLater(
      FirebaseRoutes(
        FakeDatabase({...tenant, 'trang_thai': 'HOAT_DONG'}),
        tenant,
      ).peer(2),
      throwsA(isA<ApiError>()),
    );
  });
  test('photo URL accepts own Firebase bucket path only', () {
    final routes = FirebaseRoutes(
      FakeDatabase(owner),
      tenant,
      firebase: FakeFirebase(),
    );
    routes.validatePhoto(
      'https://firebasestorage.googleapis.com/v0/b/test-rental.firebasestorage.app/o/uploads%2Frental_2%2Fphoto.jpg?alt=media&token=demo',
    );
    for (final url in [
      'https://evil.example/photo.jpg',
      'https://firebasestorage.googleapis.com/v0/b/another-project.firebasestorage.app/o/uploads%2Frental_2%2Fphoto.jpg',
      'https://firebasestorage.googleapis.com/v0/b/test-rental.firebasestorage.app/o/uploads%2Frental_1%2Fphoto.jpg',
      'https://firebasestorage.googleapis.com/v0/b/test-rental.firebasestorage.app/o/uploads%2Frental_22%2Fphoto.jpg',
    ]) {
      expect(() => routes.validatePhoto(url), throwsA(isA<ApiError>()));
    }
  });
}

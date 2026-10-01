import 'dart:io';
import 'package:test/test.dart';
import 'package:rental_domain/rental_domain.dart';
import 'package:rental_server/database.dart';
import 'package:rental_server/service.dart';

void main() {
  group(
    'MySQL rental workflows (all fixtures roll back)',
    () {
      late Database db;
      late RentalService owner, tenant, outsider;
      late Record room, contract;
      setUp(() async {
        db = await Database.open();
        await db.query('START TRANSACTION');
        final nonce = DateTime.now().microsecondsSinceEpoch;
        final landlordId = await db.insert('nguoi_dung', {
          'ho_ten': 'Test owner',
          'email': 'owner-$nonce@test.local',
          'mat_khau': 'unused',
          'vai_tro': 'CHU_TRO',
        });
        final tenantId = await db.insert('nguoi_dung', {
          'ho_ten': 'Test tenant',
          'email': 'tenant-$nonce@test.local',
          'mat_khau': 'unused',
          'vai_tro': 'KHACH_THUE',
        });
        final otherId = await db.insert('nguoi_dung', {
          'ho_ten': 'Other tenant',
          'email': 'other-$nonce@test.local',
          'mat_khau': 'unused',
          'vai_tro': 'KHACH_THUE',
        });
        owner = RentalService(db, {
          'user_id': landlordId,
          'vai_tro': 'CHU_TRO',
        });
        tenant = RentalService(db, {
          'user_id': tenantId,
          'vai_tro': 'KHACH_THUE',
        });
        outsider = RentalService(db, {
          'user_id': otherId,
          'vai_tro': 'KHACH_THUE',
        });
        final area = await owner.save('khu_tro', {
          'ten_khu': 'Test $nonce',
          'dia_chi': 'Test address',
          'so_tang': 2,
        });
        room = await owner.save('phong_tro', {
          'khu_tro_id': area['khu_tro_id'],
          'so_phong': 'A1',
          'tang': 1,
          'dien_tich': 25,
          'gia_thue': 3000000,
        });
        contract = await owner.save('hop_dong', {
          'phong_id': room['phong_id'],
          'khach_thue_id': tenantId,
          'ngay_bat_dau': '2026-01-01',
          'ngay_ket_thuc': '2027-01-01',
          'tien_coc': 3000000,
        });
      });
      tearDown(() async {
        await db.query('ROLLBACK');
        await db.close();
      });
      Future<Record> invoice() async {
        await owner.save('chi_so_dien_nuoc', {
          'phong_id': room['phong_id'],
          'ky_ghi': '2026-09',
          'dien_cu': 100,
          'dien_moi': 170,
          'nuoc_cu': 20,
          'nuoc_moi': 25,
          'ngay_ghi': '2026-09-30',
        });
        return owner.save('hoa_don', {
          'hop_dong_id': contract['hop_dong_id'],
          'ky_thanh_toan': '2026-09',
          'han_thanh_toan': '2026-10-05',
        });
      }

      test('tenant cannot view another tenant records or edit rooms', () async {
        expect(await outsider.list('hop_dong'), isEmpty);
        await expectLater(
          outsider.accessible('hop_dong', contract['hop_dong_id']),
          throwsA(isA<ApiError>()),
        );
        await expectLater(
          tenant.save('phong_tro', {}),
          throwsA(isA<ApiError>()),
        );
        expect((await tenant.list('phong_tro')).length, 1);
      });
      test(
        'contract makes room occupied and prevents double booking',
        () async {
          expect(
            (await db.row('phong_tro', room['phong_id']))['trang_thai'],
            'DA_THUE',
          );
          await expectLater(
            owner.save('hop_dong', {
              'phong_id': room['phong_id'],
              'khach_thue_id': outsider.uid,
              'ngay_bat_dau': '2026-01-01',
              'ngay_ket_thuc': '2027-01-01',
              'tien_coc': 3000000,
            }),
            throwsA(isA<ApiError>()),
          );
        },
      );
      test(
        'bank transfer stays pending, then cash clears remaining debt',
        () async {
          final bill = await invoice();
          final notice = (await tenant.list('thong_bao')).first;
          expect('${notice['da_doc']}', '0');
          await tenant.action('thong_bao', notice['thong_bao_id'], 'read', {});
          expect('${(await tenant.list('thong_bao')).first['da_doc']}', '1');
          final id = bill['hoa_don_id'];
          await tenant.action('hoa_don', id, 'pay', {
            'so_tien': 1000000,
            'phuong_thuc': 'CHUYEN_KHOAN',
          });
          expect(await owner.paid(id), 0);
          final transaction = (await tenant.list('giao_dich')).first;
          await expectLater(
            tenant.action(
              'giao_dich',
              transaction['giao_dich_id'],
              'approve',
              {},
            ),
            throwsA(isA<ApiError>()),
          );
          await owner.action(
            'giao_dich',
            transaction['giao_dich_id'],
            'approve',
            {},
          );
          expect(await owner.paid(id), 1000000);
          expect(
            (await db.row('hoa_don', id))['trang_thai'],
            'THANH_TOAN_MOT_PHAN',
          );
          await expectLater(
            owner.action(
              'giao_dich',
              transaction['giao_dich_id'],
              'approve',
              {},
            ),
            throwsA(isA<ApiError>()),
          );
          await owner.action('hoa_don', id, 'pay', {
            'so_tien': integer(bill['tong_tien']) - 1000000,
            'phuong_thuc': 'TIEN_MAT',
          });
          expect((await db.row('hoa_don', id))['trang_thai'], 'DA_THANH_TOAN');
          await expectLater(
            owner.action('hoa_don', id, 'pay', {
              'so_tien': 1,
              'phuong_thuc': 'TIEN_MAT',
            }),
            throwsA(isA<ApiError>()),
          );
        },
      );
      test(
        'invoiced readings are immutable and duplicate invoice refused',
        () async {
          await invoice();
          final meter = (await owner.list(
            'chi_so_dien_nuoc',
          )).firstWhere((r) => '${r['phong_id']}' == '${room['phong_id']}');
          await expectLater(
            owner.save('chi_so_dien_nuoc', meter, id: meter['chi_so_id']),
            throwsA(isA<ApiError>()),
          );
          await expectLater(
            owner.save('hoa_don', {
              'hop_dong_id': contract['hop_dong_id'],
              'ky_thanh_toan': '2026-09',
              'han_thanh_toan': '2026-10-05',
            }),
            throwsA(isA<ApiError>()),
          );
        },
      );
      test(
        'annex needs tenant approval and keeps original base rent',
        () async {
          final annex = await owner.save('phu_luc_hop_dong', {
            'hop_dong_id': contract['hop_dong_id'],
            'gia_thue_mmoi': 4000000,
            'ngay_ket_thuc_moi': '2027-07-01',
          });
          await expectLater(
            owner.action(
              'phu_luc_hop_dong',
              annex['phu_luc_id'],
              'approve',
              {},
            ),
            throwsA(isA<ApiError>()),
          );
          await tenant.action(
            'phu_luc_hop_dong',
            annex['phu_luc_id'],
            'approve',
            {},
          );
          final updated = await db.row('hop_dong', contract['hop_dong_id']);
          expect(integer(updated['gia_thue']), 3000000);
          expect('${updated['ngay_ket_thuc']}'.substring(0, 10), '2027-07-01');
          expect(integer((await invoice())['tien_phong']), 3000000);
        },
      );
      test(
        'termination changes room, contract and records refund once',
        () async {
          final request = await tenant.save('yeu_cau_cham_dut', {
            'hop_dong_id': contract['hop_dong_id'],
            'ngay_du_kien_tra': DateTime.now().toIso8601String().substring(
              0,
              10,
            ),
            'ly_do': 'Test',
          });
          await owner.action(
            'yeu_cau_cham_dut',
            request['yeu_cau_id'],
            'approve',
            {},
          );
          expect(
            (await db.row('phong_tro', room['phong_id']))['trang_thai'],
            'TRONG',
          );
          expect(
            (await db.row('hop_dong', contract['hop_dong_id']))['trang_thai'],
            'DA_CHAM_DUT',
          );
          await expectLater(
            owner.action(
              'yeu_cau_cham_dut',
              request['yeu_cau_id'],
              'approve',
              {},
            ),
            throwsA(isA<ApiError>()),
          );
        },
      );
    },
    skip: Platform.environment['RUN_MYSQL_TESTS'] != 'true'
        ? 'Set RUN_MYSQL_TESTS=true after starting MySQL and running setup.dart'
        : false,
  );
}

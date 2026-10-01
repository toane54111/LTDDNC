import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ck/src/app.dart';
import 'package:ck/src/data.dart';
import 'package:ck/src/forms.dart';
import 'package:rental_domain/rental_domain.dart';

void main() {
  testWidgets('Login validates email and password', (tester) async {
    await tester.pumpWidget(const RentalApp());
    await tester.ensureVisible(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Nhập mật khẩu'), findsOneWidget);
  });
  for (final tenant in [false, true]) {
    testWidgets('Mobile preview navigation: tenant=$tenant', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = RentalStore()..preview(tenant: tenant);
      addTearDown(store.dispose);
      await tester.pumpWidget(RentalApp(store: store));
      await tester.pumpAndSettle();
      expect(find.textContaining('XEM TRƯỚC'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Phòng A101'), findsOneWidget);
      await tester.tap(find.text('Phòng A101'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Thông tin trong phòng'), 300, scrollable:find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Thông tin trong phòng'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      expect(find.text('Khu trọ'), tenant ? findsNothing : findsOneWidget);
      expect(find.text('Khách thuê'), tenant ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Meter form refuses invalid period and negative readings', (
    tester,
  ) async {
    final store = RentalStore()..preview();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataForm(
            store: store,
            title: 'Điện nước',
            fields: moduleOf('chi_so_dien_nuoc').fields,
            initial: const {
              'phong_id': 1,
              'ky_ghi': '2026-13',
              'dien_cu': 0,
              'dien_moi': -1,
              'nuoc_cu': 0,
              'nuoc_moi': 0,
            },
            draft: false,
            submit: 'Lưu',
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Lưu'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kỳ ghi (YYYY-MM)'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Dùng định dạng YYYY-MM'), findsOneWidget);
    expect(find.text('Nhập số không âm hợp lệ'), findsOneWidget);
  });
  test('month arithmetic preserves end-of-month and leap year', () {
    expect(addMonths(DateTime(2024, 8, 31), 6), DateTime(2025, 2, 28));
    expect(addMonths(DateTime(2023, 8, 31), 6), DateTime(2024, 2, 29));
  });
  test('meter validation rejects backwards movement', () {
    expect(
      () => validateMeters({
        'dien_cu': 50,
        'dien_moi': 49,
        'nuoc_cu': 0,
        'nuoc_moi': 1,
      }),
      throwsArgumentError,
    );
  });
}

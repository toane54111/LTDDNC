import 'package:test/test.dart';
import 'package:rental_domain/rental_domain.dart';

void main() {
  test('rejects invalid dates rather than silently normalizing them', () {
    expect(
      validateField(const Field('d', 'Date', kind: 'date'), '2026-02-31'),
      isNotNull,
    );
    expect(
      validateField(const Field('d', 'Date', kind: 'date'), '2024-02-29'),
      isNull,
    );
  });
  test('rejects fractional or nonfinite monetary amounts', () {
    const amount = Field('a', 'Amount', kind: 'int');
    for (final input in ['NaN', 'Infinity', '-1', '12.5']) {
      expect(validateField(amount, input), isNotNull);
    }
    expect(validateField(amount, '1200000'), isNull);
  });
  test('rejects injected enum and IDs', () {
    expect(
      validateField(
        const Field('status', 'Status', options: ['TRONG', 'BAO_TRI']),
        'DA_THUE',
      ),
      isNotNull,
    );
    expect(
      validateField(
        const Field('room', 'Room', reference: 'phong_tro'),
        '1 OR 1=1',
      ),
      isNotNull,
    );
  });
}

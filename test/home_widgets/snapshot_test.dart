import 'package:flutter_test/flutter_test.dart';
import 'package:flourish/core/widgets/home_widget_snapshot.dart';

void main() {
  test('private widget snapshots contain no financial totals', () {
    final snapshot = HomeWidgetSnapshot.create(
      hidden: true,
      currency: 'EGP',
      locale: 'ar',
      updatedAt: DateTime(2026, 10, 19),
      periodEnd: DateTime(2026, 11, 1),
      labels: const {},
      income: '1000',
      spending: '250',
    );
    expect(snapshot.containsKey('income'), false);
    expect(snapshot.containsKey('spending'), false);
    expect(snapshot['hidden'], true);
  });
}

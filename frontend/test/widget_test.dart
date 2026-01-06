import 'package:flutter_test/flutter_test.dart';

import 'package:taxi_palestine_app/screens/auth/login_page.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const TaxiPalestineApp());

    expect(tester.takeException(), isNull);
  });
}

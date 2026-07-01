import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hdk_admin/main.dart';

void main() {
  testWidgets('admin app boots', (WidgetTester tester) async {
    await tester.pumpWidget(
      HDKAdminApp(navigatorKey: GlobalKey<NavigatorState>()),
    );

    expect(find.byType(MaterialApp), findsOneWidget);

    // Pump time forward to resolve pending splash screen route timer
    await tester.pumpAndSettle(const Duration(milliseconds: 1000));
  });
}

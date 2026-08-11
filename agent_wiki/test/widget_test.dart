import 'package:agent_wiki/core/models/enums.dart';
import 'package:agent_wiki/ui/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StatusBadge renders the verification-hierarchy label',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusBadge(ClaimStatus.humanVerified)),
    ));
    expect(find.text('✓ Human verified'), findsOneWidget);
  });

  testWidgets('StatusBadge renders hypothesis label', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StatusBadge(ClaimStatus.unverified)),
    ));
    expect(find.text('⚠ Hypothesis'), findsOneWidget);
  });
}

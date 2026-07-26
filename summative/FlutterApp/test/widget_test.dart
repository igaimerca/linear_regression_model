import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hearing_predictor/main.dart';

void main() {
  testWidgets(
      'Prediction page renders visible fields and Predict button; '
      'conditional fields appear only after their trigger answer',
      (WidgetTester tester) async {
    await tester.pumpWidget(const HearingPredictorApp());

    expect(find.text('Predict'), findsOneWidget);
    // 2 conditional dropdowns (ear protection, workplace noise loudness) start hidden.
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(9));

    // Answering "Have you ever fired a gun?" with Yes reveals the ear-protection question.
    await tester.ensureVisible(find.byKey(const ValueKey('AUQ300')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('AUQ300')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes').last);
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(10));
    expect(find.text('Do you wear ear protection when shooting?'), findsOneWidget);
  });
}

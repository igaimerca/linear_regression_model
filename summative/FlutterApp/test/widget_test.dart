import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hearing_predictor/main.dart';

void main() {
  testWidgets('Prediction page renders all 13 input fields and Predict button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const HearingPredictorApp());

    expect(find.text('Predict'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(DropdownButtonFormField<int>), findsNWidgets(11));
  });
}

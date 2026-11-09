import 'package:flutter_test/flutter_test.dart';

import 'package:resume_screener_frontend/main.dart';

void main() {
  testWidgets('shows the application placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const ResumeScreenerApp());

    expect(find.text('Resume Screener Assistant'), findsWidgets);
    expect(
      find.text('The application is being built phase by phase.'),
      findsOneWidget,
    );
  });
}

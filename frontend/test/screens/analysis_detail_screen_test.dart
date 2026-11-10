import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_screener_frontend/models/analysis_history_item.dart';
import 'package:resume_screener_frontend/screens/analysis_detail_screen.dart';

void main() {
  Future<void> pumpDetail(
    WidgetTester tester, {
    AnalysisHistoryItem? item,
    bool isLoading = false,
    String? errorMessage,
    bool isNotFound = false,
    VoidCallback? onRetry,
    VoidCallback? onBack,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnalysisDetailScreen(
            item: item,
            isLoading: isLoading,
            errorMessage: errorMessage,
            isNotFound: isNotFound,
            onRetry: onRetry ?? () {},
            onBack: onBack ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows an accessible loading state with History navigation', (
    WidgetTester tester,
  ) async {
    var wentBack = false;
    await pumpDetail(tester, isLoading: true, onBack: () => wentBack = true);

    expect(
      find.byKey(const ValueKey('analysis-detail-loading')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('analysis-detail-back')));
    expect(wentBack, isTrue);
  });

  testWidgets('shows only fields returned by the history detail model', (
    WidgetTester tester,
  ) async {
    final item = _historyItem();
    await pumpDetail(tester, item: item);

    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(find.text('82 / 100'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('analysis-detail-created-at')),
          )
          .data,
      'Analyzed ${_formatLocalDateTime(item.createdAt.toLocal())}',
    );
    for (final skill in item.matchingSkills) {
      expect(find.text(skill), findsOneWidget);
    }
    for (final gap in item.skillGaps) {
      expect(find.text(gap), findsOneWidget);
    }
    for (final question in item.interviewQuestions) {
      expect(find.text(question), findsOneWidget);
    }
    expect(find.text('Assessment breakdown'), findsNothing);
    expect(find.textContaining('advisory assessment'), findsNothing);
  });

  testWidgets('shows retryable safe error and not-found states', (
    WidgetTester tester,
  ) async {
    var retries = 0;
    await pumpDetail(
      tester,
      errorMessage: 'The service could not complete the request.',
      onRetry: () => retries++,
    );
    expect(find.byKey(const ValueKey('analysis-detail-error')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('analysis-detail-retry')));
    expect(retries, 1);

    await pumpDetail(
      tester,
      errorMessage: 'Analysis not found.',
      isNotFound: true,
    );
    expect(
      find.byKey(const ValueKey('analysis-detail-not-found')),
      findsOneWidget,
    );
  });

  testWidgets('wraps detail content on narrow layouts without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpDetail(tester, item: _historyItem());
    await tester.ensureVisible(find.text('Question three?'));
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

AnalysisHistoryItem _historyItem() => AnalysisHistoryItem(
  id: '123e4567-e89b-12d3-a456-426614174000',
  createdAt: DateTime.utc(2025, 3, 4, 15, 6),
  candidateName: 'Jordan Lee',
  matchScore: 82,
  matchingSkills: const ['Java', 'Spring', 'PostgreSQL', 'REST', 'Testing'],
  skillGaps: const ['Cloud deployment', 'Leadership', 'Domain experience'],
  interviewQuestions: const [
    'Question one?',
    'Question two?',
    'Question three?',
  ],
);

String _formatLocalDateTime(DateTime local) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${months[local.month - 1]} ${local.day}, ${local.year} at '
      '$hour:$minute $period';
}

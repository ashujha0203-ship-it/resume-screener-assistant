import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_screener_frontend/models/analysis_history_item.dart';
import 'package:resume_screener_frontend/models/analysis_page.dart';
import 'package:resume_screener_frontend/screens/history_screen.dart';

void main() {
  Future<void> pumpHistoryScreen(
    WidgetTester tester, {
    AnalysisPage? page,
    bool isLoading = false,
    String? errorMessage,
    ValueChanged<HistoryFilter>? onSearch,
    ValueChanged<int>? onPageChanged,
    VoidCallback? onRetry,
    ValueChanged<String>? onItemSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryScreen(
            initialPage: page,
            isLoading: isLoading,
            errorMessage: errorMessage,
            onSearch: onSearch,
            onPageChanged: onPageChanged,
            onRetry: onRetry,
            onItemSelected: onItemSelected,
          ),
        ),
      ),
    );
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows neutral idle state and no-page pagination before loading',
    (WidgetTester tester) async {
      await pumpHistoryScreen(tester);

      expect(find.byKey(const ValueKey('history-idle-title')), findsOneWidget);
      expect(find.text('History not loaded'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-empty-title')), findsNothing);
      expect(find.text('No pages'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('history-previous-page')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('history-next-page')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('shows an accessible loading indicator before first results', (
    WidgetTester tester,
  ) async {
    await pumpHistoryScreen(tester, isLoading: true);

    expect(
      find.byKey(const ValueKey('history-initial-loading')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('history-empty-title')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('displays candidate, score, local timestamp, skills and gaps', (
    WidgetTester tester,
  ) async {
    final item = _historyItem();
    await pumpHistoryScreen(tester, page: _page([item]));

    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(find.text('82 / 100'), findsOneWidget);
    final timestamp = tester.widget<Text>(
      find.byKey(ValueKey('history-created-at-${item.id}')),
    );
    expect(timestamp.data, _formatLocalDateTime(item.createdAt.toLocal()));
    for (final skill in item.matchingSkills) {
      expect(find.text(skill), findsOneWidget);
    }
    for (final gap in item.skillGaps) {
      expect(find.text(gap), findsOneWidget);
    }
  });

  testWidgets('shows a matching empty state when results are loaded empty', (
    WidgetTester tester,
  ) async {
    await pumpHistoryScreen(tester, page: _page(const []));

    expect(find.text('No matching analyses'), findsOneWidget);
    expect(
      find.text('Try changing or clearing the candidate and score filters.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('history-idle-title')), findsNothing);
    expect(find.byKey(const ValueKey('history-initial-loading')), findsNothing);
  });

  testWidgets('shows safe errors and Retry invokes the supplied callback', (
    WidgetTester tester,
  ) async {
    var retryCount = 0;
    await pumpHistoryScreen(
      tester,
      errorMessage: 'Could not connect to the service. Please try again.',
      onRetry: () => retryCount++,
    );

    expect(find.text('Could not load history'), findsOneWidget);
    expect(
      find.text('Could not connect to the service. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('provider secret'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('history-retry')));
    await tester.pump();
    expect(retryCount, 1);
    expect(find.byKey(const ValueKey('history-empty-title')), findsNothing);
  });

  testWidgets('shows refresh feedback while retaining existing records', (
    WidgetTester tester,
  ) async {
    final item = _historyItem();
    await pumpHistoryScreen(tester, page: _page([item]), isLoading: true);

    expect(
      find.byKey(const ValueKey('history-refresh-loading')),
      findsOneWidget,
    );
    expect(find.text('Jordan Lee'), findsOneWidget);
    expect(find.text('82 / 100'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-initial-loading')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a neutral candidate label for null names', (
    WidgetTester tester,
  ) async {
    await pumpHistoryScreen(
      tester,
      page: _page([_historyItem(candidateName: null)]),
    );

    expect(find.text('Candidate'), findsOneWidget);
  });

  testWidgets('validates score integer format, range, and min/max order', (
    WidgetTester tester,
  ) async {
    await pumpHistoryScreen(tester);
    final minField = find.byKey(const ValueKey('history-min-score-filter'));
    final maxField = find.byKey(const ValueKey('history-max-score-filter'));

    await tester.enterText(minField, '101');
    await tapVisible(tester, find.text('Search'));
    expect(find.text('Score must be from 0 to 100.'), findsOneWidget);

    await tester.enterText(minField, '10.5');
    await tapVisible(tester, find.text('Search'));
    expect(find.text('Enter a whole number.'), findsOneWidget);

    await tester.enterText(minField, '9' * 100);
    await tapVisible(tester, find.text('Search'));
    expect(find.text('Enter a whole number.'), findsOneWidget);

    await tester.enterText(minField, '80');
    await tester.enterText(maxField, '40');
    await tapVisible(tester, find.text('Search'));
    expect(find.text('Minimum cannot exceed maximum.'), findsWidgets);
  });

  testWidgets('validates whitespace-only candidate names and the max length', (
    WidgetTester tester,
  ) async {
    await pumpHistoryScreen(tester);
    final candidateName = find.byKey(
      const ValueKey('history-candidate-name-filter'),
    );

    await tester.enterText(candidateName, ' \t ');
    await tapVisible(tester, find.text('Search'));
    expect(
      find.text('Enter a name or leave this filter empty.'),
      findsOneWidget,
    );

    await tester.enterText(candidateName, 'c' * 205);
    await tester.pump();
    expect(
      tester.widget<TextFormField>(candidateName).controller!.text.length,
      200,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('history-candidate-name-counter')),
          )
          .data,
      '200 / 200',
    );
  });

  testWidgets('candidate limit counts UTF-16 units without splitting pairs', (
    WidgetTester tester,
  ) async {
    await pumpHistoryScreen(tester);
    final candidateName = find.byKey(
      const ValueKey('history-candidate-name-filter'),
    );
    final counter = find.byKey(
      const ValueKey('history-candidate-name-counter'),
    );
    final controller = tester.widget<TextFormField>(candidateName).controller!;

    await tester.enterText(candidateName, 'a' * 200);
    await tester.pump();
    expect(controller.text, 'a' * 200);
    expect(controller.text.length, 200);
    expect(tester.widget<Text>(counter).data, '200 / 200');

    await tester.enterText(candidateName, '🙂' * 100);
    await tester.pump();
    expect(controller.text, '🙂' * 100);
    expect(controller.text.length, 200);
    expect(tester.widget<Text>(counter).data, '200 / 200');

    await tester.enterText(candidateName, '🙂' * 101);
    await tester.pump();
    expect(controller.text, '🙂' * 100);
    expect(controller.text.length, 200);
    expect(tester.widget<Text>(counter).data, '200 / 200');

    final mixedName = '${'a' * 198}🙂b';
    await tester.enterText(candidateName, mixedName);
    await tester.pump();
    expect(controller.text, '${'a' * 198}🙂');
    expect(controller.text.length, 200);
    expect(tester.widget<Text>(counter).data, '200 / 200');

    await tester.enterText(candidateName, '${'b' * 199}🙂');
    await tester.pump();
    expect(controller.text, 'b' * 199);
    expect(controller.text.length, 199);
    expect(tester.widget<Text>(counter).data, '199 / 200');
  });

  testWidgets('search callback receives normalized optional filters', (
    WidgetTester tester,
  ) async {
    HistoryFilter? submitted;
    await pumpHistoryScreen(tester, onSearch: (filter) => submitted = filter);

    await tester.enterText(
      find.byKey(const ValueKey('history-candidate-name-filter')),
      '  Jordan Lee  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('history-min-score-filter')),
      '20',
    );
    await tester.enterText(
      find.byKey(const ValueKey('history-max-score-filter')),
      '90',
    );
    await tapVisible(tester, find.text('Search'));

    expect(submitted?.candidateName, 'Jordan Lee');
    expect(submitted?.minScore, 20);
    expect(submitted?.maxScore, 90);
  });

  testWidgets('empty score inputs are sent as no score filters', (
    WidgetTester tester,
  ) async {
    HistoryFilter? submitted;
    await pumpHistoryScreen(tester, onSearch: (filter) => submitted = filter);

    await tapVisible(tester, find.text('Search'));

    expect(submitted?.candidateName, isNull);
    expect(submitted?.minScore, isNull);
    expect(submitted?.maxScore, isNull);
  });

  testWidgets('Clear resets filters and notifies the search callback', (
    WidgetTester tester,
  ) async {
    HistoryFilter? submitted;
    await pumpHistoryScreen(tester, onSearch: (filter) => submitted = filter);
    await tester.enterText(
      find.byKey(const ValueKey('history-candidate-name-filter')),
      'Jordan',
    );
    await tester.enterText(
      find.byKey(const ValueKey('history-min-score-filter')),
      '50',
    );
    await tapVisible(tester, find.text('Clear'));

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('history-candidate-name-filter')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('history-min-score-filter')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(submitted?.candidateName, isNull);
    expect(submitted?.minScore, isNull);
    expect(find.text('Enter a name or leave this filter empty.'), findsNothing);
  });

  testWidgets('pagination disables boundaries and reports zero-based changes', (
    WidgetTester tester,
  ) async {
    var changedPage = -1;
    await pumpHistoryScreen(
      tester,
      page: _page([_historyItem()], page: 1, totalPages: 3),
      onPageChanged: (page) => changedPage = page,
    );
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('history-previous-page')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('history-next-page')),
          )
          .onPressed,
      isNotNull,
    );

    final nextPage = find.byKey(const ValueKey('history-next-page'));
    await tester.ensureVisible(nextPage);
    await tester.pumpAndSettle();
    await tester.tap(nextPage);
    expect(changedPage, 2);

    await pumpHistoryScreen(
      tester,
      page: _page([_historyItem()], page: 0, totalPages: 1),
      onPageChanged: (_) {},
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('history-previous-page')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('history-next-page')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('record selection callback receives the item ID', (
    WidgetTester tester,
  ) async {
    String? selectedId;
    final item = _historyItem();
    await pumpHistoryScreen(
      tester,
      page: _page([item]),
      onItemSelected: (id) => selectedId = id,
    );

    await tester.tap(find.byKey(ValueKey('history-candidate-${item.id}')));

    expect(selectedId, item.id);
  });

  testWidgets('communicates that backend integration is unavailable', (
    WidgetTester tester,
  ) async {
    await pumpHistoryScreen(tester, page: _page([_historyItem()]));

    await tapVisible(tester, find.text('Search'));
    expect(
      find.byKey(const ValueKey('history-integration-notice')),
      findsOneWidget,
    );
    expect(
      find.text('History integration will be added in a later step.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('history-candidate-$_id')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('history-integration-notice')),
      findsOneWidget,
    );
  });

  testWidgets('stacks filters and scrolls without overflow on narrow screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHistoryScreen(tester, page: _page([_historyItem()]));
    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out filter fields horizontally on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHistoryScreen(tester);

    final candidateRect = tester.getRect(
      find.byKey(const ValueKey('history-candidate-name-filter')),
    );
    final minRect = tester.getRect(
      find.byKey(const ValueKey('history-min-score-filter')),
    );
    final maxRect = tester.getRect(
      find.byKey(const ValueKey('history-max-score-filter')),
    );
    expect(candidateRect.top, minRect.top);
    expect(minRect.top, maxRect.top);
    expect(tester.takeException(), isNull);
  });
}

const _id = '123e4567-e89b-12d3-a456-426614174000';

AnalysisHistoryItem _historyItem({String? candidateName = 'Jordan Lee'}) =>
    AnalysisHistoryItem(
      id: _id,
      createdAt: DateTime.utc(2025, 3, 4, 15, 6),
      candidateName: candidateName,
      matchScore: 82,
      matchingSkills: const [
        'Java',
        'Spring Boot',
        'PostgreSQL',
        'REST APIs',
        'Testing',
      ],
      skillGaps: const ['Cloud deployment', 'Leadership', 'Domain experience'],
      interviewQuestions: const [
        'Question one?',
        'Question two?',
        'Question three?',
      ],
    );

AnalysisPage _page(
  List<AnalysisHistoryItem> content, {
  int page = 0,
  int totalPages = 1,
}) => AnalysisPage(
  content: content,
  page: page,
  size: 20,
  totalElements: content.length,
  totalPages: totalPages,
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

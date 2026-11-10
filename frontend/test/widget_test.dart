import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:resume_screener_frontend/app/resume_screener_controller.dart';
import 'package:resume_screener_frontend/app/resume_screener_app.dart';
import 'package:resume_screener_frontend/services/analysis_api_service.dart';

void main() {
  testWidgets('starts on Analyze with the application title', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ResumeScreenerApp());

    expect(find.text('Resume Screener Assistant'), findsOneWidget);
    expect(find.byKey(const ValueKey('analyze-screen-title')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('uses a navigation rail on wider screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ResumeScreenerApp());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('navigates between sections on a narrow screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ResumeScreenerApp());

    expect(find.byKey(const ValueKey('analyze-screen-title')), findsOneWidget);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-screen-title')), findsOneWidget);

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('results-empty-title')), findsOneWidget);
    expect(find.text('Go to Analyze'), findsOneWidget);
  });

  testWidgets(
    'loads history once on first selection and updates the UI from controller',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final response = Completer<http.Response>();
      var requestCount = 0;
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((_) {
            requestCount++;
            return response.future;
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );
      await tester.pumpWidget(ResumeScreenerApp(controller: controller));
      expect(requestCount, 0);

      await tester.tap(find.text('History'));
      await tester.pump();
      expect(requestCount, 1);
      expect(
        find.byKey(const ValueKey('history-initial-loading')),
        findsOneWidget,
      );

      await tester.tap(find.text('Results'));
      await tester.pump();
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(requestCount, 1);

      response.complete(http.Response(jsonEncode(_historyPageJson()), 200));
      await tester.pumpAndSettle();
      expect(find.text('Jordan Lee'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('history-refresh-loading')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('history filters and pagination use the active query', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <Uri>[];
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((request) async {
          requests.add(request.url);
          final requestedName =
              request.url.queryParameters['candidateName'] ?? 'Jordan';
          final page = int.parse(request.url.queryParameters['page']!);
          return http.Response(
            jsonEncode(
              _historyPageJson(name: requestedName, page: page, totalPages: 2),
            ),
            200,
          );
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    await tester.pumpWidget(ResumeScreenerApp(controller: controller));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));

    final candidateName = find.byKey(
      const ValueKey('history-candidate-name-filter'),
    );
    final minScore = find.byKey(const ValueKey('history-min-score-filter'));
    await tester.ensureVisible(candidateName);
    await tester.enterText(candidateName, 'Taylor');
    await tester.ensureVisible(minScore);
    await tester.enterText(minScore, '40');
    await tester.ensureVisible(find.byKey(const ValueKey('history-search')));
    await tester.tap(find.byKey(const ValueKey('history-search')));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests[1].queryParameters, {
      'candidateName': 'Taylor',
      'minScore': '40',
      'page': '0',
      'size': '20',
    });
    expect(controller.historyQuery.candidateName, 'Taylor');
    expect(
      find.byKey(const ValueKey('history-candidate-$_id')),
      findsOneWidget,
    );

    final nextPage = find.byKey(const ValueKey('history-next-page'));
    await tester.ensureVisible(nextPage);
    await tester.tap(nextPage);
    await tester.pumpAndSettle();

    expect(requests, hasLength(3));
    expect(requests[2].queryParameters, {
      'candidateName': 'Taylor',
      'minScore': '40',
      'page': '1',
      'size': '20',
    });
    expect(controller.historyQuery.page, 1);
    expect(find.text('Page 2 of 2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('history Retry repeats the query and renders refreshed data', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <Uri>[];
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((request) async {
          requests.add(request.url);
          if (requests.length == 1) {
            return http.Response(
              jsonEncode({
                'timestamp': '2025-01-01T00:00:00Z',
                'status': 503,
                'code': 'AI_RATE_LIMITED',
                'message': 'Sensitive provider details',
              }),
              503,
            );
          }
          return http.Response(
            jsonEncode(_historyPageJson(name: 'Retry result')),
            200,
          );
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    await tester.pumpWidget(ResumeScreenerApp(controller: controller));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(
      find.text('Analysis is temporarily unavailable. Please try again later.'),
      findsOneWidget,
    );
    expect(find.textContaining('Sensitive provider details'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('history-retry')));
    await tester.tap(find.byKey(const ValueKey('history-retry')));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests.first.queryParameters, requests.last.queryParameters);
    expect(find.text('Retry result'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-error-title')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'selecting a history record opens its detail and retry returns to History',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <Uri>[];
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((request) async {
            requests.add(request.url);
            if (request.url.path == '/api/analyses') {
              return http.Response(jsonEncode(_historyPageJson()), 200);
            }
            if (requests.where((uri) => uri.path.endsWith('/$_id')).length ==
                1) {
              return http.Response(
                jsonEncode({
                  'timestamp': '2025-01-01T00:00:00Z',
                  'status': 503,
                  'code': 'AI_RATE_LIMITED',
                  'message': 'Sensitive provider details',
                }),
                503,
              );
            }
            return http.Response(jsonEncode(_historyItemJson()), 200);
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );
      await tester.pumpWidget(ResumeScreenerApp(controller: controller));
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      final record = find.byKey(const ValueKey('history-candidate-$_id'));
      await tester.ensureVisible(record);
      await tester.tap(record);
      await tester.pumpAndSettle();

      expect(requests.last.path, '/api/analyses/$_id');
      expect(
        find.byKey(const ValueKey('analysis-detail-error')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Analysis is temporarily unavailable. Please try again later.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Sensitive provider details'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('analysis-detail-retry')));
      await tester.pumpAndSettle();
      expect(requests.last.path, '/api/analyses/$_id');
      expect(find.text('Jordan Lee'), findsOneWidget);
      expect(find.text('Suggested interview questions'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('analysis-detail-back')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('history-screen-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('history-candidate-$_id')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Results empty state action navigates to Analyze', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ResumeScreenerApp());

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('results-empty-title')), findsOneWidget);

    await tester.tap(find.text('Go to Analyze'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('analyze-screen-title')), findsOneWidget);
  });

  testWidgets('successful analysis navigates to Results with response data', (
    WidgetTester tester,
  ) async {
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient(
          (_) async => http.Response(jsonEncode(_analysisResultJson()), 201),
        ),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ResumeScreenerApp(controller: controller));

    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      'Backend role',
    );
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      'Resume text',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('analyze-submit')));
    await tester.tap(find.byKey(const ValueKey('analyze-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('results-match-score')), findsOneWidget);
    expect(find.byKey(const ValueKey('results-match-score')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('results-candidate-name')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.reset, throwsStateError);
  });
}

const _id = '123e4567-e89b-12d3-a456-426614174000';

Map<String, dynamic> _analysisResultJson() => {
  'id': _id,
  'createdAt': '2025-01-01T00:00:00Z',
  'candidateName': null,
  'matchScore': 82,
  'requiredSkills': {'rating': 80, 'rationale': 'Meets the requirements.'},
  'relevantExperience': {'rating': 81, 'rationale': 'Relevant background.'},
  'seniorityAndScope': {'rating': 82, 'rationale': 'Comparable scope.'},
  'niceToHaveSkillsAndDomainRelevance': {
    'rating': 83,
    'rationale': 'Some relevant experience.',
  },
  'matchingSkills': ['Java', 'Spring', 'SQL', 'REST', 'Testing'],
  'skillGaps': ['Cloud', 'Leadership', 'Domain'],
  'interviewQuestions': ['Question 1?', 'Question 2?', 'Question 3?'],
  'advisoryNotice': 'This is advisory only.',
};

Map<String, dynamic> _historyPageJson({
  String name = 'Jordan Lee',
  int page = 0,
  int totalPages = 1,
}) => {
  'content': [
    {
      'id': _id,
      'createdAt': '2025-01-01T00:00:00Z',
      'candidateName': name,
      'matchScore': 82,
      'matchingSkills': ['Java', 'Spring', 'SQL', 'REST', 'Testing'],
      'skillGaps': ['Cloud', 'Leadership', 'Domain'],
      'interviewQuestions': ['Question 1?', 'Question 2?', 'Question 3?'],
    },
  ],
  'page': page,
  'size': 20,
  'totalElements': totalPages * 20,
  'totalPages': totalPages,
};

Map<String, dynamic> _historyItemJson() => {
  'id': _id,
  'createdAt': '2025-01-01T00:00:00Z',
  'candidateName': 'Jordan Lee',
  'matchScore': 82,
  'matchingSkills': ['Java', 'Spring', 'SQL', 'REST', 'Testing'],
  'skillGaps': ['Cloud', 'Leadership', 'Domain'],
  'interviewQuestions': ['Question 1?', 'Question 2?', 'Question 3?'],
};

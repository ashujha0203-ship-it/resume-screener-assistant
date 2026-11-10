import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resume_screener_frontend/app/resume_screener_controller.dart';
import 'package:resume_screener_frontend/services/analysis_api_service.dart';
import 'package:resume_screener_frontend/screens/analyze_screen.dart';

void main() {
  Future<ResumeScreenerController> pumpAnalyzeScreen(
    WidgetTester tester, {
    Future<http.Response> Function(http.Request request)? handler,
    VoidCallback? onAnalysisSubmitted,
  }) async {
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient(
          handler ??
              (_) async =>
                  http.Response(jsonEncode(_analysisResultJson()), 201),
        ),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnalyzeScreen(
            controller: controller,
            onAnalysisSubmitted: onAnalysisSubmitted ?? () {},
          ),
        ),
      ),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('shows all fields with the required character limits', (
    WidgetTester tester,
  ) async {
    await pumpAnalyzeScreen(tester);

    expect(find.byKey(const ValueKey('candidate-name-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('job-description-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('resume-field')), findsOneWidget);
    expect(find.text('Candidate Name (optional)'), findsOneWidget);
    expect(find.text('Job Description'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('candidate-name-counter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('job-description-counter')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('resume-counter')), findsOneWidget);
    expect(find.text('0 / 200'), findsOneWidget);
    expect(find.text('0 / 20000'), findsOneWidget);
    expect(find.text('0 / 30000'), findsOneWidget);
  });

  testWidgets('required fields reject empty and whitespace-only input', (
    WidgetTester tester,
  ) async {
    await pumpAnalyzeScreen(tester);
    await tapVisible(tester, find.text('Analyze'));

    expect(find.text('Job description is required.'), findsOneWidget);
    expect(find.text('Resume is required.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      ' \t\n ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      ' \n\t ',
    );
    await tapVisible(tester, find.text('Analyze'));

    expect(find.text('Job description is required.'), findsOneWidget);
    expect(find.text('Resume is required.'), findsOneWidget);
  });

  testWidgets('candidate name is optional when required text is valid', (
    WidgetTester tester,
  ) async {
    final controller = await pumpAnalyzeScreen(tester);
    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      'Backend engineer role',
    );
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      'Experienced engineer',
    );

    await tapVisible(tester, find.text('Analyze'));

    expect(controller.analysisResult, isNotNull);
    expect(find.byKey(const ValueKey('analyze-error')), findsNothing);
  });

  testWidgets('updates the visible character counters as text changes', (
    WidgetTester tester,
  ) async {
    await pumpAnalyzeScreen(tester);

    await tester.enterText(
      find.byKey(const ValueKey('candidate-name-field')),
      'Jordan Lee',
    );
    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      'Backend role',
    );
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      'Resume text',
    );
    await tester.pump();

    expect(find.text('10 / 200'), findsOneWidget);
    expect(find.text('12 / 20000'), findsOneWidget);
    expect(find.text('11 / 30000'), findsOneWidget);
  });

  testWidgets('limits typed and pasted content for all fields', (
    WidgetTester tester,
  ) async {
    await pumpAnalyzeScreen(tester);

    final candidate = 'c' * 201;
    final jobDescription = 'j' * 20001;
    final resume = 'r' * 30001;

    await tester.enterText(
      find.byKey(const ValueKey('candidate-name-field')),
      candidate,
    );
    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      jobDescription,
    );
    await tester.enterText(find.byKey(const ValueKey('resume-field')), resume);
    await tester.pump();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('candidate-name-field')),
          )
          .controller!
          .text
          .length,
      200,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('job-description-field')),
          )
          .controller!
          .text
          .length,
      20000,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('resume-field')))
          .controller!
          .text
          .length,
      30000,
    );
    expect(find.text('200 / 200'), findsOneWidget);
    expect(find.text('20000 / 20000'), findsOneWidget);
    expect(find.text('30000 / 30000'), findsOneWidget);
  });

  testWidgets('does not split a surrogate pair at a character limit', (
    WidgetTester tester,
  ) async {
    await pumpAnalyzeScreen(tester);
    final text = '${'x' * 199}\u{1F600}';

    await tester.enterText(
      find.byKey(const ValueKey('candidate-name-field')),
      text,
    );

    final controller = tester
        .widget<TextFormField>(
          find.byKey(const ValueKey('candidate-name-field')),
        )
        .controller!;
    expect(controller.text.length, 199);
    expect(controller.text, 'x' * 199);
  });

  testWidgets('Clear resets fields, validation errors, and local notices', (
    WidgetTester tester,
  ) async {
    await pumpAnalyzeScreen(tester);
    await tapVisible(tester, find.text('Analyze'));
    expect(find.text('Job description is required.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('candidate-name-field')),
      'Jordan Lee',
    );
    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      'Backend role',
    );
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      'Resume text',
    );

    await tapVisible(tester, find.text('Clear'));

    expect(find.text('Job description is required.'), findsNothing);
    expect(find.text('Resume is required.'), findsNothing);
    expect(find.text('0 / 200'), findsOneWidget);
    expect(find.text('0 / 20000'), findsOneWidget);
    expect(find.text('0 / 30000'), findsOneWidget);
  });

  testWidgets('valid submission calls the API and clears the form on success', (
    WidgetTester tester,
  ) async {
    http.Request? receivedRequest;
    var navigated = false;
    final controller = await pumpAnalyzeScreen(
      tester,
      handler: (request) async {
        receivedRequest = request;
        return http.Response(jsonEncode(_analysisResultJson()), 201);
      },
      onAnalysisSubmitted: () => navigated = true,
    );
    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      '  Backend engineer role  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      '  Experienced engineer  ',
    );

    await tapVisible(tester, find.text('Analyze'));

    expect(receivedRequest?.method, 'POST');
    final body = jsonDecode(receivedRequest!.body) as Map<String, dynamic>;
    expect(body.containsKey('candidateName'), isFalse);
    expect(body['jobDescription'], '  Backend engineer role  ');
    expect(body['resume'], '  Experienced engineer  ');
    expect(controller.analysisResult?.id, _id);
    expect(controller.submissionState.status, OperationStatus.idle);
    expect(navigated, isTrue);
    expect(find.text('0 / 20000'), findsOneWidget);
    expect(find.text('0 / 30000'), findsOneWidget);
  });

  testWidgets('trims nonblank candidate name before submitting', (
    WidgetTester tester,
  ) async {
    http.Request? receivedRequest;
    await pumpAnalyzeScreen(
      tester,
      handler: (request) async {
        receivedRequest = request;
        return http.Response(jsonEncode(_analysisResultJson()), 201);
      },
    );
    await tester.enterText(
      find.byKey(const ValueKey('candidate-name-field')),
      '  Jordan Lee  ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      'Role',
    );
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      'Resume',
    );

    await tapVisible(tester, find.text('Analyze'));

    expect(
      (jsonDecode(receivedRequest!.body)
          as Map<String, dynamic>)['candidateName'],
      'Jordan Lee',
    );
  });

  testWidgets('shows only safe API errors and preserves entered values', (
    WidgetTester tester,
  ) async {
    await pumpAnalyzeScreen(
      tester,
      handler: (_) async => http.Response(
        jsonEncode({
          'timestamp': '2025-01-01T00:00:00Z',
          'status': 502,
          'code': 'AI_PROVIDER_ERROR',
          'message': 'sensitive resume or provider data',
        }),
        502,
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      'Backend role',
    );
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      'Private resume text',
    );

    await tapVisible(tester, find.text('Analyze'));

    expect(
      find.text('The analysis provider could not complete the request.'),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('job-description-field')),
          )
          .controller!
          .text,
      'Backend role',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('resume-field')))
          .controller!
          .text,
      'Private resume text',
    );
  });

  testWidgets('editing after a failed submission preserves error state', (
    WidgetTester tester,
  ) async {
    final controller = await pumpAnalyzeScreen(
      tester,
      handler: (_) async => http.Response(
        jsonEncode({
          'timestamp': '2025-01-01T00:00:00Z',
          'status': 502,
          'code': 'AI_PROVIDER_ERROR',
          'message': 'Sensitive provider details.',
        }),
        502,
      ),
    );
    final jobDescription = find.byKey(const ValueKey('job-description-field'));
    await tester.enterText(jobDescription, 'Original role');
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      'Original resume',
    );
    await tapVisible(tester, find.text('Analyze'));

    final errorMessage = controller.submissionState.errorMessage;
    expect(errorMessage, isNotNull);
    expect(find.text(errorMessage!), findsOneWidget);

    await tester.enterText(jobDescription, 'Updated role');

    expect(controller.submissionState.errorMessage, errorMessage);
    expect(find.text(errorMessage), findsOneWidget);
    expect(
      tester.widget<TextFormField>(jobDescription).controller!.text,
      'Updated role',
    );
  });

  testWidgets(
    'disables submission and shows progress while request is pending',
    (WidgetTester tester) async {
      final response = Completer<http.Response>();
      await pumpAnalyzeScreen(tester, handler: (_) => response.future);
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
      await tester.pump();

      expect(
        find.byKey(const ValueKey('analyze-loading-indicator')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('analyze-loading-status')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('analyze-submit')))
            .onPressed,
        isNull,
      );

      response.complete(http.Response(jsonEncode(_analysisResultJson()), 201));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('remains scrollable without overflow at a narrow viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAnalyzeScreen(tester);
    await tester.enterText(
      find.byKey(const ValueKey('job-description-field')),
      'Backend engineer role',
    );
    await tester.enterText(
      find.byKey(const ValueKey('resume-field')),
      'Experienced engineer',
    );
    await tapVisible(tester, find.text('Analyze'));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
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

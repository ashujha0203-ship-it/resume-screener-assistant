import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resume_screener_frontend/models/analysis_result.dart';
import 'package:resume_screener_frontend/models/criterion_assessment.dart';
import 'package:resume_screener_frontend/screens/results_screen.dart';

void main() {
  Future<void> pumpResultsScreen(
    WidgetTester tester, {
    AnalysisResult? result,
    VoidCallback? onAnalyze,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultsScreen(result: result, onAnalyze: onAnalyze ?? () {}),
        ),
      ),
    );
  }

  testWidgets('null result preserves the existing empty state', (
    WidgetTester tester,
  ) async {
    await pumpResultsScreen(tester);

    expect(find.byKey(const ValueKey('results-empty-title')), findsOneWidget);
    expect(find.text('No analysis yet'), findsOneWidget);
    expect(find.text('Go to Analyze'), findsOneWidget);
  });

  testWidgets('empty-state action invokes the Analyze callback', (
    WidgetTester tester,
  ) async {
    var analyzeTapped = false;
    await pumpResultsScreen(tester, onAnalyze: () => analyzeTapped = true);

    await tester.tap(find.text('Go to Analyze'));

    expect(analyzeTapped, isTrue);
  });

  testWidgets('shows candidate fallback and localized analysis timestamp', (
    WidgetTester tester,
  ) async {
    final result = _analysisResult();
    await pumpResultsScreen(tester, result: result);

    expect(find.text('Jordan Lee'), findsOneWidget);
    final timestamp = tester.widget<Text>(
      find.byKey(const ValueKey('results-created-at')),
    );
    expect(
      timestamp.data,
      'Analyzed ${_formatLocalDateTime(result.createdAt.toLocal())}',
    );
  });

  testWidgets('uses a neutral candidate label when the name is null', (
    WidgetTester tester,
  ) async {
    await pumpResultsScreen(
      tester,
      result: _analysisResult(candidateName: null),
    );

    expect(
      find.byKey(const ValueKey('results-candidate-name')),
      findsOneWidget,
    );
    expect(find.text('Candidate'), findsOneWidget);
  });

  testWidgets('shows the score and actual progress fraction', (
    WidgetTester tester,
  ) async {
    await pumpResultsScreen(tester, result: _analysisResult(matchScore: 73));

    expect(find.text('73 / 100'), findsOneWidget);
    expect(
      find.text(
        'This score is an advisory assessment, not an automatic hiring '
        'decision.',
      ),
      findsOneWidget,
    );
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('results-score-progress')),
    );
    expect(progress.value, 0.73);
  });

  testWidgets('shows all assessment ratings and rationales', (
    WidgetTester tester,
  ) async {
    await pumpResultsScreen(tester, result: _analysisResult());

    const assessments = {
      'Required Skills': (88, 'Strong alignment with required skills.'),
      'Relevant Experience': (81, 'Experience supports the role.'),
      'Seniority and Scope': (76, 'Scope is broadly comparable.'),
      'Nice-to-have Skills and Domain Relevance': (
        69,
        'Some domain preferences are present.',
      ),
    };
    for (final entry in assessments.entries) {
      expect(
        find.byKey(ValueKey('assessment-title-${entry.key}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('assessment-rating-${entry.key}')),
        findsOneWidget,
      );
      expect(find.text('${entry.value.$1} / 100'), findsOneWidget);
      expect(
        find.byKey(ValueKey('assessment-rationale-${entry.key}')),
        findsOneWidget,
      );
      expect(find.text(entry.value.$2), findsOneWidget);
    }
  });

  testWidgets('shows skills, gaps, questions, and backend advisory notice', (
    WidgetTester tester,
  ) async {
    await pumpResultsScreen(tester, result: _analysisResult());
    await tester.ensureVisible(
      find.byKey(const ValueKey('results-advisory-notice')),
    );
    await tester.pumpAndSettle();

    for (final skill in _matchingSkills) {
      expect(find.text(skill), findsOneWidget);
    }
    for (final gap in _skillGaps) {
      expect(find.text(gap), findsOneWidget);
    }
    for (final question in _interviewQuestions) {
      expect(find.text(question), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('results-advisory-notice')),
      findsOneWidget,
    );
    expect(
      find.text('This score is advisory and does not replace human judgment.'),
      findsOneWidget,
    );
  });

  testWidgets('scrolls without overflow on a narrow screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpResultsScreen(tester, result: _analysisResult());
    await tester.ensureVisible(
      find.byKey(const ValueKey('results-advisory-notice')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('results-content-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out assessment cards in two columns on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpResultsScreen(tester, result: _analysisResult());

    final firstCard = tester.getRect(
      find.byKey(const ValueKey('assessment-title-Required Skills')),
    );
    final secondCard = tester.getRect(
      find.byKey(const ValueKey('assessment-title-Relevant Experience')),
    );
    final thirdCard = tester.getRect(
      find.byKey(const ValueKey('assessment-title-Seniority and Scope')),
    );
    expect(firstCard.top, secondCard.top);
    expect(thirdCard.top, greaterThan(firstCard.top));
    expect(tester.takeException(), isNull);
  });
}

const _matchingSkills = ['Dart', 'Flutter', 'Java', 'SQL', 'Automated testing'];

const _skillGaps = ['Cloud deployment', 'Team leadership', 'Domain experience'];

const _interviewQuestions = [
  'How do you approach API design?',
  'Describe a difficult debugging task.',
  'How do you prioritize technical debt?',
];

AnalysisResult _analysisResult({
  String? candidateName = 'Jordan Lee',
  int matchScore = 73,
}) => AnalysisResult(
  id: '123e4567-e89b-12d3-a456-426614174000',
  createdAt: DateTime.utc(2025, 3, 4, 15, 6),
  candidateName: candidateName,
  matchScore: matchScore,
  requiredSkills: const CriterionAssessment(
    rating: 88,
    rationale: 'Strong alignment with required skills.',
  ),
  relevantExperience: const CriterionAssessment(
    rating: 81,
    rationale: 'Experience supports the role.',
  ),
  seniorityAndScope: const CriterionAssessment(
    rating: 76,
    rationale: 'Scope is broadly comparable.',
  ),
  niceToHaveSkillsAndDomainRelevance: const CriterionAssessment(
    rating: 69,
    rationale: 'Some domain preferences are present.',
  ),
  matchingSkills: _matchingSkills,
  skillGaps: _skillGaps,
  interviewQuestions: _interviewQuestions,
  advisoryNotice: 'This score is advisory and does not replace human judgment.',
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

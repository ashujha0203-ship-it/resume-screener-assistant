import 'package:flutter_test/flutter_test.dart';
import 'package:resume_screener_frontend/models/analysis_result.dart';

void main() {
  group('AnalysisResult', () {
    final json = {
      'id': '123e4567-e89b-12d3-a456-426614174000',
      'createdAt': '2026-11-10T00:00:00Z',
      'candidateName': 'Jordan Lee',
      'matchScore': 82,
      'requiredSkills': {'rating': 80, 'rationale': 'Required skills align.'},
      'relevantExperience': {'rating': 85, 'rationale': 'Experience aligns.'},
      'seniorityAndScope': {'rating': 80, 'rationale': 'Scope is relevant.'},
      'niceToHaveSkillsAndDomainRelevance': {
        'rating': 85,
        'rationale': 'Domain experience is useful.',
      },
      'matchingSkills': ['Java', 'Spring', 'PostgreSQL', 'REST', 'Maven'],
      'skillGaps': ['Docker', 'Cloud', 'Testing'],
      'interviewQuestions': ['Question 1?', 'Question 2?', 'Question 3?'],
      'advisoryNotice': 'This is advisory information.',
    };

    test('parses complete POST response including nested assessments', () {
      final result = AnalysisResult.fromJson(json);

      expect(result.id, '123e4567-e89b-12d3-a456-426614174000');
      expect(result.createdAt, DateTime.utc(2026, 11, 10));
      expect(result.candidateName, 'Jordan Lee');
      expect(result.matchScore, 82);
      expect(result.requiredSkills.rating, 80);
      expect(result.requiredSkills.rationale, 'Required skills align.');
      expect(result.relevantExperience.rating, 85);
      expect(result.seniorityAndScope.rating, 80);
      expect(result.niceToHaveSkillsAndDomainRelevance.rating, 85);
      expect(result.matchingSkills, hasLength(5));
      expect(result.skillGaps, hasLength(3));
      expect(result.interviewQuestions, hasLength(3));
      expect(result.advisoryNotice, 'This is advisory information.');
    });

    test(
      'serializes the complete response and keeps collections immutable',
      () {
        final result = AnalysisResult.fromJson(json);

        expect(result.toJson(), {
          ...json,
          'createdAt': '2026-11-10T00:00:00.000Z',
        });
        expect(
          () => result.matchingSkills.add('Kotlin'),
          throwsUnsupportedError,
        );
        expect(
          () => result.skillGaps.add('Kubernetes'),
          throwsUnsupportedError,
        );
        expect(
          () => result.interviewQuestions.add('Another question?'),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'allows a null candidate name and rejects missing or invalid fields',
      () {
        final withoutName = AnalysisResult.fromJson({
          ...json,
          'candidateName': null,
        });
        expect(withoutName.candidateName, isNull);

        final missingAssessment = Map<String, dynamic>.from(json)
          ..remove('requiredSkills');
        expect(
          () => AnalysisResult.fromJson(missingAssessment),
          throwsFormatException,
        );

        expect(
          () => AnalysisResult.fromJson({...json, 'matchScore': 101}),
          throwsFormatException,
        );
        expect(
          () => AnalysisResult.fromJson({...json, 'createdAt': 'not-a-date'}),
          throwsFormatException,
        );
      },
    );

    test('rejects skill and question lists with incorrect lengths', () {
      for (final (field, values) in [
        ('matchingSkills', ['Java']),
        (
          'matchingSkills',
          ['Java', 'Spring', 'SQL', 'REST', 'Maven', 'Kotlin'],
        ),
        ('skillGaps', ['Cloud']),
        ('skillGaps', ['Cloud', 'Docker', 'Testing', 'Kubernetes']),
        ('interviewQuestions', ['Question?']),
        ('interviewQuestions', ['Q1?', 'Q2?', 'Q3?', 'Q4?']),
      ]) {
        expect(
          () => AnalysisResult.fromJson({...json, field: values}),
          throwsFormatException,
          reason: '$field should reject a list of length ${values.length}',
        );
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_screener_frontend/models/analysis_history_item.dart';

void main() {
  group('AnalysisHistoryItem', () {
    final json = {
      'id': '123e4567-e89b-12d3-a456-426614174000',
      'createdAt': '2026-11-10T00:00:00Z',
      'candidateName': 'Jordan Lee',
      'matchScore': 82,
      'matchingSkills': ['Java', 'Spring', 'PostgreSQL', 'REST', 'Maven'],
      'skillGaps': ['Docker', 'Cloud', 'Testing'],
      'interviewQuestions': ['Question 1?', 'Question 2?', 'Question 3?'],
    };

    test('parses persisted history/detail fields and numeric values', () {
      final item = AnalysisHistoryItem.fromJson(json);

      expect(item.id, '123e4567-e89b-12d3-a456-426614174000');
      expect(item.createdAt, DateTime.utc(2026, 11, 10));
      expect(item.candidateName, 'Jordan Lee');
      expect(item.matchScore, 82);
      expect(item.matchingSkills, hasLength(5));
      expect(item.skillGaps, hasLength(3));
      expect(item.interviewQuestions, hasLength(3));
    });

    test(
      'serializes persisted fields only and exposes immutable collections',
      () {
        final item = AnalysisHistoryItem.fromJson(json);

        expect(item.toJson(), {
          ...json,
          'createdAt': '2026-11-10T00:00:00.000Z',
        });
        expect(item.toJson().containsKey('requiredSkills'), isFalse);
        expect(() => item.matchingSkills.add('Kotlin'), throwsUnsupportedError);
      },
    );

    test(
      'allows missing candidate name and rejects invalid required values',
      () {
        final withoutName = AnalysisHistoryItem.fromJson(
          {...json}..remove('candidateName'),
        );
        expect(withoutName.candidateName, isNull);

        expect(
          () => AnalysisHistoryItem.fromJson({...json, 'matchScore': '82'}),
          throwsFormatException,
        );
        expect(
          () => AnalysisHistoryItem.fromJson({
            ...json,
            'matchingSkills': ['Java', 3],
          }),
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
          () => AnalysisHistoryItem.fromJson({...json, field: values}),
          throwsFormatException,
          reason: '$field should reject a list of length ${values.length}',
        );
      }
    });
  });
}

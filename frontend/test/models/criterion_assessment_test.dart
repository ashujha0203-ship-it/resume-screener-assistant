import 'package:flutter_test/flutter_test.dart';
import 'package:resume_screener_frontend/models/criterion_assessment.dart';

void main() {
  group('CriterionAssessment', () {
    test('parses rating and rationale', () {
      final assessment = CriterionAssessment.fromJson({
        'rating': 85,
        'rationale': 'Relevant experience is demonstrated.',
      });

      expect(assessment.rating, 85);
      expect(assessment.rationale, 'Relevant experience is demonstrated.');
    });

    test('serializes rating and rationale', () {
      const assessment = CriterionAssessment(
        rating: 85,
        rationale: 'Relevant experience is demonstrated.',
      );

      expect(assessment.toJson(), {
        'rating': 85,
        'rationale': 'Relevant experience is demonstrated.',
      });
    });

    test('rejects missing, invalid, or out-of-range values', () {
      expect(
        () => CriterionAssessment.fromJson({'rationale': 'Evidence'}),
        throwsFormatException,
      );
      expect(
        () => CriterionAssessment.fromJson({
          'rating': 101,
          'rationale': 'Evidence',
        }),
        throwsFormatException,
      );
      expect(
        () => CriterionAssessment.fromJson({'rating': 80, 'rationale': ' '}),
        throwsFormatException,
      );
    });
  });
}

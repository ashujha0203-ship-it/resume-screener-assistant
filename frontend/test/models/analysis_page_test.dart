import 'package:flutter_test/flutter_test.dart';
import 'package:resume_screener_frontend/models/analysis_page.dart';

void main() {
  group('AnalysisPage', () {
    final item = {
      'id': '123e4567-e89b-12d3-a456-426614174000',
      'createdAt': '2026-11-10T00:00:00Z',
      'candidateName': null,
      'matchScore': 82,
      'matchingSkills': ['Java', 'Spring', 'PostgreSQL', 'REST', 'Maven'],
      'skillGaps': ['Cloud', 'Docker', 'Testing'],
      'interviewQuestions': ['Question 1?', 'Question 2?', 'Question 3?'],
    };

    test('parses page metadata and non-empty content', () {
      final page = AnalysisPage.fromJson({
        'content': [item],
        'page': 0,
        'size': 20,
        'totalElements': 1,
        'totalPages': 1,
      });

      expect(page.content, hasLength(1));
      expect(page.content.single.candidateName, isNull);
      expect(page.page, 0);
      expect(page.size, 20);
      expect(page.totalElements, 1);
      expect(page.totalPages, 1);
    });

    test('parses empty content and serializes page data', () {
      final page = AnalysisPage.fromJson({
        'content': <Map<String, dynamic>>[],
        'page': 2,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
      });

      expect(page.content, isEmpty);
      expect(page.toJson(), {
        'content': <Map<String, dynamic>>[],
        'page': 2,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
      });
      expect(
        () => page.content.add(
          AnalysisPage.fromJson({
            'content': [item],
            'page': 0,
            'size': 1,
            'totalElements': 1,
            'totalPages': 1,
          }).content.single,
        ),
        throwsUnsupportedError,
      );
    });

    test('rejects missing metadata and invalid content entries', () {
      expect(
        () => AnalysisPage.fromJson({
          'content': <Map<String, dynamic>>[],
          'page': 0,
          'size': 20,
          'totalElements': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => AnalysisPage.fromJson({
          'content': ['not-an-object'],
          'page': 0,
          'size': 20,
          'totalElements': 0,
          'totalPages': 0,
        }),
        throwsFormatException,
      );
    });

    test('rejects invalid pagination metadata', () {
      final validPage = {
        'content': <Map<String, dynamic>>[],
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
      };

      for (final (field, value) in [
        ('page', -1),
        ('size', 0),
        ('size', -1),
        ('totalElements', -1),
        ('totalPages', -1),
      ]) {
        expect(
          () => AnalysisPage.fromJson({...validPage, field: value}),
          throwsFormatException,
          reason: '$field should reject $value',
        );
      }
    });
  });
}

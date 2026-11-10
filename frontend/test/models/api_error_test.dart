import 'package:flutter_test/flutter_test.dart';
import 'package:resume_screener_frontend/models/api_error.dart';

void main() {
  group('ApiError', () {
    test('parses and serializes the standard error response', () {
      final error = ApiError.fromJson({
        'timestamp': '2026-11-10T00:00:00Z',
        'status': 400,
        'code': 'INVALID_REQUEST',
        'message': 'The request is invalid.',
      });

      expect(error.timestamp, DateTime.utc(2026, 11, 10));
      expect(error.status, 400);
      expect(error.code, 'INVALID_REQUEST');
      expect(error.message, 'The request is invalid.');
      expect(error.toJson(), {
        'timestamp': '2026-11-10T00:00:00.000Z',
        'status': 400,
        'code': 'INVALID_REQUEST',
        'message': 'The request is invalid.',
      });
    });

    test('rejects missing or incorrectly typed required fields', () {
      expect(
        () => ApiError.fromJson({
          'status': 400,
          'code': 'INVALID_REQUEST',
          'message': 'Invalid request.',
        }),
        throwsFormatException,
      );
      expect(
        () => ApiError.fromJson({
          'timestamp': '2026-11-10T00:00:00Z',
          'status': '400',
          'code': 'INVALID_REQUEST',
          'message': 'Invalid request.',
        }),
        throwsFormatException,
      );
    });
  });
}

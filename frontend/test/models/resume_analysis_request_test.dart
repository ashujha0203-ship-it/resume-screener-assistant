import 'package:flutter_test/flutter_test.dart';
import 'package:resume_screener_frontend/models/resume_analysis_request.dart';

void main() {
  group('ResumeAnalysisRequest', () {
    test('parses request fields and optional candidate name', () {
      final request = ResumeAnalysisRequest.fromJson({
        'candidateName': 'Jordan Lee',
        'jobDescription': 'Backend engineer role',
        'resume': 'Resume text',
      });

      expect(request.candidateName, 'Jordan Lee');
      expect(request.jobDescription, 'Backend engineer role');
      expect(request.resume, 'Resume text');
    });

    test('allows candidateName to be omitted or null', () {
      final omitted = ResumeAnalysisRequest.fromJson({
        'jobDescription': 'Role',
        'resume': 'Resume',
      });
      final explicitlyNull = ResumeAnalysisRequest.fromJson({
        'candidateName': null,
        'jobDescription': 'Role',
        'resume': 'Resume',
      });

      expect(omitted.candidateName, isNull);
      expect(explicitlyNull.candidateName, isNull);
    });

    test('serializes the optional candidate name and required fields', () {
      const request = ResumeAnalysisRequest(
        candidateName: 'Jordan Lee',
        jobDescription: 'Backend engineer role',
        resume: 'Resume text',
      );

      expect(request.toJson(), {
        'candidateName': 'Jordan Lee',
        'jobDescription': 'Backend engineer role',
        'resume': 'Resume text',
      });
    });

    test('omits a null candidate name when serialized', () {
      const request = ResumeAnalysisRequest(
        jobDescription: 'Role',
        resume: 'Resume',
      );

      expect(request.toJson(), {'jobDescription': 'Role', 'resume': 'Resume'});
    });

    test('rejects missing required fields and invalid candidate name type', () {
      expect(
        () => ResumeAnalysisRequest.fromJson({'resume': 'Resume'}),
        throwsFormatException,
      );
      expect(
        () => ResumeAnalysisRequest.fromJson({
          'candidateName': 7,
          'jobDescription': 'Role',
          'resume': 'Resume',
        }),
        throwsFormatException,
      );
    });
  });
}

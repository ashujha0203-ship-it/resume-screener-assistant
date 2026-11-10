import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resume_screener_frontend/models/analysis_history_item.dart';
import 'package:resume_screener_frontend/models/analysis_page.dart';
import 'package:resume_screener_frontend/models/analysis_result.dart';
import 'package:resume_screener_frontend/models/resume_analysis_request.dart';
import 'package:resume_screener_frontend/services/analysis_api_exception.dart';
import 'package:resume_screener_frontend/services/analysis_api_service.dart';

void main() {
  group('createAnalysis', () {
    test(
      'serializes a request without candidateName and parses HTTP 201',
      () async {
        late Map<String, dynamic> requestBody;
        final service = AnalysisApiService(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/analyses');
            expect(request.headers['content-type'], 'application/json');
            requestBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse(201, _analysisResultJson());
          }),
          baseUri: _baseUri,
        );

        final result = await service.createAnalysis(
          const ResumeAnalysisRequest(
            jobDescription: 'Backend developer',
            resume: 'Experienced engineer',
          ),
        );

        expect(requestBody, {
          'jobDescription': 'Backend developer',
          'resume': 'Experienced engineer',
        });
        expect(result, isA<AnalysisResult>());
        expect(result.id, _id);
        service.close();
      },
    );

    test('includes candidateName when supplied', () async {
      late Map<String, dynamic> requestBody;
      final service = AnalysisApiService(
        client: MockClient((request) async {
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse(201, _analysisResultJson());
        }),
        baseUri: _baseUri,
      );

      await service.createAnalysis(
        const ResumeAnalysisRequest(
          candidateName: 'Alex Candidate',
          jobDescription: 'Backend developer',
          resume: 'Experienced engineer',
        ),
      );

      expect(requestBody['candidateName'], 'Alex Candidate');
      service.close();
    });
  });

  group('getAnalyses', () {
    test('encodes filters safely and parses the history page', () async {
      final service = AnalysisApiService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/analyses');
          expect(request.url.queryParameters, {
            'candidateName': 'Alex & Sam%_',
            'minScore': '65',
            'maxScore': '90',
            'page': '2',
            'size': '15',
          });
          return _jsonResponse(200, _analysisPageJson(page: 2, size: 15));
        }),
        baseUri: _baseUri,
      );

      final result = await service.getAnalyses(
        candidateName: 'Alex & Sam%_',
        minScore: 65,
        maxScore: 90,
        page: 2,
        size: 15,
      );

      expect(result, isA<AnalysisPage>());
      expect(result.page, 2);
      expect(result.size, 15);
      service.close();
    });

    test('uses the backend pagination defaults when omitted', () async {
      final service = AnalysisApiService(
        client: MockClient((request) async {
          expect(request.url.queryParameters, {'page': '0', 'size': '20'});
          return _jsonResponse(200, _analysisPageJson(content: []));
        }),
        baseUri: _baseUri,
      );

      final page = await service.getAnalyses();

      expect(page.content, isEmpty);
      expect(page.totalElements, 0);
      service.close();
    });
  });

  test(
    'getAnalysisById requests the encoded UUID path and parses detail',
    () async {
      final service = AnalysisApiService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/analyses/$_id');
          expect(request.url.queryParameters, isEmpty);
          return _jsonResponse(200, _historyItemJson());
        }),
        baseUri: _baseUri,
      );

      final result = await service.getAnalysisById(_id);

      expect(result, isA<AnalysisHistoryItem>());
      expect(result.id, _id);
      service.close();
    },
  );

  group('HTTP errors', () {
    const errors = [
      (400, 'INVALID_REQUEST', 'The request is invalid.'),
      (404, 'ANALYSIS_NOT_FOUND', 'Analysis not found.'),
      (
        405,
        'METHOD_NOT_ALLOWED',
        'The HTTP method is not supported for this endpoint.',
      ),
      (
        415,
        'UNSUPPORTED_MEDIA_TYPE',
        'The request media type is not supported.',
      ),
      (500, 'INTERNAL_ERROR', 'An unexpected error occurred.'),
      (
        502,
        'INVALID_PROVIDER_RESPONSE',
        'The analysis provider returned an unusable response.',
      ),
      (
        502,
        'AI_PROVIDER_ERROR',
        'The analysis provider could not complete the request.',
      ),
      (
        503,
        'AI_NOT_CONFIGURED',
        'Analysis is temporarily unavailable because the AI provider is not configured.',
      ),
      (
        503,
        'AI_RATE_LIMITED',
        'Analysis is temporarily unavailable. Please try again later.',
      ),
      (504, 'AI_TIMEOUT', 'The analysis provider did not respond in time.'),
    ];
    for (final (status, code, safeMessage) in errors) {
      test(
        'preserves recognized safe ApiError for HTTP $status ($code)',
        () async {
          final service = AnalysisApiService(
            client: MockClient(
              (_) async => _jsonResponse(
                status,
                _apiErrorJson(status, code, safeMessage),
              ),
            ),
            baseUri: _baseUri,
          );

          await expectLater(
            service.getAnalyses(),
            throwsA(
              isA<AnalysisApiException>()
                  .having(
                    (error) => error.failure,
                    'failure',
                    AnalysisApiFailure.http,
                  )
                  .having((error) => error.statusCode, 'statusCode', status)
                  .having((error) => error.code, 'code', code)
                  .having((error) => error.message, 'message', safeMessage),
            ),
          );
          service.close();
        },
      );
    }

    test(
      'replaces sensitive message from a valid ApiError with safe fallback',
      () async {
        const sensitiveText = 'resume and job description private text';
        final service = AnalysisApiService(
          client: MockClient(
            (_) async => _jsonResponse(
              502,
              _apiErrorJson(502, 'AI_PROVIDER_ERROR', sensitiveText),
            ),
          ),
          baseUri: _baseUri,
        );

        await expectLater(
          service.getAnalyses(),
          throwsA(
            isA<AnalysisApiException>()
                .having((error) => error.statusCode, 'statusCode', 502)
                .having((error) => error.code, 'code', 'AI_PROVIDER_ERROR')
                .having(
                  (error) => error.message,
                  'message',
                  'The analysis service returned an unusable response.',
                )
                .having(
                  (error) => error.toString().contains(sensitiveText),
                  'contains sensitive message',
                  isFalse,
                ),
          ),
        );
        service.close();
      },
    );

    test(
      'uses a safe fallback for an unknown but well-formed error code',
      () async {
        final service = AnalysisApiService(
          client: MockClient(
            (_) async => _jsonResponse(
              404,
              _apiErrorJson(404, 'FUTURE_ERROR', 'Unrecognized server message'),
            ),
          ),
          baseUri: _baseUri,
        );

        await expectLater(
          service.getAnalyses(),
          throwsA(
            isA<AnalysisApiException>()
                .having((error) => error.statusCode, 'statusCode', 404)
                .having((error) => error.code, 'code', 'FUTURE_ERROR')
                .having(
                  (error) => error.message,
                  'message',
                  'The requested analysis was not found.',
                ),
          ),
        );
        service.close();
      },
    );

    test(
      'does not expose malformed or arbitrary error response bodies',
      () async {
        const sensitiveText = 'resume and provider secret';
        final service = AnalysisApiService(
          client: MockClient((_) async => http.Response(sensitiveText, 502)),
          baseUri: _baseUri,
        );

        await expectLater(
          service.getAnalyses(),
          throwsA(
            isA<AnalysisApiException>()
                .having(
                  (error) => error.failure,
                  'failure',
                  AnalysisApiFailure.http,
                )
                .having((error) => error.statusCode, 'statusCode', 502)
                .having(
                  (error) => error.message,
                  'message',
                  'The analysis service returned an unusable response.',
                )
                .having(
                  (error) => error.toString().contains(sensitiveText),
                  'contains sensitive response text',
                  isFalse,
                ),
          ),
        );
        service.close();
      },
    );

    test('uses a safe fallback when ApiError status does not match', () async {
      final service = AnalysisApiService(
        client: MockClient(
          (_) async => _jsonResponse(
            404,
            _apiErrorJson(500, 'INTERNAL', 'Internal details'),
          ),
        ),
        baseUri: _baseUri,
      );

      await expectLater(
        service.getAnalyses(),
        throwsA(
          isA<AnalysisApiException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.code, 'code', 'INTERNAL')
              .having(
                (error) => error.message,
                'message',
                'The requested analysis was not found.',
              ),
        ),
      );
      service.close();
    });
  });

  test(
    'classifies malformed successful JSON without exposing its contents',
    () async {
      const sensitiveText = 'resume-content';
      final service = AnalysisApiService(
        client: MockClient((_) async => http.Response(sensitiveText, 201)),
        baseUri: _baseUri,
      );

      await expectLater(
        service.createAnalysis(_request),
        throwsA(
          isA<AnalysisApiException>()
              .having(
                (error) => error.failure,
                'failure',
                AnalysisApiFailure.malformedJson,
              )
              .having(
                (error) => error.toString().contains(sensitiveText),
                'contains sensitive response text',
                isFalse,
              ),
        ),
      );
      service.close();
    },
  );

  test('classifies unexpected successful response structures', () async {
    final service = AnalysisApiService(
      client: MockClient((_) async => http.Response('[]', 201)),
      baseUri: _baseUri,
    );

    await expectLater(
      service.createAnalysis(_request),
      throwsA(
        isA<AnalysisApiException>().having(
          (error) => error.failure,
          'failure',
          AnalysisApiFailure.unexpectedResponse,
        ),
      ),
    );
    service.close();
  });

  test('classifies valid JSON with missing required response fields', () async {
    final service = AnalysisApiService(
      client: MockClient((_) async => _jsonResponse(201, {'id': _id})),
      baseUri: _baseUri,
    );

    await expectLater(
      service.createAnalysis(_request),
      throwsA(
        isA<AnalysisApiException>().having(
          (error) => error.failure,
          'failure',
          AnalysisApiFailure.unexpectedResponse,
        ),
      ),
    );
    service.close();
  });

  test('classifies request timeouts with a safe message', () async {
    final pendingResponse = Completer<http.Response>();
    final service = AnalysisApiService(
      client: MockClient((_) => pendingResponse.future),
      baseUri: _baseUri,
      requestTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      service.getAnalyses(),
      throwsA(
        isA<AnalysisApiException>()
            .having(
              (error) => error.failure,
              'failure',
              AnalysisApiFailure.timeout,
            )
            .having(
              (error) => error.message,
              'message',
              'The request timed out. Please try again.',
            ),
      ),
    );
    service.close();
  });

  test('classifies createAnalysis timeouts', () async {
    final service = AnalysisApiService(
      client: MockClient((_) => Completer<http.Response>().future),
      baseUri: _baseUri,
      requestTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      service.createAnalysis(_request),
      throwsA(
        isA<AnalysisApiException>().having(
          (error) => error.failure,
          'failure',
          AnalysisApiFailure.timeout,
        ),
      ),
    );
    service.close();
  });

  test('classifies getAnalysisById timeouts', () async {
    final service = AnalysisApiService(
      client: MockClient((_) => Completer<http.Response>().future),
      baseUri: _baseUri,
      requestTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      service.getAnalysisById(_id),
      throwsA(
        isA<AnalysisApiException>().having(
          (error) => error.failure,
          'failure',
          AnalysisApiFailure.timeout,
        ),
      ),
    );
    service.close();
  });

  test(
    'classifies transport failures without exposing exception details',
    () async {
      const sensitiveText = 'provider credentials';
      final service = AnalysisApiService(
        client: MockClient((_) async {
          throw http.ClientException(sensitiveText);
        }),
        baseUri: _baseUri,
      );

      await expectLater(
        service.getAnalyses(),
        throwsA(
          isA<AnalysisApiException>()
              .having(
                (error) => error.failure,
                'failure',
                AnalysisApiFailure.transport,
              )
              .having(
                (error) => error.toString().contains(sensitiveText),
                'contains sensitive exception text',
                isFalse,
              ),
        ),
      );
      service.close();
    },
  );

  test('does not close an externally injected client', () {
    final client = _TrackingClient();
    final service = AnalysisApiService(client: client, baseUri: _baseUri);

    service.close();
    service.close();

    expect(client.wasClosed, isFalse);
  });

  test('closes the client created internally by the service', () {
    final client = _TrackingClient();
    final service = AnalysisApiService(
      clientFactory: () => client,
      baseUri: _baseUri,
    );

    expect(client.wasClosed, isFalse);
    service.close();
    service.close();

    expect(client.wasClosed, isTrue);
  });
}

final _baseUri = Uri.parse('https://api.example.test');
const _id = '123e4567-e89b-12d3-a456-426614174000';
const _request = ResumeAnalysisRequest(
  jobDescription: 'Backend developer',
  resume: 'Experienced engineer',
);

http.Response _jsonResponse(int statusCode, Object body) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _analysisResultJson() => {
  ..._historyItemJson(),
  'requiredSkills': _criterionJson(),
  'relevantExperience': _criterionJson(),
  'seniorityAndScope': _criterionJson(),
  'niceToHaveSkillsAndDomainRelevance': _criterionJson(),
  'advisoryNotice': 'This is an advisory assessment.',
};

Map<String, dynamic> _historyItemJson() => {
  'id': _id,
  'createdAt': '2025-01-02T03:04:05Z',
  'candidateName': 'Alex Candidate',
  'matchScore': 86,
  'matchingSkills': ['Dart', 'Flutter', 'Java', 'SQL', 'Testing'],
  'skillGaps': ['Cloud', 'Leadership', 'Security'],
  'interviewQuestions': ['Question one?', 'Question two?', 'Question three?'],
};

Map<String, dynamic> _analysisPageJson({
  List<Object>? content,
  int page = 0,
  int size = 20,
}) => {
  'content': content ?? [_historyItemJson()],
  'page': page,
  'size': size,
  'totalElements': content == null ? 1 : 0,
  'totalPages': content == null ? 1 : 0,
};

Map<String, dynamic> _criterionJson() => {
  'rating': 85,
  'rationale': 'The evidence aligns with this criterion.',
};

Map<String, dynamic> _apiErrorJson(int status, String code, String message) => {
  'timestamp': '2025-01-02T03:04:05Z',
  'status': status,
  'code': code,
  'message': message,
};

class _TrackingClient extends http.BaseClient {
  final http.Client _delegate = MockClient((_) async => http.Response('', 200));
  bool wasClosed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _delegate.send(request);

  @override
  void close() {
    wasClosed = true;
    _delegate.close();
  }
}

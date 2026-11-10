import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resume_screener_frontend/app/resume_screener_controller.dart';
import 'package:resume_screener_frontend/models/analysis_history_item.dart';
import 'package:resume_screener_frontend/models/analysis_page.dart';
import 'package:resume_screener_frontend/models/analysis_result.dart';
import 'package:resume_screener_frontend/models/criterion_assessment.dart';
import 'package:resume_screener_frontend/services/analysis_api_exception.dart';
import 'package:resume_screener_frontend/services/analysis_api_service.dart';
import 'package:resume_screener_frontend/models/resume_analysis_request.dart';

void main() {
  test('initializes without making a request and exposes empty state', () {
    final client = _TrackingClient();
    final controller = ResumeScreenerController(apiService: _service(client));

    expect(controller.submissionState.status, OperationStatus.idle);
    expect(controller.historyState.status, OperationStatus.idle);
    expect(controller.historyDetailState.status, OperationStatus.idle);
    expect(controller.analysisResult, isNull);
    expect(controller.analysisPage, isNull);
    expect(controller.historyQuery.candidateName, isNull);
    expect(controller.historyQuery.minScore, isNull);
    expect(controller.historyQuery.maxScore, isNull);
    expect(controller.historyQuery.page, 0);
    expect(controller.historyQuery.size, 20);
    expect(controller.selectedHistoryItem, isNull);
    expect(client.sendCount, 0);

    controller.dispose();
  });

  test(
    'disposes an injected service and its client without making requests',
    () {
      final client = _TrackingClient();
      expect(client.isClosed, isFalse);

      final service = _service(client);
      final controller = ResumeScreenerController(apiService: service);

      controller.dispose();

      expect(client.isClosed, isTrue);
      expect(client.sendCount, 0);
    },
  );

  test('loading states for each operation are independent', () {
    final controller = ResumeScreenerController(
      apiService: _service(_TrackingClient()),
    );

    controller.startAnalysisSubmission();
    expect(controller.submissionState.isLoading, isTrue);
    expect(controller.historyState.isLoading, isFalse);
    expect(controller.historyDetailState.isLoading, isFalse);

    controller.startHistoryRetrieval();
    expect(controller.submissionState.isLoading, isTrue);
    expect(controller.historyState.isLoading, isTrue);
    expect(controller.historyDetailState.isLoading, isFalse);

    controller.startHistoryDetailRetrieval();
    expect(controller.submissionState.isLoading, isTrue);
    expect(controller.historyState.isLoading, isTrue);
    expect(controller.historyDetailState.isLoading, isTrue);

    controller.dispose();
  });

  test(
    'loads selected history detail and notifies loading then success',
    () async {
      final requestReceived = Completer<void>();
      final response = Completer<http.Response>();
      late Uri requestUri;
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((request) {
            requestUri = request.url;
            requestReceived.complete();
            return response.future;
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );
      final statuses = <OperationStatus>[];
      controller.addListener(
        () => statuses.add(controller.historyDetailState.status),
      );

      final loading = controller.loadHistoryDetail(_id);
      await requestReceived.future;
      expect(requestUri.path, '/api/analyses/$_id');
      expect(controller.selectedHistoryId, _id);
      expect(controller.selectedHistoryItem, isNull);
      expect(controller.historyDetailState.isLoading, isTrue);
      expect(statuses, [OperationStatus.loading]);

      response.complete(http.Response(jsonEncode(_historyItemJson()), 200));
      await loading;

      expect(controller.historyDetailState.status, OperationStatus.success);
      expect(controller.selectedHistoryItem?.id, _id);
      expect(controller.historyDetailNotFound, isFalse);
      expect(statuses, [OperationStatus.loading, OperationStatus.success]);
      controller.dispose();
    },
  );

  test(
    'suppresses duplicate in-flight detail requests for the same ID',
    () async {
      final response = Completer<http.Response>();
      final requestStarted = Completer<void>();
      var requestCount = 0;
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((_) {
            requestCount++;
            requestStarted.complete();
            return response.future;
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );

      final first = controller.loadHistoryDetail(_id);
      await requestStarted.future;
      await controller.loadHistoryDetail(_id);
      expect(requestCount, 1);

      response.complete(http.Response(jsonEncode(_historyItemJson()), 200));
      await first;
      controller.dispose();
    },
  );

  test('marks 404 detail failures as not found with a safe message', () async {
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'timestamp': '2025-01-01T00:00:00Z',
              'status': 404,
              'code': 'ANALYSIS_NOT_FOUND',
              'message': 'Sensitive internal details',
            }),
            404,
          ),
        ),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );

    await controller.loadHistoryDetail(_id);

    expect(controller.historyDetailState.status, OperationStatus.error);
    expect(controller.historyDetailState.errorMessage, 'Analysis not found.');
    expect(controller.historyDetailNotFound, isTrue);
    expect(
      controller.historyDetailState.errorMessage,
      isNot(contains('Sensitive')),
    );
    controller.dispose();
  });

  test(
    'ignores stale detail response after selecting a different ID',
    () async {
      final firstResponse = Completer<http.Response>();
      final secondResponse = Completer<http.Response>();
      final started = <String, Completer<void>>{
        _id: Completer<void>(),
        _secondId: Completer<void>(),
      };
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((request) {
            final id = request.url.pathSegments.last;
            started[id]!.complete();
            return id == _id ? firstResponse.future : secondResponse.future;
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );

      final first = controller.loadHistoryDetail(_id);
      await started[_id]!.future;
      final second = controller.loadHistoryDetail(_secondId);
      await started[_secondId]!.future;

      secondResponse.complete(
        http.Response(jsonEncode(_historyItemJson(id: _secondId)), 200),
      );
      await second;
      firstResponse.complete(
        http.Response(jsonEncode(_historyItemJson()), 200),
      );
      await first;

      expect(controller.selectedHistoryId, _secondId);
      expect(controller.selectedHistoryItem?.id, _secondId);
      expect(controller.historyDetailState.status, OperationStatus.success);
      controller.dispose();
    },
  );

  test('notifies listeners when state changes', () {
    final controller = ResumeScreenerController(
      apiService: _service(_TrackingClient()),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.startAnalysisSubmission();
    controller.completeAnalysisSubmission(_analysisResult());
    controller.updateHistoryQuery(
      const AnalysisHistoryQuery(
        candidateName: 'Jordan Lee',
        minScore: 60,
        maxScore: 90,
        page: 2,
        size: 15,
      ),
    );

    expect(notifications, 3);

    controller.dispose();
  });

  test(
    'submits successfully, exposes loading state, and stores result',
    () async {
      final requestReceived = Completer<http.Response>();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/analyses');
        expect(jsonDecode(request.body), {
          'candidateName': 'Jordan Lee',
          'jobDescription': '  Backend role  ',
          'resume': '  Candidate resume  ',
        });
        return requestReceived.future;
      });
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: client,
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );
      final notifications = <OperationStatus>[];
      controller.addListener(
        () => notifications.add(controller.submissionState.status),
      );

      final submission = controller.submitAnalysis(
        const ResumeAnalysisRequest(
          candidateName: 'Jordan Lee',
          jobDescription: '  Backend role  ',
          resume: '  Candidate resume  ',
        ),
      );
      expect(controller.submissionState.isLoading, isTrue);
      expect(controller.analysisResult, isNull);
      expect(notifications, [OperationStatus.loading]);

      requestReceived.complete(
        http.Response(jsonEncode(_analysisResultJson()), 201),
      );
      expect(await submission, isTrue);
      expect(controller.submissionState.status, OperationStatus.success);
      expect(controller.analysisResult?.id, _id);
      expect(notifications, [OperationStatus.loading, OperationStatus.success]);

      controller.dispose();
    },
  );

  test('prevents duplicate submissions while the first is pending', () async {
    final response = Completer<http.Response>();
    final requestStarted = Completer<void>();
    var requestCount = 0;
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((_) {
          requestCount++;
          requestStarted.complete();
          return response.future;
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    const request = ResumeAnalysisRequest(
      jobDescription: 'Role',
      resume: 'Resume',
    );

    final firstSubmission = controller.submitAnalysis(request);
    await requestStarted.future;
    expect(await controller.submitAnalysis(request), isFalse);
    expect(requestCount, 1);
    expect(controller.submissionState.isLoading, isTrue);

    response.complete(http.Response(jsonEncode(_analysisResultJson()), 201));
    expect(await firstSubmission, isTrue);
    expect(requestCount, 1);

    controller.dispose();
  });

  test('clears the previous result when a new submission starts', () async {
    final response = Completer<http.Response>();
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((_) => response.future),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    controller.completeAnalysisSubmission(_analysisResult());
    expect(controller.analysisResult, isNotNull);

    final submission = controller.submitAnalysis(
      const ResumeAnalysisRequest(
        jobDescription: 'New role',
        resume: 'New resume',
      ),
    );

    expect(controller.submissionState.isLoading, isTrue);
    expect(controller.analysisResult, isNull);

    response.complete(
      http.Response(
        jsonEncode({
          'timestamp': '2025-01-01T00:00:00Z',
          'status': 502,
          'code': 'AI_PROVIDER_ERROR',
          'message': 'Provider details.',
        }),
        502,
      ),
    );
    expect(await submission, isFalse);
    expect(controller.analysisResult, isNull);
    expect(controller.submissionState.hasError, isTrue);

    controller.dispose();
  });

  test('maps API and unexpected submission errors to safe messages', () async {
    final responses = <http.Response>[
      http.Response(
        jsonEncode({
          'timestamp': '2025-01-01T00:00:00Z',
          'status': 502,
          'code': 'AI_PROVIDER_ERROR',
          'message': 'sensitive provider details',
        }),
        502,
      ),
    ];
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((_) async {
          if (responses.isNotEmpty) {
            return responses.removeAt(0);
          }
          throw StateError('sensitive unexpected details');
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    const request = ResumeAnalysisRequest(
      jobDescription: 'Role',
      resume: 'Resume',
    );

    expect(await controller.submitAnalysis(request), isFalse);
    expect(
      controller.submissionState.errorMessage,
      'The analysis provider could not complete the request.',
    );
    expect(
      controller.submissionState.errorMessage,
      isNot(contains('sensitive')),
    );

    expect(await controller.submitAnalysis(request), isFalse);
    expect(
      controller.submissionState.errorMessage,
      'The operation could not be completed. Please try again.',
    );

    controller.dispose();
  });

  test('does not notify after disposal while submission is pending', () async {
    final response = Completer<http.Response>();
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((_) => response.future),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    final submission = controller.submitAnalysis(
      const ResumeAnalysisRequest(jobDescription: 'Role', resume: 'Resume'),
    );
    expect(notifications, 1);

    controller.dispose();
    response.complete(http.Response(jsonEncode(_analysisResultJson()), 201));

    expect(await submission, isFalse);
    expect(notifications, 1);
  });

  test(
    'loads history with exact filters and loading/success notifications',
    () async {
      final response = Completer<http.Response>();
      final requestStarted = Completer<void>();
      late Uri requestUri;
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((request) {
            requestUri = request.url;
            requestStarted.complete();
            return response.future;
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );
      final statuses = <OperationStatus>[];
      controller.addListener(
        () => statuses.add(controller.historyState.status),
      );
      const query = AnalysisHistoryQuery(
        candidateName: 'Jordan Lee',
        minScore: 60,
        maxScore: 90,
        page: 2,
        size: 15,
      );

      final loading = controller.loadHistory(query: query);
      await requestStarted.future;

      expect(requestUri.path, '/api/analyses');
      expect(requestUri.queryParameters, {
        'candidateName': 'Jordan Lee',
        'minScore': '60',
        'maxScore': '90',
        'page': '2',
        'size': '15',
      });
      expect(controller.historyQuery, query);
      expect(controller.historyState.status, OperationStatus.loading);
      expect(statuses, [OperationStatus.loading]);

      response.complete(
        http.Response(jsonEncode(_historyPageJson(page: 2, size: 15)), 200),
      );
      await loading;

      expect(controller.historyState.status, OperationStatus.success);
      expect(controller.analysisPage?.page, 2);
      expect(
        controller.analysisPage?.content.single.candidateName,
        'Jordan Lee',
      );
      expect(statuses, [OperationStatus.loading, OperationStatus.success]);
      controller.dispose();
    },
  );

  test('rejects invalid page, size, scores, and score ordering', () async {
    final client = _TrackingClient();
    final controller = ResumeScreenerController(apiService: _service(client));
    final invalidQueries = [
      const AnalysisHistoryQuery(page: -1),
      const AnalysisHistoryQuery(size: 0),
      const AnalysisHistoryQuery(size: 101),
      const AnalysisHistoryQuery(minScore: -1),
      const AnalysisHistoryQuery(minScore: 101),
      const AnalysisHistoryQuery(maxScore: -1),
      const AnalysisHistoryQuery(maxScore: 101),
      const AnalysisHistoryQuery(minScore: 80, maxScore: 79),
    ];

    for (final query in invalidQueries) {
      await expectLater(
        controller.loadHistory(query: query),
        throwsArgumentError,
      );
    }

    expect(controller.historyState.status, OperationStatus.idle);
    expect(client.sendCount, 0);
    controller.dispose();
  });

  test('page changes retain active filters and page size', () async {
    final requestedUris = <Uri>[];
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((request) async {
          requestedUris.add(request.url);
          return http.Response(
            jsonEncode(
              _historyPageJson(
                page: request.url.queryParameters['page'] == '2' ? 2 : 0,
              ),
            ),
            200,
          );
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    const filters = AnalysisHistoryQuery(
      candidateName: 'Jordan',
      minScore: 30,
      maxScore: 95,
      size: 15,
    );

    await controller.loadHistory(query: filters);
    await controller.loadHistory(query: controller.historyQuery.withPage(2));

    expect(requestedUris, hasLength(2));
    expect(requestedUris.last.queryParameters, {
      'candidateName': 'Jordan',
      'minScore': '30',
      'maxScore': '95',
      'page': '2',
      'size': '15',
    });
    expect(controller.historyQuery.page, 2);
    expect(controller.historyQuery.candidateName, 'Jordan');
    expect(controller.historyQuery.minScore, 30);
    expect(controller.historyQuery.maxScore, 95);
    expect(controller.historyQuery.size, 15);
    controller.dispose();
  });

  test('filter updates clear previously loaded history data', () async {
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((request) async {
          final name = request.url.queryParameters['candidateName'] ?? 'Jordan';
          return http.Response(jsonEncode(_historyPageJson(name: name)), 200);
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    await controller.loadHistory(
      query: const AnalysisHistoryQuery(candidateName: 'Jordan'),
    );
    expect(controller.analysisPage, isNotNull);

    controller.updateHistoryQuery(
      const AnalysisHistoryQuery(candidateName: 'Taylor', page: 3),
    );

    expect(controller.analysisPage, isNull);
    expect(controller.historyQuery.candidateName, 'Taylor');
    expect(controller.historyQuery.page, 0);
    controller.dispose();
  });

  test(
    'direct filter query clears old data while the request is loading',
    () async {
      final response = Completer<http.Response>();
      final requestStarted = Completer<void>();
      var requestCount = 0;
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((request) {
            requestCount++;
            if (requestCount == 1) {
              return Future.value(
                http.Response(jsonEncode(_historyPageJson()), 200),
              );
            }
            requestStarted.complete();
            return response.future;
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );
      await controller.loadHistory(
        query: const AnalysisHistoryQuery(candidateName: 'Jordan'),
      );
      expect(controller.analysisPage, isNotNull);

      final loading = controller.loadHistory(
        query: const AnalysisHistoryQuery(candidateName: 'Taylor'),
      );
      await requestStarted.future;

      expect(controller.analysisPage, isNull);
      expect(controller.historyState.isLoading, isTrue);
      response.complete(
        http.Response(jsonEncode(_historyPageJson(name: 'Taylor')), 200),
      );
      await loading;

      expect(controller.analysisPage?.content.single.candidateName, 'Taylor');
      controller.dispose();
    },
  );

  test(
    'page-only query change preserves existing history data while loading',
    () async {
      final response = Completer<http.Response>();
      final requestStarted = Completer<void>();
      var requestCount = 0;
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((request) {
            requestCount++;
            if (requestCount == 1) {
              return Future.value(
                http.Response(jsonEncode(_historyPageJson()), 200),
              );
            }
            requestStarted.complete();
            return response.future;
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );
      await controller.loadHistory(
        query: const AnalysisHistoryQuery(candidateName: 'Jordan'),
      );
      final previousPage = controller.analysisPage;

      final loading = controller.loadHistory(
        query: controller.historyQuery.withPage(1),
      );
      await requestStarted.future;

      expect(controller.analysisPage, same(previousPage));
      expect(controller.historyState.isLoading, isTrue);
      response.complete(
        http.Response(jsonEncode(_historyPageJson(page: 1)), 200),
      );
      await loading;

      expect(controller.analysisPage?.page, 1);
      controller.dispose();
    },
  );

  test('filter changes reset pagination to page zero', () async {
    final requestedUris = <Uri>[];
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((request) async {
          requestedUris.add(request.url);
          final page = int.parse(request.url.queryParameters['page']!);
          return http.Response(jsonEncode(_historyPageJson(page: page)), 200);
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    await controller.loadHistory(
      query: const AnalysisHistoryQuery(
        candidateName: 'Jordan',
        minScore: 40,
        size: 12,
      ),
    );
    controller.updateHistoryQuery(
      const AnalysisHistoryQuery(
        candidateName: 'Taylor',
        minScore: 50,
        page: 4,
        size: 12,
      ),
    );

    expect(controller.historyQuery.page, 0);
    await controller.loadHistory();

    expect(requestedUris.last.queryParameters['candidateName'], 'Taylor');
    expect(requestedUris.last.queryParameters['minScore'], '50');
    expect(requestedUris.last.queryParameters['page'], '0');
    expect(requestedUris.last.queryParameters['size'], '12');
    controller.dispose();
  });

  test('explicit retry repeats the exact active query', () async {
    var requestCount = 0;
    final requestedUris = <Uri>[];
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((request) async {
          requestCount++;
          requestedUris.add(request.url);
          return requestCount == 1
              ? http.Response('unavailable', 503)
              : http.Response(jsonEncode(_historyPageJson()), 200);
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    const query = AnalysisHistoryQuery(
      candidateName: 'Jordan',
      minScore: 55,
      maxScore: 88,
      page: 3,
      size: 11,
    );

    await controller.loadHistory(query: query);
    expect(controller.historyState.hasError, isTrue);
    expect(
      controller.historyState.errorMessage,
      'The service could not complete the request.',
    );
    expect(
      controller.historyState.errorMessage,
      isNot(contains('unavailable')),
    );
    expect(requestCount, 1);
    await controller.retryHistory();

    expect(requestCount, 2);
    expect(requestedUris[0].queryParameters, requestedUris[1].queryParameters);
    expect(requestedUris[1].queryParameters, {
      'candidateName': 'Jordan',
      'minScore': '55',
      'maxScore': '88',
      'page': '3',
      'size': '11',
    });
    expect(controller.historyState.status, OperationStatus.success);
    controller.dispose();
  });

  test('suppresses an identical in-flight history request', () async {
    final response = Completer<http.Response>();
    final requestStarted = Completer<void>();
    var requestCount = 0;
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((_) {
          requestCount++;
          requestStarted.complete();
          return response.future;
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    const query = AnalysisHistoryQuery(candidateName: 'Jordan');

    final first = controller.loadHistory(query: query);
    await requestStarted.future;
    await controller.loadHistory(query: query);
    expect(requestCount, 1);

    response.complete(http.Response(jsonEncode(_historyPageJson()), 200));
    await first;
    controller.dispose();
  });

  test(
    'newer query supersedes an earlier request and older success is ignored',
    () async {
      final jordanResponse = Completer<http.Response>();
      final taylorResponse = Completer<http.Response>();
      final startedQueries = <String, Completer<void>>{
        'Jordan': Completer<void>(),
        'Taylor': Completer<void>(),
      };
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((request) {
            final name = request.url.queryParameters['candidateName']!;
            startedQueries[name]!.complete();
            return name == 'Jordan'
                ? jordanResponse.future
                : taylorResponse.future;
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );

      final older = controller.loadHistory(
        query: const AnalysisHistoryQuery(candidateName: 'Jordan'),
      );
      await startedQueries['Jordan']!.future;
      final newer = controller.loadHistory(
        query: const AnalysisHistoryQuery(candidateName: 'Taylor'),
      );
      await startedQueries['Taylor']!.future;

      taylorResponse.complete(
        http.Response(jsonEncode(_historyPageJson(name: 'Taylor')), 200),
      );
      await newer;
      jordanResponse.complete(
        http.Response(jsonEncode(_historyPageJson(name: 'Jordan')), 200),
      );
      await older;

      expect(controller.analysisPage?.content.single.candidateName, 'Taylor');
      expect(controller.historyQuery.candidateName, 'Taylor');
      expect(controller.historyState.status, OperationStatus.success);
      controller.dispose();
    },
  );

  test(
    'older failure cannot overwrite a newer successful history result',
    () async {
      final jordanResponse = Completer<http.Response>();
      final taylorResponse = Completer<http.Response>();
      final startedQueries = <String, Completer<void>>{
        'Jordan': Completer<void>(),
        'Taylor': Completer<void>(),
      };
      final controller = ResumeScreenerController(
        apiService: AnalysisApiService(
          client: MockClient((request) {
            final name = request.url.queryParameters['candidateName']!;
            startedQueries[name]!.complete();
            return name == 'Jordan'
                ? jordanResponse.future
                : taylorResponse.future;
          }),
          baseUri: Uri.parse('https://api.example.test'),
        ),
      );

      final older = controller.loadHistory(
        query: const AnalysisHistoryQuery(candidateName: 'Jordan'),
      );
      await startedQueries['Jordan']!.future;
      final newer = controller.loadHistory(
        query: const AnalysisHistoryQuery(candidateName: 'Taylor'),
      );
      await startedQueries['Taylor']!.future;

      taylorResponse.complete(
        http.Response(jsonEncode(_historyPageJson(name: 'Taylor')), 200),
      );
      await newer;
      jordanResponse.complete(http.Response('private failure details', 500));
      await older;

      expect(controller.analysisPage?.content.single.candidateName, 'Taylor');
      expect(controller.historyState.status, OperationStatus.success);
      expect(controller.historyState.errorMessage, isNull);
      controller.dispose();
    },
  );

  test('history completion after disposal does not notify listeners', () async {
    final response = Completer<http.Response>();
    final requestStarted = Completer<void>();
    final controller = ResumeScreenerController(
      apiService: AnalysisApiService(
        client: MockClient((_) {
          requestStarted.complete();
          return response.future;
        }),
        baseUri: Uri.parse('https://api.example.test'),
      ),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    final loading = controller.loadHistory();
    await requestStarted.future;
    expect(notifications, 1);
    controller.dispose();
    response.complete(http.Response(jsonEncode(_historyPageJson()), 200));
    await loading;

    expect(notifications, 1);
  });

  test('stores safe errors without retaining raw exception messages', () {
    final controller = ResumeScreenerController(
      apiService: _service(_TrackingClient()),
    );
    const sensitiveDetails = 'private resume or provider response';

    controller.failAnalysisSubmission(
      const AnalysisApiException(
        failure: AnalysisApiFailure.http,
        statusCode: 500,
        code: 'INTERNAL_ERROR',
        message: sensitiveDetails,
      ),
    );
    controller.failHistoryRetrieval(StateError(sensitiveDetails));

    expect(controller.submissionState.errorMessage, isNot(sensitiveDetails));
    expect(
      controller.submissionState.errorMessage,
      isNot(contains('INTERNAL')),
    );
    expect(
      controller.historyState.errorMessage,
      'The operation could not be completed. Please try again.',
    );
    expect(controller.historyState.errorMessage, isNot(contains('private')));

    controller.dispose();
  });

  test(
    'reset clears results, history, filters, selection and operation states',
    () {
      final controller = ResumeScreenerController(
        apiService: _service(_TrackingClient()),
      );

      controller.completeAnalysisSubmission(_analysisResult());
      controller.updateHistoryQuery(
        const AnalysisHistoryQuery(
          candidateName: 'Jordan Lee',
          minScore: 20,
          maxScore: 80,
          page: 3,
          size: 10,
        ),
      );
      controller.completeHistoryRetrieval(_analysisPage());
      controller.completeHistoryDetailRetrieval(_historyItem());
      controller.failAnalysisSubmission(StateError('safe generic failure'));

      controller.reset();

      expect(controller.submissionState.status, OperationStatus.idle);
      expect(controller.submissionState.errorMessage, isNull);
      expect(controller.historyState.status, OperationStatus.idle);
      expect(controller.historyDetailState.status, OperationStatus.idle);
      expect(controller.analysisResult, isNull);
      expect(controller.analysisPage, isNull);
      expect(controller.historyQuery.candidateName, isNull);
      expect(controller.historyQuery.minScore, isNull);
      expect(controller.historyQuery.maxScore, isNull);
      expect(controller.historyQuery.page, 0);
      expect(controller.historyQuery.size, 20);
      expect(controller.selectedHistoryItem, isNull);

      controller.dispose();
    },
  );
}

AnalysisApiService _service(_TrackingClient client) => AnalysisApiService(
  clientFactory: () => client,
  baseUri: Uri.parse('https://api.example.test'),
);

AnalysisResult _analysisResult() => AnalysisResult(
  id: _id,
  createdAt: DateTime.utc(2025),
  candidateName: 'Jordan Lee',
  matchScore: 82,
  requiredSkills: const CriterionAssessment(
    rating: 80,
    rationale: 'Meets most requirements.',
  ),
  relevantExperience: const CriterionAssessment(
    rating: 80,
    rationale: 'Relevant experience.',
  ),
  seniorityAndScope: const CriterionAssessment(
    rating: 80,
    rationale: 'Comparable scope.',
  ),
  niceToHaveSkillsAndDomainRelevance: const CriterionAssessment(
    rating: 80,
    rationale: 'Some alignment.',
  ),
  matchingSkills: const ['Java', 'Spring', 'SQL', 'REST', 'Testing'],
  skillGaps: const ['Cloud', 'Leadership', 'Domain'],
  interviewQuestions: const ['Question 1?', 'Question 2?', 'Question 3?'],
  advisoryNotice: 'Advisory only.',
);

AnalysisHistoryItem _historyItem() => AnalysisHistoryItem(
  id: _id,
  createdAt: DateTime.utc(2025),
  candidateName: 'Jordan Lee',
  matchScore: 82,
  matchingSkills: const ['Java', 'Spring', 'SQL', 'REST', 'Testing'],
  skillGaps: const ['Cloud', 'Leadership', 'Domain'],
  interviewQuestions: const ['Question 1?', 'Question 2?', 'Question 3?'],
);

AnalysisPage _analysisPage() => AnalysisPage(
  content: [_historyItem()],
  page: 3,
  size: 10,
  totalElements: 31,
  totalPages: 4,
);

const _id = '123e4567-e89b-12d3-a456-426614174000';
const _secondId = '223e4567-e89b-12d3-a456-426614174000';

Map<String, dynamic> _historyItemJson({String id = _id}) => {
  'id': id,
  'createdAt': '2025-01-01T00:00:00Z',
  'candidateName': 'Jordan Lee',
  'matchScore': 82,
  'matchingSkills': ['Java', 'Spring', 'SQL', 'REST', 'Testing'],
  'skillGaps': ['Cloud', 'Leadership', 'Domain'],
  'interviewQuestions': ['Question 1?', 'Question 2?', 'Question 3?'],
};

Map<String, dynamic> _analysisResultJson() => {
  'id': _id,
  'createdAt': '2025-01-01T00:00:00Z',
  'candidateName': 'Jordan Lee',
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
  int size = 20,
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
  'size': size,
  'totalElements': 21,
  'totalPages': 2,
};

class _TrackingClient extends http.BaseClient {
  bool isClosed = false;
  int sendCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sendCount++;
    throw StateError('The test client must not make network requests.');
  }

  @override
  void close() {
    isClosed = true;
  }
}

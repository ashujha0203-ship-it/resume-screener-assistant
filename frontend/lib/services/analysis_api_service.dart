import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/analysis_history_item.dart';
import '../models/analysis_page.dart';
import '../models/analysis_result.dart';
import '../models/api_error.dart';
import '../models/resume_analysis_request.dart';
import 'analysis_api_exception.dart';

class AnalysisApiService {
  AnalysisApiService({
    http.Client? client,
    http.Client Function()? clientFactory,
    Uri? baseUri,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client ?? (clientFactory ?? http.Client.new)(),
       _ownsClient = client == null,
       _analysesUri = (baseUri ?? Uri.parse(AppConfig.apiBaseUrl)).resolve(
         '/api/analyses',
       ) {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Must be a positive duration.',
      );
    }
    if (!_analysesUri.hasAuthority ||
        !{'http', 'https'}.contains(_analysesUri.scheme)) {
      throw ArgumentError.value(
        baseUri ?? AppConfig.apiBaseUrl,
        'baseUri',
        'Must be an absolute HTTP or HTTPS URL.',
      );
    }
  }

  final http.Client _client;
  final bool _ownsClient;
  final Uri _analysesUri;
  final Duration requestTimeout;
  bool _isClosed = false;

  Future<AnalysisResult> createAnalysis(ResumeAnalysisRequest request) async {
    final response = await _send(
      () => _client.post(
        _analysesUri,
        headers: _jsonHeaders,
        body: jsonEncode(request.toJson()),
      ),
    );
    return _parseSuccess(
      response,
      expectedStatus: 201,
      parser: AnalysisResult.fromJson,
    );
  }

  Future<AnalysisPage> getAnalyses({
    String? candidateName,
    int? minScore,
    int? maxScore,
    int page = 0,
    int size = 20,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'candidateName': ?candidateName,
      if (minScore != null) 'minScore': minScore.toString(),
      if (maxScore != null) 'maxScore': maxScore.toString(),
    };
    final uri = _analysesUri.replace(queryParameters: queryParameters);
    final response = await _send(
      () => _client.get(uri, headers: _acceptHeaders),
    );
    return _parseSuccess(
      response,
      expectedStatus: 200,
      parser: AnalysisPage.fromJson,
    );
  }

  Future<AnalysisHistoryItem> getAnalysisById(String id) async {
    final uri = _analysesUri.replace(
      path: '${_analysesUri.path}/${Uri.encodeComponent(id)}',
    );
    final response = await _send(
      () => _client.get(uri, headers: _acceptHeaders),
    );
    return _parseSuccess(
      response,
      expectedStatus: 200,
      parser: AnalysisHistoryItem.fromJson,
    );
  }

  void close() {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    if (_ownsClient) {
      _client.close();
    }
  }

  static const Map<String, String> _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static const Map<String, String> _acceptHeaders = {
    'Accept': 'application/json',
  };

  Future<http.Response> _send(
    Future<http.Response> Function() sendRequest,
  ) async {
    if (_isClosed) {
      throw const AnalysisApiException(
        failure: AnalysisApiFailure.transport,
        message: 'The API service has been closed.',
      );
    }
    try {
      return await sendRequest().timeout(requestTimeout);
    } on TimeoutException {
      throw const AnalysisApiException(
        failure: AnalysisApiFailure.timeout,
        message: 'The request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const AnalysisApiException(
        failure: AnalysisApiFailure.transport,
        message: 'Could not connect to the service. Please try again.',
      );
    }
  }

  T _parseSuccess<T>(
    http.Response response, {
    required int expectedStatus,
    required T Function(Map<String, dynamic>) parser,
  }) {
    if (response.statusCode != expectedStatus) {
      throw _httpException(response);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AnalysisApiException(
        failure: AnalysisApiFailure.malformedJson,
        message: 'The service returned invalid JSON.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const AnalysisApiException(
        failure: AnalysisApiFailure.unexpectedResponse,
        message: 'The service returned an unexpected response.',
      );
    }
    try {
      return parser(decoded);
    } on FormatException {
      throw const AnalysisApiException(
        failure: AnalysisApiFailure.unexpectedResponse,
        message: 'The service returned an unexpected response.',
      );
    }
  }

  AnalysisApiException _httpException(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final apiError = ApiError.fromJson(decoded);
        final safeMessage = _recognizedSafeMessage(
          response.statusCode,
          apiError.code,
          apiError.message,
        );
        if (apiError.status == response.statusCode && safeMessage != null) {
          return AnalysisApiException(
            failure: AnalysisApiFailure.http,
            statusCode: response.statusCode,
            code: apiError.code,
            message: safeMessage,
          );
        }
        return AnalysisApiException(
          failure: AnalysisApiFailure.http,
          statusCode: response.statusCode,
          code: _safeErrorCode(apiError.code, response.statusCode),
          message: _safeStatusMessage(response.statusCode),
        );
      }
    } on FormatException {
      // Fall back to a safe status-based message for invalid error payloads.
    }

    return AnalysisApiException(
      failure: AnalysisApiFailure.http,
      statusCode: response.statusCode,
      code: 'HTTP_${response.statusCode}',
      message: _safeStatusMessage(response.statusCode),
    );
  }

  String? _recognizedSafeMessage(int status, String code, String message) {
    final recognized = switch ((status, code)) {
      (400, 'INVALID_REQUEST') => 'The request is invalid.',
      (404, 'ANALYSIS_NOT_FOUND') => 'Analysis not found.',
      (405, 'METHOD_NOT_ALLOWED') =>
        'The HTTP method is not supported for this endpoint.',
      (415, 'UNSUPPORTED_MEDIA_TYPE') =>
        'The request media type is not supported.',
      (500, 'INTERNAL_ERROR') => 'An unexpected error occurred.',
      (502, 'INVALID_PROVIDER_RESPONSE') =>
        'The analysis provider returned an unusable response.',
      (502, 'AI_PROVIDER_ERROR') =>
        'The analysis provider could not complete the request.',
      (503, 'AI_NOT_CONFIGURED') =>
        'Analysis is temporarily unavailable because the AI provider is not configured.',
      (503, 'AI_RATE_LIMITED') =>
        'Analysis is temporarily unavailable. Please try again later.',
      (504, 'AI_TIMEOUT') => 'The analysis provider did not respond in time.',
      _ => null,
    };
    return message == recognized ? recognized : null;
  }

  String _safeErrorCode(String code, int statusCode) {
    if (RegExp(r'^[A-Z][A-Z0-9_]{0,63}$').hasMatch(code)) {
      return code;
    }
    return 'HTTP_$statusCode';
  }

  String _safeStatusMessage(int statusCode) => switch (statusCode) {
    400 => 'The request is invalid. Please check the provided information.',
    404 => 'The requested analysis was not found.',
    405 => 'This operation is not supported.',
    415 => 'The request format is not supported.',
    502 => 'The analysis service returned an unusable response.',
    503 => 'The analysis service is temporarily unavailable.',
    504 => 'The analysis service timed out. Please try again.',
    _ => 'The service could not complete the request.',
  };
}

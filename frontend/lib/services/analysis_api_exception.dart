enum AnalysisApiFailure {
  http,
  transport,
  timeout,
  malformedJson,
  unexpectedResponse,
}

class AnalysisApiException implements Exception {
  const AnalysisApiException({
    required this.failure,
    required this.message,
    this.statusCode,
    this.code,
  });

  final AnalysisApiFailure failure;
  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'AnalysisApiException(${failure.name}): $message';
}

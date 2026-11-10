import 'package:flutter/foundation.dart';

import '../models/analysis_history_item.dart';
import '../models/analysis_page.dart';
import '../models/analysis_result.dart';
import '../models/resume_analysis_request.dart';
import '../services/analysis_api_exception.dart';
import '../services/analysis_api_service.dart';

enum OperationStatus { idle, loading, success, error }

@immutable
class OperationState {
  const OperationState._(this.status, this.errorMessage);

  const OperationState.idle() : this._(OperationStatus.idle, null);

  const OperationState.loading() : this._(OperationStatus.loading, null);

  const OperationState.success() : this._(OperationStatus.success, null);

  const OperationState.error(String message)
    : this._(OperationStatus.error, message);

  final OperationStatus status;
  final String? errorMessage;

  bool get isLoading => status == OperationStatus.loading;
  bool get hasError => status == OperationStatus.error;
}

@immutable
class AnalysisHistoryQuery {
  const AnalysisHistoryQuery({
    this.candidateName,
    this.minScore,
    this.maxScore,
    this.page = 0,
    this.size = 20,
  });

  final String? candidateName;
  final int? minScore;
  final int? maxScore;
  final int page;
  final int size;

  AnalysisHistoryQuery withPage(int page) => AnalysisHistoryQuery(
    candidateName: candidateName,
    minScore: minScore,
    maxScore: maxScore,
    page: page,
    size: size,
  );

  @override
  bool operator ==(Object other) =>
      other is AnalysisHistoryQuery &&
      candidateName == other.candidateName &&
      minScore == other.minScore &&
      maxScore == other.maxScore &&
      page == other.page &&
      size == other.size;

  @override
  int get hashCode =>
      Object.hash(candidateName, minScore, maxScore, page, size);
}

class ResumeScreenerController extends ChangeNotifier {
  /// Takes ownership of [apiService], or creates one when omitted.
  ResumeScreenerController({AnalysisApiService? apiService})
    : _apiService = apiService ?? AnalysisApiService();

  final AnalysisApiService _apiService;
  bool _isDisposed = false;

  OperationState _submissionState = const OperationState.idle();
  OperationState get submissionState => _submissionState;

  OperationState _historyState = const OperationState.idle();
  OperationState get historyState => _historyState;

  OperationState _historyDetailState = const OperationState.idle();
  OperationState get historyDetailState => _historyDetailState;
  bool _historyDetailNotFound = false;
  bool get historyDetailNotFound => _historyDetailNotFound;

  AnalysisResult? _analysisResult;
  AnalysisResult? get analysisResult => _analysisResult;

  AnalysisPage? _analysisPage;
  AnalysisPage? get analysisPage => _analysisPage;

  AnalysisHistoryQuery _historyQuery = const AnalysisHistoryQuery();
  AnalysisHistoryQuery get historyQuery => _historyQuery;
  int _historyRequestGeneration = 0;
  AnalysisHistoryQuery? _inFlightHistoryQuery;

  AnalysisHistoryItem? _selectedHistoryItem;
  AnalysisHistoryItem? get selectedHistoryItem => _selectedHistoryItem;
  String? _selectedHistoryId;
  String? get selectedHistoryId => _selectedHistoryId;
  int _historyDetailRequestGeneration = 0;
  String? _inFlightHistoryDetailId;

  Future<bool> submitAnalysis(ResumeAnalysisRequest request) async {
    _ensureNotDisposed();
    if (_submissionState.isLoading) {
      return false;
    }

    _analysisResult = null;
    _submissionState = const OperationState.loading();
    notifyListeners();

    try {
      final result = await _apiService.createAnalysis(request);
      if (_isDisposed) {
        return false;
      }
      _analysisResult = result;
      _submissionState = const OperationState.success();
      notifyListeners();
      return true;
    } on Object catch (error) {
      if (_isDisposed) {
        return false;
      }
      _submissionState = OperationState.error(_safeErrorMessage(error));
      notifyListeners();
      return false;
    }
  }

  void clearSubmissionState() {
    _ensureNotDisposed();
    if (_submissionState.status == OperationStatus.idle) {
      return;
    }
    _submissionState = const OperationState.idle();
    notifyListeners();
  }

  void startAnalysisSubmission() {
    _ensureNotDisposed();
    _analysisResult = null;
    _submissionState = const OperationState.loading();
    notifyListeners();
  }

  void completeAnalysisSubmission(AnalysisResult result) {
    _ensureNotDisposed();
    _analysisResult = result;
    _submissionState = const OperationState.success();
    notifyListeners();
  }

  void failAnalysisSubmission(Object error) {
    _ensureNotDisposed();
    _submissionState = OperationState.error(_safeErrorMessage(error));
    notifyListeners();
  }

  void startHistoryRetrieval() {
    _ensureNotDisposed();
    _historyState = const OperationState.loading();
    notifyListeners();
  }

  Future<void> loadHistory({AnalysisHistoryQuery? query}) async {
    _ensureNotDisposed();
    final requestedQuery = query ?? _historyQuery;
    _validateHistoryQuery(requestedQuery);

    if (_historyState.isLoading && requestedQuery == _inFlightHistoryQuery) {
      return;
    }

    if (_historyFiltersChanged(requestedQuery, _historyQuery)) {
      _analysisPage = null;
    }

    final generation = ++_historyRequestGeneration;
    _historyQuery = requestedQuery;
    _inFlightHistoryQuery = requestedQuery;
    _historyState = const OperationState.loading();
    notifyListeners();

    try {
      final page = await _apiService.getAnalyses(
        candidateName: requestedQuery.candidateName,
        minScore: requestedQuery.minScore,
        maxScore: requestedQuery.maxScore,
        page: requestedQuery.page,
        size: requestedQuery.size,
      );
      if (_isDisposed || generation != _historyRequestGeneration) {
        return;
      }

      _analysisPage = page;
      _historyQuery = requestedQuery.withPage(page.page);
      _inFlightHistoryQuery = null;
      _historyState = const OperationState.success();
      notifyListeners();
    } on Object catch (error) {
      if (_isDisposed || generation != _historyRequestGeneration) {
        return;
      }

      _inFlightHistoryQuery = null;
      _historyState = OperationState.error(_safeErrorMessage(error));
      notifyListeners();
    }
  }

  Future<void> retryHistory() => loadHistory(query: _historyQuery);

  void completeHistoryRetrieval(AnalysisPage page) {
    _ensureNotDisposed();
    _analysisPage = page;
    _historyQuery = _historyQuery.withPage(page.page);
    _historyState = const OperationState.success();
    notifyListeners();
  }

  void failHistoryRetrieval(Object error) {
    _ensureNotDisposed();
    _historyState = OperationState.error(_safeErrorMessage(error));
    notifyListeners();
  }

  void updateHistoryQuery(AnalysisHistoryQuery query) {
    _ensureNotDisposed();
    _validateHistoryQuery(query);
    final filtersChanged = _historyFiltersChanged(query, _historyQuery);
    final updatedQuery = filtersChanged ? query.withPage(0) : query;
    if (updatedQuery == _historyQuery) {
      return;
    }

    _historyRequestGeneration++;
    _inFlightHistoryQuery = null;
    _historyQuery = updatedQuery;
    if (filtersChanged) {
      _analysisPage = null;
    }
    if (_historyState.isLoading) {
      _historyState = const OperationState.idle();
    }
    notifyListeners();
  }

  bool _historyFiltersChanged(
    AnalysisHistoryQuery query,
    AnalysisHistoryQuery currentQuery,
  ) =>
      query.candidateName != currentQuery.candidateName ||
      query.minScore != currentQuery.minScore ||
      query.maxScore != currentQuery.maxScore ||
      query.size != currentQuery.size;

  void startHistoryDetailRetrieval() {
    _ensureNotDisposed();
    _historyDetailRequestGeneration++;
    _inFlightHistoryDetailId = null;
    _historyDetailNotFound = false;
    _historyDetailState = const OperationState.loading();
    notifyListeners();
  }

  Future<void> loadHistoryDetail(String id) async {
    _ensureNotDisposed();
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (_historyDetailState.isLoading && id == _inFlightHistoryDetailId) {
      return;
    }

    final generation = ++_historyDetailRequestGeneration;
    _selectedHistoryId = id;
    _selectedHistoryItem = null;
    _historyDetailNotFound = false;
    _inFlightHistoryDetailId = id;
    _historyDetailState = const OperationState.loading();
    notifyListeners();

    try {
      final item = await _apiService.getAnalysisById(id);
      if (_isDisposed ||
          generation != _historyDetailRequestGeneration ||
          id != _selectedHistoryId) {
        return;
      }

      _selectedHistoryItem = item;
      _inFlightHistoryDetailId = null;
      _historyDetailState = const OperationState.success();
      notifyListeners();
    } on Object catch (error) {
      if (_isDisposed ||
          generation != _historyDetailRequestGeneration ||
          id != _selectedHistoryId) {
        return;
      }

      _inFlightHistoryDetailId = null;
      _historyDetailNotFound =
          error is AnalysisApiException &&
          error.statusCode == 404 &&
          error.code == 'ANALYSIS_NOT_FOUND';
      _historyDetailState = OperationState.error(_safeErrorMessage(error));
      notifyListeners();
    }
  }

  Future<void> retryHistoryDetail() {
    final id = _selectedHistoryId;
    if (id == null) {
      return Future<void>.value();
    }
    return loadHistoryDetail(id);
  }

  void completeHistoryDetailRetrieval(AnalysisHistoryItem item) {
    _ensureNotDisposed();
    _historyDetailRequestGeneration++;
    _inFlightHistoryDetailId = null;
    _selectedHistoryId = item.id;
    _selectedHistoryItem = item;
    _historyDetailNotFound = false;
    _historyDetailState = const OperationState.success();
    notifyListeners();
  }

  void failHistoryDetailRetrieval(Object error) {
    _ensureNotDisposed();
    _historyDetailRequestGeneration++;
    _inFlightHistoryDetailId = null;
    _historyDetailNotFound =
        error is AnalysisApiException &&
        error.statusCode == 404 &&
        error.code == 'ANALYSIS_NOT_FOUND';
    _historyDetailState = OperationState.error(_safeErrorMessage(error));
    notifyListeners();
  }

  void reset() {
    _ensureNotDisposed();
    _historyRequestGeneration++;
    _inFlightHistoryQuery = null;
    _historyDetailRequestGeneration++;
    _inFlightHistoryDetailId = null;
    _submissionState = const OperationState.idle();
    _historyState = const OperationState.idle();
    _historyDetailState = const OperationState.idle();
    _historyDetailNotFound = false;
    _analysisResult = null;
    _analysisPage = null;
    _historyQuery = const AnalysisHistoryQuery();
    _selectedHistoryItem = null;
    _selectedHistoryId = null;
    notifyListeners();
  }

  void _validateHistoryQuery(AnalysisHistoryQuery query) {
    if (query.page < 0) {
      throw ArgumentError.value(query.page, 'page', 'Must be zero or greater.');
    }
    if (query.size < 1 || query.size > 100) {
      throw ArgumentError.value(
        query.size,
        'size',
        'Must be between 1 and 100.',
      );
    }
    if (query.minScore != null &&
        (query.minScore! < 0 || query.minScore! > 100)) {
      throw ArgumentError.value(
        query.minScore,
        'minScore',
        'Must be between 0 and 100.',
      );
    }
    if (query.maxScore != null &&
        (query.maxScore! < 0 || query.maxScore! > 100)) {
      throw ArgumentError.value(
        query.maxScore,
        'maxScore',
        'Must be between 0 and 100.',
      );
    }
    if (query.minScore != null &&
        query.maxScore != null &&
        query.minScore! > query.maxScore!) {
      throw ArgumentError('minScore must not exceed maxScore.');
    }
  }

  String _safeErrorMessage(Object error) {
    if (error is! AnalysisApiException) {
      return 'The operation could not be completed. Please try again.';
    }

    return switch (error.failure) {
      AnalysisApiFailure.http => switch ((error.statusCode, error.code)) {
        (400, 'INVALID_REQUEST') => 'The request is invalid.',
        (404, 'ANALYSIS_NOT_FOUND') => 'Analysis not found.',
        (502, 'INVALID_PROVIDER_RESPONSE') =>
          'The analysis service returned an unusable response.',
        (502, 'AI_PROVIDER_ERROR') =>
          'The analysis provider could not complete the request.',
        (503, 'AI_NOT_CONFIGURED') => 'Analysis is temporarily unavailable because the AI provider is not configured.',
        (503, 'AI_RATE_LIMITED') =>
          'Analysis is temporarily unavailable. Please try again later.',
        (504, 'AI_TIMEOUT') => 'The analysis provider did not respond in time.',
        _ => 'The service could not complete the request.',
      },
      AnalysisApiFailure.transport =>
        'Could not connect to the service. Please try again.',
      AnalysisApiFailure.timeout => 'The request timed out. Please try again.',
      AnalysisApiFailure.malformedJson =>
        'The service returned invalid data. Please try again.',
      AnalysisApiFailure.unexpectedResponse =>
        'The service returned an unexpected response. Please try again.',
    };
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('ResumeScreenerController has been disposed.');
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _historyRequestGeneration++;
    _inFlightHistoryQuery = null;
    _historyDetailRequestGeneration++;
    _inFlightHistoryDetailId = null;
    _apiService.close();
    super.dispose();
  }
}

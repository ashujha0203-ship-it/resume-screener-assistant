import 'analysis_history_item.dart';

class AnalysisPage {
  AnalysisPage({
    required List<AnalysisHistoryItem> content,
    required int page,
    required int size,
    required int totalElements,
    required int totalPages,
  }) : content = List.unmodifiable(content),
       page = _requireMinimum('page', page, 0),
       size = _requireMinimum('size', size, 1),
       totalElements = _requireMinimum('totalElements', totalElements, 0),
       totalPages = _requireMinimum('totalPages', totalPages, 0);

  final List<AnalysisHistoryItem> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  factory AnalysisPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];
    if (content is! List ||
        content.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException(
        'content must be a list of analysis records.',
      );
    }

    return AnalysisPage(
      content: content
          .cast<Map<String, dynamic>>()
          .map(AnalysisHistoryItem.fromJson)
          .toList(growable: false),
      page: _requiredInteger(json, 'page'),
      size: _requiredInteger(json, 'size'),
      totalElements: _requiredInteger(json, 'totalElements'),
      totalPages: _requiredInteger(json, 'totalPages'),
    );
  }

  Map<String, dynamic> toJson() => {
    'content': content.map((item) => item.toJson()).toList(growable: false),
    'page': page,
    'size': size,
    'totalElements': totalElements,
    'totalPages': totalPages,
  };
}

int _requiredInteger(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key must be an integer.');
  }
  return value;
}

int _requireMinimum(String fieldName, int value, int minimum) {
  if (value < minimum) {
    throw FormatException('$fieldName must be at least $minimum.');
  }
  return value;
}

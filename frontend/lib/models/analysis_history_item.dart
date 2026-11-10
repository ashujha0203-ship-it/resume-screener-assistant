class AnalysisHistoryItem {
  AnalysisHistoryItem({
    required this.id,
    required this.createdAt,
    required this.candidateName,
    required this.matchScore,
    required List<String> matchingSkills,
    required List<String> skillGaps,
    required List<String> interviewQuestions,
  }) : matchingSkills = _validatedImmutableList(
         'matchingSkills',
         matchingSkills,
         5,
       ),
       skillGaps = _validatedImmutableList('skillGaps', skillGaps, 3),
       interviewQuestions = _validatedImmutableList(
         'interviewQuestions',
         interviewQuestions,
         3,
       );

  final String id;
  final DateTime createdAt;
  final String? candidateName;
  final int matchScore;
  final List<String> matchingSkills;
  final List<String> skillGaps;
  final List<String> interviewQuestions;

  factory AnalysisHistoryItem.fromJson(Map<String, dynamic> json) {
    final candidateName = json['candidateName'];
    if (candidateName != null && candidateName is! String) {
      throw const FormatException('candidateName must be a string or null.');
    }
    final matchScore = json['matchScore'];
    if (matchScore is! int || matchScore < 0 || matchScore > 100) {
      throw const FormatException(
        'matchScore must be an integer from 0 to 100.',
      );
    }

    return AnalysisHistoryItem(
      id: _requiredString(json, 'id'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      candidateName: candidateName as String?,
      matchScore: matchScore,
      matchingSkills: _requiredStringList(json, 'matchingSkills'),
      skillGaps: _requiredStringList(json, 'skillGaps'),
      interviewQuestions: _requiredStringList(json, 'interviewQuestions'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'candidateName': candidateName,
    'matchScore': matchScore,
    'matchingSkills': matchingSkills,
    'skillGaps': skillGaps,
    'interviewQuestions': interviewQuestions,
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('$key must be a string.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw FormatException('$key must be a valid ISO-8601 timestamp.');
  }
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$key must be a list of strings.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

List<String> _validatedImmutableList(
  String fieldName,
  List<String> values,
  int expectedLength,
) {
  if (values.length != expectedLength) {
    throw FormatException(
      '$fieldName must contain exactly $expectedLength items; '
      'received ${values.length}.',
    );
  }
  return List<String>.unmodifiable(values);
}

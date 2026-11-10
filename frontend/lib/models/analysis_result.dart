import 'criterion_assessment.dart';

class AnalysisResult {
  AnalysisResult({
    required this.id,
    required this.createdAt,
    required this.candidateName,
    required this.matchScore,
    required this.requiredSkills,
    required this.relevantExperience,
    required this.seniorityAndScope,
    required this.niceToHaveSkillsAndDomainRelevance,
    required List<String> matchingSkills,
    required List<String> skillGaps,
    required List<String> interviewQuestions,
    required this.advisoryNotice,
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
  final CriterionAssessment requiredSkills;
  final CriterionAssessment relevantExperience;
  final CriterionAssessment seniorityAndScope;
  final CriterionAssessment niceToHaveSkillsAndDomainRelevance;
  final List<String> matchingSkills;
  final List<String> skillGaps;
  final List<String> interviewQuestions;
  final String advisoryNotice;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
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

    return AnalysisResult(
      id: _requiredString(json, 'id'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      candidateName: candidateName as String?,
      matchScore: matchScore,
      requiredSkills: _requiredCriterion(json, 'requiredSkills'),
      relevantExperience: _requiredCriterion(json, 'relevantExperience'),
      seniorityAndScope: _requiredCriterion(json, 'seniorityAndScope'),
      niceToHaveSkillsAndDomainRelevance: _requiredCriterion(
        json,
        'niceToHaveSkillsAndDomainRelevance',
      ),
      matchingSkills: _requiredStringList(json, 'matchingSkills'),
      skillGaps: _requiredStringList(json, 'skillGaps'),
      interviewQuestions: _requiredStringList(json, 'interviewQuestions'),
      advisoryNotice: _requiredString(json, 'advisoryNotice'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'candidateName': candidateName,
    'matchScore': matchScore,
    'requiredSkills': requiredSkills.toJson(),
    'relevantExperience': relevantExperience.toJson(),
    'seniorityAndScope': seniorityAndScope.toJson(),
    'niceToHaveSkillsAndDomainRelevance': niceToHaveSkillsAndDomainRelevance
        .toJson(),
    'matchingSkills': matchingSkills,
    'skillGaps': skillGaps,
    'interviewQuestions': interviewQuestions,
    'advisoryNotice': advisoryNotice,
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

CriterionAssessment _requiredCriterion(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('$key must be an assessment object.');
  }
  return CriterionAssessment.fromJson(value);
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

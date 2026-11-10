class ResumeAnalysisRequest {
  const ResumeAnalysisRequest({
    this.candidateName,
    required this.jobDescription,
    required this.resume,
  });

  final String? candidateName;
  final String jobDescription;
  final String resume;

  factory ResumeAnalysisRequest.fromJson(Map<String, dynamic> json) {
    final candidateName = json['candidateName'];
    if (candidateName != null && candidateName is! String) {
      throw const FormatException('candidateName must be a string or null.');
    }

    return ResumeAnalysisRequest(
      candidateName: candidateName as String?,
      jobDescription: _requiredString(json, 'jobDescription'),
      resume: _requiredString(json, 'resume'),
    );
  }

  Map<String, dynamic> toJson() => {
    if (candidateName != null) 'candidateName': candidateName,
    'jobDescription': jobDescription,
    'resume': resume,
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('$key must be a string.');
  }
  return value;
}

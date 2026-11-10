class CriterionAssessment {
  const CriterionAssessment({required this.rating, required this.rationale});

  final int rating;
  final String rationale;

  factory CriterionAssessment.fromJson(Map<String, dynamic> json) {
    final rating = json['rating'];
    if (rating is! int || rating < 0 || rating > 100) {
      throw const FormatException('rating must be an integer from 0 to 100.');
    }

    final rationale = json['rationale'];
    if (rationale is! String || rationale.trim().isEmpty) {
      throw const FormatException('rationale must be a non-empty string.');
    }

    return CriterionAssessment(rating: rating, rationale: rationale);
  }

  Map<String, dynamic> toJson() => {'rating': rating, 'rationale': rationale};
}

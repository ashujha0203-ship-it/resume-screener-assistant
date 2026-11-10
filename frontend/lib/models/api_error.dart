class ApiError {
  const ApiError({
    required this.timestamp,
    required this.status,
    required this.code,
    required this.message,
  });

  final DateTime timestamp;
  final int status;
  final String code;
  final String message;

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final timestampValue = _requiredString(json, 'timestamp');
    final timestamp = _parseTimestamp(timestampValue);
    final status = json['status'];
    if (status is! int) {
      throw const FormatException('status must be an integer.');
    }

    return ApiError(
      timestamp: timestamp,
      status: status,
      code: _requiredString(json, 'code'),
      message: _requiredString(json, 'message'),
    );
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'status': status,
    'code': code,
    'message': message,
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('$key must be a string.');
  }
  return value;
}

DateTime _parseTimestamp(String value) {
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw const FormatException(
      'timestamp must be a valid ISO-8601 timestamp.',
    );
  }
}

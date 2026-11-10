import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/resume_screener_controller.dart';
import '../models/resume_analysis_request.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({
    required this.controller,
    required this.onAnalysisSubmitted,
    super.key,
  });

  final ResumeScreenerController controller;
  final VoidCallback onAnalysisSubmitted;

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  static const int _candidateNameLimit = 200;
  static const int _jobDescriptionLimit = 20000;
  static const int _resumeLimit = 30000;

  final _formKey = GlobalKey<FormState>();
  final _candidateNameController = TextEditingController();
  final _jobDescriptionController = TextEditingController();
  final _resumeController = TextEditingController();

  @override
  void dispose() {
    _candidateNameController.dispose();
    _jobDescriptionController.dispose();
    _resumeController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final candidateName = _candidateNameController.text.trim();
    final succeeded = await widget.controller.submitAnalysis(
      ResumeAnalysisRequest(
        candidateName: candidateName.isEmpty ? null : candidateName,
        jobDescription: _jobDescriptionController.text,
        resume: _resumeController.text,
      ),
    );
    if (!mounted || !succeeded) {
      return;
    }

    _clearForm();
    widget.controller.clearSubmissionState();
    widget.onAnalysisSubmitted();
  }

  void _clear() {
    _clearForm();
    widget.controller.clearSubmissionState();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _candidateNameController.clear();
    _jobDescriptionController.clear();
    _resumeController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final submissionState = widget.controller.submissionState;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Analyze a resume',
                      key: const ValueKey('analyze-screen-title'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Compare a resume with a job description. Candidate name '
                      'is optional.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: _candidateNameController,
                      fieldKey: const ValueKey('candidate-name-field'),
                      label: 'Candidate Name (optional)',
                      hint: 'Enter the candidate name',
                      maxLength: _candidateNameLimit,
                      counterKey: const ValueKey('candidate-name-counter'),
                      minLines: 1,
                      maxLines: 1,
                      validator: (value) {
                        if ((value?.length ?? 0) > _candidateNameLimit) {
                          return 'Candidate name must be at most '
                              '$_candidateNameLimit characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _jobDescriptionController,
                      fieldKey: const ValueKey('job-description-field'),
                      label: 'Job Description',
                      hint: 'Paste the job description here',
                      maxLength: _jobDescriptionLimit,
                      counterKey: const ValueKey('job-description-counter'),
                      minLines: 5,
                      maxLines: 10,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Job description is required.';
                        }
                        if (value.length > _jobDescriptionLimit) {
                          return 'Job description must be at most '
                              '$_jobDescriptionLimit characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _resumeController,
                      fieldKey: const ValueKey('resume-field'),
                      label: 'Resume',
                      hint: 'Paste the resume text here',
                      maxLength: _resumeLimit,
                      counterKey: const ValueKey('resume-counter'),
                      minLines: 5,
                      maxLines: 10,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Resume is required.';
                        }
                        if (value.length > _resumeLimit) {
                          return 'Resume must be at most $_resumeLimit characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: submissionState.isLoading ? null : _clear,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear'),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('analyze-submit'),
                          onPressed: submissionState.isLoading
                              ? null
                              : _analyze,
                          icon: submissionState.isLoading
                              ? const SizedBox(
                                  key: ValueKey('analyze-loading-indicator'),
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome_outlined),
                          label: Text(
                            submissionState.isLoading
                                ? 'Analyzing…'
                                : 'Analyze',
                          ),
                        ),
                      ],
                    ),
                    if (submissionState.isLoading) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: const Text(
                          'Analysis is in progress. Please wait.',
                          key: ValueKey('analyze-loading-status'),
                        ),
                      ),
                    ],
                    if (submissionState.errorMessage case final message?) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          key: const ValueKey('analyze-error'),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            message,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required Key fieldKey,
    required String label,
    required String hint,
    required int maxLength,
    required Key counterKey,
    required int minLines,
    required int maxLines,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: minLines == 1
          ? TextInputType.name
          : TextInputType.multiline,
      textCapitalization: minLines == 1
          ? TextCapitalization.words
          : TextCapitalization.sentences,
      inputFormatters: [_Utf16LengthLimitingTextInputFormatter(maxLength)],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: minLines > 1,
        border: const OutlineInputBorder(),
        counter: Text(
          '${controller.text.length} / $maxLength',
          key: counterKey,
          semanticsLabel: '${controller.text.length} of $maxLength characters',
        ),
      ),
      validator: validator,
      onChanged: (_) => setState(() {}),
    );
  }
}

class _Utf16LengthLimitingTextInputFormatter extends TextInputFormatter {
  const _Utf16LengthLimitingTextInputFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= maxLength) {
      return newValue;
    }

    var end = maxLength;
    if (end > 0 && _isHighSurrogate(newValue.text.codeUnitAt(end - 1))) {
      end--;
    }
    final truncatedText = newValue.text.substring(0, end);
    final selectionOffset = newValue.selection.end.clamp(0, end);
    return TextEditingValue(
      text: truncatedText,
      selection: TextSelection.collapsed(offset: selectionOffset),
    );
  }

  bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/analysis_history_item.dart';
import '../models/analysis_page.dart';

class HistoryFilter {
  const HistoryFilter({this.candidateName, this.minScore, this.maxScore});

  final String? candidateName;
  final int? minScore;
  final int? maxScore;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    this.initialPage,
    this.isLoading = false,
    this.errorMessage,
    this.onSearch,
    this.onPageChanged,
    this.onRetry,
    this.onItemSelected,
    super.key,
  });

  final AnalysisPage? initialPage;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<HistoryFilter>? onSearch;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onItemSelected;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const int _candidateNameLimit = 200;

  final _formKey = GlobalKey<FormState>();
  final _candidateNameController = TextEditingController();
  final _minScoreController = TextEditingController();
  final _maxScoreController = TextEditingController();
  String? _notice;

  @override
  void dispose() {
    _candidateNameController.dispose();
    _minScoreController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  void _search() {
    FocusScope.of(context).unfocus();
    setState(() {
      _notice = null;
    });
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final candidateName = _candidateNameController.text.trim();
    final filter = HistoryFilter(
      candidateName: candidateName.isEmpty ? null : candidateName,
      minScore: _parseScore(_minScoreController.text),
      maxScore: _parseScore(_maxScoreController.text),
    );
    if (widget.onSearch == null) {
      _showIntegrationNotice();
      return;
    }
    widget.onSearch!(filter);
  }

  void _clear() {
    _formKey.currentState?.reset();
    _candidateNameController.clear();
    _minScoreController.clear();
    _maxScoreController.clear();
    setState(() {
      _notice = null;
    });
    if (widget.onSearch == null) {
      _showIntegrationNotice();
    } else {
      widget.onSearch!(const HistoryFilter());
    }
  }

  void _changePage(int page) {
    setState(() {
      _notice = null;
    });
    if (widget.onPageChanged == null) {
      _showIntegrationNotice();
      return;
    }
    widget.onPageChanged!(page);
  }

  void _selectItem(AnalysisHistoryItem item) {
    if (widget.onItemSelected == null) {
      _showIntegrationNotice();
      return;
    }
    widget.onItemSelected!(item.id);
  }

  void _showIntegrationNotice() {
    setState(() {
      _notice = 'History integration will be added in a later step.';
    });
  }

  int? _parseScore(String value) =>
      value.trim().isEmpty ? null : int.tryParse(value.trim());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = widget.initialPage;
    final items = page?.content ?? const <AnalysisHistoryItem>[];

    return SingleChildScrollView(
      key: const ValueKey('history-content-scroll'),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Analysis history',
                key: const ValueKey('history-screen-title'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Search saved analyses by candidate and match score.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _buildFilters(context),
              if (_notice case final notice?) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const ValueKey('history-integration-notice'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      notice,
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (widget.isLoading && page == null)
                const _InitialHistoryLoadingState()
              else ...[
                if (widget.isLoading) const _HistoryRefreshIndicator(),
                if (widget.errorMessage case final message?)
                  _HistoryErrorState(message: message, onRetry: widget.onRetry),
                if (page == null &&
                    !widget.isLoading &&
                    widget.errorMessage == null)
                  const _IdleHistoryState()
                else if (page != null && items.isEmpty)
                  const _EmptyHistoryState()
                else if (items.isNotEmpty) ...[
                  for (final item in items) ...[
                    _HistoryItemCard(
                      item: item,
                      onTap: () => _selectItem(item),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
              const SizedBox(height: 12),
              _PaginationControls(page: page, onPageChanged: _changePage),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final candidateNameField = TextFormField(
      key: const ValueKey('history-candidate-name-filter'),
      controller: _candidateNameController,
      inputFormatters: [
        _Utf16LengthLimitingTextInputFormatter(_candidateNameLimit),
      ],
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Candidate name',
        hintText: 'Search by candidate',
        border: OutlineInputBorder(),
        counter: Text(
          '${_candidateNameController.text.length} / $_candidateNameLimit',
          key: const ValueKey('history-candidate-name-counter'),
          semanticsLabel:
              '${_candidateNameController.text.length} of '
              '$_candidateNameLimit characters',
        ),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty && value.trim().isEmpty) {
          return 'Enter a name or leave this filter empty.';
        }
        return null;
      },
      onChanged: (_) {
        setState(() {
          _notice = null;
        });
      },
    );
    final minScoreField = _scoreField(
      controller: _minScoreController,
      key: const ValueKey('history-min-score-filter'),
      label: 'Minimum score',
    );
    final maxScoreField = _scoreField(
      controller: _maxScoreController,
      key: const ValueKey('history-max-score-filter'),
      label: 'Maximum score',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (!isWide) {
                    return Column(
                      children: [
                        candidateNameField,
                        const SizedBox(height: 12),
                        minScoreField,
                        const SizedBox(height: 12),
                        maxScoreField,
                      ],
                    );
                  }
                  const spacing = 12.0;
                  final candidateWidth = constraints.maxWidth * 0.46;
                  final scoreWidth =
                      (constraints.maxWidth - candidateWidth - spacing * 2) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      SizedBox(
                        width: candidateWidth,
                        child: candidateNameField,
                      ),
                      SizedBox(width: scoreWidth, child: minScoreField),
                      SizedBox(width: scoreWidth, child: maxScoreField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('history-clear-filters'),
                    onPressed: _clear,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('history-search'),
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreField({
    required TextEditingController controller,
    required Key key,
    required String label,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: '0–100',
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return null;
        }
        if (!RegExp(r'^-?\d+$').hasMatch(text)) {
          return 'Enter a whole number.';
        }
        final score = int.tryParse(text);
        if (score == null) {
          return 'Enter a whole number.';
        }
        if (score < 0 || score > 100) {
          return 'Score must be from 0 to 100.';
        }
        final otherValue = identical(controller, _minScoreController)
            ? _maxScoreController.text.trim()
            : _minScoreController.text.trim();
        final otherScore = int.tryParse(otherValue);
        if (otherScore != null) {
          if (identical(controller, _minScoreController) &&
              score > otherScore) {
            return 'Minimum cannot exceed maximum.';
          }
          if (identical(controller, _maxScoreController) &&
              otherScore > score) {
            return 'Minimum cannot exceed maximum.';
          }
        }
        return null;
      },
      onChanged: (_) => _clearNotice(),
    );
  }

  void _clearNotice() {
    if (_notice == null) {
      return;
    }
    setState(() {
      _notice = null;
    });
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No matching analyses',
              key: const ValueKey('history-empty-title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing or clearing the candidate and score filters.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleHistoryState extends StatelessWidget {
  const _IdleHistoryState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.manage_search,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'History not loaded',
              key: const ValueKey('history-idle-title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Use Search to view saved analyses.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialHistoryLoadingState extends StatelessWidget {
  const _InitialHistoryLoadingState();

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('history-initial-loading'),
    liveRegion: true,
    label: 'Loading history',
    child: const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    ),
  );
}

class _HistoryRefreshIndicator extends StatelessWidget {
  const _HistoryRefreshIndicator();

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('history-refresh-loading'),
    liveRegion: true,
    label: 'Refreshing history',
    child: const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: LinearProgressIndicator(),
    ),
  );
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Could not load history',
              key: const ValueKey('history-error-title'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              key: const ValueKey('history-error-message'),
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: const ValueKey('history-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            if (onRetry == null)
              Text(
                'Retry will be available when history integration is connected.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({required this.item, required this.onTap});

  final AnalysisHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidateName = item.candidateName?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidateName == null || candidateName.isEmpty
                              ? 'Candidate'
                              : candidateName,
                          key: ValueKey('history-candidate-${item.id}'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatLocalDateTime(item.createdAt),
                          key: ValueKey('history-created-at-${item.id}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _HistoryScore(score: item.matchScore),
                ],
              ),
              const SizedBox(height: 16),
              _SkillPreview(
                title: 'Matching skills',
                items: item.matchingSkills,
              ),
              const SizedBox(height: 10),
              _SkillPreview(title: 'Skill gaps', items: item.skillGaps),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryScore extends StatelessWidget {
  const _HistoryScore({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Match score: $score out of 100',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$score / 100',
            key: ValueKey('history-score-$score'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 84,
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: score / 100,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillPreview extends StatelessWidget {
  const _SkillPreview({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Chip(
                  label: Text(item, overflow: TextOverflow.ellipsis),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({required this.page, required this.onPageChanged});

  final AnalysisPage? page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final currentPage = page?.page ?? 0;
    final totalPages = page?.totalPages ?? 0;
    final hasPages = totalPages > 0;
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('history-previous-page'),
          onPressed: hasPages && currentPage > 0
              ? () => onPageChanged(currentPage - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        Text(
          hasPages ? 'Page ${currentPage + 1} of $totalPages' : 'No pages',
          key: const ValueKey('history-page-label'),
          style: theme.textTheme.bodyMedium,
        ),
        OutlinedButton.icon(
          key: const ValueKey('history-next-page'),
          onPressed: hasPages && currentPage < totalPages - 1
              ? () => onPageChanged(currentPage + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
      ],
    );
  }
}

String _formatLocalDateTime(DateTime timestamp) {
  final local = timestamp.toLocal();
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${months[local.month - 1]} ${local.day}, ${local.year} at '
      '$hour:$minute $period';
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

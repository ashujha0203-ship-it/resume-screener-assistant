import 'package:flutter/material.dart';

import '../models/analysis_history_item.dart';

class AnalysisDetailScreen extends StatelessWidget {
  const AnalysisDetailScreen({
    required this.onBack,
    required this.onRetry,
    this.item,
    this.isLoading = false,
    this.errorMessage,
    this.isNotFound = false,
    super.key,
  });

  final AnalysisHistoryItem? item;
  final bool isLoading;
  final String? errorMessage;
  final bool isNotFound;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = item;

    return SingleChildScrollView(
      key: const ValueKey('analysis-detail-scroll'),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('analysis-detail-back'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to History'),
                ),
              ),
              const SizedBox(height: 8),
              if (isLoading && detail == null)
                const _DetailLoadingState()
              else if (isNotFound)
                _DetailErrorState(
                  title: 'Analysis not found',
                  message: 'This saved analysis may have been removed.',
                  onRetry: onRetry,
                  notFound: true,
                )
              else if (errorMessage case final message?)
                _DetailErrorState(
                  title: 'Could not load analysis',
                  message: message,
                  onRetry: onRetry,
                )
              else if (detail != null) ...[
                if (isLoading) const _DetailRefreshIndicator(),
                Text(
                  detail.candidateName?.trim().isNotEmpty == true
                      ? detail.candidateName!
                      : 'Candidate',
                  key: const ValueKey('analysis-detail-candidate'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Analyzed ${_formatLocalDateTime(detail.createdAt)}',
                  key: const ValueKey('analysis-detail-created-at'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                _ScoreCard(score: detail.matchScore),
                const SizedBox(height: 16),
                _TextListCard(
                  title: 'Matching skills',
                  icon: Icons.check_circle_outline,
                  items: detail.matchingSkills,
                ),
                const SizedBox(height: 16),
                _TextListCard(
                  title: 'Skill gaps',
                  icon: Icons.flag_outlined,
                  items: detail.skillGaps,
                ),
                const SizedBox(height: 16),
                _TextListCard(
                  title: 'Suggested interview questions',
                  icon: Icons.question_answer_outlined,
                  items: detail.interviewQuestions,
                ),
              ] else
                const _DetailIdleState(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLoadingState extends StatelessWidget {
  const _DetailLoadingState();

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('analysis-detail-loading'),
    liveRegion: true,
    label: 'Loading saved analysis',
    child: const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      ),
    ),
  );
}

class _DetailRefreshIndicator extends StatelessWidget {
  const _DetailRefreshIndicator();

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('analysis-detail-refresh-loading'),
    liveRegion: true,
    label: 'Refreshing saved analysis',
    child: const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: LinearProgressIndicator(),
    ),
  );
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
    this.notFound = false,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final bool notFound;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              notFound ? Icons.search_off : Icons.error_outline,
              size: 44,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              key: ValueKey(
                notFound
                    ? 'analysis-detail-not-found'
                    : 'analysis-detail-error',
              ),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              key: const ValueKey('analysis-detail-error-message'),
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('analysis-detail-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailIdleState extends StatelessWidget {
  const _DetailIdleState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text(
      'Select an analysis from History to view its details.',
      key: ValueKey('analysis-detail-idle'),
      textAlign: TextAlign.center,
    ),
  );
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match score',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Match score: $score out of 100',
              child: Text(
                '$score / 100',
                key: const ValueKey('analysis-detail-score'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: score / 100,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextListCard extends StatelessWidget {
  const _TextListCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < items.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == items.length - 1 ? 0 : 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        items[index],
                        key: ValueKey('$title-item-$index'),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
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

import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../models/criterion_assessment.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({required this.onAnalyze, this.result, super.key});

  final VoidCallback onAnalyze;
  final AnalysisResult? result;

  @override
  Widget build(BuildContext context) {
    final analysis = result;
    if (analysis == null) {
      return _EmptyResultsState(onAnalyze: onAnalyze);
    }

    return _AnalysisResults(analysis: analysis);
  }
}

class _EmptyResultsState extends StatelessWidget {
  const _EmptyResultsState({required this.onAnalyze});

  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assessment_outlined,
                size: 52,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'No analysis yet',
                key: const ValueKey('results-empty-title'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'After you analyze a resume, its match score, skills, gaps, '
                'and interview questions will appear here.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAnalyze,
                icon: const Icon(Icons.edit_note),
                label: const Text('Go to Analyze'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisResults extends StatelessWidget {
  const _AnalysisResults({required this.analysis});

  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layoutWidth = MediaQuery.sizeOf(context).width;
    final isWide = layoutWidth >= 900;

    return SingleChildScrollView(
      key: const ValueKey('results-content-scroll'),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                analysis.candidateName?.trim().isNotEmpty == true
                    ? analysis.candidateName!
                    : 'Candidate',
                key: const ValueKey('results-candidate-name'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Analyzed ${_formatLocalDateTime(analysis.createdAt)}',
                key: const ValueKey('results-created-at'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _ScoreSummary(score: analysis.matchScore),
              const SizedBox(height: 28),
              Text(
                'Assessment breakdown',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _AssessmentGrid(
                isWide: isWide,
                assessments: [
                  _AssessmentData(
                    title: 'Required Skills',
                    assessment: analysis.requiredSkills,
                  ),
                  _AssessmentData(
                    title: 'Relevant Experience',
                    assessment: analysis.relevantExperience,
                  ),
                  _AssessmentData(
                    title: 'Seniority and Scope',
                    assessment: analysis.seniorityAndScope,
                  ),
                  _AssessmentData(
                    title: 'Nice-to-have Skills and Domain Relevance',
                    assessment:
                        analysis.niceToHaveSkillsAndDomainRelevance,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _TextListCard(
                title: 'Matching skills',
                icon: Icons.check_circle_outline,
                items: analysis.matchingSkills,
              ),
              const SizedBox(height: 16),
              _TextListCard(
                title: 'Skill gaps',
                icon: Icons.flag_outlined,
                items: analysis.skillGaps,
              ),
              const SizedBox(height: 16),
              _TextListCard(
                title: 'Suggested interview questions',
                icon: Icons.question_answer_outlined,
                items: analysis.interviewQuestions,
                numbered: true,
              ),
              const SizedBox(height: 16),
              _AdvisoryNotice(notice: analysis.advisoryNotice),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall match score',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$score / 100',
              key: const ValueKey('results-match-score'),
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              semanticsLabel: 'Overall match score: $score out of 100',
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Match score progress',
              value: '$score percent',
              child: ExcludeSemantics(
                child: LinearProgressIndicator(
                  key: const ValueKey('results-score-progress'),
                  value: score / 100,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This score is an advisory assessment, not an automatic '
              'hiring decision.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentGrid extends StatelessWidget {
  const _AssessmentGrid({required this.assessments, required this.isWide});

  final List<_AssessmentData> assessments;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isWide ? 2 : 1;
        const spacing = 12.0;
        final cardWidth = (constraints.maxWidth - spacing * (columns - 1)) /
            columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in assessments)
              SizedBox(
                width: cardWidth,
                child: _AssessmentCard(
                  title: item.title,
                  assessment: item.assessment,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AssessmentData {
  const _AssessmentData({required this.title, required this.assessment});

  final String title;
  final CriterionAssessment assessment;
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.title, required this.assessment});

  final String title;
  final CriterionAssessment assessment;

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
              title,
              key: ValueKey('assessment-title-$title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${assessment.rating} / 100',
              key: ValueKey('assessment-rating-$title'),
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              semanticsLabel: '$title rating: ${assessment.rating} out of 100',
            ),
            const SizedBox(height: 8),
            Text(
              assessment.rationale,
              key: ValueKey('assessment-rationale-$title'),
              style: theme.textTheme.bodyMedium,
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
    this.numbered = false,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final bool numbered;

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
                const SizedBox(width: 10),
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
                  top: index == 0 ? 0 : 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: numbered ? 28 : 20,
                      child: Text(
                        numbered ? '${index + 1}.' : '•',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        items[index],
                        style: theme.textTheme.bodyMedium,
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

class _AdvisoryNotice extends StatelessWidget {
  const _AdvisoryNotice({required this.notice});

  final String notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Important advisory',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notice,
              key: const ValueKey('results-advisory-notice'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
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
  final month = _monthName(local.month);
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$month ${local.day}, ${local.year} at $hour:$minute $period';
}

String _monthName(int month) => const [
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
][month - 1];

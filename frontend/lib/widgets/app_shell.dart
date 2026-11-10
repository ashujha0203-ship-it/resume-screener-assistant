import 'dart:async';

import 'package:flutter/material.dart';

import '../app/resume_screener_controller.dart';
import '../screens/analyze_screen.dart';
import '../screens/analysis_detail_screen.dart';
import '../screens/history_screen.dart';
import '../screens/results_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});

  final ResumeScreenerController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _navigationRailBreakpoint = 760;
  int _selectedIndex = 0;
  bool _initialHistoryLoadStarted = false;
  bool _showingHistoryDetail = false;

  static const List<_AppDestination> _destinations = [
    _AppDestination(
      label: 'Analyze',
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note,
    ),
    _AppDestination(
      label: 'Results',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment,
    ),
    _AppDestination(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
    ),
  ];

  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _showingHistoryDetail = false;
    });
    if (index != 2 || _initialHistoryLoadStarted) {
      return;
    }

    _initialHistoryLoadStarted = true;
    if (widget.controller.analysisPage == null &&
        widget.controller.historyState.status == OperationStatus.idle) {
      unawaited(widget.controller.loadHistory());
    }
  }

  void _searchHistory(HistoryFilter filter) {
    final query = AnalysisHistoryQuery(
      candidateName: filter.candidateName,
      minScore: filter.minScore,
      maxScore: filter.maxScore,
      page: 0,
      size: widget.controller.historyQuery.size,
    );
    widget.controller.updateHistoryQuery(query);
    unawaited(widget.controller.loadHistory(query: query));
  }

  void _changeHistoryPage(int page) {
    final query = widget.controller.historyQuery.withPage(page);
    unawaited(widget.controller.loadHistory(query: query));
  }

  void _selectHistoryItem(String id) {
    setState(() {
      _showingHistoryDetail = true;
    });
    unawaited(widget.controller.loadHistoryDetail(id));
  }

  void _returnToHistory() {
    setState(() {
      _showingHistoryDetail = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final useNavigationRail =
        MediaQuery.sizeOf(context).width >= _navigationRailBreakpoint;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Resume Screener Assistant',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        body: SafeArea(
          top: false,
          child: useNavigationRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectDestination,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final destination in _destinations)
                          NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: _sectionStack()),
                  ],
                )
              : _sectionStack(),
        ),
        bottomNavigationBar: useNavigationRail
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _selectDestination,
                destinations: [
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _sectionStack() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        AnalyzeScreen(
          controller: widget.controller,
          onAnalysisSubmitted: () => _selectDestination(1),
        ),
        ResultsScreen(
          result: widget.controller.analysisResult,
          onAnalyze: () => _selectDestination(0),
        ),
        IndexedStack(
          index: _showingHistoryDetail ? 1 : 0,
          children: [
            HistoryScreen(
              initialPage: widget.controller.analysisPage,
              isLoading: widget.controller.historyState.isLoading,
              errorMessage: widget.controller.historyState.errorMessage,
              onSearch: _searchHistory,
              onPageChanged: _changeHistoryPage,
              onRetry: () => unawaited(widget.controller.retryHistory()),
              onItemSelected: _selectHistoryItem,
            ),
            AnalysisDetailScreen(
              item: widget.controller.selectedHistoryItem,
              isLoading: widget.controller.historyDetailState.isLoading,
              errorMessage: widget.controller.historyDetailState.errorMessage,
              isNotFound: widget.controller.historyDetailNotFound,
              onRetry: () => unawaited(widget.controller.retryHistoryDetail()),
              onBack: _returnToHistory,
            ),
          ],
        ),
      ],
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

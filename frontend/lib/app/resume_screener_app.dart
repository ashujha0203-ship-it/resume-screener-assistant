import 'package:flutter/material.dart';

import 'resume_screener_controller.dart';
import '../widgets/app_shell.dart';
import 'app_theme.dart';

class ResumeScreenerApp extends StatefulWidget {
  const ResumeScreenerApp({this.controller, super.key});

  /// An injected controller is owned and disposed by this app widget.
  final ResumeScreenerController? controller;

  @override
  State<ResumeScreenerApp> createState() => _ResumeScreenerAppState();
}

class _ResumeScreenerAppState extends State<ResumeScreenerApp> {
  late final ResumeScreenerController _controller =
      widget.controller ?? ResumeScreenerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resume Screener Assistant',
      theme: AppTheme.light,
      home: AppShell(controller: _controller),
    );
  }
}

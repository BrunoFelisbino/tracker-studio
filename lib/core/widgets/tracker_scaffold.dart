import 'package:flutter/material.dart';

import '../design/tracker_colors.dart';
import '../design/tracker_spacing.dart';
import 'tracker_scaffold_header.dart';

enum TrackerScaffoldStyle { flat, headerGradient }

class TrackerScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> headerActions;
  final Widget body;
  final Widget? bottomNavigationBar;
  final TrackerScaffoldStyle style;

  const TrackerScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.headerActions = const [],
    required this.body,
    this.bottomNavigationBar,
    this.style = TrackerScaffoldStyle.headerGradient,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: TrackerColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              TrackerScaffoldHeader(
                title: title,
                subtitle: subtitle,
                actions: headerActions,
                style: style == TrackerScaffoldStyle.headerGradient
                    ? TrackerScaffoldHeaderStyle.gradient
                    : TrackerScaffoldHeaderStyle.flat,
              ),
              Expanded(
                child: body,
              ),
            ],
          ),
        ),
        bottomNavigationBar: bottomNavigationBar,
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/widgets/tracker_section_header.dart';

class DeviceDiagnosticsScreen extends ConsumerWidget {
  final String deviceId;

  const DeviceDiagnosticsScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnósticos'),
        backgroundColor: TrackerColors.surface,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackerSectionHeader(title: 'Diagnósticos do Dispositivo'),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'ID: $deviceId',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TrackerColors.primary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Realize diagnósticos e análise do dispositivo aqui',
                      style: TextStyle(
                        fontSize: 14,
                        color: TrackerColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

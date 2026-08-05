import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/widgets/tracker_section_header.dart';

class DeviceSummaryScreen extends ConsumerWidget {
  final String deviceId;

  const DeviceSummaryScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo'),
        backgroundColor: TrackerColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TrackerSectionHeader(title: 'Resumo do Dispositivo'),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'ID: $deviceId',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TrackerColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Resumo completo do dispositivo será exibido aqui',
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

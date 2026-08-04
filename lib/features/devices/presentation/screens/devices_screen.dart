import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/widgets/tracker_card.dart';
import '../../../../core/widgets/tracker_section_header.dart';
import '../../../../core/widgets/tracker_empty_state.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos'),
        backgroundColor: TrackerColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TrackerSectionHeader(title: 'Portas Serial'),
            const SizedBox(height: 12),
            const Text('Nenhuma porta detectada',
                style: TextStyle(color: TrackerColors.textSecondary)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    items: [],
                    onChanged: (v) {},
                    decoration: InputDecoration(
                      labelText: 'Porta',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Atualizar portas'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Conectar'),
            ),
          ],
        ),
      ),
    );
  }
}
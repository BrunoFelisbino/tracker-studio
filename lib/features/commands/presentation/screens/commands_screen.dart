import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/widgets/tracker_card.dart';
import '../../../../core/widgets/tracker_empty_state.dart';
import '../../../../core/widgets/tracker_scaffold.dart';
import '../../../sessions/presentation/tracker_studio/suntech_legacy_commands.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

class CommandsScreen extends ConsumerStatefulWidget {
  const CommandsScreen({super.key});

  @override
  ConsumerState<CommandsScreen> createState() => _CommandsScreenState();
}

class _CommandsScreenState extends ConsumerState<CommandsScreen> {
  String _search = '';
  String _riskFilter = 'Todos';
  List<Map<String, dynamic>> _commands = [];

  @override
  void initState() {
    super.initState();
    _loadCommands();
  }

  Future<void> _loadCommands() async {
    try {
      final json = await _readCatalog();
      final data = jsonDecode(json) as Map<String, dynamic>;
      final items = data['commands'] as List<dynamic>? ?? const [];
      if (!mounted) return;
      setState(() {
        _commands = items.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commands = const [];
      });
    }
  }

  Future<String> _readCatalog() async {
    try {
      return await rootBundle.loadString('assets/catalogs/suntech_commands.json');
    } catch (e) {
      debugPrint('CommandsScreen: catalog load fallback failed: $e');
      final file = File('assets/catalogs/suntech_commands.json');
      if (await file.exists()) {
        return file.readAsString();
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _commands.where((cmd) {
      final matchSearch = _search.isEmpty ||
          (cmd['code']?.toString().toLowerCase().contains(_search.toLowerCase()) ??
              false) ||
          (cmd['name']?.toString().toLowerCase().contains(_search.toLowerCase()) ??
              false);
      final matchRisk = _riskFilter == 'Todos' ||
          cmd['risk']?.toString() == _riskFilter;
      return matchSearch && matchRisk;
    }).toList();
  }

  Color _riskColor(String? risk) {
    switch (risk) {
      case 'low':
        return Colors.green;
      case 'destructive':
      case 'high':
        return Colors.red;
      case 'warning':
      case 'medium':
        return Colors.amber;
      default:
        return TrackerColors.textSecondary;
    }
  }

  IconData _categoryIcon(String? category) {
    switch (category) {
      case 'read':
        return Icons.visibility;
      case 'config':
        return Icons.settings;
      case 'action':
        return Icons.bolt;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(trackerSessionControllerProvider);
    final liveCatalog = session.handshakeResult?.commandCatalog.values.toList() ?? const <SuntechCommandDefinition>[];
    return TrackerScaffold(
      title: 'Comandos',
      subtitle: 'Catálogo técnico e comandos do equipamento conectado',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TrackerSpacing.lg,
              TrackerSpacing.sm,
              TrackerSpacing.lg,
              TrackerSpacing.sm,
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar comandos...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TrackerSpacing.sm),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: TrackerSpacing.md,
                  vertical: TrackerSpacing.sm,
                ),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: TrackerSpacing.lg),
              children: [
                 _buildChip('Risco', _riskFilter, ['Todos', 'read', 'destructive', 'warning']),
               ],
             ),
           ),
           const SizedBox(height: TrackerSpacing.sm),
           if (liveCatalog.isNotEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: TrackerSpacing.lg),
               child: TrackerCard(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('Equipamento conectado', style: TextStyle(fontWeight: FontWeight.bold)),
                     const SizedBox(height: 8),
                     Text('${liveCatalog.length} comando(s) carregado(s) do handshake real.'),
                   ],
                 ),
               ),
             ),
           if (liveCatalog.isNotEmpty) const SizedBox(height: TrackerSpacing.sm),
           _filtered.isEmpty
               ? const TrackerEmptyState(
                   icon: Icons.search_off,
                   title: 'Nenhum comando encontrado',
                   message: 'Sem template válido no catálogo carregado.',
                 )
               : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: TrackerSpacing.lg,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final cmd = _filtered[index];
                      final isClickable = cmd['risk'] != 'destructive' && cmd['critical'] != true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: TrackerSpacing.sm),
                        child: TrackerCard(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(TrackerSpacing.sm),
                            onTap: isClickable ? () => _executeCommand(context, ref, cmd) : null,
                            child: Row(
                              children: [
                                Icon(
                                  _categoryIcon(cmd['category']),
                                  color: isClickable
                                      ? TrackerColors.communicationBlue
                                      : TrackerColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: TrackerSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       Text(
                                         cmd['rawCommand'] ?? '',
                                         style: TextStyle(
                                           fontWeight: FontWeight.bold,
                                           fontFamily: 'monospace',
                                           color: isClickable
                                               ? TrackerColors.textPrimary
                                               : TrackerColors.textSecondary,
                                         ),
                                       ),
                                       const SizedBox(height: 2),
                                       Text(
                                         '${cmd['name'] ?? ''} · ${cmd['family'] ?? '-'}',
                                         style: const TextStyle(
                                           color: TrackerColors.textSecondary,
                                           fontSize: 13,
                                         ),
                                       ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _riskColor(cmd['risk']).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (cmd['risk'] ?? '').toString().toUpperCase(),
                                    style: TextStyle(
                                      color: _riskColor(cmd['risk']),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: TrackerSpacing.sm),
                                if (isClickable)
                                  Icon(
                                    Icons.play_circle_outline,
                                    size: 20,
                                    color: TrackerColors.communicationBlue,
                                  )
                                else
                                  Icon(
                                     ((cmd['channels'] as List<dynamic>?) ?? const []).contains('usb')
                                         ? Icons.usb
                                         : Icons.cable,
                                     size: 16,
                                     color: TrackerColors.textSecondary,
                                   ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
         if (liveCatalog.isNotEmpty)
           Padding(
             padding: const EdgeInsets.all(TrackerSpacing.lg),
             child: Wrap(
               spacing: TrackerSpacing.sm,
               runSpacing: TrackerSpacing.sm,
               children: liveCatalog.take(6).map((definition) {
                 return FilledButton.tonal(
                   onPressed: ref
                           .read(trackerSessionControllerProvider.notifier)
                           .canSendCatalogCommand(definition)
                       ? () => ref
                           .read(trackerSessionControllerProvider.notifier)
                           .sendCatalogCommand(definition)
                       : null,
                   child: Text(definition.label),
                 );
               }).toList(),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String selected, List<String> options) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() {
          if (label == 'Risco') _riskFilter = value;
        });
      },
      itemBuilder: (context) => options
          .map((opt) => PopupMenuItem(
                value: opt,
                child: Text(opt),
              ))
          .toList(),
      child: Chip(
        label: Text(
          '$label: $selected',
          style: const TextStyle(fontSize: 12),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _executeCommand(BuildContext context, WidgetRef ref, Map<String, dynamic> cmd) async {
    final session = ref.read(trackerSessionControllerProvider);
    if (!session.connection.usbConnected) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conecte um dispositivo USB primeiro')),
      );
      return;
    }

    final rawCommand = cmd['rawCommand'] as String? ?? '';
    final esn = session.device.esn;
    final command = rawCommand.replaceAll('<ESN>', esn);

    try {
      await ref.read(trackerSessionControllerProvider.notifier).sendManualCommand(command);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comando enviado: ${cmd['name']}'),
          backgroundColor: TrackerColors.technicalGreen,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar comando: $e'),
          backgroundColor: TrackerColors.failureRed,
        ),
      );
    }
  }
}

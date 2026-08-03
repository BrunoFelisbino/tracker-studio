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
import '../../../../core/widgets/tracker_section_header.dart';
import '../../../sessions/presentation/tracker_studio/suntech_command_family.dart';
import '../../../sessions/presentation/tracker_studio/tracker_studio_controller.dart';

class SmsScreen extends ConsumerStatefulWidget {
  const SmsScreen({super.key});

  @override
  ConsumerState<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends ConsumerState<SmsScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _previewController = TextEditingController();
  List<Map<String, dynamic>> _commands = const [];
  String _search = '';
  String? _selectedCommandId;

  @override
  void initState() {
    super.initState();
    _loadCommands();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  Future<void> _loadCommands() async {
    try {
      final json = await _readCatalog();
      final data = jsonDecode(json) as Map<String, dynamic>;
      final items = (data['commands'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .where((item) => ((item['channels'] as List<dynamic>?) ?? const [])
              .contains('sms'))
          .toList();
      if (!mounted) return;
      setState(() {
        _commands = items;
      });
    } catch (e) {
      debugPrint('SmsScreen: failed to load commands: $e');
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
      debugPrint('SmsScreen: catalog load fallback failed: $e');
      final file = File('assets/catalogs/suntech_commands.json');
      if (await file.exists()) {
        return file.readAsString();
      }
      rethrow;
    }
  }

  String _familyKey(SuntechCommandFamily family) {
    switch (family) {
      case SuntechCommandFamily.legacySt300St310:
        return 'legacy_st300';
      case SuntechCommandFamily.newGenSt8210St8310:
        return 'newgen_st8210';
      case SuntechCommandFamily.manual:
      case SuntechCommandFamily.unknown:
        return 'all';
    }
  }

  List<Map<String, dynamic>> _filteredCommands(String familyKey) {
    return _commands.where((cmd) {
      final familyMatches = familyKey == 'all' || cmd['family'] == familyKey;
      final text = '${cmd['name'] ?? ''} ${cmd['rawCommand'] ?? ''}'
          .toLowerCase();
      final searchMatches = _search.isEmpty || text.contains(_search.toLowerCase());
      return familyMatches && searchMatches;
    }).toList();
  }

  String _toSmsCommand({
    required String raw,
    required String esn,
  }) {
    return raw
        .replaceAll('AT^', '')
        .replaceAll('<ESN>', esn)
        .trim();
  }

  void _selectCommand(Map<String, dynamic> command, String esn) {
    final preview = _toSmsCommand(
      raw: command['rawCommand']?.toString() ?? '',
      esn: esn,
    );
    setState(() {
      _selectedCommandId = command['id']?.toString();
      _previewController.text = preview;
    });
  }

  Future<void> _copyPreview() async {
    final preview = _previewController.text.trim();
    if (preview.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: preview));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comando SMS copiado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(trackerSessionControllerProvider);
    final familyKey = _familyKey(session.selectedSuntechFamily);
    final filtered = _filteredCommands(familyKey);
    final esn = session.hasDeviceRead ? session.device.esn : 'XXXX';
    final selected = filtered.where((cmd) => cmd['id'] == _selectedCommandId).firstOrNull;

    return TrackerScaffold(
      title: 'SMS',
      subtitle: 'Gerador rápido de comandos SMS por dispositivo',
      body: ListView(
        padding: const EdgeInsets.all(TrackerSpacing.lg),
        children: [
          TrackerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destino e família detectada',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: TrackerSpacing.sm),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone / gateway SMS',
                    hintText: '+55 11 99999-9999',
                  ),
                ),
                const SizedBox(height: TrackerSpacing.sm),
                Wrap(
                  spacing: TrackerSpacing.sm,
                  runSpacing: TrackerSpacing.sm,
                  children: [
                    Chip(label: Text('Família: ${session.selectedSuntechFamily.name}')),
                    Chip(label: Text('Modelo: ${session.device.model}')),
                    Chip(label: Text('ESN: $esn')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: TrackerSpacing.lg),
          const TrackerSectionHeader(
            title: 'Comandos SMS',
            icon: Icons.sms_outlined,
            eyebrow: 'Escolha, gere e copie',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar comando SMS...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: TrackerSpacing.sm),
          if (filtered.isEmpty)
            const TrackerEmptyState(
              icon: Icons.sms_failed_outlined,
              title: 'Nenhum comando SMS disponível',
              message: 'Conecte e identifique um dispositivo ou ajuste a busca.',
            )
          else
            ...filtered.map((cmd) {
              final selectedItem = _selectedCommandId == cmd['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: TrackerSpacing.sm),
                child: TrackerCard(
                  child: InkWell(
                    onTap: () => _selectCommand(cmd, esn),
                    borderRadius: BorderRadius.circular(TrackerSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          selectedItem ? Icons.radio_button_checked : Icons.sms,
                          color: selectedItem
                              ? TrackerColors.communicationBlue
                              : TrackerColors.textSecondary,
                        ),
                        const SizedBox(width: TrackerSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cmd['name']?.toString() ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _toSmsCommand(
                                  raw: cmd['rawCommand']?.toString() ?? '',
                                  esn: esn,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: TrackerColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: TrackerSpacing.lg),
          const TrackerSectionHeader(
            title: 'Preview SMS',
            icon: Icons.preview_outlined,
            eyebrow: 'Texto pronto para copiar e enviar',
          ),
          const SizedBox(height: TrackerSpacing.sm),
          TrackerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((_phoneController.text.trim()).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TrackerSpacing.sm),
                    child: Text(
                      'Destino sugerido: ${_phoneController.text.trim()}',
                      style: const TextStyle(color: TrackerColors.textSecondary),
                    ),
                  ),
                TextField(
                  controller: _previewController,
                  minLines: 3,
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    hintText: 'Selecione um comando SMS para gerar o preview',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selected != null) ...[
                  const SizedBox(height: TrackerSpacing.sm),
                  Text(
                    selected['notes']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12, color: TrackerColors.textSecondary),
                  ),
                ],
                const SizedBox(height: TrackerSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _previewController.text.trim().isEmpty
                            ? null
                            : _copyPreview,
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copiar SMS'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

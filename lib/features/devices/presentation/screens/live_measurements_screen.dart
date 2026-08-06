import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/tracker_colors.dart';
import '../../../../core/sessions/device_session.dart';
import '../../../../core/sessions/device_session_provider.dart';
import '../../../../core/sessions/session_persistence.dart';
import '../providers/can_provider.dart';

class LiveMeasurementsScreen extends ConsumerStatefulWidget {
  final String deviceId;

  const LiveMeasurementsScreen({super.key, required this.deviceId});

  @override
  ConsumerState<LiveMeasurementsScreen> createState() =>
      _LiveMeasurementsScreenState();
}

class _LiveMeasurementsScreenState extends ConsumerState<LiveMeasurementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isPaused = false;
  String _searchQuery = '';
  final String _selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(deviceSessionProvider(widget.deviceId));
    final canStatus = ref.watch(canStatusProvider(widget.deviceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medições ao Vivo (Real-time)'),
        backgroundColor: TrackerColors.surface,
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _isPaused ? 'Retomar Atualizações' : 'Pausar Visualização',
            onPressed: () => setState(() => _isPaused = !_isPaused),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reprocessar Sessão',
            onPressed: () async {
              final persistence = ref.read(sessionPersistenceServiceProvider);
              await persistence.reprocessSession(widget.deviceId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Sessão reprocessada com sucesso!')),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Widgets'),
            Tab(icon: Icon(Icons.list), text: 'Lista'),
            Tab(icon: Icon(Icons.history), text: 'Histórico'),
            Tab(icon: Icon(Icons.code), text: 'Somente CAN'),
            Tab(icon: Icon(Icons.help_outline), text: 'IOs Desconhecidos'),
            Tab(
                icon: Icon(Icons.check_circle_outline),
                text: 'Medições Feitas'),
          ],
        ),
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) =>
            Center(child: Text('Erro ao carregar sessão: $err')),
        data: (session) {
          if (_isPaused) {
            // Persistência continua funcionando no background via provider, mas ignoramos re-render se pausado ou mantemos dados correntes
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _WidgetsTab(session: session, canStatus: canStatus),
              _ListTab(
                  session: session,
                  searchQuery: _searchQuery,
                  category: _selectedCategory,
                  onSearchChanged: (q) => setState(() => _searchQuery = q)),
              _HistoryTab(session: session),
              _OnlyCanTab(session: session, canStatus: canStatus),
              _UnknownIoTab(session: session),
              _MeasurementsDoneTab(session: session),
            ],
          );
        },
      ),
    );
  }
}

class _WidgetsTab extends StatelessWidget {
  final DeviceSession session;
  final CanRuntimeStatus canStatus;

  const _WidgetsTab({required this.session, required this.canStatus});

  @override
  Widget build(BuildContext context) {
    final measurements = session.measurements;
    if (measurements.isEmpty) {
      return const Center(
        child: Text('Aguardando medições do dispositivo...',
            style: TextStyle(color: TrackerColors.textSecondary)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: measurements.length,
      itemBuilder: (context, index) {
        final m = measurements[index];
        final isStale = DateTime.now().difference(m.timestamp).inSeconds > 60;

        return Card(
          elevation: 2,
          color: isStale
              ? TrackerColors.surface.withValues(alpha: 0.5)
              : TrackerColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        m.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isStale)
                      const Tooltip(
                        message: 'Valor Stale (> 60s sem atualização)',
                        child: Icon(Icons.warning_amber,
                            size: 16, color: TrackerColors.attentionAmber),
                      ),
                  ],
                ),
                Text(
                  '${m.value ?? 'null'}${m.unit != null ? ' ${m.unit}' : ''}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: m.value != null
                        ? TrackerColors.communicationBlue
                        : TrackerColors.textSecondary,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Raw: ${m.rawKey}',
                        style: const TextStyle(
                            fontSize: 10, color: TrackerColors.textSecondary)),
                    Text(
                      '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}:${m.timestamp.second.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 10, color: TrackerColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ListTab extends StatelessWidget {
  final DeviceSession session;
  final String searchQuery;
  final String category;
  final ValueChanged<String> onSearchChanged;

  const _ListTab(
      {required this.session,
      required this.searchQuery,
      required this.category,
      required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    final filtered = session.measurements.where((m) {
      if (searchQuery.isNotEmpty &&
          !m.name.toLowerCase().contains(searchQuery.toLowerCase()) &&
          !m.key.toLowerCase().contains(searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Filtrar medições...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final m = filtered[index];
              return ListTile(
                leading: const Icon(Icons.sensors,
                    color: TrackerColors.communicationBlue),
                title: Text(m.name),
                subtitle: Text('Chave: ${m.key} | Categoria: ${m.category}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${m.value}${m.unit != null ? ' ${m.unit}' : ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(m.timestamp.toIso8601String().substring(11, 19),
                        style: const TextStyle(
                            fontSize: 10, color: TrackerColors.textSecondary)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final DeviceSession session;

  const _HistoryTab({required this.session});

  @override
  Widget build(BuildContext context) {
    final rawEntries = session.rawData.entries.toList().reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rawEntries.length,
      itemBuilder: (context, index) {
        final entry = rawEntries[index];
        final val = entry.value;
        return Card(
          child: ListTile(
            title: Text(entry.key,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                val is Map ? (val['ascii'] ?? val.toString()) : val.toString()),
            trailing: Text(
                val is Map && val['timestamp'] != null
                    ? val['timestamp'].toString().substring(11, 19)
                    : '',
                style: const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}

class _OnlyCanTab extends StatelessWidget {
  final DeviceSession session;
  final CanRuntimeStatus canStatus;

  const _OnlyCanTab({required this.session, required this.canStatus});

  @override
  Widget build(BuildContext context) {
    if (!canStatus.supportsCan) {
      return const Center(
          child: Text('Módulo CAN não suportado por este dispositivo.',
              style: TextStyle(color: TrackerColors.textSecondary)));
    }

    final canMeasurements = session.measurements
        .where((m) =>
            m.category.toLowerCase().contains('can') ||
            m.key.toLowerCase().contains('can') ||
            m.key.toLowerCase().contains('rpm') ||
            m.key.toLowerCase().contains('speed'))
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: canStatus.statusColor.withValues(alpha: 0.1),
          child: Row(
            children: [
              Icon(Icons.circle, color: canStatus.statusColor, size: 16),
              const SizedBox(width: 8),
              Text(canStatus.statusDescription,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: canMeasurements.length,
            itemBuilder: (context, index) {
              final m = canMeasurements[index];
              return ListTile(
                leading: const Icon(Icons.directions_car,
                    color: TrackerColors.technicalGreen),
                title: Text(m.name),
                trailing: Text('${m.value} ${m.unit ?? ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UnknownIoTab extends StatelessWidget {
  final DeviceSession session;

  const _UnknownIoTab({required this.session});

  @override
  Widget build(BuildContext context) {
    final unknown = session.measurements
        .where((m) => m.key.startsWith('io_') || m.category == 'io')
        .toList();

    return ListView.builder(
      itemCount: unknown.length,
      itemBuilder: (context, index) {
        final m = unknown[index];
        final rawVal = m.value;
        final dec = rawVal is num ? rawVal : 0;
        final hex =
            dec is int ? '0x${dec.toRadixString(16).toUpperCase()}' : null;
        final bin = dec is int ? dec.toRadixString(2) : null;

        return ExpansionTile(
          title: Text(m.name.isNotEmpty ? m.name : 'IO ${m.rawKey}'),
          subtitle: Text('Valor bruto: $rawVal | Decimal: $dec'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hexadecimal: $hex'),
                  Text('Binário: $bin'),
                  Text(
                      'Quantidade de mudanças: ${m.metadata?['changeCount'] ?? 1}'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MeasurementsDoneTab extends StatelessWidget {
  final DeviceSession session;

  const _MeasurementsDoneTab({required this.session});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Resumo de Medições Concluídas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text('Total de medições registradas: ${session.measurements.length}'),
        Text('Total de chunks brutos salvos: ${session.rawData.length}'),
        Text('Respostas de comandos: ${session.responses.length}'),
        Text(
            'Snapshots de configuração: ${session.configurationSnapshots.length}'),
      ],
    );
  }
}

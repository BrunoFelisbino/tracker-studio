import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tracker_studio/core/design/tracker_theme.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_session_state.dart';

void showIdentityModal(BuildContext context, TrackerSessionState session) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: TrackerColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: TrackerRadius.large),
      title: const Text('Identidade do Equipamento',
          style: TrackerTextStyles.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Fabricante', session.device.manufacturer),
          _buildDetailRow('Modelo', session.device.model),
          _buildDetailRow('ESN', session.device.esn),
          _buildDetailRow('Firmware', session.device.firmware),
          _buildDetailRow('IMEI',
              session.device.imei.isNotEmpty ? session.device.imei : '-'),
          _buildDetailRow('SIM (ICCID)',
              session.device.sim.isNotEmpty ? session.device.sim : '-'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar',
              style: TextStyle(color: TrackerColors.primary)),
        ),
      ],
    ),
  );
}

void showPowerModal(BuildContext context, TrackerSessionState session) {
  showDialog(
    context: context,
    builder: (context) {
      final hasData = session.voltageHistory.isNotEmpty;
      final mainVoltNum = session.voltageHistory.isEmpty
          ? null
          : session.voltageHistory.last.value;
      final backupVoltNum = session.backupVoltageHistory.isEmpty
          ? null
          : session.backupVoltageHistory.last.value;
      final currentMain =
          mainVoltNum != null ? '${mainVoltNum.toStringAsFixed(1)} V' : '-';
      final currentBackup =
          backupVoltNum != null ? '${backupVoltNum.toStringAsFixed(1)} V' : '-';

      return AlertDialog(
        backgroundColor: TrackerColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: TrackerRadius.large),
        title: Row(
          children: [
            const Text('Histórico de Alimentação',
                style: TrackerTextStyles.cardTitle),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TrackerColors.communicationBlue.withValues(alpha: 0.1),
                borderRadius: TrackerRadius.pill,
              ),
              child: const Text(
                'Leituras: 5s',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: TrackerColors.communicationBlue,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── CARD DE VALORES EM FUNDO BRANCO COM LETRA PRETA ──────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(TrackerSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: TrackerRadius.medium,
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'ALIMENTAÇÃO PRINCIPAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF666666),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentMain,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Container(
                        height: 36, width: 1, color: const Color(0xFFE0E0E0)),
                    Column(
                      children: [
                        const Text(
                          'BATERIA DE BACKUP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF666666),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentBackup,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: TrackerSpacing.md),

              // ── GRÁFICO DE LINHAS ─────────────────────────────────────
              SizedBox(
                height: 200,
                child: hasData
                    ? LineChart(
                        LineChartData(
                          minY: 0,
                          lineBarsData: [
                            LineChartBarData(
                              spots: session.voltageHistory
                                  .asMap()
                                  .entries
                                  .map((e) {
                                return FlSpot(e.key.toDouble(), e.value.value);
                              }).toList(),
                              isCurved: true,
                              color: TrackerColors.communicationBlue,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: TrackerColors.communicationBlue
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            handleBuiltInTouches: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (spot) => Colors.white,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    '${spot.y.toStringAsFixed(1)} V',
                                    const TextStyle(
                                      color: TrackerColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text('${value.toStringAsFixed(1)} V',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: TrackerColors.textMuted));
                                },
                              ),
                            ),
                            bottomTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(
                              show: true, drawVerticalLine: false),
                          borderData: FlBorderData(show: false),
                        ),
                      )
                    : const Center(
                        child: Text('Aguardando dados...',
                            style: TrackerTextStyles.body)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar',
                style: TextStyle(color: TrackerColors.primary)),
          ),
        ],
      );
    },
  );
}

void showIgnitionModal(BuildContext context, TrackerSessionState session) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: TrackerColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: TrackerRadius.large),
      title: const Text('Histórico de Ignição',
          style: TrackerTextStyles.cardTitle),
      content: SizedBox(
        width: 400,
        height: 300,
        child: session.ignitionHistory.isEmpty
            ? const Center(
                child: Text('Sem mudanças de estado nesta sessão.',
                    style: TrackerTextStyles.body))
            : ListView.builder(
                itemCount: session.ignitionHistory.length,
                itemBuilder: (context, index) {
                  final evt = session.ignitionHistory[index];
                  final timeStr =
                      '${evt.timestamp.hour.toString().padLeft(2, '0')}:${evt.timestamp.minute.toString().padLeft(2, '0')}:${evt.timestamp.second.toString().padLeft(2, '0')}';
                  return ListTile(
                    leading: Icon(
                      evt.event == 'Ligada'
                          ? Icons.key_rounded
                          : Icons.key_off_rounded,
                      color: evt.event == 'Ligada'
                          ? TrackerColors.technicalGreen
                          : TrackerColors.textMuted,
                    ),
                    title: Text(evt.event, style: TrackerTextStyles.body),
                    subtitle: Text(timeStr,
                        style: TrackerTextStyles.body.copyWith(fontSize: 12)),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar',
              style: TextStyle(color: TrackerColors.primary)),
        ),
      ],
    ),
  );
}

void showOutputModal(BuildContext context, TrackerSessionState session,
    VoidCallback onEnable, VoidCallback onDisable) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: TrackerColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: TrackerRadius.large),
      title: const Text('Comandos de Saída 1 (Bloqueio)',
          style: TrackerTextStyles.cardTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    onEnable();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.lock_rounded, size: 18),
                  label: const Text('Ativar Bloqueio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TrackerColors.technicalGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    onDisable();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Desativar Bloqueio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TrackerColors.failureRed,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: TrackerSpacing.lg),
            const Text('Histórico:', style: TrackerTextStyles.label),
            const SizedBox(height: TrackerSpacing.sm),
            SizedBox(
              height: 150,
              child: session.commandHistory.isEmpty
                  ? const Center(
                      child: Text('Nenhum comando enviado.',
                          style: TrackerTextStyles.body))
                  : ListView.builder(
                      itemCount: session.commandHistory.length,
                      itemBuilder: (context, index) {
                        final evt = session.commandHistory[index];
                        final timeStr =
                            '${evt.timestamp.hour.toString().padLeft(2, '0')}:${evt.timestamp.minute.toString().padLeft(2, '0')}';
                        return ListTile(
                          dense: true,
                          title: Text(evt.event, style: TrackerTextStyles.body),
                          subtitle: Text(evt.detail,
                              style: TrackerTextStyles.body
                                  .copyWith(fontSize: 12)),
                          trailing: Text(timeStr,
                              style: TrackerTextStyles.body
                                  .copyWith(fontSize: 12)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar',
              style: TextStyle(color: TrackerColors.primary)),
        ),
      ],
    ),
  );
}

void showGprsModal(BuildContext context, TrackerSessionState session,
    Function(String) onUpdateApn) {
  final apnController = TextEditingController(
      text: session.configuration.desired['APN'] ??
          session.configuration.original['APN'] ??
          '');
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: TrackerColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: TrackerRadius.large),
      title: const Text('Rede GPRS e APN', style: TrackerTextStyles.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
              'Status', session.connection.gprsOnline ? 'Online' : 'Offline'),
          _buildDetailRow(
              'Código de Rede', session.connection.networkCode ?? '-'),
          _buildDetailRow('SIM (ICCID)',
              session.device.sim.isNotEmpty ? session.device.sim : '-'),
          if (session.connection.networkWarning != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                session.connection.networkWarning!,
                style: const TextStyle(
                    color: TrackerColors.attentionAmber, fontSize: 12),
              ),
            ),
          const SizedBox(height: TrackerSpacing.lg),
          const Text('APN Configurada', style: TrackerTextStyles.label),
          const SizedBox(height: TrackerSpacing.sm),
          TextField(
            controller: apnController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'ex: m2m.vivo.com.br',
              isDense: true,
            ),
            style: TrackerTextStyles.body,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar',
              style: TextStyle(color: TrackerColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () {
            onUpdateApn(apnController.text.trim());
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: TrackerColors.primary,
              foregroundColor: Colors.white),
          child: const Text('Atualizar APN'),
        ),
      ],
    ),
  );
}

void showGpsModal(BuildContext context, TrackerSessionState session) {
  // Try to find the raw GPS snapshot data if we had it in state,
  // but for now we'll just show what's in diagnostics.
  final gpsDiag = session.diagnostics.firstWhere((d) => d.title == 'GPS',
      orElse: () => const DiagnosticGroup('GPS', {}));

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: TrackerColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: TrackerRadius.large),
      title: const Text('GPS e Satélites', style: TrackerTextStyles.cardTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: gpsDiag.values.entries
            .map((e) => _buildDetailRow(e.key, e.value))
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar',
              style: TextStyle(color: TrackerColors.primary)),
        ),
      ],
    ),
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TrackerTextStyles.body
                .copyWith(color: TrackerColors.textMuted)),
        Text(value,
            style:
                TrackerTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

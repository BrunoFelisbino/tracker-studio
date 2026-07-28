import 'package:flutter/material.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_radius.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/design/tracker_text_styles.dart';
import '../../../../core/widgets/tracker_card.dart';
import 'tracker_session_state.dart';

class DiagnosticIssue {
  final String title;
  final String description;
  final String recommendation;
  final IconData icon;
  final Color severityColor;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DiagnosticIssue({
    required this.title,
    required this.description,
    required this.recommendation,
    required this.icon,
    required this.severityColor,
    this.actionLabel,
    this.onAction,
  });
}

class TroubleshootingEngine {
  static List<DiagnosticIssue> analyzeSession(
    TrackerSessionState session, {
    Function(String apn)? onFixApn,
    VoidCallback? onReadStatus,
  }) {
    final issues = <DiagnosticIssue>[];

    // 1. Diagnóstico de Alimentação Principal
    final mainVolt = session.voltageHistory.isEmpty ? null : session.voltageHistory.last.value;
    if (mainVolt != null && mainVolt < 10.5) {
      issues.add(
        DiagnosticIssue(
          title: 'Subtensão em Alimentação Principal (${mainVolt.toStringAsFixed(1)}V)',
          description: 'A voltagem lida está abaixo de 10.5V. O equipamento pode sofrer reset ao ligar a partida do veículo.',
          recommendation: 'Verificar ponto de conexão pós-chave/linha 30 e fusível principal de alimentação.',
          icon: Icons.bolt_rounded,
          severityColor: TrackerColors.failureRed,
        ),
      );
    }

    // 2. Diagnóstico de Bateria Interna / Backup
    final backupVolt = session.backupVoltageHistory.isEmpty ? null : session.backupVoltageHistory.last.value;
    if (backupVolt != null && backupVolt < 3.6) {
      issues.add(
        DiagnosticIssue(
          title: 'Acumulador Interno Fraco (${backupVolt.toStringAsFixed(1)}V)',
          description: 'Bateria interna de backup está descarregada. Alertas de desengate de bateria podem falhar.',
          recommendation: 'Manter a alimentação principal conectada por ao menos 20 minutos para carga interna.',
          icon: Icons.battery_alert_rounded,
          severityColor: TrackerColors.attentionAmber,
        ),
      );
    }

    // 3. Diagnóstico de APN / GPRS
    if (!session.connection.gprsOnline) {
      final currentApn = session.configuration.desired['APN'] ?? session.configuration.original['APN'] ?? '';
      issues.add(
        DiagnosticIssue(
          title: 'Equipamento Offline na Rede GPRS',
          description: currentApn.isEmpty
              ? 'APN não está configurada no equipamento.'
              : 'APN atual "$currentApn" pode não corresponder ao SIM card instalado.',
          recommendation: 'Gravar APN M2M compatível com a operadora do chip.',
          icon: Icons.signal_cellular_off_rounded,
          severityColor: TrackerColors.attentionAmber,
          actionLabel: onFixApn != null ? 'Configurar APN' : null,
          onAction: onFixApn != null ? () => onFixApn('m2m.vivo.com.br') : null,
        ),
      );
    }

    // 4. Diagnóstico de Satélites / Antena GPS
    final gpsTest = session.tests.firstWhere(
      (t) => t.id == 'gps',
      orElse: () => const TestStepState('gps', 'GPS', TestStatus.pending, 0, 0, ''),
    );
    if (gpsTest.status == TestStatus.failed) {
      issues.add(
        const DiagnosticIssue(
          title: 'Sinal GPS Fraco / Sem Fix',
          description: 'Não foi possível obter a sincronização de satélites (Fix GPS).',
          recommendation: 'Posicionar o equipamento com a face do GPS voltada para o céu, livre de chapas metálicas.',
          icon: Icons.satellite_alt_rounded,
          severityColor: TrackerColors.attentionAmber,
        ),
      );
    }

    return issues;
  }
}

class TroubleshootingWidget extends StatelessWidget {
  final TrackerSessionState session;
  final Function(String apn)? onFixApn;
  final VoidCallback? onReadStatus;

  const TroubleshootingWidget({
    super.key,
    required this.session,
    this.onFixApn,
    this.onReadStatus,
  });

  @override
  Widget build(BuildContext context) {
    final issues = TroubleshootingEngine.analyzeSession(
      session,
      onFixApn: onFixApn,
      onReadStatus: onReadStatus,
    );

    if (issues.isEmpty) {
      return TrackerCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: TrackerColors.technicalGreen.withValues(alpha: 0.1),
                borderRadius: TrackerRadius.small,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: TrackerColors.technicalGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: TrackerSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Diagnóstico do Equipamento: Sem Anomalias', style: TrackerTextStyles.cardTitle),
                  Text('Todos os parâmetros de alimentação, sinal GPRS e GPS estão operando dentro dos limites nominais.', style: TrackerTextStyles.body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: TrackerColors.communicationBlue, size: 18),
            const SizedBox(width: 8),
            const Text('Assistente de Diagnóstico Inteligente', style: TrackerTextStyles.cardTitle),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TrackerColors.attentionAmber.withValues(alpha: 0.1),
                borderRadius: TrackerRadius.pill,
              ),
              child: Text(
                '${issues.length} Alerta(s)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: TrackerColors.attentionAmber),
              ),
            ),
          ],
        ),
        const SizedBox(height: TrackerSpacing.sm),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: issues.length,
          separatorBuilder: (_, __) => const SizedBox(height: TrackerSpacing.xs),
          itemBuilder: (context, index) {
            final issue = issues[index];
            return Container(
              padding: const EdgeInsets.all(TrackerSpacing.md),
              decoration: BoxDecoration(
                color: issue.severityColor.withValues(alpha: 0.04),
                borderRadius: TrackerRadius.medium,
                border: Border.all(color: issue.severityColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(issue.icon, color: issue.severityColor, size: 20),
                  const SizedBox(width: TrackerSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(issue.title, style: TrackerTextStyles.bodyStrong.copyWith(color: issue.severityColor)),
                        const SizedBox(height: 2),
                        Text(issue.description, style: TrackerTextStyles.body.copyWith(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('💡 ${issue.recommendation}', style: TrackerTextStyles.body.copyWith(fontSize: 11, color: TrackerColors.textMuted)),
                      ],
                    ),
                  ),
                  if (issue.actionLabel != null && issue.onAction != null) ...[
                    const SizedBox(width: TrackerSpacing.sm),
                    ElevatedButton(
                      onPressed: issue.onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: issue.severityColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: const RoundedRectangleBorder(borderRadius: TrackerRadius.small),
                      ),
                      child: Text(issue.actionLabel!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

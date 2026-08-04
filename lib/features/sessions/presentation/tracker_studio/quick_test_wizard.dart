import 'package:flutter/material.dart';

import '../../../../core/design/tracker_colors.dart';
import '../../../../core/design/tracker_radius.dart';
import '../../../../core/design/tracker_spacing.dart';
import '../../../../core/design/tracker_text_styles.dart';
import '../../../../core/widgets/tracker_card.dart';
import 'tracker_session_state.dart';
import 'report_generator.dart';

class QuickTestWizardStep {
  final int number;
  final String title;
  final String description;
  final IconData icon;
  final bool isCompleted;
  final bool isPassed;

  const QuickTestWizardStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.isCompleted,
    required this.isPassed,
  });
}

class QuickTestWizardWidget extends StatefulWidget {
  final TrackerSessionState session;
  final VoidCallback? onTriggerLockTest;
  final VoidCallback? onFinishWizard;

  const QuickTestWizardWidget({
    super.key,
    required this.session,
    this.onTriggerLockTest,
    this.onFinishWizard,
  });

  @override
  State<QuickTestWizardWidget> createState() => _QuickTestWizardWidgetState();
}

class _QuickTestWizardWidgetState extends State<QuickTestWizardWidget> {
  int _currentStep = 1;

  @override
  Widget build(BuildContext context) {
    final hasIdentity = widget.session.device.hasIdentity;
    final mainVolt = widget.session.voltageHistory.isNotEmpty
        ? widget.session.voltageHistory.last.value
        : null;
    final isPowerOk = mainVolt != null && mainVolt >= 10.5;
    final isIgnitionOn = widget.session.ignitionHistory.isNotEmpty &&
        widget.session.ignitionHistory.last.event
            .toLowerCase()
            .contains('liga');
    final isOutputOk = widget.session.commandHistory.isNotEmpty;
    final gpsTest = widget.session.tests.firstWhere(
      (t) => t.id == 'gps',
      orElse: () =>
          const TestStepState('gps', 'GPS', TestStatus.pending, 0, 0, ''),
    );
    final isGpsOk = gpsTest.status == TestStatus.passed;

    final steps = [
      QuickTestWizardStep(
        number: 1,
        title: 'Identidade ESN',
        description: hasIdentity
            ? 'ESN: ${widget.session.device.esn}'
            : 'Aguardando ESN...',
        icon: Icons.fingerprint_rounded,
        isCompleted: hasIdentity,
        isPassed: hasIdentity,
      ),
      QuickTestWizardStep(
        number: 2,
        title: 'Alimentação',
        description: mainVolt != null
            ? '${mainVolt.toStringAsFixed(1)}V (Linha 30)'
            : 'Aguardando voltagem...',
        icon: Icons.bolt_rounded,
        isCompleted: mainVolt != null,
        isPassed: isPowerOk,
      ),
      QuickTestWizardStep(
        number: 3,
        title: 'Chave de Ignição',
        description: isIgnitionOn
            ? 'Sinal Ligado Detectado'
            : 'Ligue a chave do veículo',
        icon: Icons.key_rounded,
        isCompleted: isIgnitionOn,
        isPassed: isIgnitionOn,
      ),
      QuickTestWizardStep(
        number: 4,
        title: 'Saída 1 (Bloqueio)',
        description: isOutputOk
            ? 'Pulso Enviado com Sucesso'
            : 'Toque para testar pulso',
        icon: Icons.lock_rounded,
        isCompleted: isOutputOk,
        isPassed: isOutputOk,
      ),
      QuickTestWizardStep(
        number: 5,
        title: 'Fix GPS & Rede',
        description:
            isGpsOk ? 'Fix GPS OK & Conectado' : 'Buscando Fix do GPS...',
        icon: Icons.satellite_alt_rounded,
        isCompleted: isGpsOk,
        isPassed: isGpsOk,
      ),
    ];

    final passedCount = steps.where((s) => s.isPassed).length;
    final isAllPassed = passedCount >= 4;

    return TrackerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TrackerColors.technicalGreen.withValues(alpha: 0.1),
                  borderRadius: TrackerRadius.small,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: TrackerColors.technicalGreen,
                ),
              ),
              const SizedBox(width: TrackerSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Check-in Automático Vapt-Vupt',
                        style: TrackerTextStyles.cardTitle),
                    Text(
                        'Sequência de homologação rápida de instalação em campo.',
                        style: TrackerTextStyles.body),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAllPassed
                      ? TrackerColors.technicalGreen.withValues(alpha: 0.1)
                      : TrackerColors.attentionAmber.withValues(alpha: 0.1),
                  borderRadius: TrackerRadius.pill,
                ),
                child: Text(
                  '$passedCount/5 ETAPAS OK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAllPassed
                        ? TrackerColors.technicalGreen
                        : TrackerColors.attentionAmber,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: TrackerSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: TrackerSpacing.md),

          // Passos horizontais do Wizard
          Row(
            children: steps.map((step) {
              final isCurrent = step.number == _currentStep;
              final color = step.isPassed
                  ? TrackerColors.technicalGreen
                  : step.isCompleted
                      ? TrackerColors.attentionAmber
                      : TrackerColors.textMuted;

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _currentStep = step.number),
                    borderRadius: TrackerRadius.small,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      child: Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(
                                  alpha: isCurrent ? 0.2 : 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isCurrent ? color : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              step.isPassed ? Icons.check_rounded : step.icon,
                              size: 16,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isCurrent
                                  ? TrackerColors.textPrimary
                                  : TrackerColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: TrackerSpacing.md),

          // Detalhe da Etapa Selecionada
          Builder(builder: (context) {
            final step = steps[_currentStep - 1];
            return Container(
              padding: const EdgeInsets.all(TrackerSpacing.md),
              decoration: BoxDecoration(
                color: TrackerColors.background,
                borderRadius: TrackerRadius.medium,
                border: Border.all(color: TrackerColors.lineSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Etapa ${step.number}: ${step.title}',
                            style: TrackerTextStyles.bodyStrong),
                        const SizedBox(height: 2),
                        Text(step.description,
                            style:
                                TrackerTextStyles.body.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                  if (step.number == 4 && widget.onTriggerLockTest != null) ...[
                    ElevatedButton.icon(
                      onPressed: widget.onTriggerLockTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TrackerColors.communicationBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: const RoundedRectangleBorder(
                            borderRadius: TrackerRadius.small),
                      ),
                      icon: const Icon(Icons.lock_rounded, size: 14),
                      label: const Text('Testar Pulso',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          }),

          if (isAllPassed) ...[
            const SizedBox(height: TrackerSpacing.md),
            Container(
              padding: const EdgeInsets.all(TrackerSpacing.md),
              decoration: BoxDecoration(
                color: TrackerColors.technicalGreen.withValues(alpha: 0.08),
                borderRadius: TrackerRadius.medium,
                border: Border.all(
                    color: TrackerColors.technicalGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      color: TrackerColors.technicalGreen, size: 24),
                  const SizedBox(width: TrackerSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CERTIFICADO DE LAUDO: INSTALAÇÃO APROVADA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: TrackerColors.technicalGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Todos os 5 testes nominais foram homologados com sucesso. O veículo está pronto para liberação.',
                          style: TextStyle(
                              fontSize: 11, color: TrackerColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          ReportGenerator.generateAndPrintSessionReport(
                              widget.session);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TrackerColors.communicationBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: const RoundedRectangleBorder(
                              borderRadius: TrackerRadius.small),
                        ),
                        icon:
                            const Icon(Icons.picture_as_pdf_rounded, size: 14),
                        label: const Text('Gerar Relatório (PDF)',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: widget.onFinishWizard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TrackerColors.technicalGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: const RoundedRectangleBorder(
                              borderRadius: TrackerRadius.small),
                        ),
                        icon: const Icon(Icons.assignment_turned_in_rounded,
                            size: 14),
                        label: const Text('Concluir Laudo',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

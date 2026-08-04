import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/tracker_session_state.dart';

class ReportGenerator {
  static Future<void> generateAndPrintSessionReport(
      TrackerSessionState session) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(session),
            pw.SizedBox(height: 20),
            _buildIdentitySection(session),
            pw.SizedBox(height: 20),
            _buildDiagnosticSummary(session),
            pw.SizedBox(height: 20),
            _buildHistorySection(
                'Histórico de Ignição', session.ignitionHistory),
            pw.SizedBox(height: 20),
            _buildHistorySection(
                'Histórico de Comandos', session.commandHistory),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name:
          'Relatorio_${session.device.esn}_${DateTime.now().toIso8601String()}.pdf',
    );
  }

  static pw.Widget _buildHeader(TrackerSessionState session) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Relatório de Sessão - Tracker Studio',
            style: const pw.TextStyle(
                fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text('Gerado em: ${DateTime.now().toString()}'),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildIdentitySection(TrackerSessionState session) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Identidade do Equipamento',
            style: const pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        _buildRow('Fabricante', session.device.manufacturer),
        _buildRow('Modelo', session.device.model),
        _buildRow('ESN', session.device.esn),
        _buildRow('Firmware', session.device.firmware),
        _buildRow(
            'IMEI', session.device.imei.isNotEmpty ? session.device.imei : '-'),
      ],
    );
  }

  static pw.Widget _buildDiagnosticSummary(TrackerSessionState session) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Último Diagnóstico',
            style: const pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        ...session.diagnostics.map((group) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(group.title,
                  style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ...group.values.entries
                  .map((e) => _buildRow('  ${e.key}', e.value)),
              pw.SizedBox(height: 4),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildHistorySection(
      String title, List<EventRecord> history) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: const pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        if (history.isEmpty)
          pw.Text('Sem registros.')
        else
          ...history.map((evt) {
            final timeStr =
                '${evt.timestamp.hour.toString().padLeft(2, '0')}:${evt.timestamp.minute.toString().padLeft(2, '0')}';
            return pw.Text('[$timeStr] ${evt.event} - ${evt.detail}');
          }),
      ],
    );
  }

  static pw.Widget _buildRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label),
        pw.Text(value),
      ],
    );
  }
}

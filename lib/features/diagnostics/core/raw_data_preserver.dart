import 'diagnostic_types.dart';

/// Garante que o conteúdo bruto nunca seja perdido durante o pipeline.
class RawDataPreserver {
  /// Normaliza uma entrada preservando o texto original integralmente.
  RawDiagnosticInput preserve(RawDiagnosticInput input) {
    return RawDiagnosticInput(
      text: input.text,
      bytes: input.bytes,
      type: input.type,
      source: input.source,
    );
  }
}

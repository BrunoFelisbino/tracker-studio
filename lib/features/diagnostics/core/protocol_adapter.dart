import 'diagnostic_types.dart';

abstract class DiagnosticProtocolAdapter {
  String get id;
  SupportedManufacturer get manufacturer;
  String get displayName;
  String get parserVersion;
  bool get supportsCommands => false;

  /// Detecta evidências do fabricante no conteúdo.
  ProtocolDetectionResult detect(RawDiagnosticInput input);

  /// Parseia o conteúdo e normaliza em eventos/telemetria.
  DiagnosticParseResult parse(
    RawDiagnosticInput input,
    ProtocolDetectionResult detection,
  );
}

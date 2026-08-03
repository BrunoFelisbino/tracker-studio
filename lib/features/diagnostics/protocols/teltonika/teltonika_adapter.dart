import '../../core/diagnostic_types.dart';
import '../../core/protocol_adapter.dart';
import 'teltonika_detector.dart';
import 'teltonika_parser.dart';
import 'teltonika_rules.dart';

class TeltonikaAdapter implements DiagnosticProtocolAdapter {
  const TeltonikaAdapter();

  static const _detector = TeltonikaDetector();
  static const _parser = TeltonikaParser();
  static const _rules = TeltonikaRules();

  @override
  String get id => 'teltonika';

  @override
  SupportedManufacturer get manufacturer => SupportedManufacturer.teltonika;

  @override
  String get displayName => 'Teltonika';

  @override
  String get parserVersion => 'teltonika-parser@1.0.0';

  @override
  bool get supportsCommands => true;

  @override
  ProtocolDetectionResult detect(RawDiagnosticInput input) =>
      _detector.detect(input);

  @override
  DiagnosticParseResult parse(
    RawDiagnosticInput input,
    ProtocolDetectionResult detection,
  ) {
    final result = _parser.parse(input, detection);
    return result.copyWith(findings: _rules.diagnose(result.events));
  }
}

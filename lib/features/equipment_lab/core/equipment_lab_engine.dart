import '../protocols/suntech/suntech_adapter.dart';
import '../protocols/teltonika/teltonika_equipment_adapter.dart';
import 'equipment_lab_types.dart';
import 'field_registry.dart';
import 'io_registry.dart';
import 'protocol_adapter.dart';
import 'test_registry.dart';

/// Orquestrador do Laboratório de Equipamentos.
///
/// Fluxo: detectar fabricante -> identificar modelo -> parsear campos/IOs ->
/// rodar testes -> diagnosticar -> gerar relatório.
class EquipmentLabEngine {
  EquipmentLabEngine({
    List<EquipmentProtocolAdapter>? adapters,
    FieldRegistry? fields,
    IoRegistry? ios,
    TestRegistry? tests,
  })  : adapters = AdapterRegistry(
            adapters ?? [const SunTechAdapter(), const TeltonikaAdapter()]),
        fieldRegistry = fields ?? FieldRegistry(version: '0', definitions: []),
        ioRegistry = ios ?? IoRegistry(version: '0', definitions: []),
        testRegistry = tests ?? TestRegistry(version: '0', definitions: []);

  final AdapterRegistry adapters;
  final FieldRegistry fieldRegistry;
  final IoRegistry ioRegistry;
  final TestRegistry testRegistry;

  ManufacturerDetectionResult detectManufacturer(String text) {
    ManufacturerDetectionResult? best;
    var bestConfidence = -1;
    for (final adapter in adapters.adapters) {
      final result = adapter.detect(text);
      if (result.confidence > bestConfidence) {
        bestConfidence = result.confidence;
        best = result;
      }
    }
    return best ??
        const ManufacturerDetectionResult(
          manufacturer: Manufacturer.unknown,
          confidence: 0,
        );
  }

  EquipmentProtocolAdapter? adapterFor(Manufacturer manufacturer) =>
      adapters.byManufacturer(manufacturer);

  EquipmentParseResult parse(String text) {
    final detection = detectManufacturer(text);
    final adapter = adapterFor(detection.manufacturer);
    if (adapter == null) {
      return EquipmentParseResult(
        identity: EquipmentIdentity(
          manufacturer: Manufacturer.unknown,
          confidence: detection.confidence,
          rawSources: [text],
        ),
        fields: const [],
        ioValues: const {},
      );
    }
    final parsed = adapter.parseLines(text);
    return EquipmentParseResult(
      identity: parsed.identity,
      fields: parsed.fields,
      ioValues: parsed.ioValues,
      rawChunks: parsed.rawChunks,
    );
  }

  List<EquipmentTestResult> runTests(
    Manufacturer manufacturer,
    EquipmentParseResult parsed,
  ) {
    final adapter = adapterFor(manufacturer);
    if (adapter == null) return const [];
    final results = <EquipmentTestResult>[];
    for (final test in adapter.testDefinitions) {
      results.add(_evaluateTest(test: test, parsed: parsed));
    }
    return results;
  }

  List<DiagnosticFinding> diagnose(
    Manufacturer manufacturer,
    EquipmentParseResult parsed,
    List<CommandTransaction> transactions,
  ) {
    final adapter = adapterFor(manufacturer);
    if (adapter == null) return const [];
    return adapter.diagnose(parsed, transactions);
  }

  String generateReport(EquipmentLabSession session) {
    final buffer = StringBuffer()..writeln('RELATÓRIO DE VALIDAÇÃO');
    buffer.writeln('========================================');
    buffer.writeln(
        'Fabricante: ${_manufacturerName(session.equipment.manufacturer)}');
    if (session.equipment.model != null) {
      buffer.writeln('Modelo: ${session.equipment.model}');
    }
    if (session.equipment.imei != null) {
      buffer.writeln('IMEI: ${session.equipment.imei}');
    }
    if (session.equipment.esn != null) {
      buffer.writeln('ESN: ${session.equipment.esn}');
    }
    if (session.equipment.iccid != null) {
      buffer.writeln('ICCID: ${session.equipment.iccid}');
    }
    if (session.equipment.firmware != null) {
      buffer.writeln('Firmware: ${session.equipment.firmware}');
    }
    buffer.writeln('Confiança: ${session.equipment.confidence}%');
    buffer.writeln('');

    buffer.writeln('Campos detectados: ${session.fields.length}');
    for (final field in session.fields) {
      final value = field.values.isNotEmpty ? field.values.last.rawValue : '-';
      buffer.writeln(
          '- ${field.normalizedName ?? field.rawName}: $value (${field.values.length} amostras)');
    }
    buffer.writeln('');

    buffer.writeln('IOs mapeados: ${session.ioValues.length}');
    buffer.writeln('');

    buffer.writeln('Testes: ${session.tests.length}');
    var passed = 0, failed = 0, warnings = 0;
    for (final t in session.tests) {
      if (t.status == TestStatus.passed) {
        passed++;
      } else if (t.status == TestStatus.failed) {
        failed++;
      } else if (t.status == TestStatus.passedWithWarning) {
        warnings++;
      }
    }
    buffer.writeln('  ✓ Aprovados: $passed');
    buffer.writeln('  ⚠ Atenção: $warnings');
    buffer.writeln('  ✕ Falhas: $failed');
    buffer.writeln('');

    buffer.writeln('Achados: ${session.findings.length}');
    for (final f in session.findings) {
      buffer.writeln('  ${f.severity.symbol} ${f.severity.label}: ${f.title}');
    }
    return buffer.toString();
  }

  String _manufacturerName(Manufacturer m) {
    switch (m) {
      case Manufacturer.suntech:
        return 'SunTech';
      case Manufacturer.teltonika:
        return 'Teltonika';
      case Manufacturer.unknown:
        return 'Desconhecido';
    }
  }
}

EquipmentTestResult _evaluateTest({
  required EquipmentTestDefinition test,
  required EquipmentParseResult parsed,
}) {
  final started = DateTime.now();
  final hasRequired = test.requiredFields
      .every((f) => parsed.fields.any((field) => field.id == f));

  if (!hasRequired) {
    final missing = test.requiredFields
        .where((f) => !parsed.fields.any((field) => field.id == f))
        .toList();
    return EquipmentTestResult(
      testId: test.id,
      name: test.name,
      category: test.category,
      status: TestStatus.notConfigured,
      startedAt: started,
      completedAt: DateTime.now(),
      detail: 'Campos obrigatórios ausentes: $missing',
    );
  }

  var passed = true;
  var warning = false;
  for (final exp in test.expectedChanges) {
    DetectedField? field;
    for (final f in parsed.fields) {
      if (f.id == exp.field) field = f;
    }
    if (field == null) {
      passed = false;
      continue;
    }
    if (exp.requiresChange && field.changeCount < 1) {
      passed = false;
      warning = true;
    }
    if (exp.from != null) {
      final first =
          field.values.isNotEmpty ? field.values.first.rawValue : null;
      if (first != exp.from) {
        passed = false;
      }
    }
    if (exp.to != null) {
      final last = field.values.isNotEmpty ? field.values.last.rawValue : null;
      if (last != exp.to) passed = false;
    }
    if (exp.minDelta != null &&
        field.values.length >= 2 &&
        field.values.last.normalizedValue is num &&
        field.values[field.values.length - 2].normalizedValue is num) {
      final delta = (field.values.last.normalizedValue as num) -
          (field.values[field.values.length - 2].normalizedValue as num);
      if (delta < exp.minDelta!) passed = false;
      if (exp.maxDelta != null && delta > exp.maxDelta!) passed = false;
    }
  }

  return EquipmentTestResult(
    testId: test.id,
    name: test.name,
    category: test.category,
    status: !passed
        ? (warning ? TestStatus.passedWithWarning : TestStatus.failed)
        : TestStatus.passed,
    startedAt: started,
    completedAt: DateTime.now(),
  );
}

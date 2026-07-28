enum SuntechCommandFamily {
  unknown,
  legacySt300St310,
  newGenSt8210St8310,
  manual,
}

String familyLabel(SuntechCommandFamily family) => switch (family) {
      SuntechCommandFamily.unknown => 'Desconhecida',
      SuntechCommandFamily.legacySt300St310 => 'ST300/ST310 Legacy',
      SuntechCommandFamily.newGenSt8210St8310 => 'ST8210/ST8310 New Gen',
      SuntechCommandFamily.manual => 'Manual',
    };

SuntechCommandFamily resolveSuntechFamily(String model) {
  final normalized = model.trim().toUpperCase();
  if (normalized.startsWith('ST300') || normalized.startsWith('ST310')) {
    return SuntechCommandFamily.legacySt300St310;
  }
  if (normalized.startsWith('ST8210') || normalized.startsWith('ST8310')) {
    return SuntechCommandFamily.newGenSt8210St8310;
  }
  return SuntechCommandFamily.unknown;
}

bool isCommandEcho(String sentCommand, String receivedLine) {
  if (sentCommand.isEmpty) return false;
  return sentCommand.trim() == receivedLine.trim();
}

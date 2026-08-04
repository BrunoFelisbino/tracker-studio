/// Nível de risco de um comando/teste.
enum RiskLevel {
  readOnly, // Sem risco, só leitura
  safe, // Leitura segura, baixo risco
  configuration, // Requer gravação de configuração, risco moderado
  destructive, // Destrói/modifica estado do dispositivo, alto risco
}

extension RiskLevelLabel on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.readOnly:
        return 'Leitura apenas';
      case RiskLevel.safe:
        return 'Seguro';
      case RiskLevel.configuration:
        return 'Configuração';
      case RiskLevel.destructive:
        return 'Destrutivo';
    }
  }

  String get symbol {
    switch (this) {
      case RiskLevel.readOnly:
        return 'R';
      case RiskLevel.safe:
        return 'S';
      case RiskLevel.configuration:
        return 'C';
      case RiskLevel.destructive:
        return 'D';
    }
  }
}

extension RiskLevelOrder on RiskLevel {
  int get order {
    switch (this) {
      case RiskLevel.readOnly:
        return 0;
      case RiskLevel.safe:
        return 1;
      case RiskLevel.configuration:
        return 2;
      case RiskLevel.destructive:
        return 3;
    }
  }

  bool get isDestructive => this == RiskLevel.destructive;
  bool get isReadOnly => this == RiskLevel.readOnly;
  bool get isSafe => this == RiskLevel.safe;
}

extension RiskLevelFilter on RiskLevel {
  /// Se o nível permite a operação.
  bool allows(RiskLevel requested) {
    return this == RiskLevel.readOnly || this == requested;
  }
}

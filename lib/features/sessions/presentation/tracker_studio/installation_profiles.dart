import 'suntech_command_family.dart';

enum InstallationMode { car, motorcycle, custom }

enum IgnitionMode { physical, virtual }

enum TimingProfile { standard, economy, aggressive, custom }

class InstallationProfile {
  final InstallationMode mode;
  final IgnitionMode ignitionMode;
  final TimingProfile timingProfile;
  final int movingIntervalSeconds;
  final int stoppedIntervalSeconds;
  final int ignitionOnIntervalSeconds;
  final int ignitionOffIntervalSeconds;
  final int curveAngleDegrees;
  final int distanceMeters;
  final bool enableSleep;
  final bool enableBlocking;

  const InstallationProfile({
    required this.mode,
    required this.ignitionMode,
    required this.timingProfile,
    required this.movingIntervalSeconds,
    required this.stoppedIntervalSeconds,
    required this.ignitionOnIntervalSeconds,
    required this.ignitionOffIntervalSeconds,
    required this.curveAngleDegrees,
    required this.distanceMeters,
    required this.enableSleep,
    required this.enableBlocking,
  });

  InstallationProfile copyWith({
    InstallationMode? mode,
    IgnitionMode? ignitionMode,
    TimingProfile? timingProfile,
    int? movingIntervalSeconds,
    int? stoppedIntervalSeconds,
    int? ignitionOnIntervalSeconds,
    int? ignitionOffIntervalSeconds,
    int? curveAngleDegrees,
    int? distanceMeters,
    bool? enableSleep,
    bool? enableBlocking,
  }) {
    return InstallationProfile(
      mode: mode ?? this.mode,
      ignitionMode: ignitionMode ?? this.ignitionMode,
      timingProfile: timingProfile ?? this.timingProfile,
      movingIntervalSeconds:
          movingIntervalSeconds ?? this.movingIntervalSeconds,
      stoppedIntervalSeconds:
          stoppedIntervalSeconds ?? this.stoppedIntervalSeconds,
      ignitionOnIntervalSeconds:
          ignitionOnIntervalSeconds ?? this.ignitionOnIntervalSeconds,
      ignitionOffIntervalSeconds:
          ignitionOffIntervalSeconds ?? this.ignitionOffIntervalSeconds,
      curveAngleDegrees: curveAngleDegrees ?? this.curveAngleDegrees,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      enableSleep: enableSleep ?? this.enableSleep,
      enableBlocking: enableBlocking ?? this.enableBlocking,
    );
  }
}

class InstallationProfiles {
  static const carStandard = InstallationProfile(
    mode: InstallationMode.car,
    ignitionMode: IgnitionMode.physical,
    timingProfile: TimingProfile.standard,
    movingIntervalSeconds: 60,
    stoppedIntervalSeconds: 300,
    ignitionOnIntervalSeconds: 60,
    ignitionOffIntervalSeconds: 3600,
    curveAngleDegrees: 30,
    distanceMeters: 500,
    enableSleep: false,
    enableBlocking: true,
  );

  static const motorcycleStandard = InstallationProfile(
    mode: InstallationMode.motorcycle,
    ignitionMode: IgnitionMode.virtual,
    timingProfile: TimingProfile.standard,
    movingIntervalSeconds: 60,
    stoppedIntervalSeconds: 600,
    ignitionOnIntervalSeconds: 60,
    ignitionOffIntervalSeconds: 1800,
    curveAngleDegrees: 30,
    distanceMeters: 300,
    enableSleep: true,
    enableBlocking: false,
  );

  static const custom = InstallationProfile(
    mode: InstallationMode.custom,
    ignitionMode: IgnitionMode.physical,
    timingProfile: TimingProfile.custom,
    movingIntervalSeconds: 60,
    stoppedIntervalSeconds: 300,
    ignitionOnIntervalSeconds: 60,
    ignitionOffIntervalSeconds: 3600,
    curveAngleDegrees: 30,
    distanceMeters: 500,
    enableSleep: false,
    enableBlocking: true,
  );
}

class GeneratedCommandPlan {
  final String title;
  final String description;
  final String commandPreview;
  final bool critical;
  final bool requiresBackup;
  final bool requiresReadback;
  final String status;

  const GeneratedCommandPlan({
    required this.title,
    required this.description,
    required this.commandPreview,
    required this.critical,
    required this.requiresBackup,
    required this.requiresReadback,
    required this.status,
  });
}

List<GeneratedCommandPlan> generateInstallationCommandPlan({
  required InstallationProfile profile,
  required bool hasBackup,
  required SuntechCommandFamily family,
}) {
  if (family == SuntechCommandFamily.unknown ||
      family == SuntechCommandFamily.manual) {
    return const [
      GeneratedCommandPlan(
        title: 'Identificar família Suntech',
        description: 'Identifique o modelo antes de gerar comandos.',
        commandPreview: 'Nenhum comando gerado.',
        critical: true,
        requiresBackup: true,
        requiresReadback: true,
        status: 'blocked',
      ),
    ];
  }
  final blockedDescription = hasBackup
      ? 'Comando pendente de homologação para este modelo.'
      : 'Leia e salve a configuração original antes de aplicar.';
  final familyPreview = family == SuntechCommandFamily.legacySt300St310
      ? 'CMD/NTW/NTN Legacy - comando pendente de homologação.'
      : 'PRG/CMD New Gen - comando pendente de homologação.';
  GeneratedCommandPlan item(String title, String description) {
    return GeneratedCommandPlan(
      title: title,
      description: '$description $blockedDescription',
      commandPreview: familyPreview,
      critical: true,
      requiresBackup: true,
      requiresReadback: true,
      status: 'blocked',
    );
  }

  return [
    item('Ajustar APN/Servidor',
        'Preservar origem e preparar parâmetros de rede revisados.'),
    item(
      'Ajustar tempos de envio',
      'Movimento ${profile.movingIntervalSeconds}s; parado ${profile.stoppedIntervalSeconds}s; '
          'ignição ligada ${profile.ignitionOnIntervalSeconds}s; desligada ${profile.ignitionOffIntervalSeconds}s.',
    ),
    item(
      'Ajustar ignição',
      profile.ignitionMode == IgnitionMode.physical
          ? 'Configurar ignição física.'
          : 'Configurar ignição virtual.',
    ),
    item(
        'Ajustar sleep',
        profile.enableSleep
            ? 'Habilitar sleep.'
            : 'Manter sleep desabilitado.'),
    item(
        'Ajustar bloqueio',
        profile.enableBlocking
            ? 'Preparar bloqueio com confirmação.'
            : 'Manter bloqueio desabilitado.'),
  ];
}

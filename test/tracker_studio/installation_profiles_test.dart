import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/installation_profiles.dart';
import 'package:tracker_studio/features/sessions/presentation/tracker_studio/suntech_command_family.dart';

void main() {
  test('car standard uses physical ignition', () {
    expect(InstallationProfiles.carStandard.mode, InstallationMode.car);
    expect(
        InstallationProfiles.carStandard.ignitionMode, IgnitionMode.physical);
  });

  test('motorcycle standard uses virtual ignition', () {
    expect(InstallationProfiles.motorcycleStandard.mode,
        InstallationMode.motorcycle);
    expect(InstallationProfiles.motorcycleStandard.ignitionMode,
        IgnitionMode.virtual);
  });

  test(
      'command plan stays blocked without backup and has no executable command',
      () {
    final plan = generateInstallationCommandPlan(
      profile: InstallationProfiles.carStandard,
      hasBackup: false,
      family: SuntechCommandFamily.legacySt300St310,
    );

    expect(plan, isNotEmpty);
    expect(plan.every((item) => item.status == 'blocked'), isTrue);
    expect(
        plan.every(
            (item) => item.commandPreview.contains('pendente de homologação')),
        isTrue);
  });

  test('custom profile updates timing without changing the source preset', () {
    final custom = InstallationProfiles.custom.copyWith(
      movingIntervalSeconds: 25,
      stoppedIntervalSeconds: 120,
      ignitionOffIntervalSeconds: 900,
    );

    expect(custom.movingIntervalSeconds, 25);
    expect(custom.stoppedIntervalSeconds, 120);
    expect(custom.ignitionOffIntervalSeconds, 900);
    expect(InstallationProfiles.carStandard.movingIntervalSeconds, 60);
  });

  test('unknown family blocks plan before generating commands', () {
    final plan = generateInstallationCommandPlan(
      profile: InstallationProfiles.carStandard,
      hasBackup: true,
      family: SuntechCommandFamily.unknown,
    );

    expect(plan, hasLength(1));
    expect(plan.single.status, 'blocked');
    expect(plan.single.description, contains('Identifique o modelo'));
  });

  test('legacy plan never generates PRG', () {
    final plan = generateInstallationCommandPlan(
      profile: InstallationProfiles.carStandard,
      hasBackup: true,
      family: SuntechCommandFamily.legacySt300St310,
    );
    expect(plan.any((item) => item.commandPreview.contains('PRG')), isFalse);
  });

  test('new gen plan does not generate NTW or NTN by default', () {
    final plan = generateInstallationCommandPlan(
      profile: InstallationProfiles.carStandard,
      hasBackup: true,
      family: SuntechCommandFamily.newGenSt8210St8310,
    );
    expect(
        plan.any((item) =>
            item.commandPreview.contains('NTW') ||
            item.commandPreview.contains('NTN')),
        isFalse);
  });
}

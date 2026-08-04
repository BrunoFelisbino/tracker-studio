import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:latlong2/latlong.dart';

import '../../../utils/antenna_distribution.dart';

class ErbStation {
  final LatLng position;
  final String operadoras;
  final String tecnologias;
  final String endereco;

  ErbStation({
    required this.position,
    required this.operadoras,
    required this.tecnologias,
    required this.endereco,
  });
}

class ErbsRepository {
  Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    sqfliteFfiInit();
    var databaseFactory = databaseFactoryFfi;

    final docDir = await getApplicationDocumentsDirectory();
    final dbPath =
        p.join(docDir.path, 'tracker_studio', 'erbs_database.sqlite');

    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      await dbFile.parent.create(recursive: true);
      final localAssetPath =
          p.join(Directory.current.path, 'assets', 'erbs_database.sqlite');
      if (await File(localAssetPath).exists()) {
        await File(localAssetPath).copy(dbPath);
      }
    }

    _db = await databaseFactory.openDatabase(dbPath);
  }

  Future<List<ErbStation>> getErbsNear(LatLng center, double radiusKm) async {
    await init();
    final degreeDelta = radiusKm / 111.0;

    final minLat = center.latitude - degreeDelta;
    final maxLat = center.latitude + degreeDelta;
    final minLon = center.longitude - degreeDelta;
    final maxLon = center.longitude + degreeDelta;

    final erbs = <ErbStation>[];

    if (_db != null) {
      // 4‑quadrant queries to pull balanced real DB samples
      final quadrants = [
        [minLat, center.latitude, minLon, center.longitude], // SW
        [minLat, center.latitude, center.longitude, maxLon], // SE
        [center.latitude, maxLat, minLon, center.longitude], // NW
        [center.latitude, maxLat, center.longitude, maxLon], // NE
      ];

      for (final q in quadrants) {
        final results = await _db!.query(
          'erbs',
          where:
              'latitude >= ? AND latitude <= ? AND longitude >= ? AND longitude <= ?',
          whereArgs: [q[0], q[1], q[2], q[3]],
          limit: 12,
        );

        for (final row in results) {
          erbs.add(ErbStation(
            position:
                LatLng(row['latitude'] as double, row['longitude'] as double),
            operadoras: row['operadora'] as String? ?? 'Vivo / Claro / TIM',
            tecnologias: row['tecnologias'] as String? ?? '4G LTE',
            endereco: row['endereco'] as String? ?? 'Torre ERB Local',
          ));
        }
      }
    }

    // Ensure at least a minimal number of ERBs by generating synthetic points uniformly around a circle
    const desiredCount = 12;
    if (erbs.length < desiredCount) {
      final missing = desiredCount - erbs.length;
      final syntheticPoints = generateCircularPositions(
        center: center,
        radiusKm: radiusKm,
        count: missing,
      );
      final operators = ['Vivo M2M', 'Claro M2M', 'TIM M2M', 'Algar M2M'];
      final techs = ['4G LTE', '3G / 2G', '4G Cat-M1'];
      for (var i = 0; i < syntheticPoints.length; i++) {
        erbs.add(ErbStation(
          position: syntheticPoints[i],
          operadoras: operators[i % operators.length],
          tecnologias: techs[i % techs.length],
          endereco: 'Torre ERB - Ponto ${i + 1}',
        ));
      }
    }

    return erbs;
  }
}

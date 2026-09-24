import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:pmtiles/pmtiles.dart';

import 'model.dart';
import 'world_city_database.dart';

class OfflineMapDownloadResult {
  const OfflineMapDownloadResult({
    required this.pack,
    required this.downloaded,
    required this.skipped,
  });

  final OfflineMapPack pack;
  final int downloaded;
  final int skipped;
}

class OfflineMapService {
  static const sourceUrl =
      'https://data.source.coop/protomaps/openstreetmap/v4.pmtiles';

  Future<OfflineMapDownloadResult> downloadAroundProfile({
    required UserProfile profile,
    required String scope,
    int? minZoom,
    int? maxZoom,
    void Function(int completed, int total)? onProgress,
  }) async {
    final lat = profile.latitude;
    final lon = profile.longitude;
    if (lat == null || lon == null) {
      throw const FormatException('В профиле нет координат города.');
    }
    if (lat < -85.0511 || lat > 85.0511 || lon < -180 || lon > 180) {
      throw const FormatException('Координаты профиля находятся вне карты.');
    }

    final definition = switch (scope) {
      'country' => (radiusKm: 750.0, minZoom: 0, maxZoom: 7, limit: 2600),
      'region' => (radiusKm: 120.0, minZoom: 5, maxZoom: 11, limit: 3600),
      _ => (radiusKm: 14.0, minZoom: 8, maxZoom: 15, limit: 5200),
    };
    final countryBounds = scope == 'country'
        ? await WorldCityDatabase.instance.countryMapBounds(profile.country)
        : null;
    final requestedMin = (minZoom ?? definition.minZoom).clamp(0, 15);
    var effectiveMax = (maxZoom ?? definition.maxZoom).clamp(requestedMin, 15);
    List<_MapTile> buildTiles() => countryBounds == null
        ? _tilesAround(
            latitude: lat,
            longitude: lon,
            radiusKm: definition.radiusKm,
            minZoom: requestedMin,
            maxZoom: effectiveMax,
          )
        : _tilesWithinBounds(
            bounds: countryBounds,
            minZoom: requestedMin,
            maxZoom: effectiveMax,
          );
    var tiles = buildTiles();
    while (tiles.length > definition.limit && effectiveMax > requestedMin) {
      effectiveMax--;
      tiles = buildTiles();
    }
    if (tiles.length > definition.limit) {
      throw FormatException(
        'Область содержит ${tiles.length} тайлов, безопасный предел '
        '${definition.limit}. Уменьшите масштаб пакета.',
      );
    }

    final root = await getApplicationDocumentsDirectory();
    final packId = newId();
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}offline_maps'
      '${Platform.pathSeparator}$packId',
    );
    await dir.create(recursive: true);

    PmTilesArchive? archive;
    var downloaded = 0;
    var skipped = 0;
    try {
      archive = await PmTilesArchive.fromUri(
        Uri.parse(sourceUrl),
        headers: const {
          HttpHeaders.userAgentHeader:
              'MyHealth/1.8 (+https://github.com/TheBestMKS/MyHealth)',
        },
      ).timeout(const Duration(seconds: 45));
      if (archive.tileType != TileType.mvt) {
        throw const FormatException('Источник не содержит векторную карту.');
      }

      const batchSize = 96;
      for (var offset = 0; offset < tiles.length; offset += batchSize) {
        final end = math.min(offset + batchSize, tiles.length);
        final batch = tiles.sublist(offset, end);
        final byId = <int, _MapTile>{for (final tile in batch) tile.id: tile};
        await for (final remoteTile in archive.tiles(byId.keys.toList())) {
          final tile = byId[remoteTile.id]!;
          try {
            final bytes = remoteTile.bytes();
            final tileDir = Directory(
              '${dir.path}${Platform.pathSeparator}${tile.z}'
              '${Platform.pathSeparator}${tile.x}',
            );
            await tileDir.create(recursive: true);
            await File(
              '${tileDir.path}${Platform.pathSeparator}${tile.y}.mvt',
            ).writeAsBytes(bytes, flush: false);
            downloaded++;
          } on TileNotFoundException {
            skipped++;
          }
          onProgress?.call(downloaded + skipped, tiles.length);
        }
      }
    } catch (_) {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      rethrow;
    } finally {
      await archive?.close();
    }

    final pack = OfflineMapPack(
      id: packId,
      title:
          '${_scopeTitle(scope)}: ${profile.city.isEmpty ? profile.country : profile.city}',
      scope: scope,
      country: profile.country,
      region: '',
      city: profile.city,
      minZoom: requestedMin,
      maxZoom: effectiveMax,
      downloadedAt: DateTime.now().toIso8601String(),
      tileCount: downloaded,
      storagePath: dir.path,
      format: 'mvt',
      source: sourceUrl,
    );
    return OfflineMapDownloadResult(
      pack: pack,
      downloaded: downloaded,
      skipped: skipped,
    );
  }

  Future<void> deletePack(OfflineMapPack pack) async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(
      '${documents.path}${Platform.pathSeparator}offline_maps',
    ).absolute.path;
    final target = Directory(pack.storagePath).absolute.path;
    final rootPrefix = '${root.toLowerCase()}${Platform.pathSeparator}';
    if (!target.toLowerCase().startsWith(rootPrefix)) return;
    final directory = Directory(target);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

String _scopeTitle(String scope) {
  return switch (scope) {
    'country' => 'страна',
    'region' => 'регион',
    _ => 'город',
  };
}

List<_MapTile> _tilesAround({
  required double latitude,
  required double longitude,
  required double radiusKm,
  required int minZoom,
  required int maxZoom,
}) {
  final result = <_MapTile>[];
  for (var z = minZoom; z <= maxZoom; z++) {
    final center = _tileXY(latitude, longitude, z);
    final n = 1 << z;
    final metersPerTile =
        40075016.686 * math.cos(latitude * math.pi / 180).abs() / n;
    final tileRadius = math.max(
      1,
      (radiusKm * 1000 / math.max(metersPerTile, 1)).ceil(),
    );
    final seen = <int>{};
    for (
      var rawX = center.x - tileRadius;
      rawX <= center.x + tileRadius;
      rawX++
    ) {
      final x = ((rawX % n) + n) % n;
      for (
        var y = math.max(0, center.y - tileRadius);
        y <= math.min(n - 1, center.y + tileRadius);
        y++
      ) {
        final tile = _MapTile(z, x, y);
        if (seen.add(tile.id)) result.add(tile);
      }
    }
  }
  return result;
}

List<_MapTile> _tilesWithinBounds({
  required CountryMapBounds bounds,
  required int minZoom,
  required int maxZoom,
}) {
  final result = <_MapTile>[];
  for (var z = minZoom; z <= maxZoom; z++) {
    final n = 1 << z;
    final northWest = _tileXY(bounds.north, bounds.west, z);
    final southEast = _tileXY(bounds.south, bounds.east, z);
    final yStart = math.min(northWest.y, southEast.y);
    final yEnd = math.max(northWest.y, southEast.y);
    final xRanges = bounds.crossesAntimeridian
        ? [(start: northWest.x, end: n - 1), (start: 0, end: southEast.x)]
        : [
            (
              start: math.min(northWest.x, southEast.x),
              end: math.max(northWest.x, southEast.x),
            ),
          ];
    for (final range in xRanges) {
      for (var x = range.start; x <= range.end; x++) {
        for (var y = yStart; y <= yEnd; y++) {
          result.add(_MapTile(z, x, y));
        }
      }
    }
  }
  return result;
}

({int x, int y}) _tileXY(double lat, double lon, int zoom) {
  final latRad = lat * math.pi / 180;
  final n = math.pow(2, zoom).toDouble();
  final x = ((lon + 180) / 360 * n).floor().clamp(0, n.toInt() - 1);
  final y =
      ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
              2 *
              n)
          .floor()
          .clamp(0, n.toInt() - 1);
  return (x: x, y: y);
}

class _MapTile {
  const _MapTile(this.z, this.x, this.y);

  final int z;
  final int x;
  final int y;

  int get id => ZXY(z, x, y).toTileId();
}

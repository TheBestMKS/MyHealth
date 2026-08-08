import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';

import 'model.dart';

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
    final radiusKm = switch (scope) {
      'country' => 750.0,
      'region' => 120.0,
      _ => 14.0,
    };
    final zoomRange = switch (scope) {
      'country' => (min: minZoom ?? 4, max: maxZoom ?? 7, limit: 3200),
      'region' => (min: minZoom ?? 7, max: maxZoom ?? 11, limit: 4200),
      _ => (min: minZoom ?? 11, max: maxZoom ?? 15, limit: 5200),
    };
    final root = await getApplicationDocumentsDirectory();
    final packId = newId();
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}offline_maps'
      '${Platform.pathSeparator}$packId',
    );
    await dir.create(recursive: true);
    final client = HttpClient()
      ..userAgent = 'MyHealth/1.1 offline map downloader';
    var downloaded = 0;
    var skipped = 0;
    try {
      final tiles = <({int z, int x, int y})>[];
      for (var z = zoomRange.min; z <= zoomRange.max; z++) {
        final center = _tileXY(lat, lon, z);
        final metersPerTile =
            156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, z) * 256;
        final tileRadius = math.max(
          1,
          (radiusKm * 1000 / metersPerTile).ceil(),
        );
        for (var x = center.x - tileRadius; x <= center.x + tileRadius; x++) {
          for (var y = center.y - tileRadius; y <= center.y + tileRadius; y++) {
            if (tiles.length >= zoomRange.limit) break;
            tiles.add((z: z, x: x, y: y));
          }
          if (tiles.length >= zoomRange.limit) break;
        }
        if (tiles.length >= zoomRange.limit) break;
      }
      for (final tile in tiles) {
        final z = tile.z;
        final x = tile.x;
        final y = tile.y;
        final tileDir = Directory(
          '${dir.path}${Platform.pathSeparator}$z${Platform.pathSeparator}$x',
        );
        await tileDir.create(recursive: true);
        final file = File('${tileDir.path}${Platform.pathSeparator}$y.png');
        if (await file.exists()) {
          skipped++;
          onProgress?.call(downloaded + skipped, tiles.length);
          continue;
        }
        final request = await client.getUrl(
          Uri.parse('https://tile.openstreetmap.org/$z/$x/$y.png'),
        );
        request.headers.set(HttpHeaders.userAgentHeader, client.userAgent!);
        final response = await request.close();
        if (response.statusCode == 200) {
          await response.pipe(file.openWrite());
          downloaded++;
        } else {
          skipped++;
        }
        onProgress?.call(downloaded + skipped, tiles.length);
      }
    } finally {
      client.close(force: true);
    }
    final pack = OfflineMapPack(
      id: packId,
      title:
          '${_scopeTitle(scope)}: ${profile.city.isEmpty ? profile.country : profile.city}',
      scope: scope,
      country: profile.country,
      region: '',
      city: profile.city,
      minZoom: zoomRange.min,
      maxZoom: zoomRange.max,
      downloadedAt: DateTime.now().toIso8601String(),
      tileCount: downloaded + skipped,
      storagePath: dir.path,
    );
    return OfflineMapDownloadResult(
      pack: pack,
      downloaded: downloaded,
      skipped: skipped,
    );
  }
}

String _scopeTitle(String scope) {
  return switch (scope) {
    'country' => 'страна',
    'region' => 'регион',
    _ => 'город',
  };
}

({int x, int y}) _tileXY(double lat, double lon, int zoom) {
  final latRad = lat * math.pi / 180;
  final n = math.pow(2, zoom).toDouble();
  final x = ((lon + 180) / 360 * n).floor();
  final y =
      ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
              2 *
              n)
          .floor();
  return (x: x, y: y);
}

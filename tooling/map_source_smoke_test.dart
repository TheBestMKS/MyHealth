import 'dart:math' as math;

import 'package:pmtiles/pmtiles.dart';

const sourceUrl =
    'https://data.source.coop/protomaps/openstreetmap/v4.pmtiles';

Future<void> main() async {
  const latitude = 55.7558;
  const longitude = 37.6173;
  const zoom = 10;
  final n = 1 << zoom;
  final x = ((longitude + 180) / 360 * n).floor();
  final latitudeRadians = latitude * math.pi / 180;
  final y =
      ((1 -
                  math.log(
                        math.tan(latitudeRadians) +
                            1 / math.cos(latitudeRadians),
                      ) /
                      math.pi) /
              2 *
              n)
          .floor();
  final archive = await PmTilesArchive.fromUri(
    Uri.parse(sourceUrl),
    headers: const {
      'User-Agent':
          'MyHealth/1.8 map smoke (+https://github.com/TheBestMKS/MyHealth)',
    },
  ).timeout(const Duration(seconds: 45));
  try {
    if (archive.tileType != TileType.mvt) {
      throw StateError('Expected MVT, got ${archive.tileType}');
    }
    final tile = await archive
        .tile(ZXY(zoom, x, y).toTileId())
        .timeout(const Duration(seconds: 45));
    final bytes = tile.bytes();
    if (bytes.length < 100) {
      throw StateError('Unexpectedly small MVT tile: ${bytes.length} bytes');
    }
    print(
      'MAP_SOURCE_OK type=${archive.tileType.name} '
      'zoom=$zoom tile=$x/$y bytes=${bytes.length}',
    );
  } finally {
    await archive.close();
  }
}

import 'dart:io';

import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/model.dart';
import 'package:my_health/src/offline_vector_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('directory vector provider reads a stored tile', () async {
    final root = await Directory.systemTemp.createTemp('myhealth_map_test_');
    addTearDown(() => root.delete(recursive: true));
    final tileFile = File(
      '${root.path}${Platform.pathSeparator}10${Platform.pathSeparator}619'
      '${Platform.pathSeparator}320.mvt',
    );
    await tileFile.parent.create(recursive: true);
    await tileFile.writeAsBytes([1, 2, 3, 4]);
    final provider = DirectoryVectorTileProvider(_pack(root.path));

    final response = await provider.load(const vt.TileKey(10, 619, 320));

    expect(response, isA<vt.TileResponseData>());
    expect((response as vt.TileResponseData).bytes, [1, 2, 3, 4]);
    expect(
      await provider.load(const vt.TileKey(10, 620, 320)),
      isA<vt.TileResponseNotFound>(),
    );
    provider.dispose();
  });

  test('bundled offline vector style resolves without network', () async {
    final provider = vt.MemoryVectorTileProvider(
      tiles: const {},
      cacheKey: 'offline-style-test',
    );
    final style = await vt.StyleReader(
      uri: 'asset://assets/maps/myhealth_offline_style.json',
      cache: false,
      resolveProvider: (sourceId) async =>
          sourceId == 'protomaps' ? provider : null,
    ).read();
    addTearDown(style.dispose);

    expect(style.name, 'MyHealth offline');
    expect(style.providers['protomaps'], same(provider));
    expect(style.attributions.single.text, contains('OpenStreetMap'));
  });
}

OfflineMapPack _pack(String path) => OfflineMapPack(
  id: 'test-pack',
  title: 'Москва',
  scope: 'city',
  country: 'Россия',
  region: 'Москва',
  city: 'Москва',
  minZoom: 8,
  maxZoom: 15,
  downloadedAt: '2026-09-24T00:00:00.000',
  tileCount: 1,
  storagePath: path,
  format: 'mvt',
  source: 'test',
);

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

import 'model.dart';

class OfflineVectorMapLayer extends StatefulWidget {
  const OfflineVectorMapLayer({super.key, required this.pack});

  final OfflineMapPack pack;

  @override
  State<OfflineVectorMapLayer> createState() => _OfflineVectorMapLayerState();
}

class _OfflineVectorMapLayerState extends State<OfflineVectorMapLayer> {
  vt.Style? _style;
  Object? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OfflineVectorMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pack.id != widget.pack.id ||
        oldWidget.pack.storagePath != widget.pack.storagePath) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final previous = _style;
    _style = null;
    _error = null;
    previous?.dispose();
    try {
      final provider = DirectoryVectorTileProvider(widget.pack);
      final style = await vt.StyleReader(
        uri: 'asset://assets/maps/myhealth_offline_style.json',
        cache: false,
        resolveProvider: (sourceId) async =>
            sourceId == 'protomaps' ? provider : null,
      ).read();
      if (!mounted || generation != _loadGeneration) {
        style.dispose();
        return;
      }
      setState(() => _style = style);
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _style?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style == null) {
      return ColoredBox(
        color: const Color(0xFFF4F6F3),
        child: _error == null
            ? const Center(child: CircularProgressIndicator())
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Не удалось открыть локальную карту',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
      );
    }
    return vt.VectorTileLayer(
      theme: style.theme,
      tileProviders: style.providers,
      rasterSources: style.rasterSources,
      sprites: style.sprites,
      diskCacheMaximumSizeInBytes: 0,
      memoryCacheMaxBytes: 16 * 1024 * 1024,
      rasterCacheMaxBytes: 64 * 1024 * 1024,
      concurrency: 2,
    );
  }
}

class DirectoryVectorTileProvider extends vt.VectorTileProvider {
  DirectoryVectorTileProvider(this.pack);

  final OfflineMapPack pack;
  final _inFlight = vt.SingleFlight<vt.TileKey, vt.TileResponse>();
  var _disposed = false;

  @override
  int get maximumZoom => pack.maxZoom;

  @override
  int get minimumZoom => pack.minZoom;

  @override
  String get cacheKey => 'myhealth-offline:${pack.id}:${pack.downloadedAt}';

  @override
  bool get cacheBytesToDisk => false;

  @override
  Future<vt.TileResponse> load(
    vt.TileKey tile, {
    vt.CancellationToken? cancellation,
  }) {
    return _inFlight.run(
      tile,
      (token) => _load(tile, token),
      cancellation: cancellation,
    );
  }

  Future<vt.TileResponse> _load(
    vt.TileKey tile,
    vt.CancellationToken cancellation,
  ) async {
    if (_disposed || cancellation.isCancelled) {
      return const vt.TileResponseCancelled();
    }
    final file = File(
      '${pack.storagePath}${Platform.pathSeparator}${tile.z}'
      '${Platform.pathSeparator}${tile.x}${Platform.pathSeparator}${tile.y}.mvt',
    );
    try {
      if (!await file.exists()) return const vt.TileResponseNotFound();
      final bytes = await file.readAsBytes();
      if (_disposed || cancellation.isCancelled) {
        return const vt.TileResponseCancelled();
      }
      return bytes.isEmpty
          ? const vt.TileResponseNotFound()
          : vt.TileResponseData(bytes);
    } catch (error) {
      return vt.TileResponseError(error);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _inFlight.clear();
  }
}

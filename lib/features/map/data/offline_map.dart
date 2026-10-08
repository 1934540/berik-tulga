import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'offline_map_files_stub.dart'
    if (dart.library.io) 'offline_map_files_io.dart'
    as files;

const offlineMapBounds = (west: 65.34, south: 44.72, east: 65.70, north: 44.98);

bool outsideOfflineMap(double latitude, double longitude) =>
    latitude < offlineMapBounds.south ||
    latitude > offlineMapBounds.north ||
    longitude < offlineMapBounds.west ||
    longitude > offlineMapBounds.east;

class OfflineMap {
  const OfflineMap(this.style, this.metadata);
  final String style;
  final Map<String, dynamic> metadata;
}

/// The map, names and font glyphs ship with the app. No remote resources.
final offlineMapProvider = FutureProvider<OfflineMap>((ref) async {
  final metadata = jsonDecode(
    await rootBundle.loadString('assets/maps/metadata.json'),
  ) as Map<String, dynamic>;
  final template = jsonDecode(
    await rootBundle.loadString('assets/maps/style.json'),
  ) as Map<String, dynamic>;
  if (kIsWeb) {
    final base = Uri.base.resolve('assets/assets/maps/').toString();
    return OfflineMap(
      jsonEncode(
        resolveOfflineStyle(
          template,
          base,
          webFont: metadata['font'] as String,
        ),
      ),
      metadata,
    );
  }
  final base = await files.prepareOfflineMap(metadata);
  final style = jsonEncode(resolveOfflineStyle(template, base.url));
  return OfflineMap(await files.saveOfflineStyle(base.path, style), metadata);
});

Map<String, dynamic> resolveOfflineStyle(
  Map<String, dynamic> template,
  String baseUrl, {
  String? webFont,
}) {
  final style = jsonDecode(jsonEncode(template)) as Map<String, dynamic>;
  // Flutter writes escaped asset names (Noto%20Sans%20Regular) on web.
  // Escape that asset key again so the HTTP server resolves its literal %20.
  final stack = webFont == null
      ? '{fontstack}'
      : Uri.encodeComponent(Uri.encodeComponent(webFont));
  // The web package has one font. Keep MapLibre's required fontstack token
  // in the query while resolving Flutter's escaped file name in the path.
  final query = webFont == null ? '' : '?fontstack={fontstack}';
  style['glyphs'] = '${baseUrl}glyphs/$stack/{range}.pbf$query';
  (style['sources'] as Map<String, dynamic>)['city']['data'] =
      '${baseUrl}kyzylorda.geojson';
  return style;
}

import 'dart:convert';
import 'dart:io';

import 'package:berik_tulga/core/config/app_config.dart';
import 'package:berik_tulga/features/map/data/offline_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundled map has real geometry, complete glyph ranges and no network resources', () {
    final template = jsonDecode(
      File('assets/maps/style.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final metadata = jsonDecode(
      File('assets/maps/metadata.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final data = jsonDecode(
      File('assets/maps/kyzylorda.geojson').readAsStringSync(),
    ) as Map<String, dynamic>;
    final features = (data['features'] as List).cast<Map<String, dynamic>>();
    expect(AppConfig.offlineOnly, isTrue);
    expect(AppConfig.hasBackend, isFalse);
    expect(metadata['license'], 'ODbL-1.0');
    expect(metadata['bounds'], [65.34, 44.72, 65.70, 44.98]);
    expect(
      features.where((f) => f['properties']['kind'] == 'road').length,
      greaterThan(200),
    );
    expect(
      features.where((f) => f['properties']['kind'] == 'building').length,
      greaterThan(500),
    );
    for (final entry
        in (metadata['files'] as List).cast<Map<String, dynamic>>()) {
      expect(File('assets/maps/${entry['file']}').lengthSync(), entry['bytes']);
    }
    for (final feature in features) {
      for (final rune in (feature['properties']['name'] as String).runes) {
        final start = rune ~/ 256 * 256;
        expect(
          File('assets/maps/glyphs/Noto Sans Regular/$start-${start + 255}.pbf')
              .existsSync(),
          isTrue,
        );
      }
    }
    final native = resolveOfflineStyle(
      template,
      'file:///private/offline_maps/',
    );
    expect(native['glyphs'], startsWith('file:///'));
    expect(
      native['sources']['city']['data'],
      'file:///private/offline_maps/kyzylorda.geojson',
    );
    expect(native.containsKey('sprite'), isFalse);
    expect(native['sources']['city'].containsKey('tiles'), isFalse);
    final web = resolveOfflineStyle(
      template,
      'http://127.0.0.1:8087/assets/assets/maps/',
      webFont: metadata['font'] as String,
    );
    expect(
      web['sources']['city']['data'],
      startsWith('http://127.0.0.1:8087/'),
    );
    expect(web['glyphs'], startsWith('http://127.0.0.1:8087/'));
    expect(web['glyphs'], contains('{fontstack}'));
    expect(
      Uri.decodeComponent(Uri.parse(web['glyphs'] as String).path),
      contains('glyphs/Noto%20Sans%20Regular/{range}.pbf'),
    );
  });

  test('coverage warning detects positions outside the bundled city', () {
    expect(outsideOfflineMap(44.8488, 65.4823), isFalse);
    expect(outsideOfflineMap(44.72, 65.34), isFalse);
    expect(outsideOfflineMap(44.98, 65.70), isFalse);
    expect(outsideOfflineMap(43.24, 76.93), isTrue);
    expect(outsideOfflineMap(45, 65.48), isTrue);
  });
}

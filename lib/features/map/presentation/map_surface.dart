import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MapSurfaceOptions {
  const MapSurfaceOptions({
    required this.key,
    required this.style,
    required this.camera,
    required this.created,
    required this.styleLoaded,
    required this.idle,
  });
  final Key key;
  final String style;
  final CameraPosition camera;
  final void Function(MapLibreMapController) created;
  final VoidCallback styleLoaded, idle;
}

typedef MapSurfaceBuilder = Widget Function(MapSurfaceOptions options);

/// Tests replace only the native/WebGL surface, keeping all application UI.
final mapSurfaceProvider = Provider<MapSurfaceBuilder>(
  (ref) =>
      (options) => MapLibreMap(
        key: options.key,
        styleString: options.style,
        initialCameraPosition: options.camera,
        onMapCreated: options.created,
        onStyleLoadedCallback: options.styleLoaded,
        onMapIdle: options.idle,
        myLocationEnabled: false,
        compassEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        minMaxZoomPreference: const MinMaxZoomPreference(9, 19),
        attributionButtonPosition: AttributionButtonPosition.bottomRight,
        foregroundLoadColor: const Color(0xFF11151A),
        webPreserveDrawingBuffer: true,
      ),
);

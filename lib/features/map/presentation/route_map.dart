import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/providers.dart';
import '../../activity/domain/activity.dart';
import '../../auth/data/account_controller.dart';
import '../../territory/domain/territory.dart';
import '../data/offline_map.dart';
import '../domain/route_geojson.dart';
import 'map_surface.dart';

class RouteMap extends ConsumerStatefulWidget {
  const RouteMap({
    super.key,
    this.points = const [],
    this.position,
    this.demo = false,
    this.centerVersion = 0,
    this.tracking = false,
    this.cells = const [],
  });
  final List<RoutePoint> points;
  final RoutePoint? position;
  final bool demo, tracking;
  final List<TerritoryCell> cells;
  final int centerVersion;
  @override
  ConsumerState<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<RouteMap> {
  MapLibreMapController? _map;
  Future<void> _updates = Future.value();
  Timer? _loadTimer;
  Timer? _territoryTimer;
  List<TerritoryCell>? _viewportCells;
  int _request = 0;
  RealtimeChannel? _territoryChannel;
  bool _ready = false, _loaded = false, _failed = false, _follow = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _watchLoad();
    final account = ref.read(accountProvider);
    if (!account.demo && !account.local) {
      _territoryChannel = ref
          .read(backendProvider)
          ?.channel('territory-${identityHashCode(this)}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'teams',
            callback: (_) => _scheduleTerritories(),
          )
          .subscribe();
    }
  }

  void _watchLoad() {
    _loadTimer?.cancel();
    _territoryTimer?.cancel();
    _loadTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && !_loaded) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    _territoryTimer?.cancel();
    if (_territoryChannel != null) unawaited(_territoryChannel!.unsubscribe());
    // MapLibreMap owns and disposes its controller/platform view.
    _map = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (!old.tracking && widget.tracking) _follow = true;
    if (old.points != widget.points || old.position != widget.position) {
      _queueDraw();
      if (widget.position != null &&
          (old.position == null || (widget.tracking && _follow))) {
        _center();
      }
    }
    if (old.centerVersion != widget.centerVersion) {
      _follow = true;
      _center();
    }
    final changed =
        old.cells.length != widget.cells.length ||
        List.generate(widget.cells.length, (i) => i).any(
          (i) =>
              i >= old.cells.length ||
              old.cells[i].id != widget.cells[i].id ||
              old.cells[i].hp != widget.cells[i].hp ||
              old.cells[i].ownerTeam != widget.cells[i].ownerTeam,
        );
    if (changed) {
      _queueDraw();
      _scheduleTerritories();
    }
  }

  void _center() {
    final position = widget.position;
    if (_ready && position != null) {
      unawaited(
        _map
            ?.moveCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(position.latitude, position.longitude),
                16,
              ),
            )
            .catchError((Object _) => false),
      );
    }
  }

  void _queueDraw() {
    final generation = _generation;
    _updates = _updates
        .then((_) async {
          final map = _map;
          if (!mounted || !_ready || generation != _generation || map == null) {
            return;
          }
          await map.setGeoJsonSource('walk-route', routeGeoJson(widget.points));
          await map.setGeoJsonSource(
            'territory-cells',
            territoryGeoJson(_viewportCells ?? widget.cells),
          );
          if (!mounted || generation != _generation) return;
          await map.setGeoJsonSource(
            'walk-markers',
            markerGeoJson(widget.points, widget.position),
          );
        })
        .catchError((Object _) {});
  }

  Future<void> _styleLoaded() async {
    final map = _map, generation = _generation;
    if (map == null || _ready) return;
    try {
      await map.addGeoJsonSource(
        'territory-cells',
        territoryGeoJson(widget.cells),
      );
      await map.addFillLayer(
        'territory-cells',
        'territory-fill',
        const FillLayerProperties(
          fillColor: ['get', 'color'],
          fillOpacity: .55,
          // Adjacent cells form a continuous arena without seams or a grid.
          fillAntialias: false,
        ),
        enableInteraction: false,
      );
      await map.addGeoJsonSource('walk-route', routeGeoJson(widget.points));
      await map.addLineLayer(
        'walk-route',
        'walk-route-halo',
        const LineLayerProperties(
          lineColor: '#FF673B',
          lineWidth: 10,
          lineOpacity: .18,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await map.addLineLayer(
        'walk-route',
        'walk-route-line',
        const LineLayerProperties(
          lineColor: '#FF673B',
          lineWidth: 4,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await map.addGeoJsonSource(
        'walk-markers',
        markerGeoJson(widget.points, widget.position),
      );
      await map.addCircleLayer(
        'walk-markers',
        'walk-markers-layer',
        const CircleLayerProperties(
          circleRadius: 7,
          circleColor: ['get', 'color'],
          circleStrokeWidth: 3,
          circleStrokeColor: '#FFFFFF',
        ),
        enableInteraction: false,
      );
      if (!mounted || generation != _generation) return;
      _ready = true;
      _queueDraw();
      final valid = widget.points.where((p) => p.accepted).toList();
      if (!widget.tracking && valid.length > 1) {
        final south = valid.map((p) => p.latitude).reduce(math.min);
        final north = valid.map((p) => p.latitude).reduce(math.max);
        final west = valid.map((p) => p.longitude).reduce(math.min);
        final east = valid.map((p) => p.longitude).reduce(math.max);
        if (north > south && east > west) {
          await map.moveCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(south, west),
                northeast: LatLng(north, east),
              ),
              top: 32,
              bottom: 32,
              left: 32,
              right: 32,
            ),
          );
        } else {
          _center();
        }
      } else if (widget.tracking) {
        _center();
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  void _idle() {
    if (!mounted) return;
    _scheduleTerritories();
    if (_loaded) return;
    _loadTimer?.cancel();
    setState(() {
      _loaded = true;
      _failed = false;
    });
  }

  void _scheduleTerritories() {
    if (!mounted) return;
    _territoryTimer?.cancel();
    _territoryTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_fetchTerritories()),
    );
  }

  Future<void> _fetchTerritories() async {
    if (!mounted) return;
    final account = ref.read(accountProvider);
    final backend = ref.read(backendProvider);
    if (!_ready ||
        _map == null ||
        account.demo ||
        account.local ||
        backend == null) {
      return;
    }
    final request = ++_request, generation = _generation;
    try {
      final bounds = await _map!.getVisibleRegion();
      final response = await backend.rpc(
        'get_territory_cells',
        params: {
          'p_west': bounds.southwest.longitude,
          'p_south': bounds.southwest.latitude,
          'p_east': bounds.northeast.longitude,
          'p_north': bounds.northeast.latitude,
        },
      );
      if (!mounted || request != _request || generation != _generation) return;
      final data = Map<String, dynamic>.from(response as Map);
      _viewportCells = [
        for (final f in data['features'] as List)
          TerritoryCell.fromFeature(Map<String, dynamic>.from(f as Map)),
      ];
      _queueDraw();
    } catch (_) {
      // Keep the most recent cells visible while connectivity is unavailable.
    }
  }

  void _retry() {
    if (ref.read(offlineMapProvider).hasError) {
      ref.invalidate(offlineMapProvider);
    }
    setState(() {
      _generation++;
      _map = null;
      _ready = false;
      _loaded = false;
      _failed = false;
      _viewportCells = null;
    });
    _watchLoad();
  }

  @override
  Widget build(BuildContext context) {
    final package = ref.watch(offlineMapProvider);
    final failed = _failed || package.hasError;
    return Stack(
      children: [
        if (package.hasValue)
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => _follow = false,
              child: ref.watch(mapSurfaceProvider)(
                MapSurfaceOptions(
                  key: ValueKey('real-map-$_generation'),
                  style: package.requireValue.style,
                  camera: CameraPosition(
                    target: LatLng(
                      widget.position?.latitude ?? AppConfig.cityLatitude,
                      widget.position?.longitude ?? AppConfig.cityLongitude,
                    ),
                    zoom: 14.5,
                  ),
                  created: (map) => _map = map,
                  styleLoaded: () => unawaited(_styleLoaded()),
                  idle: _idle,
                ),
              ),
            ),
          ),
        if (!_loaded || failed)
          Positioned(
            left: 16,
            right: 56,
            bottom: 24,
            child: PointerInterceptor(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (!failed)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t(failed ? 'mapLoadError' : 'mapLoading'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (failed)
                        IconButton(
                          onPressed: _retry,
                          tooltip: context.t('retry'),
                          icon: const Icon(Icons.refresh),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_loaded &&
            !failed &&
            widget.position != null &&
            outsideOfflineMap(
              widget.position!.latitude,
              widget.position!.longitude,
            ))
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: PointerInterceptor(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.t('offlineOutside'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TerritoryCell {
  const TerritoryCell({
    required this.id,
    required this.ring,
    required this.area,
    this.hp = 100,
    this.ownerTeam,
    this.color = '#FF673B',
  });
  final String id, color;
  final String? ownerTeam;
  final List<List<double>> ring;
  final double area;
  final int hp;

  Map<String, dynamic> toFeature() => {
    'type': 'Feature',
    'id': id,
    'properties': {
      'id': id,
      'area': area,
      'hp': hp,
      'owner_team_id': ownerTeam,
      'color': color,
    },
    'geometry': {
      'type': 'Polygon',
      'coordinates': [ring],
    },
  };

  factory TerritoryCell.fromFeature(Map<String, dynamic> feature) {
    final properties = Map<String, dynamic>.from(feature['properties'] as Map);
    final geometry = feature['geometry'] as Map;
    return TerritoryCell(
      id: (properties['id'] ?? feature['id']).toString(),
      ring: [
        for (final p in (geometry['coordinates'] as List).first as List)
          [for (final n in p as List) (n as num).toDouble()],
      ],
      area: (properties['area'] as num?)?.toDouble() ?? 0,
      hp: (properties['hp'] as num?)?.toInt() ?? 100,
      ownerTeam: properties['owner_team_id'] as String?,
      color: properties['color'] as String? ?? '#FF673B',
    );
  }
}

class CaptureResult {
  const CaptureResult({
    this.area = 0,
    this.cells = const [],
    this.status = 'open',
    this.attacked = 0,
    this.defended = 0,
    this.processedPoints = 0,
  });
  final double area;
  final List<TerritoryCell> cells;
  final String status;
  final int attacked, defended, processedPoints;
  Map<String, dynamic> get geoJson => territoryGeoJson(cells);
  Map<String, dynamic> toJson() => {
    'captured_area': area,
    'territory': geoJson,
    'capture_status': status,
    'attacked_cells': attacked,
    'defended_cells': defended,
    'processed_points': processedPoints,
  };
  factory CaptureResult.fromJson(Map<String, dynamic> json) {
    final territory = json['territory'] as Map?;
    return CaptureResult(
      area: (json['captured_area'] as num?)?.toDouble() ?? 0,
      status: json['capture_status'] as String? ?? 'open',
      attacked: (json['attacked_cells'] as num?)?.toInt() ?? 0,
      defended: (json['defended_cells'] as num?)?.toInt() ?? 0,
      processedPoints: (json['processed_points'] as num?)?.toInt() ?? 0,
      cells: [
        for (final feature in territory?['features'] as List? ?? const [])
          TerritoryCell.fromFeature(Map<String, dynamic>.from(feature as Map)),
      ],
    );
  }
}

Map<String, dynamic> territoryGeoJson(Iterable<TerritoryCell> cells) => {
  'type': 'FeatureCollection',
  'features': [for (final c in cells) c.toFeature()],
};

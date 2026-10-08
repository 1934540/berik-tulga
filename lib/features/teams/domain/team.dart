class TeamSummary {
  const TeamSummary({
    required this.name,
    required this.members,
    required this.area,
    required this.steps,
    required this.distance,
  });
  final String name;
  final int members, steps;
  final double area, distance;
  factory TeamSummary.fromJson(Map<String, dynamic> j) => TeamSummary(
    name: j['name'] as String,
    members: (j['members_count'] as num).toInt(),
    area: (j['territory_area'] as num).toDouble(),
    steps: (j['total_steps'] as num).toInt(),
    distance: (j['total_distance'] as num).toDouble(),
  );
}

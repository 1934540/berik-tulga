class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.teamId,
    this.gender,
    this.birthDate,
    this.territoryArea = 0,
  });
  final String id, name, username;
  final String? avatarUrl, teamId, gender, birthDate;
  final double territoryArea;
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: json['full_name'] as String? ?? '',
    username: json['username'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    teamId: json['team_id'] as String?,
    gender: json['gender'] as String?,
    birthDate: json['birth_date'] as String?,
    territoryArea: (json['total_area'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': name,
    'username': username,
    'avatar_url': avatarUrl,
    'team_id': teamId,
    'gender': gender,
    'birth_date': birthDate,
  };
}

class RankingEntry {
  const RankingEntry(this.name, this.score, this.color, {this.self = false});
  final String name;
  final double score;
  final int color;
  final bool self;
}

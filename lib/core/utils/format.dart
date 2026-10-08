String grouped(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]} ',
);
String durationLabel(Duration duration) {
  final s = duration.inSeconds.clamp(0, 999999);
  return '${(s ~/ 3600).toString().padLeft(2, '0')}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

String timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

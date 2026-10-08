Future<({String path, String url})> prepareOfflineMap(
  Map<String, dynamic> metadata,
) => throw UnsupportedError('Native map storage is unavailable on web.');

Future<String> saveOfflineStyle(String directory, String json) =>
    throw UnsupportedError('Native map storage is unavailable on web.');

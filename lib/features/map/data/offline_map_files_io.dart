import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<({String path, String url})> prepareOfflineMap(
  Map<String, dynamic> metadata,
) async {
  final support = await getApplicationSupportDirectory();
  // A new extract gets a new directory. Interrupted first-run copies are retried.
  final version = (metadata['package_sha256'] as String).substring(0, 12);
  final directory = Directory('${support.path}/offline_maps/$version');
  await directory.create(recursive: true);
  for (final entry
      in (metadata['files'] as List).cast<Map<String, dynamic>>()) {
    final name = entry['file'] as String;
    final target = File('${directory.path}/$name');
    if (await target.exists() && await target.length() == entry['bytes']) {
      continue;
    }
    final data = await rootBundle.load('assets/maps/$name');
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.part');
    await partial.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    await partial.rename(target.path);
  }
  return (
    path: directory.path,
    url:
        '${Uri.directory(directory.path).toString().replaceAll(RegExp(r'/+$'), '')}/',
  );
}

Future<String> saveOfflineStyle(String directory, String json) async {
  final file = File('$directory/style.json');
  if (!await file.exists() || await file.readAsString() != json) {
    final partial = File('${file.path}.part');
    await partial.writeAsString(json, flush: true);
    await partial.rename(file.path);
  }
  // The plugin accepts an absolute style path, not a file:// style URI.
  return file.path;
}

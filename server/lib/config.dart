import 'dart:io';

Map<String, String> loadConfig() {
  final result = <String, String>{};
  final file = File('../.env');
  if (file.existsSync()) {
    for (final line in file.readAsLinesSync()) {
      final at = line.indexOf('=');
      if (at > 0 && !line.trimLeft().startsWith('#')) {
        result[line.substring(0, at).trim()] = line.substring(at + 1).trim();
      }
    }
  }
  return {...result, ...Platform.environment};
}

final config = loadConfig();

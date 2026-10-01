import 'dart:io';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

Future<void> main() async {
  await io.serve(
    createStaticHandler('../build/web', defaultDocument: 'index.html'),
    '127.0.0.1',
    5173,
  );
  stdout.writeln('Flutter preview: http://localhost:5173');
}

import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/firebase_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseServices.initialize();
  runApp(const RentalApp());
}

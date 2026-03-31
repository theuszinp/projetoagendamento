import 'package:flutter/widgets.dart';

import 'src/app/app.dart';
import 'src/app/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = AppDependencies.production();
  await dependencies.initialize();

  runApp(MyApp(dependencies: dependencies));
}

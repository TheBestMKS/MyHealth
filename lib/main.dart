import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/notification_service.dart';
import 'src/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HealthNotificationService.instance.initialize();
  runApp(MyHealthApp(repository: FileHealthRepository()));
}

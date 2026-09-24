import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';
import 'src/error_log_service.dart';
import 'src/notification_service.dart';
import 'src/repository.dart';
import 'src/runtime_service.dart';

void main(List<String> arguments) {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final log = ErrorLogService.instance;
      await log.initialize();

      final previousFlutterError = FlutterError.onError;
      FlutterError.onError = (details) {
        unawaited(log.recordFlutterError(details));
        if (previousFlutterError != null) {
          previousFlutterError(details);
        } else {
          FlutterError.presentError(details);
        }
      };

      final previousPlatformError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        unawaited(
          log.recordError(error, stackTrace, source: 'Platform dispatcher'),
        );
        return previousPlatformError?.call(error, stackTrace) ?? true;
      };

      await log.recordInfo(
        'Application process started on ${Platform.operatingSystem}.',
        source: 'Lifecycle',
      );
      await HealthNotificationService.instance.initialize();
      await AppRuntimeService.instance.initialize();
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await windowManager.ensureInitialized();
        await windowManager.setPreventClose(true);
      }
      runApp(MyHealthApp(repository: FileHealthRepository()));
      if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
          arguments.contains('--background-start')) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await windowManager.minimize();
        });
      }
    },
    (error, stackTrace) {
      unawaited(
        ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Unhandled Dart zone',
        ),
      );
    },
  );
}

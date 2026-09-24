import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'error_log_service.dart';
import 'model.dart';
import 'notification_service.dart';
import 'repository.dart';

const _backgroundTaskName = 'myHealthBackgroundAnalysis';
const _backgroundTaskUniqueName =
    'ru.thebestmks.myhealth.backgroundAnalysis.v1';

@pragma('vm:entry-point')
void myHealthBackgroundDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    await ErrorLogService.instance.initialize();
    try {
      final repository = FileHealthRepository();
      final state = await repository.load();
      if (!state.settings.backgroundAnalysisEnabled) return true;
      await HealthNotificationService.instance.initialize();
      await HealthNotificationService.instance.sync(state);
      await AppRuntimeService.writeBackgroundHeartbeat(
        taskName: taskName,
        success: true,
        details: 'Напоминания и состояние локального сейфа проверены.',
      );
      return true;
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Background task: $taskName',
      );
      await AppRuntimeService.writeBackgroundHeartbeat(
        taskName: taskName,
        success: false,
        details: '$error',
      );
      return false;
    }
  });
}

class RuntimeStatus {
  const RuntimeStatus({
    required this.backgroundScheduled,
    required this.launchAtStartupEnabled,
    required this.lastBackgroundRun,
    required this.lastBackgroundResult,
  });

  final bool backgroundScheduled;
  final bool launchAtStartupEnabled;
  final DateTime? lastBackgroundRun;
  final String lastBackgroundResult;
}

class AppRuntimeService {
  AppRuntimeService._();

  static final instance = AppRuntimeService._();

  bool _initialized = false;
  bool? _lastBackgroundSetting;
  bool? _lastStartupSetting;

  bool get supportsDesktopStartup =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get supportsBackgroundTasks =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (supportsDesktopStartup) {
      launchAtStartup.setup(
        appName: 'Моё здоровье',
        appPath: Platform.resolvedExecutable,
        packageName: 'ru.thebestmks.myhealth',
        args: const ['--background-start'],
      );
    }
    if (supportsBackgroundTasks) {
      await Workmanager().initialize(myHealthBackgroundDispatcher);
    }
  }

  Future<void> apply(AppSettings settings) async {
    await initialize();
    if (supportsBackgroundTasks &&
        _lastBackgroundSetting != settings.backgroundAnalysisEnabled) {
      _lastBackgroundSetting = settings.backgroundAnalysisEnabled;
      try {
        if (settings.backgroundAnalysisEnabled) {
          await Workmanager().registerPeriodicTask(
            _backgroundTaskUniqueName,
            _backgroundTaskName,
            frequency: const Duration(hours: 1),
            initialDelay: const Duration(minutes: 15),
            existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
            constraints: Constraints(
              networkType: NetworkType.notRequired,
              requiresBatteryNotLow: true,
              requiresStorageNotLow: true,
            ),
          );
        } else {
          await Workmanager().cancelByUniqueName(_backgroundTaskUniqueName);
        }
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Background scheduler',
        );
      }
    }
    if (supportsDesktopStartup &&
        _lastStartupSetting != settings.launchAtStartup) {
      _lastStartupSetting = settings.launchAtStartup;
      try {
        if (settings.launchAtStartup) {
          await launchAtStartup.enable();
        } else {
          await launchAtStartup.disable();
        }
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Launch at startup',
        );
      }
    }
  }

  Future<RuntimeStatus> status() async {
    await initialize();
    var backgroundScheduled = false;
    if (supportsBackgroundTasks && Platform.isAndroid) {
      try {
        backgroundScheduled = await Workmanager().isScheduledByUniqueName(
          _backgroundTaskUniqueName,
        );
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Background task status',
        );
      }
    } else if (supportsBackgroundTasks) {
      backgroundScheduled = _lastBackgroundSetting == true;
    }
    var startupEnabled = false;
    if (supportsDesktopStartup) {
      try {
        startupEnabled = await launchAtStartup.isEnabled();
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Launch at startup status',
        );
      }
    }
    final heartbeat = await _readBackgroundHeartbeat();
    return RuntimeStatus(
      backgroundScheduled: backgroundScheduled,
      launchAtStartupEnabled: startupEnabled,
      lastBackgroundRun: DateTime.tryParse('${heartbeat['createdAt'] ?? ''}'),
      lastBackgroundResult: '${heartbeat['details'] ?? ''}',
    );
  }

  static Future<void> writeBackgroundHeartbeat({
    required String taskName,
    required bool success,
    required String details,
  }) async {
    try {
      final file = await _heartbeatFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'taskName': taskName,
          'success': success,
          'details': details,
          'createdAt': DateTime.now().toIso8601String(),
        }),
        flush: true,
      );
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _readBackgroundHeartbeat() async {
    try {
      final file = await _heartbeatFile();
      if (!await file.exists()) return const {};
      final value = jsonDecode(await file.readAsString());
      return value is Map<String, dynamic> ? value : const {};
    } catch (_) {
      return const {};
    }
  }

  static Future<File> _heartbeatFile() async {
    final root = await getApplicationSupportDirectory();
    return File(
      '${root.path}${Platform.pathSeparator}background_analysis_status.json',
    );
  }
}

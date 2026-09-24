import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ErrorLogSnapshot {
  const ErrorLogSnapshot({
    required this.contents,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String contents;
  final String path;
  final int sizeBytes;
  final DateTime? modifiedAt;

  bool get isEmpty => contents.trim().isEmpty;
}

class ErrorLogService {
  ErrorLogService({Directory? rootDirectory, this.maxFileBytes = 1024 * 1024})
    : _rootDirectory = rootDirectory;

  static final instance = ErrorLogService();

  static const _fileName = 'myhealth-errors.log';
  static const _previousFileName = 'myhealth-errors.previous.log';

  final Directory? _rootDirectory;
  final int maxFileBytes;

  Future<File>? _fileFuture;
  Future<void> _writeTail = Future<void>.value();

  Future<void> initialize() async {
    try {
      await _logFile();
    } catch (error) {
      debugPrint('Error log initialization failed: $error');
    }
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) {
    final context = details.context?.toDescription() ?? '';
    final library = details.library ?? '';
    final metadata = [
      if (library.isNotEmpty) 'library=$library',
      if (context.isNotEmpty) 'context=$context',
    ].join('; ');
    return recordError(
      details.exception,
      details.stack ?? StackTrace.current,
      source: metadata.isEmpty
          ? 'Flutter framework'
          : 'Flutter framework; $metadata',
    );
  }

  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String source = 'Application',
  }) {
    return _append(
      level: 'ERROR',
      source: source,
      message: error.toString(),
      stackTrace: stackTrace,
    );
  }

  Future<void> recordInfo(String message, {String source = 'Application'}) {
    return _append(level: 'INFO', source: source, message: message);
  }

  Future<ErrorLogSnapshot> read() async {
    await _writeTail;
    final file = await _logFile();
    final previous = _previousLogFile(file);
    final sections = <String>[];
    var sizeBytes = 0;
    DateTime? modifiedAt;

    for (final entry in <(String, File)>[
      ('PREVIOUS LOG', previous),
      ('CURRENT LOG', file),
    ]) {
      if (!await entry.$2.exists()) continue;
      final length = await entry.$2.length();
      sizeBytes += length;
      if (length == 0) continue;
      final stat = await entry.$2.stat();
      if (modifiedAt == null || stat.modified.isAfter(modifiedAt)) {
        modifiedAt = stat.modified;
      }
      sections.add(
        '================ ${entry.$1} ================\n'
        '${await entry.$2.readAsString(encoding: utf8)}',
      );
    }

    return ErrorLogSnapshot(
      contents: sections.join('\n'),
      path: file.path,
      sizeBytes: sizeBytes,
      modifiedAt: modifiedAt,
    );
  }

  Future<void> clear() {
    _writeTail = _writeTail.then((_) async {
      try {
        final file = await _logFile();
        final previous = _previousLogFile(file);
        if (await previous.exists()) await previous.delete();
        await file.writeAsString('', flush: true, encoding: utf8);
      } catch (error) {
        debugPrint('Error log cleanup failed: $error');
      }
    });
    return _writeTail;
  }

  Future<void> _append({
    required String level,
    required String source,
    required String message,
    StackTrace? stackTrace,
  }) {
    final entry = _formatEntry(
      level: level,
      source: source,
      message: message,
      stackTrace: stackTrace,
    );
    _writeTail = _writeTail.then((_) async {
      try {
        final file = await _logFile();
        final entryBytes = utf8.encode(entry).length;
        if (await file.exists() &&
            await file.length() + entryBytes > maxFileBytes) {
          final previous = _previousLogFile(file);
          if (await previous.exists()) await previous.delete();
          await file.rename(previous.path);
          await file.create(recursive: true);
        }
        await file.writeAsString(
          entry,
          mode: FileMode.append,
          flush: true,
          encoding: utf8,
        );
      } catch (error) {
        debugPrint('Error log write failed: $error');
      }
    });
    return _writeTail;
  }

  Future<File> _logFile() {
    return _fileFuture ??= _resolveLogFile();
  }

  Future<File> _resolveLogFile() async {
    Directory root;
    if (_rootDirectory case final configuredRoot?) {
      root = configuredRoot;
    } else {
      try {
        root = await getApplicationSupportDirectory();
      } catch (_) {
        root = Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}myhealth',
        );
      }
    }
    final directory = Directory('${root.path}${Platform.pathSeparator}logs');
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$_fileName');
    if (!await file.exists()) await file.create();
    return file;
  }

  File _previousLogFile(File current) {
    return File(
      '${current.parent.path}${Platform.pathSeparator}$_previousFileName',
    );
  }

  String _formatEntry({
    required String level,
    required String source,
    required String message,
    StackTrace? stackTrace,
  }) {
    final safeSource = _limit(source.replaceAll(RegExp(r'[\r\n]+'), ' '), 500);
    final safeMessage = _limit(message, 16000);
    final safeStack = stackTrace == null ? '' : _limit('$stackTrace', 32000);
    final timestamp = DateTime.now().toUtc().toIso8601String();
    return '[$timestamp] $level [$safeSource]\n'
        '$safeMessage\n'
        '${safeStack.isEmpty ? '' : '$safeStack\n'}'
        '\n';
  }

  String _limit(String value, int limit) {
    if (value.length <= limit) return value;
    return '${value.substring(0, limit)}\n... truncated ...';
  }
}

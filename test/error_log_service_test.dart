import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/error_log_service.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'myhealth-error-log-test-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('stores UTF-8 errors, source and stack trace', () async {
    final service = ErrorLogService(rootDirectory: temporaryDirectory);
    await service.initialize();
    await service.recordError(
      StateError('Ошибка распознавания рецепта'),
      StackTrace.fromString('frame one\nframe two'),
      source: 'Фото и OCR',
    );

    final snapshot = await service.read();

    expect(snapshot.contents, contains('Ошибка распознавания рецепта'));
    expect(snapshot.contents, contains('Фото и OCR'));
    expect(snapshot.contents, contains('frame one'));
    expect(snapshot.path, endsWith('myhealth-errors.log'));
    expect(snapshot.sizeBytes, greaterThan(0));
    expect(snapshot.modifiedAt, isNotNull);
  });

  test(
    'records Flutter details and rotates without unbounded growth',
    () async {
      final service = ErrorLogService(
        rootDirectory: temporaryDirectory,
        maxFileBytes: 420,
      );
      await service.recordFlutterError(
        FlutterErrorDetails(
          exception: StateError('build failed'),
          stack: StackTrace.fromString('widget frame'),
          library: 'widgets',
          context: ErrorDescription('while building dashboard'),
        ),
      );
      for (var index = 0; index < 8; index++) {
        await service.recordError(
          StateError('failure $index ${List.filled(90, 'x').join()}'),
          StackTrace.fromString('trace $index'),
          source: 'rotation test',
        );
      }

      final snapshot = await service.read();

      expect(snapshot.contents, contains('CURRENT LOG'));
      expect(snapshot.contents, contains('PREVIOUS LOG'));
      expect(snapshot.contents, contains('failure 7'));
      expect(snapshot.sizeBytes, lessThan(1400));
    },
  );

  test('clear removes current and rotated entries', () async {
    final service = ErrorLogService(
      rootDirectory: temporaryDirectory,
      maxFileBytes: 180,
    );
    await service.recordInfo('first entry');
    await service.recordError(
      StateError(List.filled(240, 'y').join()),
      StackTrace.current,
    );
    await service.clear();

    final snapshot = await service.read();

    expect(snapshot.isEmpty, isTrue);
    expect(snapshot.sizeBytes, 0);
    expect(await File(snapshot.path).exists(), isTrue);
  });
}

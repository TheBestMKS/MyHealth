import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_health/src/error_log_service.dart';
import 'package:my_health/src/screens.dart' show showErrorLogDialog;

void main() {
  late Directory temporaryDirectory;
  late ErrorLogService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'myhealth-error-log-dialog-test-',
    );
    service = ErrorLogService(rootDirectory: temporaryDirectory);
    await service.recordError(
      StateError('Ошибка для копирования'),
      StackTrace.fromString('dialog test frame'),
      source: 'Widget test',
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  testWidgets('opens, renders and copies the local error log', (tester) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showErrorLogDialog(context, service: service),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await _pumpUntilFound(tester, find.byKey(const Key('error_log_contents')));

    expect(find.byKey(const Key('error_log_title')), findsOneWidget);
    expect(find.byKey(const Key('error_log_contents')), findsOneWidget);
    expect(find.textContaining('Ошибка для копирования'), findsOneWidget);

    await tester.tap(find.byKey(const Key('error_log_copy_button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('error_log_copied_notice')),
    );

    expect(copiedText, contains('Ошибка для копирования'));
    expect(find.byKey(const Key('error_log_copied_notice')), findsOneWidget);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for the expected log viewer widget.');
}

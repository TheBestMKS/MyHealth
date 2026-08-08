import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_health/src/food_recognition_service.dart';
import 'package:my_health/src/media_import_service.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled Food-101 ONNX model performs native inference', (
    tester,
  ) async {
    final image = File(
      '${Directory.current.path}${Platform.pathSeparator}icon${Platform.pathSeparator}logo.png',
    );
    expect(await image.exists(), isTrue);

    final predictions = await FoodRecognitionService.instance.classifyFile(
      image.path,
    );

    expect(predictions, hasLength(3));
    expect(predictions.first.confidence, greaterThan(0));
    expect(
      predictions.first.confidence,
      greaterThanOrEqualTo(predictions.last.confidence),
    );
  });

  testWidgets('PDFium extracts multiple laboratory rows from a PDF', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'my_health_pdf_integration_',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final document = pw.Document();
    document.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Glucose  5.1 mmol/l  3.9-6.1'),
            pw.Text('Hemoglobin  145 g/l  130-170'),
          ],
        ),
      ),
    );
    final file = File('${directory.path}${Platform.pathSeparator}labs.pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    final service = MediaImportService(
      filePicker: ({String kind = 'file'}) async =>
          ImportedMedia(path: file.path, name: 'labs.pdf', kind: kind),
    );

    final results = await service.importForRecognitionBatch(
      source: 'OCR анализа',
      requiresMedicalReview: true,
    );

    expect(results, hasLength(2));
    expect(results.first.metadata['marker'], 'Glucose');
    expect(results.last.metadata['value'], '145');
  });
}

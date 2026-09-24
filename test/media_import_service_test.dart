import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_health/src/food_recognition_service.dart';
import 'package:my_health/src/media_import_service.dart';

void main() {
  test(
    'falls back to file import when camera capture is unsupported',
    () async {
      String? requestedKind;
      final service = MediaImportService(
        picker: _UnsupportedCameraPicker(),
        filePicker: ({String kind = 'file'}) async {
          requestedKind = kind;
          return ImportedMedia(
            path: 'fallback.jpg',
            name: 'fallback.jpg',
            kind: kind,
          );
        },
      );

      final media = await service.captureCameraImage();

      expect(requestedKind, 'camera-fallback');
      expect(media?.kind, 'camera-fallback');
      expect(media?.name, 'fallback.jpg');
    },
  );

  test(
    'persists file picker bytes when a platform path is unavailable',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'my_health_media_test_',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final bytes = Uint8List.fromList(utf8.encode('калории 320 белок 24'));
      final service = MediaImportService(
        supportDirectory: () async => root,
        filePickerResult: () async => FilePickerResult([
          PlatformFile(name: 'meal.txt', size: bytes.length, bytes: bytes),
        ]),
      );

      final media = await service.pickImageFile();

      expect(media, isNotNull);
      expect(media?.kind, 'file');
      expect(media?.name, 'meal.txt');
      expect(await File(media!.path).readAsString(), 'калории 320 белок 24');
    },
  );

  test('extracts complete food label values and their 100 g basis', () async {
    final root = await Directory.systemTemp.createTemp(
      'my_health_food_ocr_test_',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final bytes = Uint8List.fromList(
      utf8.encode(
        'Порция 40 г. На 100 г: 250 ккал, белок 10 г, жиры 8 г, '
        'углеводы 35 г, из них сахара 7 г, клетчатка 5 г, соль 1,2 г.',
      ),
    );
    final service = MediaImportService(
      supportDirectory: () async => root,
      filePickerResult: () async => FilePickerResult([
        PlatformFile(name: 'label.txt', size: bytes.length, bytes: bytes),
      ]),
    );

    final result = await service.importForRecognition(
      source: 'фото еды',
      requiresMedicalReview: false,
    );

    expect(result, isNotNull);
    expect(result!.metadata['calories'], '250');
    expect(result.metadata['portionGrams'], '40');
    expect(result.metadata['nutritionBasisGrams'], '100');
    expect(result.metadata['sugar'], '7');
    expect(result.metadata['fiber'], '5');
    expect(result.metadata['salt'], '1,2');
  });

  test(
    'extracts multiple laboratory rows into separate confirmations',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'my_health_lab_batch_test_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final bytes = Uint8List.fromList(
        utf8.encode(
          'Глюкоза  5,1 ммоль/л  3,9-6,1\n'
          'Гемоглобин  145 г/л  130-170\n',
        ),
      );
      final service = MediaImportService(
        supportDirectory: () async => root,
        filePickerResult: () async => FilePickerResult([
          PlatformFile(
            name: 'laboratory.txt',
            size: bytes.length,
            bytes: bytes,
          ),
        ]),
      );

      final results = await service.importForRecognitionBatch(
        source: 'OCR анализа',
        requiresMedicalReview: true,
      );

      expect(results, hasLength(2));
      expect(results.map((item) => item.metadata['marker']), [
        'Глюкоза',
        'Гемоглобин',
      ]);
      expect(results.first.metadata['reference'], '3,9-6,1');
    },
  );

  test(
    'merges injected visual prediction with confirmation metadata',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'my_health_visual_food_test_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final bytes = Uint8List.fromList([0, 1, 2, 3]);
      const estimate = FoodClassEstimate(
        label: 'pizza',
        titleRu: 'Пицца',
        servingGrams: 250,
        caloriesPer100Grams: 266,
        proteinPer100Grams: 11,
        fatPer100Grams: 10,
        carbsPer100Grams: 33,
      );
      final service = MediaImportService(
        supportDirectory: () async => root,
        filePickerResult: () async => FilePickerResult([
          PlatformFile(name: 'meal.jpg', size: bytes.length, bytes: bytes),
        ]),
        foodClassifier: (_) async => const [
          FoodVisualPrediction(
            label: 'pizza',
            confidence: 0.82,
            estimate: estimate,
          ),
        ],
      );

      final result = await service.importForRecognition(
        source: 'фото еды',
        requiresMedicalReview: false,
      );

      expect(result, isNotNull);
      expect(result!.metadata['visualLabel'], 'pizza');
      expect(result.metadata['nutritionEstimate'], 'true');
      expect(result.metadata['calories'], '266');
      expect(result.metadata['portionGrams'], '250');
      expect(result.confidence, closeTo(0.82, 0.0001));
    },
  );

  test('extracts readable text from DOCX and RTF attachments', () async {
    final root = await Directory.systemTemp.createTemp(
      'my_health_documents_test_',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'word/document.xml',
          '<?xml version="1.0" encoding="UTF-8"?>'
              '<w:document xmlns:w="urn:test"><w:body><w:p>'
              '<w:r><w:t>Принимать после еды</w:t></w:r>'
              '</w:p></w:body></w:document>',
        ),
      );
    final docx = File('${root.path}/recipe.docx');
    await docx.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    final rtf = File('${root.path}/note.rtf');
    await rtf.writeAsString(
      r"{\rtf1\ansi Назначение\par Доза 5 мг}",
      flush: true,
    );
    final service = MediaImportService(supportDirectory: () async => root);

    final docxText = await service.extractLocalText(
      ImportedMedia(path: docx.path, name: 'recipe.docx', kind: 'attachment'),
    );
    final rtfText = await service.extractLocalText(
      ImportedMedia(path: rtf.path, name: 'note.rtf', kind: 'attachment'),
    );

    expect(docxText, contains('Принимать после еды'));
    expect(rtfText, contains('Назначение'));
    expect(rtfText, contains('Доза 5 мг'));
  });
}

class _UnsupportedCameraPicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    throw UnsupportedError('camera is not available on this platform');
  }
}

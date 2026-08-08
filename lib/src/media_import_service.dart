import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'food_recognition_service.dart';
import 'model.dart';

class ImportedMedia {
  const ImportedMedia({
    required this.path,
    required this.name,
    required this.kind,
  });

  final String path;
  final String name;
  final String kind;
}

class MediaImportService {
  MediaImportService({
    ImagePicker? picker,
    Future<ImportedMedia?> Function({String kind})? filePicker,
    Future<FilePickerResult?> Function()? filePickerResult,
    Future<Directory> Function()? supportDirectory,
    Future<List<FoodVisualPrediction>> Function(String path)? foodClassifier,
  }) : _picker = picker ?? ImagePicker(),
       _filePicker = filePicker,
       _filePickerResult = filePickerResult,
       _supportDirectory = supportDirectory,
       _foodClassifier = foodClassifier;

  final ImagePicker _picker;
  final Future<ImportedMedia?> Function({String kind})? _filePicker;
  final Future<FilePickerResult?> Function()? _filePickerResult;
  final Future<Directory> Function()? _supportDirectory;
  final Future<List<FoodVisualPrediction>> Function(String path)?
  _foodClassifier;

  Future<ImportedMedia?> pickImageFile({String kind = 'file'}) async {
    final override = _filePicker;
    if (override != null) {
      return override(kind: kind);
    }
    final filePickerResult = _filePickerResult;
    final result = filePickerResult == null
        ? await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              'jpg',
              'jpeg',
              'png',
              'heic',
              'webp',
              'bmp',
              'tif',
              'tiff',
              'pdf',
              'txt',
              'csv',
            ],
            allowMultiple: false,
            withData: true,
          )
        : await filePickerResult();
    final file = result?.files.single;
    final path = file?.path;
    if (file == null) {
      return null;
    }
    if (path != null) {
      return _persist(File(path), file.name, kind);
    }
    final bytes = file.bytes;
    if (bytes == null) {
      return null;
    }
    return _persistBytes(bytes, file.name, kind);
  }

  Future<ImportedMedia?> captureCameraImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) {
        return null;
      }
      return _persist(File(image.path), image.name, 'camera');
    } catch (_) {
      return pickImageFile(kind: 'camera-fallback');
    }
  }

  Future<RecognitionCandidate?> importForRecognition({
    required String source,
    required bool requiresMedicalReview,
    bool camera = false,
  }) async {
    final candidates = await importForRecognitionBatch(
      source: source,
      requiresMedicalReview: requiresMedicalReview,
      camera: camera,
    );
    return candidates.firstOrNull;
  }

  Future<List<RecognitionCandidate>> importForRecognitionBatch({
    required String source,
    required bool requiresMedicalReview,
    bool camera = false,
  }) async {
    final media = camera ? await captureCameraImage() : await pickImageFile();
    if (media == null) {
      return const [];
    }
    final extractedText = await _extractLocalText(media);
    final parsedMetadata = requiresMedicalReview
        ? _labMetadataList(extractedText)
        : [_foodMetadata(extractedText)];
    if (requiresMedicalReview) {
      return [
        for (final metadata in parsedMetadata)
          _candidate(
            media: media,
            source: source,
            requiresMedicalReview: true,
            metadata: metadata,
            confidence: _hasCompleteLabValues(metadata) ? 0.68 : 0.25,
          ),
      ];
    }

    final foodMetadata = parsedMetadata.first;
    var metadata = Map<String, String>.from(foodMetadata);
    var visualConfidence = 0.0;
    if (_isLikelyImage(media.name)) {
      try {
        final classifier =
            _foodClassifier ?? FoodRecognitionService.instance.classifyFile;
        final predictions = await classifier(media.path);
        if (predictions.isNotEmpty) {
          visualConfidence = predictions.first.confidence;
          metadata = {
            ...foodVisualMetadata(predictions),
            ...foodMetadata.entries
                .where((entry) => entry.value.trim().isNotEmpty)
                .fold<Map<String, String>>(
                  {},
                  (result, entry) => result..[entry.key] = entry.value,
                ),
          };
        }
      } catch (error) {
        metadata['visualStatus'] =
            'Визуальный анализ не выполнен: ${_shortError(error)}';
      }
    }
    final hasStructuredData = metadata.entries.any(
      (item) =>
          !const {'rawText', 'mealKind', 'visualStatus'}.contains(item.key) &&
          item.value.trim().isNotEmpty,
    );
    final confidence = visualConfidence > 0
        ? visualConfidence
        : hasStructuredData
        ? 0.55
        : 0.15;
    return [
      _candidate(
        media: media,
        source: source,
        requiresMedicalReview: false,
        metadata: metadata,
        confidence: confidence,
      ),
    ];
  }

  RecognitionCandidate _candidate({
    required ImportedMedia media,
    required String source,
    required bool requiresMedicalReview,
    required Map<String, String> metadata,
    required double confidence,
  }) => RecognitionCandidate(
    id: newId(),
    source: source,
    title: _suggestTitle(media, source, metadata),
    confidence: confidence,
    requiresMedicalReview: requiresMedicalReview,
    filePath: media.path,
    kind: media.kind,
    createdAt: todayKey(),
    metadata: metadata,
  );

  Future<ImportedMedia> _persist(
    File source,
    String originalName,
    String kind,
  ) async {
    final mediaDir = await _mediaDirectory();
    await mediaDir.create(recursive: true);
    final target = _targetFile(mediaDir, originalName);
    await source.copy(target.path);
    return ImportedMedia(path: target.path, name: originalName, kind: kind);
  }

  Future<ImportedMedia> _persistBytes(
    Uint8List bytes,
    String originalName,
    String kind,
  ) async {
    final mediaDir = await _mediaDirectory();
    await mediaDir.create(recursive: true);
    final target = _targetFile(mediaDir, originalName);
    await target.writeAsBytes(bytes, flush: true);
    return ImportedMedia(path: target.path, name: originalName, kind: kind);
  }

  Future<Directory> _mediaDirectory() async {
    final supportDirectory = _supportDirectory;
    final root = supportDirectory == null
        ? await getApplicationSupportDirectory()
        : await supportDirectory();
    return Directory('${root.path}${Platform.pathSeparator}media');
  }

  File _targetFile(Directory mediaDir, String originalName) {
    final safeName = originalName.replaceAll(
      RegExp(r'[^a-zA-Z0-9А-Яа-я._-]+'),
      '_',
    );
    return File(
      '${mediaDir.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
  }

  Future<String> _extractLocalText(ImportedMedia media) async {
    final extension = media.name.split('.').last.toLowerCase();
    final fileNameText = media.name
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[_-]+'), ' ');
    if (extension == 'txt' || extension == 'csv') {
      try {
        final text = await File(media.path).readAsString();
        return '$fileNameText\n$text';
      } catch (_) {
        return fileNameText;
      }
    }
    if (extension == 'pdf') {
      final pdfText = await _extractPdfText(media);
      return pdfText.isEmpty ? fileNameText : '$fileNameText\n$pdfText';
    }
    final ocrText = await _extractImageText(media);
    if (ocrText.isNotEmpty) {
      return '$fileNameText\n$ocrText';
    }
    return fileNameText;
  }

  Future<String> _extractPdfText(ImportedMedia media) async {
    PdfDocument? document;
    try {
      await pdfrxFlutterInitialize();
      document = await PdfDocument.openFile(media.path);
      final pages = <String>[];
      final tempDirectory = await getTemporaryDirectory();
      for (final page in document.pages) {
        var text = (await page.loadText())?.fullText.trim() ?? '';
        if (text.isEmpty) {
          final scale = 180 / 72;
          final rendered = await page.render(
            fullWidth: page.width * scale,
            fullHeight: page.height * scale,
          );
          if (rendered != null) {
            final image = rendered.createImageNF();
            final target = File(
              '${tempDirectory.path}${Platform.pathSeparator}my_health_pdf_${DateTime.now().microsecondsSinceEpoch}_${page.pageNumber}.png',
            );
            try {
              await target.writeAsBytes(
                image_lib.encodePng(image),
                flush: true,
              );
              text = await _extractImageText(
                ImportedMedia(
                  path: target.path,
                  name: target.uri.pathSegments.last,
                  kind: 'pdf-page',
                ),
              );
            } finally {
              rendered.dispose();
              if (await target.exists()) await target.delete();
            }
          }
        }
        if (text.trim().isNotEmpty) {
          pages.add('Страница ${page.pageNumber}\n${text.trim()}');
        }
      }
      return pages.join('\n');
    } catch (_) {
      return _extractPdfWithSystemTool(media.path);
    } finally {
      await document?.dispose();
    }
  }

  Future<String> _extractPdfWithSystemTool(String path) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return '';
    }
    try {
      final result = await Process.run('pdftotext', [
        '-layout',
        '-enc',
        'UTF-8',
        path,
        '-',
      ]);
      return result.exitCode == 0 ? '${result.stdout}'.trim() : '';
    } catch (_) {
      return '';
    }
  }

  Future<String> _extractImageText(ImportedMedia media) async {
    if (!_isLikelyImage(media.name) && media.kind != 'camera') {
      return '';
    }
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      try {
        return (await FlutterTesseractOcr.extractText(
          media.path,
          language: 'rus+eng',
          args: const {'psm': '4', 'preserve_interword_spaces': '1'},
        )).trim();
      } catch (_) {
        return '';
      }
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      try {
        final result = await Process.run('tesseract', [
          media.path,
          'stdout',
          '-l',
          'rus+eng',
          '--psm',
          '4',
        ]);
        if (result.exitCode == 0) {
          return '${result.stdout}'.trim();
        }
      } catch (_) {
        return '';
      }
    }
    return '';
  }

  bool _isLikelyImage(String name) {
    final extension = name.split('.').last.toLowerCase();
    return const {
      'jpg',
      'jpeg',
      'png',
      'heic',
      'webp',
      'bmp',
      'tif',
      'tiff',
    }.contains(extension);
  }

  Map<String, String> _foodMetadata(String text) {
    final normalized = text.toLowerCase();
    return {
      'rawText': text,
      'calories': _firstMatch(normalized, [
        RegExp(r'(\d{2,4})\s*(?:ккал|kcal|cal)'),
        RegExp(r'(?:калории|calories)\D{0,12}(\d{2,4})'),
      ]),
      'protein': _firstMatch(normalized, [
        RegExp(r'(?:белок|protein|протеин|б)\D{0,10}(\d{1,3})'),
      ]),
      'carbs': _firstMatch(normalized, [
        RegExp(r'(?:углеводы|carbs|у)\D{0,10}(\d{1,3})'),
      ]),
      'fat': _firstMatch(normalized, [
        RegExp(r'(?:жиры|fat|ж)\D{0,10}(\d{1,3})'),
      ]),
      'sugar': _firstMatch(normalized, [
        RegExp(
          r'(?:сахара|сахар|sugars?|из них сахара)\D{0,12}(\d{1,3}(?:[,.]\d+)?)',
        ),
      ]),
      'fiber': _firstMatch(normalized, [
        RegExp(
          r'(?:клетчатка|пищевые волокна|fibre|fiber)\D{0,12}(\d{1,3}(?:[,.]\d+)?)',
        ),
      ]),
      'salt': _firstMatch(normalized, [
        RegExp(r'(?:соль|salt)\D{0,10}(\d{1,3}(?:[,.]\d+)?)'),
      ]),
      'portionGrams': _firstMatch(normalized, [
        RegExp(
          r'(?:масса|вес|порция|net weight|serving)\D{0,12}(\d{1,4})\s*(?:г|g)',
        ),
        RegExp(r'(\d{1,4})\s*(?:г|g)\b'),
      ]),
      'mealKind': _mealKind(normalized),
      'nutritionBasisGrams':
          RegExp(r'(?:на|per)\s*100\s*(?:г|g)').hasMatch(normalized)
          ? '100'
          : '',
    };
  }

  Map<String, String> _labMetadata(String text) {
    final normalized = text.toLowerCase();
    final marker = _firstMatch(normalized, [
      RegExp(
        r'(глюкоза|холестерин|гемоглобин|ферритин|витамин\s*d|ттг|с-?реактивный\s+белок|crp|glucose|cholesterol|hemoglobin|ferritin)',
      ),
    ]);
    return {
      'rawText': text,
      'marker': marker.isEmpty ? 'показатель из OCR' : marker,
      'value': _firstMatch(normalized, [
        RegExp(r'(?:значение|value|result)\D{0,12}(\d+(?:[,.]\d+)?)'),
        RegExp(r'(\d+(?:[,.]\d+)?)\s*(?:ммоль/л|мг/дл|г/л|нг/мл|мед/л|ме/л|%)'),
      ]),
      'unit': _firstMatch(normalized, [
        RegExp(r'(ммоль/л|мг/дл|г/л|мкг/л|нг/мл|мед/л|ме/л|%)'),
      ]),
      'reference': _firstMatch(normalized, [
        RegExp(r'(?:референс|норма|reference)\D{0,12}([\d,.]+ ?[-–] ?[\d,.]+)'),
      ]),
    };
  }

  List<Map<String, String>> _labMetadataList(String text) {
    final normalized = text.replaceAll('\r', '\n');
    final rowPattern = RegExp(
      r'^\s*([A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё0-9 ()_+.,%/-]{1,80}?)\s{1,}'
      r'([<>]?\s*\d+(?:[,.]\d+)?)\s*'
      r'(ммоль/л|мкмоль/л|мг/дл|мг/л|г/л|г/дл|мкг/л|нг/мл|пг/мл|мед/л|ме/л|ед/л|mmol/l|umol/l|µmol/l|mg/dl|mg/l|g/l|g/dl|µg/l|ug/l|ng/ml|pg/ml|iu/l|u/l|10\^?[*x×]?\d+/л|фл|fl|пг|pg|%)'
      r'(?:\s+(?:референс|норма|reference)?\s*([<>]?\s*\d+(?:[,.]\d+)?(?:\s*[-–]\s*\d+(?:[,.]\d+)?)?))?',
      caseSensitive: false,
      multiLine: true,
    );
    final results = <Map<String, String>>[];
    final seen = <String>{};
    for (final match in rowPattern.allMatches(normalized)) {
      final marker = (match.group(1) ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final value = (match.group(2) ?? '').replaceAll(' ', '').trim();
      final unit = (match.group(3) ?? '').trim();
      final reference = (match.group(4) ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (marker.length < 2 ||
          marker.toLowerCase().startsWith('страница') ||
          !seen.add('${marker.toLowerCase()}|$value|$unit')) {
        continue;
      }
      results.add({
        'rawText': text,
        'marker': marker,
        'value': value,
        'unit': unit,
        if (reference.isNotEmpty) 'reference': reference,
      });
      if (results.length >= 80) break;
    }
    if (results.isNotEmpty) return results;
    return [_labMetadata(text)];
  }

  bool _hasCompleteLabValues(Map<String, String> metadata) =>
      (metadata['marker'] ?? '').isNotEmpty &&
      (metadata['value'] ?? '').isNotEmpty &&
      (metadata['unit'] ?? '').isNotEmpty;

  String _firstMatch(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)?.trim() ?? '';
      }
    }
    return '';
  }

  String _mealKind(String text) {
    if (text.contains('завтрак') || text.contains('breakfast')) {
      return 'завтрак';
    }
    if (text.contains('ужин') || text.contains('dinner')) {
      return 'ужин';
    }
    if (text.contains('перекус') || text.contains('snack')) {
      return 'перекус';
    }
    return 'обед';
  }

  String _suggestTitle(
    ImportedMedia media,
    String source,
    Map<String, String> metadata,
  ) {
    if (source.contains('еда')) {
      final visualTitle = metadata['visualTitle'] ?? '';
      if (visualTitle.isNotEmpty) {
        return '$visualTitle · визуальная оценка';
      }
      final calories = metadata['calories'] ?? '';
      if (calories.isNotEmpty) {
        return 'Фото еды: ${media.name}, около $calories ккал';
      }
      return 'Фото еды: ${media.name}. Проверьте блюдо, массу и калории вручную.';
    }
    if (source.contains('анализ')) {
      final marker = metadata['marker'] ?? '';
      final value = metadata['value'] ?? '';
      final unit = metadata['unit'] ?? '';
      if (value.isNotEmpty) {
        return '$marker: $value $unit'.trim();
      }
      return 'Файл анализа: ${media.name}. Проверьте показатель, единицы и референсы вручную.';
    }
    return 'Файл: ${media.name}. Требуется ручное подтверждение.';
  }

  String _shortError(Object error) {
    final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 180 ? text : '${text.substring(0, 180)}...';
  }
}

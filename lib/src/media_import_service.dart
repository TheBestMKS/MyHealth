import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image_lib;
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

import 'error_log_service.dart';
import 'food_recognition_service.dart';
import 'model.dart';
import 'prescription_parser.dart';

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

class AttachmentAnalysis {
  const AttachmentAnalysis({
    required this.media,
    required this.mimeType,
    required this.extractedText,
    required this.description,
    required this.thumbnailPath,
    required this.originalBytes,
    required this.storedBytes,
  });

  final ImportedMedia media;
  final String mimeType;
  final String extractedText;
  final String description;
  final String thumbnailPath;
  final int originalBytes;
  final int storedBytes;

  bool get isImage => mimeType.startsWith('image/');
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

  Future<ImportedMedia?> pickAnyFile({String kind = 'attachment'}) async {
    final override = _filePicker;
    if (override != null) return override(kind: kind);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return null;
    if (file.path != null && file.path!.isNotEmpty) {
      return _persist(File(file.path!), file.name, kind);
    }
    if (file.bytes != null) {
      return _persistBytes(file.bytes!, file.name, kind);
    }
    return null;
  }

  Future<ImportedMedia?> captureCameraImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) {
        return null;
      }
      return _persist(File(image.path), image.name, 'camera');
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Camera capture; falling back to file picker',
      );
      return pickImageFile(kind: 'camera-fallback');
    }
  }

  Future<AttachmentAnalysis> prepareAttachment(ImportedMedia source) async {
    try {
      final sourceFile = File(source.path);
      if (!await sourceFile.exists()) {
        throw FileSystemException('Файл вложения не найден', source.path);
      }
      final originalBytes = await sourceFile.length();
      final optimized = _isLikelyImage(source.name)
          ? await _optimizeImage(source)
          : source;
      final mimeType =
          lookupMimeType(
            optimized.name,
            headerBytes: await _headerBytes(optimized.path),
          ) ??
          'application/octet-stream';
      final extractedText = await _extractLocalText(optimized);
      final thumbnailPath = _isLikelyImage(optimized.name)
          ? await _createThumbnail(optimized)
          : '';
      final storedBytes = await File(optimized.path).length();
      final description = _attachmentDescription(
        optimized,
        mimeType,
        extractedText,
      );
      return AttachmentAnalysis(
        media: optimized,
        mimeType: mimeType,
        extractedText: extractedText,
        description: description,
        thumbnailPath: thumbnailPath,
        originalBytes: originalBytes,
        storedBytes: storedBytes,
      );
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Attachment preparation; ${source.name}; ${source.path}',
      );
      rethrow;
    }
  }

  Future<String> extractLocalText(ImportedMedia media) =>
      _extractLocalText(media);

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
    return recognizeExistingMedia(
      media,
      source: source,
      requiresMedicalReview: requiresMedicalReview,
    );
  }

  Future<List<RecognitionCandidate>> recognizeExistingMedia(
    ImportedMedia media, {
    required String source,
    required bool requiresMedicalReview,
  }) async {
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
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Food image recognition',
        );
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

  Future<List<RecognitionCandidate>> importPrescriptionBatch({
    bool camera = false,
  }) async {
    final media = camera ? await captureCameraImage() : await pickImageFile();
    if (media == null) return const [];
    return recognizeExistingPrescription(media);
  }

  Future<List<RecognitionCandidate>> recognizeExistingPrescription(
    ImportedMedia media,
  ) async {
    final extractedText = await _extractLocalText(media);
    final drafts = parsePrescriptionText(extractedText);
    return [
      for (final draft in drafts)
        _candidate(
          media: media,
          source: 'рецепт',
          requiresMedicalReview: true,
          metadata: draft.toMetadata(),
          confidence: draft.confidence,
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

  Future<List<int>> _headerBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    final reader = await file.open();
    try {
      return reader.read(32);
    } finally {
      await reader.close();
    }
  }

  Future<ImportedMedia> _optimizeImage(ImportedMedia media) async {
    final source = File(media.path);
    try {
      final original = await source.readAsBytes();
      final extension = media.name.split('.').last.toLowerCase();
      final transformed = await compute(_optimizeImageBytes, {
        'bytes': original,
        'extension': extension,
      });
      final encoded = transformed['bytes'] as Uint8List?;
      if (encoded == null) {
        return media;
      }
      final outputExtension = transformed['extension']! as String;
      final baseName = media.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      final output = File(
        '${source.parent.path}${Platform.pathSeparator}'
        '${DateTime.now().microsecondsSinceEpoch}_${_safeMediaName(baseName)}_optimized.$outputExtension',
      );
      await output.writeAsBytes(encoded, flush: true);
      if (await source.exists()) await source.delete();
      return ImportedMedia(
        path: output.path,
        name: '$baseName.$outputExtension',
        kind: media.kind,
      );
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Image optimization',
      );
      return media;
    }
  }

  Future<String> _createThumbnail(ImportedMedia media) async {
    try {
      final encoded = await compute(
        _createThumbnailBytes,
        await File(media.path).readAsBytes(),
      );
      if (encoded == null) return '';
      final target = File(
        '${File(media.path).parent.path}${Platform.pathSeparator}'
        '${DateTime.now().microsecondsSinceEpoch}_thumbnail.jpg',
      );
      await target.writeAsBytes(encoded, flush: true);
      return target.path;
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Image thumbnail creation',
      );
      return '';
    }
  }

  String _attachmentDescription(
    ImportedMedia media,
    String mimeType,
    String extractedText,
  ) {
    final type = mimeType.startsWith('image/')
        ? 'Изображение'
        : mimeType == 'application/pdf'
        ? 'PDF-документ'
        : 'Файл';
    final cleanText = extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final excerpt = cleanText.length > 700
        ? '${cleanText.substring(0, 700)}…'
        : cleanText;
    return excerpt.isEmpty
        ? '$type «${media.name}». Текст для анализа не найден.'
        : '$type «${media.name}». Извлечённый текст: $excerpt';
  }

  String _safeMediaName(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9А-Яа-яЁё._-]+'), '_');

  Future<String> _extractLocalText(ImportedMedia media) async {
    final extension = media.name.split('.').last.toLowerCase();
    final fileNameText = media.name
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[_-]+'), ' ');
    if (const {
      'txt',
      'csv',
      'md',
      'json',
      'xml',
      'yaml',
      'yml',
      'log',
    }.contains(extension)) {
      try {
        final text = await _readTextFile(media.path);
        return '$fileNameText\n$text';
      } catch (_) {
        return fileNameText;
      }
    }
    if (extension == 'docx') {
      final text = await _extractZippedXmlText(media.path, const [
        'word/document.xml',
        'word/header1.xml',
        'word/footer1.xml',
      ]);
      return text.isEmpty ? fileNameText : '$fileNameText\n$text';
    }
    if (extension == 'odt') {
      final text = await _extractZippedXmlText(media.path, const [
        'content.xml',
      ]);
      return text.isEmpty ? fileNameText : '$fileNameText\n$text';
    }
    if (extension == 'xlsx') {
      final text = await _extractZippedXmlText(media.path, const [
        'xl/sharedStrings.xml',
      ]);
      return text.isEmpty ? fileNameText : '$fileNameText\n$text';
    }
    if (extension == 'rtf') {
      try {
        final text = _rtfToText(await _readTextFile(media.path));
        return text.isEmpty ? fileNameText : '$fileNameText\n$text';
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

  Future<String> _readTextFile(String path) async {
    const limit = 4 * 1024 * 1024;
    final file = File(path);
    final reader = await file.open();
    try {
      final bytes = await reader.read((await file.length()).clamp(0, limit));
      return utf8.decode(bytes, allowMalformed: true).trim();
    } finally {
      await reader.close();
    }
  }

  Future<String> _extractZippedXmlText(
    String path,
    List<String> acceptedEntries,
  ) async {
    try {
      final source = File(path);
      if (await source.length() > 80 * 1024 * 1024) return '';
      final archive = ZipDecoder().decodeBytes(
        await source.readAsBytes(),
        verify: true,
      );
      final parts = <String>[];
      for (final entryName in acceptedEntries) {
        final entries = archive.files.where((item) => item.name == entryName);
        for (final entry in entries) {
          if (!entry.isFile || entry.size > 12 * 1024 * 1024) continue;
          final xmlSource = utf8.decode(entry.content, allowMalformed: true);
          final document = XmlDocument.parse(xmlSource);
          final paragraphs = document.descendants
              .whereType<XmlElement>()
              .where(
                (element) => const {'p', 'si'}.contains(element.name.local),
              )
              .map(
                (element) => element.descendants
                    .whereType<XmlElement>()
                    .where((child) => child.name.local == 't')
                    .map((child) => child.innerText)
                    .join(),
              )
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
          if (paragraphs.isNotEmpty) {
            parts.addAll(paragraphs);
          } else {
            parts.addAll(
              document.descendants
                  .whereType<XmlElement>()
                  .where((element) => element.name.local == 't')
                  .map((element) => element.innerText.trim())
                  .where((value) => value.isNotEmpty),
            );
          }
        }
      }
      final text = parts.join('\n');
      return text.length <= 24000 ? text : text.substring(0, 24000);
    } catch (_) {
      return '';
    }
  }

  String _rtfToText(String source) {
    var text = source;
    text = text.replaceAllMapped(
      RegExp(r"\\'([0-9a-fA-F]{2})"),
      (match) => _cp1251Char(int.parse(match.group(1)!, radix: 16)),
    );
    text = text.replaceAllMapped(RegExp(r'\\u(-?\d+)\??'), (match) {
      var value = int.parse(match.group(1)!);
      if (value < 0) value += 65536;
      return String.fromCharCode(value);
    });
    text = text
        .replaceAll(RegExp(r'\\(?:par|line)\b\s?'), '\n')
        .replaceAll(RegExp(r'\\tab\b\s?'), '\t')
        .replaceAll(RegExp(r'\\[a-zA-Z]+-?\d*\s?'), '')
        .replaceAll(RegExp(r'\\[^a-zA-Z0-9]'), '')
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return text.length <= 24000 ? text : text.substring(0, 24000);
  }

  String _cp1251Char(int value) {
    if (value == 0xa8) return 'Ё';
    if (value == 0xb8) return 'ё';
    if (value >= 0xc0) return String.fromCharCode(0x0410 + value - 0xc0);
    return String.fromCharCode(value);
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
      final text = pages.join('\n');
      return text.length <= 48000 ? text : text.substring(0, 48000);
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'PDF text and OCR extraction',
      );
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
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Image OCR on mobile',
        );
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
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Image OCR with Tesseract process',
        );
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

Map<String, Object?> _optimizeImageBytes(Map<String, Object> request) {
  final original = request['bytes']! as Uint8List;
  var decoded = image_lib.decodeImage(original);
  if (decoded == null) return const {'bytes': null, 'extension': ''};
  decoded = image_lib.bakeOrientation(decoded);
  const maxSide = 2048;
  if (decoded.width > maxSide || decoded.height > maxSide) {
    final landscape = decoded.width >= decoded.height;
    decoded = image_lib.copyResize(
      decoded,
      width: landscape ? maxSide : null,
      height: landscape ? null : maxSide,
      interpolation: image_lib.Interpolation.average,
    );
  }
  final preservePng =
      request['extension'] == 'png' && original.length < 3 * 1024 * 1024;
  final encoded = preservePng
      ? image_lib.encodePng(decoded, level: 9)
      : image_lib.encodeJpg(decoded, quality: 86);
  if (encoded.length >= original.length && original.length < 3 * 1024 * 1024) {
    return const {'bytes': null, 'extension': ''};
  }
  return {
    'bytes': Uint8List.fromList(encoded),
    'extension': preservePng ? 'png' : 'jpg',
  };
}

Uint8List? _createThumbnailBytes(Uint8List source) {
  var decoded = image_lib.decodeImage(source);
  if (decoded == null) return null;
  decoded = image_lib.bakeOrientation(decoded);
  const maxSide = 560;
  final landscape = decoded.width >= decoded.height;
  final thumbnail = image_lib.copyResize(
    decoded,
    width: landscape ? maxSide : null,
    height: landscape ? null : maxSide,
    interpolation: image_lib.Interpolation.average,
  );
  return Uint8List.fromList(image_lib.encodeJpg(thumbnail, quality: 72));
}

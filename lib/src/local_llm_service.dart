import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:lib_llama_cpp/lib_llama_cpp.dart';
import 'package:path_provider/path_provider.dart';

class LocalModelStatus {
  const LocalModelStatus({
    required this.isInstalled,
    this.path = '',
    this.name = '',
    this.sizeBytes = 0,
    this.mmprojPath = '',
    this.isBundled = false,
  });

  final bool isInstalled;
  final String path;
  final String name;
  final int sizeBytes;
  final String mmprojPath;
  final bool isBundled;

  bool get isMultimodal => mmprojPath.isNotEmpty;

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    final megabytes = sizeBytes / (1024 * 1024);
    return megabytes >= 1024
        ? '${(megabytes / 1024).toStringAsFixed(1)} GB'
        : '${megabytes.toStringAsFixed(0)} MB';
  }
}

class LocalLlmService {
  LocalLlmService._();

  static final instance = LocalLlmService._();

  static const bundledAtBuild = bool.fromEnvironment(
    'MYHEALTH_BUNDLED_LLM',
    defaultValue: false,
  );
  static const recommendedModelName =
      'qwen3.5-0.8b-ablate-e2-opus46-postopus-runtime.Q4_K_M.gguf';
  static const recommendedProjectorName = 'mmproj-Qwen3.5-0.8B-F16.gguf';
  static const recommendedModelSize = 527502816;
  static const recommendedProjectorSize = 204987104;
  static const modelAssetPath = 'assets/models/$recommendedModelName';
  static const projectorAssetPath = 'assets/models/$recommendedProjectorName';
  static final recommendedModelUri = Uri.parse(
    'https://huggingface.co/amkkk/'
    'Qwen3.5-0.8B-GGUF-uncensored-opus-distill/resolve/main/'
    '$recommendedModelName?download=true',
  );
  static final recommendedProjectorUri = Uri.parse(
    'https://huggingface.co/amkkk/'
    'Qwen3.5-0.8B-GGUF-uncensored-opus-distill/resolve/main/'
    '$recommendedProjectorName?download=true',
  );
  static const _assetChannel = MethodChannel(
    'ru.thebestmks.myhealth/bundled_assets',
  );

  bool _bundledChecked = false;

  Future<Directory> _modelDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}models');
    await directory.create(recursive: true);
    return directory;
  }

  Future<LocalModelStatus> status() async {
    await _ensureBundledModel();
    final bundledDesktop = _desktopBundledStatus();
    if (bundledDesktop != null) return bundledDesktop;
    final directory = await _modelDirectory();
    final files = await directory
        .list()
        .where(
          (item) =>
              item is File &&
              item.path.toLowerCase().endsWith('.gguf') &&
              !_isProjectorName(item.uri.pathSegments.last),
        )
        .cast<File>()
        .toList();
    if (files.isEmpty) return const LocalModelStatus(isInstalled: false);
    files.sort((left, right) {
      final leftPreferred = left.uri.pathSegments.last == recommendedModelName;
      final rightPreferred =
          right.uri.pathSegments.last == recommendedModelName;
      if (leftPreferred != rightPreferred) return leftPreferred ? -1 : 1;
      return right.lastModifiedSync().compareTo(left.lastModifiedSync());
    });
    final model = files.first;
    if (!await _isValidGguf(model)) {
      return const LocalModelStatus(isInstalled: false);
    }
    final projector = await _findProjector(directory);
    return LocalModelStatus(
      isInstalled: true,
      path: model.path,
      name: model.uri.pathSegments.last,
      sizeBytes: await model.length(),
      mmprojPath: projector?.path ?? '',
      isBundled:
          bundledAtBuild && model.uri.pathSegments.last == recommendedModelName,
    );
  }

  Future<LocalModelStatus?> importModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gguf'],
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final sources = result.files
        .where((item) => item.path != null && item.path!.isNotEmpty)
        .toList();
    if (sources.isEmpty) return null;
    final modelSources = sources
        .where((item) => !_isProjectorName(item.name))
        .toList();
    if (modelSources.length != 1) {
      throw const FormatException(
        'Выберите одну основную GGUF-модель и, при необходимости, один mmproj.',
      );
    }
    final directory = await _modelDirectory();
    for (final source in sources) {
      final input = File(source.path!);
      if (!await _isValidGguf(input)) {
        throw FormatException('${source.name} не является корректным GGUF.');
      }
      await _copyVerified(
        input,
        File(
          '${directory.path}${Platform.pathSeparator}${_safeName(source.name)}',
        ),
      );
    }
    return status();
  }

  Future<LocalModelStatus> downloadRecommended({
    void Function(double progress)? onProgress,
  }) async {
    final directory = await _modelDirectory();
    final model = File(
      '${directory.path}${Platform.pathSeparator}$recommendedModelName',
    );
    final projector = File(
      '${directory.path}${Platform.pathSeparator}$recommendedProjectorName',
    );
    await _downloadFile(
      recommendedModelUri,
      model,
      onProgress: (value) => onProgress?.call(value * 0.72),
    );
    await _downloadFile(
      recommendedProjectorUri,
      projector,
      onProgress: (value) => onProgress?.call(0.72 + value * 0.28),
    );
    onProgress?.call(1);
    return status();
  }

  Future<void> removeInstalledModel() async {
    final current = await status();
    if (!current.isInstalled || current.isBundled) return;
    for (final path in [current.path, current.mmprojPath]) {
      if (path.isEmpty) continue;
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<String> answer({
    required String query,
    required String localContext,
    String localeCode = 'ru',
  }) async {
    final current = await status();
    if (!current.isInstalled) {
      throw StateError('Локальная языковая модель не установлена.');
    }
    final longDocument = query.length > 1800;
    final client = _client(current, contextSize: longDocument ? 4096 : 2048);
    final language = localeCode == 'ru' ? 'русском' : 'языке интерфейса';
    final boundedContext = _boundedContext(
      localContext,
      limit: longDocument ? 2200 : 4600,
    );
    final boundedQuery = _boundedContext(
      query,
      limit: longDocument ? 4200 : 1800,
    );
    final response = await client.responses.create(
      model: 'my-health-local',
      instructions:
          'Ты локальный помощник приложения "Моё здоровье". Отвечай кратко на $language. '
          'Пиши только на $language, кроме точных названий и единиц. '
          'Используй факты из локального контекста, отделяй факты от предположений. '
          'Не ставь диагноз, не назначай лечение и не меняй дозировки. При опасных симптомах '
          'советуй срочную медицинскую помощь. Не утверждай, что выполнил действие, если это '
          'не указано в контексте. В конце укажи уверенность: высокая, средняя или низкая.',
      input: [
        LlamaResponseInputItem(
          role: 'user',
          name: 'user',
          content: [
            LlamaTextPart(
              'Локальный контекст:\n$boundedContext\n\nЗапрос пользователя:\n$boundedQuery',
            ),
          ],
        ),
      ],
      maxOutputTokens: 256,
      temperature: 0.7,
      topP: 0.8,
      stop: const ['<|im_end|>', '<|endoftext|>'],
    );
    return _validatedText(response.outputText);
  }

  Future<String> describeImage({
    required String imagePath,
    String extractedText = '',
    String localeCode = 'ru',
  }) async {
    final current = await status();
    if (!current.isInstalled || !current.isMultimodal) {
      throw StateError('Мультимодальная локальная модель не установлена.');
    }
    final client = _client(current, contextSize: 2304, useMultimodal: true);
    final language = localeCode == 'ru' ? 'русском' : 'языке интерфейса';
    final response = await client.responses.create(
      model: 'my-health-local',
      instructions:
          'Опиши изображение на $language кратко и буквально. Для еды перечисли видимые '
          'компоненты без выдумывания массы и калорий. Для медицинского документа перепиши '
          'разборчивые факты, но не ставь диагноз и не меняй назначения. Отмечай неуверенность. '
          'Пиши только на $language, кроме точных названий и единиц.',
      input: [
        LlamaResponseInputItem(
          role: 'user',
          content: [
            LlamaTextPart(
              extractedText.isEmpty
                  ? 'Опиши изображение и укажи, какие данные можно безопасно перенести в дневник.'
                  : 'Опиши изображение. Локальный OCR уже извлёк текст:\n${_boundedContext(extractedText, limit: 3000)}',
            ),
            LlamaImageFilePart(path: imagePath),
          ],
        ),
      ],
      maxOutputTokens: 280,
      temperature: 0.7,
      topP: 0.8,
      stop: const ['<|im_end|>', '<|endoftext|>'],
    );
    return _validatedText(response.outputText);
  }

  Future<String?> routeToolCommand({
    required String query,
    String localeCode = 'ru',
  }) async {
    final current = await status();
    if (!current.isInstalled) return null;
    final client = _client(current, contextSize: 1536);
    final response = await client.responses.create(
      model: 'my-health-local',
      instructions:
          'Ты маршрутизатор локальных инструментов приложения здоровья. Перепиши явную '
          'команду пользователя в одну короткую русскую команду без Markdown, заголовков и '
          'объяснений. Сохрани исходные числа, единицы, время и названия. Допустимы: вода, '
          'шаги, вес, сон, активность, тренировка, еда, симптом, анализ, напоминание, '
          'будильник, отметка приема уже назначенного лекарства и разбор назначения врача. '
          'Никогда не меняй дозу, не назначай и не отменяй лечение. Начни ответ с КОМАНДА: . '
          'Пример: КОМАНДА: поставь будильник на 06:45.',
      input: [
        LlamaResponseInputItem(
          role: 'user',
          name: 'user',
          content: [LlamaTextPart(_boundedContext(query, limit: 1800))],
        ),
      ],
      maxOutputTokens: 120,
      temperature: 0,
      topP: 0.8,
      stop: const ['<|im_end|>', '<|endoftext|>'],
    );
    var command = _validatedText(response.outputText)
        .replaceFirst(
          RegExp(r'^\s*(?:КОМАНДА|COMMAND)\s*:\s*', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'^\*+|\*+$'), '')
        .split(RegExp(r'[\r\n]+'))
        .map(
          (line) => line
              .replaceFirst(RegExp(r'^\s*(?:#{1,4}|[-*]|\d+[.)])\s*'), '')
              .trim(),
        )
        .where((line) => line.isNotEmpty)
        .join(' ')
        .trim();
    if (command.isEmpty || command.length > 1600) return null;
    return command;
  }

  LlamaOpenAIClient _client(
    LocalModelStatus status, {
    required int contextSize,
    bool useMultimodal = false,
  }) {
    return LlamaOpenAIClient(
      models: {
        'my-health-local': LlamaModelConfig(
          modelPath: status.path,
          contextSize: contextSize,
          gpuLayerCount: 0,
          mmprojPath: useMultimodal && status.mmprojPath.isNotEmpty
              ? status.mmprojPath
              : null,
          mmprojUseGpu: false,
          imageMinTokens: 384,
          imageMaxTokens: 768,
        ),
      },
    );
  }

  String _validatedText(String value) {
    var text = value.trim();
    text = text.replaceFirst(
      RegExp(r'^assistant\s*:\s*', caseSensitive: false),
      '',
    );
    final reasoningEnd = text.lastIndexOf('</think>');
    if (reasoningEnd >= 0) {
      text = text.substring(reasoningEnd + '</think>'.length).trim();
    } else if (text.startsWith('<think>')) {
      throw StateError('Локальная модель не завершила краткий ответ.');
    }
    for (final marker in const [
      '**Explanation:**',
      '**Reasoning:**',
      '**Объяснение:**',
      '**Рассуждение:**',
    ]) {
      final index = text.indexOf(marker);
      if (index > 0) text = text.substring(0, index).trim();
    }
    text = text
        .replaceFirst(RegExp(r'^\*\*(?:Answer|Ответ):\*\*\s*'), '')
        .trim();
    if (text.isEmpty) {
      throw StateError('Локальная модель не вернула ответ.');
    }
    return text;
  }

  String _boundedContext(String value, {int limit = 4600}) {
    final text = value.trim();
    if (text.length <= limit) return text;
    final headLength = (limit * 0.6).round();
    final tailLength = limit - headLength;
    return '${text.substring(0, headLength)}\n…\n'
        '${text.substring(text.length - tailLength)}';
  }

  Future<void> _ensureBundledModel() async {
    if (!bundledAtBuild || _bundledChecked) return;
    _bundledChecked = true;
    if (!Platform.isAndroid) return;
    final directory = await _modelDirectory();
    final model = File(
      '${directory.path}${Platform.pathSeparator}$recommendedModelName',
    );
    final projector = File(
      '${directory.path}${Platform.pathSeparator}$recommendedProjectorName',
    );
    if (await _isExactBundledFile(model, recommendedModelSize) &&
        await _isExactBundledFile(projector, recommendedProjectorSize)) {
      return;
    }
    try {
      await _assetChannel.invokeMethod<void>('installBundledModel', {
        'modelAsset': modelAssetPath,
        'projectorAsset': projectorAssetPath,
        'modelPath': model.path,
        'projectorPath': projector.path,
        'modelSize': recommendedModelSize,
        'projectorSize': recommendedProjectorSize,
      });
      if (!await _isExactBundledFile(model, recommendedModelSize) ||
          !await _isExactBundledFile(projector, recommendedProjectorSize)) {
        throw StateError('Встроенная модель не была установлена полностью.');
      }
    } catch (_) {
      _bundledChecked = false;
      rethrow;
    }
  }

  LocalModelStatus? _desktopBundledStatus() {
    if (!bundledAtBuild ||
        !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return null;
    }
    final executable = File(Platform.resolvedExecutable).parent;
    final assetRoot = Platform.isMacOS
        ? Directory(
            '${executable.parent.path}${Platform.pathSeparator}Frameworks'
            '${Platform.pathSeparator}App.framework${Platform.pathSeparator}Resources'
            '${Platform.pathSeparator}flutter_assets',
          )
        : Directory(
            '${executable.path}${Platform.pathSeparator}data'
            '${Platform.pathSeparator}flutter_assets',
          );
    final model = File(
      '${assetRoot.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}models${Platform.pathSeparator}$recommendedModelName',
    );
    final projector = File(
      '${assetRoot.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}models${Platform.pathSeparator}$recommendedProjectorName',
    );
    if (!model.existsSync() || model.lengthSync() != recommendedModelSize) {
      return null;
    }
    return LocalModelStatus(
      isInstalled: true,
      path: model.path,
      name: recommendedModelName,
      sizeBytes: model.lengthSync(),
      mmprojPath:
          projector.existsSync() &&
              projector.lengthSync() == recommendedProjectorSize
          ? projector.path
          : '',
      isBundled: true,
    );
  }

  Future<File?> _findProjector(Directory directory) async {
    final preferred = File(
      '${directory.path}${Platform.pathSeparator}$recommendedProjectorName',
    );
    if (await _isValidGguf(preferred)) return preferred;
    final items = await directory
        .list()
        .where(
          (item) =>
              item is File &&
              item.path.toLowerCase().endsWith('.gguf') &&
              _isProjectorName(item.uri.pathSegments.last),
        )
        .cast<File>()
        .toList();
    for (final item in items) {
      if (await _isValidGguf(item)) return item;
    }
    return null;
  }

  Future<void> _downloadFile(
    Uri uri,
    File target, {
    required void Function(double progress) onProgress,
  }) async {
    final temporary = File('${target.path}.part');
    if (await temporary.exists()) await temporary.delete();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'MyHealth/1.8');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Сервер модели вернул код ${response.statusCode}.',
          uri: uri,
        );
      }
      final total = response.contentLength;
      var received = 0;
      final sink = temporary.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }
      } finally {
        await sink.close();
      }
      if (!await _isValidGguf(temporary)) {
        throw const FormatException('Загруженный GGUF повреждён.');
      }
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      onProgress(1);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _copyVerified(File source, File target) async {
    final temporary = File('${target.path}.part');
    if (await temporary.exists()) await temporary.delete();
    await source.openRead().pipe(temporary.openWrite());
    if (!await _isValidGguf(temporary)) {
      await temporary.delete();
      throw const FormatException('Скопированная GGUF-модель повреждена.');
    }
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<bool> _isValidGguf(File file) async {
    if (!await file.exists() || await file.length() < 1024 * 1024) return false;
    final reader = await file.open();
    try {
      final magic = await reader.read(4);
      return _ascii(magic) == 'GGUF';
    } finally {
      await reader.close();
    }
  }

  Future<bool> _isExactBundledFile(File file, int expectedSize) async {
    return await file.exists() &&
        await file.length() == expectedSize &&
        await _isValidGguf(file);
  }

  static bool _isProjectorName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('mmproj') || lower.contains('projector');
  }

  static String _safeName(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
}

String _ascii(Uint8List bytes) => String.fromCharCodes(bytes);

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:lib_llama_cpp/lib_llama_cpp.dart';
import 'package:path_provider/path_provider.dart';

class LocalModelStatus {
  const LocalModelStatus({
    required this.isInstalled,
    this.path = '',
    this.name = '',
    this.sizeBytes = 0,
  });

  final bool isInstalled;
  final String path;
  final String name;
  final int sizeBytes;

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

  static const recommendedModelName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static final recommendedModelUri = Uri.parse(
    'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/'
    'resolve/main/$recommendedModelName?download=true',
  );

  Future<Directory> _modelDirectory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}models');
    await directory.create(recursive: true);
    return directory;
  }

  Future<LocalModelStatus> status() async {
    final directory = await _modelDirectory();
    final files = await directory
        .list()
        .where(
          (item) => item is File && item.path.toLowerCase().endsWith('.gguf'),
        )
        .cast<File>()
        .toList();
    if (files.isEmpty) return const LocalModelStatus(isInstalled: false);
    files.sort(
      (left, right) =>
          right.lastModifiedSync().compareTo(left.lastModifiedSync()),
    );
    final model = files.first;
    if (!await _isValidGguf(model)) {
      return const LocalModelStatus(isInstalled: false);
    }
    return LocalModelStatus(
      isInstalled: true,
      path: model.path,
      name: model.uri.pathSegments.last,
      sizeBytes: await model.length(),
    );
  }

  Future<LocalModelStatus?> importModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['gguf'],
      allowMultiple: false,
      withData: false,
    );
    final sourcePath = result?.files.single.path;
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final source = File(sourcePath);
    if (!await _isValidGguf(source)) {
      throw const FormatException('Файл не является корректной GGUF-моделью.');
    }
    final directory = await _modelDirectory();
    final safeName = result!.files.single.name.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]+'),
      '_',
    );
    final target = File('${directory.path}${Platform.pathSeparator}$safeName');
    final temporary = File('${target.path}.part');
    await source.openRead().pipe(temporary.openWrite());
    if (!await _isValidGguf(temporary)) {
      await temporary.delete();
      throw const FormatException('Скопированная GGUF-модель повреждена.');
    }
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
    return status();
  }

  Future<LocalModelStatus> downloadRecommended({
    void Function(double progress)? onProgress,
  }) async {
    final directory = await _modelDirectory();
    final target = File(
      '${directory.path}${Platform.pathSeparator}$recommendedModelName',
    );
    final temporary = File('${target.path}.part');
    if (await temporary.exists()) await temporary.delete();

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25);
    try {
      final request = await client.getUrl(recommendedModelUri);
      request.headers.set(HttpHeaders.userAgentHeader, 'MyHealth/1.7');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Сервер модели вернул код ${response.statusCode}.',
          uri: recommendedModelUri,
        );
      }
      final total = response.contentLength;
      var received = 0;
      final sink = temporary.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
      } finally {
        await sink.close();
      }
      if (!await _isValidGguf(temporary)) {
        throw const FormatException('Загруженный файл GGUF повреждён.');
      }
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      onProgress?.call(1);
      return status();
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> removeInstalledModel() async {
    final current = await status();
    if (!current.isInstalled) return;
    final model = File(current.path);
    if (await model.exists()) await model.delete();
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
    final client = LlamaOpenAIClient(
      models: {
        'my-health-local': LlamaModelConfig(
          modelPath: current.path,
          contextSize: 1536,
          gpuLayerCount: 0,
        ),
      },
    );
    final language = localeCode == 'ru' ? 'русском' : 'языке интерфейса';
    final response = await client.responses.create(
      model: 'my-health-local',
      instructions:
          'Ты локальный помощник приложения "Моё здоровье". Отвечай кратко на $language. '
          'Используй только факты из локального контекста, отделяй факты от предположений. '
          'Не ставь диагноз, не назначай лечение, не меняй дозировки. При опасных симптомах '
          'советуй срочную медицинскую помощь. Не утверждай, что выполнил действие, если это '
          'не указано в контексте. В конце укажи уровень уверенности: высокий, средний или низкий.',
      input:
          'Локальный контекст:\n$localContext\n\nЗапрос пользователя:\n$query',
      maxOutputTokens: 320,
      temperature: 0.25,
      topP: 0.85,
      stop: const ['<|im_end|>', '<|endoftext|>'],
    );
    final text = response.outputText.trim();
    if (text.isEmpty) {
      throw StateError('Локальная модель не вернула ответ.');
    }
    return text;
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
}

String _ascii(Uint8List bytes) => String.fromCharCodes(bytes);

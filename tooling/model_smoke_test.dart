import 'dart:io';

import 'package:image/image.dart' as image_lib;
import 'package:lib_llama_cpp/lib_llama_cpp.dart';
import 'package:lib_llama_cpp_platform_interface/lib_llama_cpp_platform_interface.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length < 3) {
    stderr.writeln(
      'Usage: dart run tooling/model_smoke_test.dart <library.dll> <model.gguf> <mmproj.gguf>',
    );
    exitCode = 64;
    return;
  }
  final library = File(arguments[0]);
  final model = File(arguments[1]);
  final projector = File(arguments[2]);
  for (final file in [library, model, projector]) {
    if (!file.existsSync()) {
      throw StateError('Missing test input: ${file.path}');
    }
  }

  final engine = LibLlamaCpp(platform: _FixedLibraryPlatform(library.path));
  final textClient = LlamaOpenAIClient(
    models: {
      'my-health-smoke': LlamaModelConfig(
        modelPath: model.path,
        contextSize: 2048,
        gpuLayerCount: 0,
      ),
    },
    engine: engine,
  );
  final routerClient = LlamaOpenAIClient(
    models: {
      'my-health-smoke': LlamaModelConfig(
        modelPath: model.path,
        contextSize: 1536,
        gpuLayerCount: 0,
      ),
    },
    engine: engine,
  );
  final visionClient = LlamaOpenAIClient(
    models: {
      'my-health-smoke': LlamaModelConfig(
        modelPath: model.path,
        mmprojPath: projector.path,
        contextSize: 2304,
        gpuLayerCount: 0,
        mmprojUseGpu: false,
        imageMinTokens: 384,
        imageMaxTokens: 768,
      ),
    },
    engine: engine,
  );

  final textTimer = Stopwatch()..start();
  final textResponse = await textClient.responses.create(
    model: 'my-health-smoke',
    instructions: 'Отвечай по-русски одним коротким предложением. /no_think',
    input: const [
      LlamaResponseInputItem(
        role: 'user',
        name: 'user',
        content: [
          LlamaTextPart(
            'Назови один безопасный способ напомнить себе выпить воды. /no_think',
          ),
        ],
      ),
    ],
    maxOutputTokens: 80,
    temperature: 0,
  );
  textTimer.stop();
  final visibleText = _visibleText(textResponse.outputText);
  if (visibleText.isEmpty || !RegExp(r'[А-яЁё]').hasMatch(visibleText)) {
    throw StateError('The model returned an empty text response.');
  }
  stdout.writeln('TEXT_OK (${textTimer.elapsedMilliseconds} ms): $visibleText');

  final toolTimer = Stopwatch()..start();
  final toolResponse = await routerClient.responses.create(
    model: 'my-health-smoke',
    instructions:
        'Ты маршрутизатор локальных инструментов. Перепиши явную команду '
        'пользователя в одну короткую русскую команду без Markdown и объяснений. '
        'Сохрани числа и время. Начни ответ с КОМАНДА: .',
    input: const [
      LlamaResponseInputItem(
        role: 'user',
        name: 'user',
        content: [LlamaTextPart('Поставь будильник на 06:45.')],
      ),
    ],
    maxOutputTokens: 120,
    temperature: 0,
    stop: const ['<|im_end|>', '<|endoftext|>'],
  );
  toolTimer.stop();
  final routedCommand = _visibleText(toolResponse.outputText);
  if (!routedCommand.contains('06:45') ||
      !routedCommand.toLowerCase().contains('буд')) {
    throw StateError(
      'The tool router did not preserve the requested alarm and time: '
      '${toolResponse.outputText}',
    );
  }
  stdout.writeln(
    'TOOL_OK (${toolTimer.elapsedMilliseconds} ms): $routedCommand',
  );

  final temporary = await Directory.systemTemp.createTemp('myhealth-vision-');
  try {
    final sample = image_lib.Image(width: 128, height: 128);
    image_lib.fill(sample, color: image_lib.ColorRgb8(220, 25, 25));
    final imagePath = '${temporary.path}${Platform.pathSeparator}red.png';
    await File(
      imagePath,
    ).writeAsBytes(image_lib.encodePng(sample), flush: true);
    final visionTimer = Stopwatch()..start();
    final visionResponse = await visionClient.responses.create(
      model: 'my-health-smoke',
      instructions: 'Отвечай по-русски и не выдумывай детали. /no_think',
      input: [
        LlamaResponseInputItem(
          role: 'user',
          content: [
            const LlamaTextPart(
              'Ответь одним русским словом: какой основной цвет на этом изображении?',
            ),
            LlamaImageFilePart(path: imagePath, mimeType: 'image/png'),
          ],
        ),
      ],
      maxOutputTokens: 48,
      temperature: 0,
    );
    visionTimer.stop();
    final visionText = _visibleText(visionResponse.outputText);
    final normalizedVision = visionText.toLowerCase();
    if (!normalizedVision.contains('крас') &&
        !RegExp(r'\bred\b').hasMatch(normalizedVision)) {
      throw StateError(
        'The model did not identify the red test image: '
        '${visionResponse.outputText}',
      );
    }
    stdout.writeln(
      'VISION_OK (${visionTimer.elapsedMilliseconds} ms): $visionText',
    );
  } finally {
    await temporary.delete(recursive: true);
  }
}

String _visibleText(String raw) {
  var text = raw.trim();
  text = text.replaceFirst(
    RegExp(r'^assistant\s*:\s*', caseSensitive: false),
    '',
  );
  final reasoningEnd = text.lastIndexOf('</think>');
  if (reasoningEnd >= 0) {
    text = text.substring(reasoningEnd + '</think>'.length).trim();
  }
  if (text.contains('<think>') || text.isEmpty) {
    throw StateError('The model exposed or failed to finish chain-of-thought.');
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
  text = text.replaceFirst(RegExp(r'^\*\*(?:Answer|Ответ):\*\*\s*'), '').trim();
  if (text.isEmpty) {
    throw StateError('The model returned no user-visible answer.');
  }
  return text;
}

final class _FixedLibraryPlatform extends LibLlamaCppPlatform {
  _FixedLibraryPlatform(this.path);

  final String path;

  @override
  Future<LlamaCppLibraryDescriptor> resolveLibrary({
    LlamaCppLibraryRequest request = const LlamaCppLibraryRequest(),
  }) async {
    return LlamaCppLibraryDescriptor(
      resolution: LlamaCppLibraryResolution.path,
      path: path,
      capabilities: const {LlamaCppLibraryCapability.cpu},
    );
  }
}

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechInputService {
  SpeechInputService._();

  static final instance = SpeechInputService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  void Function(String status)? _statusListener;
  void Function(String error)? _errorListener;

  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    _statusListener = onStatus;
    _errorListener = onError;
    if (_initialized) return _speech.isAvailable;
    _initialized = await _speech.initialize(
      onStatus: (status) => _statusListener?.call(status),
      onError: (SpeechRecognitionError error) =>
          _errorListener?.call(error.errorMsg),
      finalTimeout: const Duration(seconds: 3),
    );
    return _initialized;
  }

  Future<String?> russianLocaleId() async {
    if (!_initialized) return null;
    final locales = await _speech.locales();
    final russian = locales.where(
      (item) => item.localeId.toLowerCase().startsWith('ru'),
    );
    return russian.isEmpty ? null : russian.first.localeId;
  }

  Future<void> startRussian({
    required void Function(String words, bool isFinal) onWords,
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    final available = await initialize(onStatus: onStatus, onError: onError);
    if (!available) {
      throw StateError('Системное распознавание речи недоступно.');
    }
    final localeId = await russianLocaleId();
    if (localeId == null) {
      throw StateError(
        'Русский языковой пакет распознавания речи не установлен.',
      );
    }
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) =>
          onWords(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        onDevice: true,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(minutes: 2),
        contextualPhrases: const [
          'лекарство',
          'давление',
          'глюкоза',
          'калории',
          'тренировка',
          'симптом',
          'напоминание',
        ],
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}

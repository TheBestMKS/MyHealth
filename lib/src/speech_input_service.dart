import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'error_log_service.dart';

class SpeechInputService {
  SpeechInputService._();

  static final instance = SpeechInputService._();

  final SpeechToText _speech = SpeechToText();
  final AudioRecorder _recorder = AudioRecorder();
  bool _initialized = false;
  bool _recording = false;
  String _recordingTarget = '';
  String _recordedAudioPath = '';
  Future<String?>? _audioStopInFlight;
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
      onStatus: (status) {
        _statusListener?.call(status);
        if (status == 'done' || status == 'notListening') {
          unawaited(_stopAudioRecording());
        }
      },
      onError: (SpeechRecognitionError error) {
        _errorListener?.call(error.errorMsg);
        unawaited(_stopAudioRecording());
      },
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
    await _discardUnclaimedAudio();
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
      onResult: (SpeechRecognitionResult result) {
        onWords(result.recognizedWords, result.finalResult);
        if (result.finalResult) unawaited(_stopAudioRecording());
      },
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
    await _startAudioRecording();
  }

  Future<void> stop() async {
    await _speech.stop();
    await _stopAudioRecording();
  }

  String takeRecordedAudio() {
    final path = _recordedAudioPath;
    _recordedAudioPath = '';
    return path;
  }

  Future<void> cancel() async {
    await _speech.cancel();
    if (_recording) {
      try {
        await _recorder.cancel();
      } catch (_) {}
      _recording = false;
      _recordingTarget = '';
    }
    await _discardUnclaimedAudio();
  }

  Future<void> _startAudioRecording() async {
    try {
      if (!await _recorder.hasPermission()) return;
      final root = await getApplicationSupportDirectory();
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}assistant_media'
        '${Platform.pathSeparator}voice',
      );
      await directory.create(recursive: true);
      _recordingTarget =
          '${directory.path}${Platform.pathSeparator}'
          'voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _recordingTarget,
      );
      _recording = true;
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Voice audio recording start',
      );
      _recording = false;
      _recordingTarget = '';
    }
  }

  Future<String?> _stopAudioRecording() {
    final existing = _audioStopInFlight;
    if (existing != null) return existing;
    if (!_recording) return Future.value(_recordedAudioPath);
    final operation = () async {
      try {
        final path = await _recorder.stop();
        final candidate = path ?? _recordingTarget;
        if (candidate.isNotEmpty && await File(candidate).exists()) {
          _recordedAudioPath = candidate;
        }
        return _recordedAudioPath.isEmpty ? null : _recordedAudioPath;
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Voice audio recording stop',
        );
        return null;
      } finally {
        _recording = false;
        _recordingTarget = '';
      }
    }();
    _audioStopInFlight = operation;
    unawaited(operation.whenComplete(() => _audioStopInFlight = null));
    return operation;
  }

  Future<void> _discardUnclaimedAudio() async {
    final path = _recordedAudioPath;
    _recordedAudioPath = '';
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

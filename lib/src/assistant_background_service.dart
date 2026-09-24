import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';

import 'assistant_conversation_service.dart';
import 'error_log_service.dart';
import 'local_llm_service.dart';
import 'media_import_service.dart';
import 'model.dart';

enum AssistantAttachmentIntent { auto, food, lab, prescription, chat }

class AssistantBackgroundStatus {
  const AssistantBackgroundStatus({
    this.queued = 0,
    this.processing = false,
    this.label = '',
    this.lastResult = '',
    this.lastError = '',
  });

  final int queued;
  final bool processing;
  final String label;
  final String lastResult;
  final String lastError;

  bool get busy => processing || queued > 0;
}

class AssistantBackgroundService {
  AssistantBackgroundService({
    AssistantConversationService? conversation,
    MediaImportService? media,
    LocalLlmService? llm,
  }) : _conversation = conversation ?? AssistantConversationService(),
       _media = media ?? MediaImportService(),
       _llm = llm ?? LocalLlmService.instance;

  static final instance = AssistantBackgroundService();

  final AssistantConversationService _conversation;
  final MediaImportService _media;
  final LocalLlmService _llm;
  final List<_AssistantJob> _queue = [];
  final ValueNotifier<AssistantBackgroundStatus> status = ValueNotifier(
    const AssistantBackgroundStatus(),
  );

  HealthAppState Function()? _readState;
  void Function(HealthAppState)? _writeState;
  bool _draining = false;
  Completer<void>? _idleCompleter;

  void bind({
    required HealthAppState Function() readState,
    required void Function(HealthAppState) writeState,
  }) {
    _readState = readState;
    _writeState = writeState;
    scheduleMicrotask(() => unawaited(_drain()));
  }

  void unbind() {
    _readState = null;
    _writeState = null;
  }

  String enqueueText({
    required String query,
    String kind = 'text',
    String transcript = '',
    String attachmentPath = '',
    String attachmentName = '',
    String mimeType = '',
    int durationSeconds = 0,
    String activityContext = '',
  }) {
    final id = newId();
    final effectiveMime = mimeType.isNotEmpty
        ? mimeType
        : attachmentPath.isEmpty
        ? ''
        : lookupMimeType(attachmentPath) ?? 'audio/mp4';
    final pending = AssistantMessage(
      id: '$id-user',
      createdAt: DateTime.now().toIso8601String(),
      role: 'user',
      text: query.trim(),
      kind: kind,
      transcript: transcript,
      attachmentPath: attachmentPath,
      attachmentName: attachmentName,
      mimeType: effectiveMime,
      durationSeconds: durationSeconds,
    );
    _appendPending(pending);
    _enqueue(
      _AssistantJob(
        id: id,
        label: kind == 'voice'
            ? 'Обработка голосового запроса'
            : 'Обработка запроса помощнику',
        run: () => _processText(
          query: query,
          kind: kind,
          transcript: transcript,
          attachmentPath: attachmentPath,
          attachmentName: attachmentName,
          mimeType: effectiveMime,
          durationSeconds: durationSeconds,
          activityContext: activityContext,
          pending: pending,
        ),
      ),
    );
    return id;
  }

  String enqueueAttachment({
    required ImportedMedia media,
    AssistantAttachmentIntent intent = AssistantAttachmentIntent.auto,
  }) {
    final id = newId();
    final pendingMime = lookupMimeType(media.name) ?? '';
    final pending = AssistantMessage(
      id: '$id-user',
      createdAt: DateTime.now().toIso8601String(),
      role: 'user',
      text: pendingMime.startsWith('image/')
          ? 'Отправлено изображение: ${media.name}'
          : 'Приложен файл: ${media.name}',
      kind: pendingMime.startsWith('image/') ? 'image' : 'file',
      attachmentPath: media.path,
      attachmentName: media.name,
      mimeType: pendingMime,
    );
    _appendPending(pending);
    _enqueue(
      _AssistantJob(
        id: id,
        label: 'Анализ файла ${media.name}',
        run: () => _processAttachment(media, intent, pending),
      ),
    );
    return id;
  }

  Future<void> waitUntilIdle() {
    if (!_draining && _queue.isEmpty) return Future<void>.value();
    return (_idleCompleter ??= Completer<void>()).future;
  }

  void _enqueue(_AssistantJob job) {
    _queue.add(job);
    _idleCompleter ??= Completer<void>();
    _publish(queued: _queue.length, processing: _draining);
    scheduleMicrotask(() => unawaited(_drain()));
  }

  Future<void> _drain() async {
    if (_draining || _readState == null || _writeState == null) return;
    _draining = true;
    while (_queue.isNotEmpty && _readState != null && _writeState != null) {
      final job = _queue.removeAt(0);
      _publish(queued: _queue.length, processing: true, label: job.label);
      try {
        final result = await job.run();
        _publish(queued: _queue.length, processing: false, lastResult: result);
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Assistant background job ${job.id}; ${job.label}',
        );
        _appendFailure(job.label, error);
        _publish(
          queued: _queue.length,
          processing: false,
          lastError: _shortError(error),
        );
      }
    }
    _draining = false;
    _publish(queued: _queue.length, processing: false);
    final completer = _idleCompleter;
    if (_queue.isEmpty && completer != null) {
      if (!completer.isCompleted) completer.complete();
      _idleCompleter = null;
    }
  }

  Future<String> _processText({
    required String query,
    required String kind,
    required String transcript,
    required String attachmentPath,
    required String attachmentName,
    required String mimeType,
    required int durationSeconds,
    required String activityContext,
    required AssistantMessage pending,
  }) async {
    final read = _requireReader();
    final write = _requireWriter();
    var effectiveMime = mimeType;
    if (effectiveMime.isEmpty && attachmentPath.isNotEmpty) {
      effectiveMime = lookupMimeType(attachmentPath) ?? 'audio/mp4';
    }
    if (attachmentPath.isNotEmpty && !await File(attachmentPath).exists()) {
      await ErrorLogService.instance.recordInfo(
        'Аудиофайл не найден, запрос будет обработан по расшифровке: $attachmentPath',
        source: 'Assistant voice attachment',
      );
      attachmentPath = '';
      attachmentName = '';
      effectiveMime = '';
    }
    HealthAppState latestState() => _withoutMessage(read(), pending.id);
    final effectiveUser = AssistantMessage(
      id: pending.id,
      createdAt: pending.createdAt,
      role: pending.role,
      text: pending.text,
      kind: pending.kind,
      transcript: pending.transcript,
      attachmentPath: attachmentPath,
      attachmentName: attachmentName,
      mimeType: effectiveMime,
      durationSeconds: pending.durationSeconds,
    );
    final result = await _conversation.submit(
      state: latestState(),
      latestState: latestState,
      existingUserMessage: effectiveUser,
      query: query,
      kind: kind,
      transcript: transcript,
      durationSeconds: durationSeconds,
      attachmentPath: attachmentPath,
      attachmentName: attachmentName,
      mimeType: effectiveMime,
      activityContext: activityContext,
    );
    write(result.state);
    return result.usedTool
        ? 'Команда выполнена и сохранена'
        : 'Ответ помощника готов';
  }

  Future<String> _processAttachment(
    ImportedMedia source,
    AssistantAttachmentIntent requestedIntent,
    AssistantMessage pending,
  ) async {
    final read = _requireReader();
    final write = _requireWriter();
    final attachment = await _media.prepareAttachment(source);
    final intent = requestedIntent == AssistantAttachmentIntent.auto
        ? detectAssistantAttachmentIntent(attachment)
        : requestedIntent;
    final relatedSection = switch (intent) {
      AssistantAttachmentIntent.food => 'nutrition',
      AssistantAttachmentIntent.lab => 'labs',
      AssistantAttachmentIntent.prescription => 'medicines',
      _ => 'documents',
    };
    _replacePending(
      AssistantMessage(
        id: pending.id,
        createdAt: pending.createdAt,
        role: 'user',
        text: attachment.isImage
            ? 'Отправлено изображение: ${attachment.media.name}'
            : 'Приложен файл: ${attachment.media.name}',
        relatedSection: relatedSection,
        kind: attachment.isImage ? 'image' : 'file',
        attachmentPath: attachment.media.path,
        thumbnailPath: attachment.thumbnailPath,
        attachmentName: attachment.media.name,
        mimeType: attachment.mimeType,
        analysis: attachment.description,
      ),
    );
    var actionSummary = '';
    List<RecognitionCandidate> candidates = const [];
    if (intent == AssistantAttachmentIntent.food) {
      candidates = await _media.recognizeExistingMedia(
        attachment.media,
        source: 'фото еды',
        requiresMedicalReview: false,
      );
    } else if (intent == AssistantAttachmentIntent.lab) {
      candidates = await _media.recognizeExistingMedia(
        attachment.media,
        source: 'OCR анализа',
        requiresMedicalReview: true,
      );
    } else if (intent == AssistantAttachmentIntent.prescription) {
      candidates = await _media.recognizeExistingPrescription(attachment.media);
    }
    if (candidates.isNotEmpty) {
      actionSummary =
          'На проверку добавлено записей: ${candidates.length}. Изменения применятся после подтверждения.';
    }

    var analysis = attachment.description;
    if (attachment.isImage) {
      try {
        final modelStatus = await _llm.status();
        if (modelStatus.isMultimodal) {
          analysis = await _llm.describeImage(
            imagePath: attachment.media.path,
            extractedText: attachment.extractedText,
            localeCode: read().localeCode,
          );
        }
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Assistant image vision; ${attachment.media.name}',
        );
        analysis = '$analysis\nVision-анализ недоступен: ${_shortError(error)}';
      }
    }
    final query = attachment.extractedText.trim().isEmpty
        ? 'Проанализируй вложение ${attachment.media.name}'
        : 'Проанализируй вложение ${attachment.media.name}. '
              'Извлечённый текст:\n${attachment.extractedText.trim()}';
    final analyzeDocumentWithModel =
        intent == AssistantAttachmentIntent.chat &&
        !attachment.isImage &&
        attachment.extractedText.trim().isNotEmpty;
    HealthAppState stateWithCandidates() =>
        _mergeCandidates(_withoutMessage(read(), pending.id), candidates);
    final finalUserMessage = AssistantMessage(
      id: pending.id,
      createdAt: pending.createdAt,
      role: 'user',
      text: attachment.isImage
          ? 'Отправлено изображение: ${attachment.media.name}'
          : 'Приложен файл: ${attachment.media.name}',
      relatedSection: relatedSection,
      kind: attachment.isImage ? 'image' : 'file',
      attachmentPath: attachment.media.path,
      thumbnailPath: attachment.thumbnailPath,
      attachmentName: attachment.media.name,
      mimeType: attachment.mimeType,
      analysis: analysis,
    );
    final result = await _conversation.submit(
      state: stateWithCandidates(),
      latestState: stateWithCandidates,
      existingUserMessage: finalUserMessage,
      query: query,
      displayText: attachment.isImage
          ? 'Отправлено изображение: ${attachment.media.name}'
          : 'Приложен файл: ${attachment.media.name}',
      kind: attachment.isImage ? 'image' : 'file',
      attachmentPath: attachment.media.path,
      thumbnailPath: attachment.thumbnailPath,
      attachmentName: attachment.media.name,
      mimeType: attachment.mimeType,
      analysis: analysis,
      allowTools:
          intent == AssistantAttachmentIntent.chat &&
          attachment.extractedText.isNotEmpty,
      prefilledAnswer: analyzeDocumentWithModel
          ? ''
          : [
              analysis,
              if (actionSummary.isNotEmpty) actionSummary,
            ].join('\n\n'),
      prefilledRelatedSection: analyzeDocumentWithModel ? '' : relatedSection,
      actionSummary: actionSummary,
    );
    write(result.state);
    return candidates.isEmpty
        ? 'Файл проанализирован'
        : 'Файл проанализирован, найдено записей: ${candidates.length}';
  }

  HealthAppState _mergeCandidates(
    HealthAppState state,
    List<RecognitionCandidate> candidates,
  ) {
    if (candidates.isEmpty) return state;
    final existing = state.confirmationQueue.map((item) => item.id).toSet();
    return state.copyWith(
      confirmationQueue: [
        ...candidates.where((item) => existing.add(item.id)),
        ...state.confirmationQueue,
      ],
    );
  }

  HealthAppState _withoutMessage(HealthAppState state, String id) {
    if (!state.assistantMessages.any((message) => message.id == id)) {
      return state;
    }
    return state.copyWith(
      assistantMessages: state.assistantMessages
          .where((message) => message.id != id)
          .toList(),
    );
  }

  void _appendPending(AssistantMessage message) {
    final read = _readState;
    final write = _writeState;
    if (read == null || write == null) return;
    final state = read();
    write(
      state.copyWith(
        assistantMessages: [
          message,
          ...state.assistantMessages.where((item) => item.id != message.id),
        ].take(3000).toList(),
      ),
    );
  }

  void _replacePending(AssistantMessage message) {
    final read = _readState;
    final write = _writeState;
    if (read == null || write == null) return;
    final state = read();
    write(
      state.copyWith(
        assistantMessages: state.assistantMessages
            .map((item) => item.id == message.id ? message : item)
            .toList(),
      ),
    );
  }

  void _appendFailure(String label, Object error) {
    final read = _readState;
    final write = _writeState;
    if (read == null || write == null) return;
    final state = read();
    final message = AssistantMessage(
      id: '${newId()}-assistant-error',
      createdAt: DateTime.now().toIso8601String(),
      role: 'assistant',
      text:
          'Не удалось завершить фоновую обработку «$label»: ${_shortError(error)}. Подробности сохранены в журнале ошибок.',
      kind: 'action',
      relatedSection: 'assistant',
      actionSummary: 'Ошибка фоновой обработки',
    );
    write(
      state.copyWith(
        assistantMessages: [
          message,
          ...state.assistantMessages,
        ].take(3000).toList(),
      ),
    );
  }

  HealthAppState Function() _requireReader() {
    final reader = _readState;
    if (reader == null) throw StateError('Assistant queue is not bound');
    return reader;
  }

  void Function(HealthAppState) _requireWriter() {
    final writer = _writeState;
    if (writer == null) throw StateError('Assistant queue is not bound');
    return writer;
  }

  void _publish({
    required int queued,
    required bool processing,
    String label = '',
    String lastResult = '',
    String lastError = '',
  }) {
    status.value = AssistantBackgroundStatus(
      queued: queued,
      processing: processing,
      label: label,
      lastResult: lastResult.isEmpty ? status.value.lastResult : lastResult,
      lastError: lastError,
    );
  }
}

class _AssistantJob {
  const _AssistantJob({
    required this.id,
    required this.label,
    required this.run,
  });

  final String id;
  final String label;
  final Future<String> Function() run;
}

@visibleForTesting
AssistantAttachmentIntent detectAssistantAttachmentIntent(
  AttachmentAnalysis attachment,
) {
  final lower = attachment.extractedText.toLowerCase();
  if (RegExp(
        r'(?:таблет|капсул|принимать|назначен|рецепт|дозиров)',
      ).hasMatch(lower) &&
      RegExp(r'\d+(?:[\.,]\d+)?\s*(?:мг|мкг|мл|ме|ед\.)').hasMatch(lower)) {
    return AssistantAttachmentIntent.prescription;
  }
  if (RegExp(
    r'(?:гемоглоб|глюкоз|холестерин|ферритин|референс|ммоль/л|мг/дл|анализ крови)',
  ).hasMatch(lower)) {
    return AssistantAttachmentIntent.lab;
  }
  if (RegExp(
    r'(?:ккал|калори|белк|жир|углевод|состав|пищевая ценность)',
  ).hasMatch(lower)) {
    return AssistantAttachmentIntent.food;
  }
  return AssistantAttachmentIntent.chat;
}

String _shortError(Object error) {
  final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= 180 ? text : '${text.substring(0, 177)}...';
}

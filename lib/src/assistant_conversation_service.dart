import 'dart:io';

import 'assistant_engine.dart';
import 'assistant_tools.dart';
import 'error_log_service.dart';
import 'local_llm_service.dart';
import 'model.dart';

class ConversationSubmitResult {
  const ConversationSubmitResult({
    required this.state,
    required this.relatedSection,
    required this.usedTool,
  });

  final HealthAppState state;
  final String relatedSection;
  final bool usedTool;
}

class AssistantConversationService {
  AssistantConversationService({
    AssistantToolEngine tools = const AssistantToolEngine(),
    LocalLlmService? llm,
  }) : _tools = tools,
       _llm = llm ?? LocalLlmService.instance;

  final AssistantToolEngine _tools;
  final LocalLlmService _llm;

  Future<ConversationSubmitResult> submit({
    required HealthAppState state,
    HealthAppState Function()? latestState,
    AssistantMessage? existingUserMessage,
    required String query,
    String displayText = '',
    String kind = 'text',
    String transcript = '',
    String attachmentPath = '',
    String thumbnailPath = '',
    String attachmentName = '',
    String mimeType = '',
    String analysis = '',
    int durationSeconds = 0,
    String activityContext = '',
    bool allowTools = true,
    String prefilledAnswer = '',
    String prefilledRelatedSection = '',
    String actionSummary = '',
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty && attachmentPath.isEmpty) {
      return ConversationSubmitResult(
        state: state,
        relatedSection: '',
        usedTool: false,
      );
    }
    var currentState = latestState?.call() ?? state;
    var toolResult = allowTools && normalizedQuery.isNotEmpty
        ? _tools.execute(currentState, normalizedQuery)
        : null;
    if (toolResult == null &&
        allowTools &&
        _looksLikeActionRequest(normalizedQuery)) {
      try {
        final routed = await _llm.routeToolCommand(
          query: normalizedQuery,
          localeCode: state.localeCode,
        );
        if (routed != null) {
          currentState = latestState?.call() ?? currentState;
          toolResult = _tools.execute(currentState, routed);
        }
      } catch (error, stackTrace) {
        await ErrorLogService.instance.recordError(
          error,
          stackTrace,
          source: 'Assistant tool routing',
        );
      }
    }
    var effectiveState = toolResult?.state ?? currentState;
    final deterministic = buildAssistantAnswer(
      effectiveState,
      normalizedQuery.isEmpty ? 'Проанализируй вложение' : normalizedQuery,
    );
    var answerText = prefilledAnswer.trim();
    var answerSource = actionSummary.isEmpty
        ? 'Быстрый локальный анализ'
        : 'Результат действия';
    if (answerText.isEmpty && toolResult != null) {
      answerText = toolResult.message;
      answerSource = 'Инструмент приложения';
    }
    if (answerText.isEmpty) {
      answerText = deterministic.text;
      final modelStatus = await _llm.status();
      if (modelStatus.isInstalled && normalizedQuery.isNotEmpty) {
        try {
          var localContext = await buildLocalAssistantContext(
            effectiveState,
            normalizedQuery,
            activityContext: activityContext,
          );
          final conversation = _conversationMemory(
            effectiveState.assistantMessages,
            normalizedQuery,
          );
          if (conversation.isNotEmpty) {
            localContext = '$localContext\nИстория диалога:\n$conversation';
          }
          answerText = await _llm.answer(
            query: _boundedMessage(normalizedQuery),
            localContext: localContext,
            localeCode: effectiveState.localeCode,
          );
          answerSource = 'Qwen3.5 0.8B · локально';
        } catch (error, stackTrace) {
          await ErrorLogService.instance.recordError(
            error,
            stackTrace,
            source: 'Local assistant answer',
          );
          answerText =
              '${deterministic.text}\n\nЛокальная модель не ответила: ${_shortError(error)}';
        }
      }
    }

    if (toolResult == null && latestState != null) {
      effectiveState = latestState();
    }

    final related = prefilledRelatedSection.isNotEmpty
        ? prefilledRelatedSection
        : toolResult?.relatedSection ?? deterministic.relatedSection;
    final now = DateTime.now();
    final userMessage =
        existingUserMessage ??
        AssistantMessage(
          id: newId(),
          createdAt: now.toIso8601String(),
          role: 'user',
          text: displayText.trim().isEmpty
              ? normalizedQuery
              : displayText.trim(),
          relatedSection: related,
          kind: kind,
          transcript: transcript,
          attachmentPath: attachmentPath,
          thumbnailPath: thumbnailPath,
          attachmentName: attachmentName,
          mimeType: mimeType,
          analysis: analysis,
          durationSeconds: durationSeconds,
        );
    final assistantMessage = AssistantMessage(
      id: '${newId()}-assistant',
      createdAt: DateTime.now().toIso8601String(),
      role: 'assistant',
      text: '$answerSource\n$answerText',
      relatedSection: related,
      kind: toolResult == null && actionSummary.isEmpty ? 'text' : 'action',
      actionSummary: actionSummary.isNotEmpty
          ? actionSummary
          : toolResult?.message ?? '',
    );
    final combined = [
      assistantMessage,
      userMessage,
      ...effectiveState.assistantMessages.where(
        (message) => message.id != userMessage.id,
      ),
    ];
    if (combined.length > 3000) {
      await deleteMediaForMessages(combined.skip(3000));
    }
    effectiveState = effectiveState.copyWith(
      assistantMessages: combined.take(3000).toList(),
    );
    return ConversationSubmitResult(
      state: effectiveState,
      relatedSection: related,
      usedTool: toolResult != null,
    );
  }

  Future<void> deleteMediaForMessages(
    Iterable<AssistantMessage> messages,
  ) async {
    final paths = <String>{
      for (final message in messages)
        ...[
          message.attachmentPath,
          message.thumbnailPath,
        ].where((path) => path.trim().isNotEmpty),
    };
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}

String _conversationMemory(List<AssistantMessage> messages, String query) {
  if (messages.isEmpty) return '';
  final currentDate = todayKey();
  final words = query
      .toLowerCase()
      .split(RegExp(r'[^a-zа-яё0-9]+', caseSensitive: false))
      .where((word) => word.length >= 4)
      .toSet();
  final selected = <AssistantMessage>[];
  for (final message in messages) {
    if (message.dateKey == currentDate && selected.length < 28) {
      selected.add(message);
    }
  }
  var recentPrevious = 0;
  for (final message in messages) {
    if (message.dateKey == currentDate || selected.contains(message)) continue;
    selected.add(message);
    recentPrevious++;
    if (recentPrevious >= 8) break;
  }
  for (final message in messages) {
    if (message.dateKey == currentDate || selected.contains(message)) continue;
    final haystack = '${message.text} ${message.transcript} ${message.analysis}'
        .toLowerCase();
    if (words.any(haystack.contains)) selected.add(message);
    if (selected.length >= 40) break;
  }
  selected.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return selected
      .map((message) {
        final role = message.role == 'user' ? 'Пользователь' : 'Ассистент';
        final content = [
          message.text,
          if (message.transcript.isNotEmpty)
            'Расшифровка: ${message.transcript}',
          if (message.analysis.isNotEmpty) 'Анализ: ${message.analysis}',
        ].where((item) => item.trim().isNotEmpty).join(' ');
        final compact = content.length > 650
            ? '${content.substring(0, 650)}…'
            : content;
        return '[${message.dateKey}] $role: $compact';
      })
      .join('\n');
}

String _shortError(Object error) {
  final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= 180 ? text : '${text.substring(0, 177)}...';
}

String _boundedMessage(String value, {int limit = 6000}) {
  final text = value.trim();
  if (text.length <= limit) return text;
  final head = (limit * 0.72).round();
  final tail = limit - head;
  return '${text.substring(0, head)}\n…\n'
      '${text.substring(text.length - tail)}';
}

bool _looksLikeActionRequest(String value) {
  final lower = value.toLowerCase();
  if (RegExp(
    r'^(?:как|что|почему|зачем|когда|где|можно\s+ли|расскажи|объясни|проанализируй|how|what|why|when|where|can\s+i)\b',
    caseSensitive: false,
  ).hasMatch(lower.trimLeft())) {
    return false;
  }
  return const [
    'запиш',
    'добав',
    'созда',
    'постав',
    'завед',
    'напомни',
    'отмет',
    'выпил',
    'съел',
    'принял',
    'приняла',
    'прошёл',
    'прошел',
    'пробежал',
    'тренировался',
    'тренировалась',
    'занимался',
    'занималась',
    'record ',
    'add ',
    'create ',
    'log ',
    'set ',
    'remind ',
  ].any(lower.contains);
}

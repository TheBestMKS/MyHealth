part of '../screens.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onSelect,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;
  final SectionSelected onSelect;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _activityService = const ActivityContextService();
  final _llm = LocalLlmService.instance;
  final _speech = SpeechInputService.instance;
  final _conversation = AssistantConversationService();

  LocalModelStatus? _modelStatus;
  ActivityContextSnapshot? _activityContext;
  double? _downloadProgress;
  bool _modelBusy = false;
  bool _contextBusy = false;
  bool _listening = false;
  String _speechStatus = '';
  String _voicePrefix = '';
  String _selectedDate = todayKey();
  bool _voiceInput = false;
  DateTime? _voiceStartedAt;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshModelStatus());
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (!state.settings.aiEnabled) {
      return PageBand(
        title: AppText.get(state.localeCode, 'assistant'),
        subtitle: 'Локальный помощник отключён пользователем',
        children: [
          const MedicalDisclaimerBanner(),
          InfoTile(
            icon: Icons.psychology_alt_outlined,
            title: 'AI-анализ выключен',
            subtitle:
                'Дневники и ручной ввод продолжают работать. Включить локальный анализ можно в настройках.',
            onTap: () => widget.onSelect(AppSection.settings),
          ),
        ],
      );
    }
    final dates =
        state.assistantMessages
            .map((message) => message.dateKey)
            .where((date) => date.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (dates.isNotEmpty && !dates.contains(_selectedDate)) {
      _selectedDate = dates.first;
    }
    final messages = state.assistantMessages
        .where((message) => message.dateKey == _selectedDate)
        .toList()
        .reversed
        .toList();
    final lowStock = state.medications.where((item) => item.stockIsLow).length;
    return PageBand(
      title: AppText.get(state.localeCode, 'assistant'),
      subtitle:
          'Локальный помощник по дневнику, питанию, здоровью, расписанию и тренировкам',
      trailing: state.assistantMessages.isEmpty
          ? null
          : LocalizedIconButton.filledTonal(
              tooltip: 'Очистить выбранный день',
              onPressed: _modelBusy ? null : _clearSelectedDay,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
      children: [
        const MedicalDisclaimerBanner(),
        if (dates.isNotEmpty) _buildHistorySelector(context, dates, messages),
        _buildModelCard(context),
        _buildContextCard(context),
        ResponsiveGrid(
          children: [
            MetricCard(
              title: 'Готовность',
              value: '${state.readinessScore}/100',
              subtitle: _readinessText(state.readinessScore),
              icon: Icons.speed_outlined,
              color: Colors.teal,
              progress: state.readinessScore / 100,
            ),
            MetricCard(
              title: 'Лекарства',
              value: '${state.medications.length}',
              subtitle: lowStock == 0
                  ? 'низких остатков нет'
                  : 'низкий остаток: $lowStock',
              icon: Icons.medication_outlined,
              color: lowStock == 0 ? Colors.indigo : Colors.deepOrange,
              onTap: () => widget.onSelect(AppSection.medicines),
            ),
            MetricCard(
              title: 'Медкарта',
              value:
                  '${state.medicalEvents.length + state.injuries.length + state.careProviders.length}',
              subtitle: 'события, травмы, врачи и клиники',
              icon: Icons.badge_outlined,
              color: Colors.purple,
              onTap: () => widget.onSelect(AppSection.medicalCard),
            ),
            MetricCard(
              title: 'Документы',
              value: '${state.documents.length}',
              subtitle: 'с тегами и связями',
              icon: Icons.folder_copy_outlined,
              color: Colors.blueGrey,
              onTap: () => widget.onSelect(AppSection.documents),
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Быстрые запросы',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _assistantPromptChip('Что важно сегодня?'),
                    _assistantPromptChip('Проверь лекарства и остатки'),
                    _assistantPromptChip(
                      'Подбери тренировку по готовности и ограничениям',
                    ),
                    _assistantPromptChip('Оцени питание с учётом аллергий'),
                    _assistantPromptChip('Что показать врачу?'),
                    _assistantPromptChip('Напомни выпить воду в 15:30'),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (messages.isEmpty)
          const InfoTile(
            icon: Icons.psychology_outlined,
            title: 'Диалог пока пуст',
            subtitle:
                'Задайте вопрос или продиктуйте его. Команды вроде «выпил 300 мл воды», «давление 120/80» и «напомни лекарство в 20:00» сразу обновляют дневник.',
          )
        else
          ...messages.map(
            (message) => _AssistantMessageBubble(
              message: message,
              onOpenSection: message.role == 'assistant'
                  ? () => widget.onSelect(
                      _assistantSection(message.relatedSection),
                    )
                  : null,
            ),
          ),
        _buildInputCard(context),
      ],
    );
  }

  Widget _buildHistorySelector(
    BuildContext context,
    List<String> dates,
    List<AssistantMessage> messages,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.history_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedDate,
                  items: [
                    for (final date in dates)
                      DropdownMenuItem(
                        value: date,
                        child: LocalizedText(
                          date == todayKey()
                              ? 'Сегодня · ${displayDateKey(date)}'
                              : displayDateKey(date),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedDate = value);
                  },
                ),
              ),
            ),
            Pill(label: '${messages.length}', icon: Icons.forum_outlined),
          ],
        ),
      ),
    );
  }

  Future<void> _clearSelectedDay() async {
    if (_modelBusy) return;
    final removed = widget.state.assistantMessages
        .where((message) => message.dateKey == _selectedDate)
        .toList();
    await _conversation.deleteMediaForMessages(removed);
    if (!mounted) return;
    widget.onChanged(
      widget.state.copyWith(
        assistantMessages: widget.state.assistantMessages
            .where((message) => message.dateKey != _selectedDate)
            .toList(),
      ),
    );
    setState(() => _selectedDate = todayKey());
  }

  Widget _buildModelCard(BuildContext context) {
    final status = _modelStatus;
    final installed = status?.isInstalled == true;
    final downloading = _downloadProgress != null;
    final subtitle = status == null
        ? 'Проверяем локальную модель...'
        : installed
        ? '${status.name} · ${status.sizeLabel} · ${status.isBundled ? 'встроена в Full' : 'установлена пользователем'} · ${status.isMultimodal ? 'текст и изображения' : 'только текст'}. Загружается в память только на время ответа.'
        : 'Быстрые инструменты работают без модели. Установите Qwen3.5 0.8B Q4_K_M с vision-projector (около 700 МБ) или импортируйте совместимые GGUF.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  installed ? Icons.memory_outlined : Icons.smart_toy_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LocalizedText(
                    installed
                        ? 'Локальная языковая модель готова'
                        : 'Локальная языковая модель',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Pill(
                  label: installed
                      ? (status!.isMultimodal ? 'офлайн · vision' : 'офлайн')
                      : 'быстрый режим',
                  icon: installed ? Icons.offline_bolt_outlined : Icons.bolt,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LocalizedText(subtitle),
            if (downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 6),
              LocalizedText(
                _downloadProgress == null
                    ? 'Подготовка загрузки'
                    : 'Загружено ${(_downloadProgress! * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            ActionRow(
              children: [
                if (!installed)
                  FilledButton.icon(
                    onPressed: downloading ? null : _downloadModel,
                    icon: const Icon(Icons.download_outlined),
                    label: const LocalizedText('Установить'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: downloading || _modelBusy ? null : _importModel,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const LocalizedText('Импорт GGUF'),
                ),
                if (installed && status?.isBundled != true)
                  LocalizedIconButton(
                    tooltip: 'Удалить локальную модель',
                    onPressed: _modelBusy ? null : _removeModel,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextCard(BuildContext context) {
    final snapshot = _activityContext;
    final profile = widget.state.profile;
    final hasHome =
        profile.homeLatitude != null && profile.homeLongitude != null;
    final hasWork =
        profile.workLatitude != null && profile.workLongitude != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: LocalizedText(
                    'Контекст телефона',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                LocalizedIconButton.filledTonal(
                  tooltip: 'Обновить контекст',
                  onPressed: _contextBusy ? null : _refreshActivityContext,
                  icon: _contextBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LocalizedText(
              snapshot?.summary ??
                  'Движение и местоположение проверяются только по нажатию. Фоновое слежение не используется.',
            ),
            if (snapshot != null && snapshot.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              LocalizedText(
                snapshot.notes.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Pill(
                  label: hasHome ? 'дом сохранён' : 'дом не задан',
                  icon: Icons.home_outlined,
                ),
                Pill(
                  label: hasWork ? 'работа сохранена' : 'работа не задана',
                  icon: Icons.work_outline,
                ),
                LocalizedText('радиус ${profile.placeRadiusMeters} м'),
              ],
            ),
            const SizedBox(height: 10),
            ActionRow(
              children: [
                FilledButton.tonalIcon(
                  onPressed: snapshot?.latitude == null
                      ? null
                      : () => _saveCurrentPlace(home: true),
                  icon: const Icon(Icons.home_outlined),
                  label: const LocalizedText('Это дом'),
                ),
                FilledButton.tonalIcon(
                  onPressed: snapshot?.latitude == null
                      ? null
                      : () => _saveCurrentPlace(home: false),
                  icon: const Icon(Icons.work_outline),
                  label: const LocalizedText('Это работа'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: LocalizedTextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                enabled: !_modelBusy,
                decoration: InputDecoration(
                  labelText: 'Вопрос или команда',
                  hintText:
                      'Например: оцени сон и подбери безопасную тренировку',
                  helperText: _speechStatus.isEmpty
                      ? 'Все данные остаются на устройстве'
                      : _speechStatus,
                ),
                onChanged: (_) {
                  if (_voiceInput) unawaited(_speech.cancel());
                  _voiceInput = false;
                },
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<UniversalCaptureStart>(
              tooltip: 'Камера или файл',
              enabled: !_modelBusy,
              icon: const Icon(Icons.attach_file),
              onSelected: (start) => showUniversalCaptureSheet(
                context,
                widget.state,
                widget.onChanged,
                widget.onSelect,
                start: start,
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: UniversalCaptureStart.camera,
                  child: ListTile(
                    leading: Icon(Icons.photo_camera_outlined),
                    title: LocalizedText('Сфотографировать'),
                  ),
                ),
                PopupMenuItem(
                  value: UniversalCaptureStart.file,
                  child: ListTile(
                    leading: Icon(Icons.attach_file),
                    title: LocalizedText('Приложить файл'),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            LocalizedIconButton.filledTonal(
              tooltip: _listening
                  ? 'Остановить диктовку'
                  : 'Диктовать по-русски офлайн',
              onPressed: _modelBusy ? null : _toggleSpeech,
              icon: Icon(_listening ? Icons.mic : Icons.mic_none_outlined),
            ),
            const SizedBox(width: 8),
            LocalizedIconButton.filled(
              tooltip: 'Отправить',
              onPressed: _modelBusy ? null : _send,
              icon: _modelBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assistantPromptChip(String text) {
    return ActionChip(
      avatar: const Icon(Icons.bolt_outlined),
      label: LocalizedText(text),
      onPressed: _modelBusy
          ? null
          : () {
              _voiceInput = false;
              _controller.text = text;
              unawaited(_send());
            },
    );
  }

  Future<void> _send() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _modelBusy) return;
    if (_voiceInput) await _speech.stop();
    final voicePath = _voiceInput ? _speech.takeRecordedAudio() : '';
    try {
      final duration = _voiceStartedAt == null
          ? 0
          : DateTime.now().difference(_voiceStartedAt!).inSeconds;
      AssistantBackgroundService.instance.enqueueText(
        query: query,
        kind: _voiceInput ? 'voice' : 'text',
        transcript: _voiceInput ? query : '',
        durationSeconds: duration,
        attachmentPath: voicePath,
        attachmentName: voicePath.isEmpty
            ? ''
            : File(voicePath).uri.pathSegments.last,
        activityContext: _activityContext?.summary ?? '',
      );
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _selectedDate = todayKey();
        _voiceInput = false;
        _voiceStartedAt = null;
        _listening = false;
        _speechStatus = 'Запрос обрабатывается в фоне';
      });
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Assistant request',
      );
      _showError('Не удалось обработать запрос: $error');
    }
  }

  Future<void> _toggleSpeech() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _listening = false;
          _speechStatus = 'Диктовка остановлена';
        });
      }
      return;
    }
    _voicePrefix = _controller.text.trim();
    _voiceStartedAt = DateTime.now();
    try {
      await _speech.startRussian(
        onWords: (words, isFinal) {
          if (!mounted) return;
          setState(() {
            _controller.text = [
              _voicePrefix,
              words.trim(),
            ].where((item) => item.isNotEmpty).join(' ');
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
            if (isFinal) {
              _listening = false;
              _voiceInput = true;
              _speechStatus = 'Распознано локально';
            }
          });
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            _speechStatus = 'Ошибка диктовки: $error';
          });
        },
      );
      if (mounted) {
        setState(() {
          _listening = true;
          _voiceInput = true;
          _speechStatus = 'Слушаю по-русски на устройстве...';
        });
      }
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Russian voice input',
      );
      if (!mounted) return;
      setState(() {
        _listening = false;
        _speechStatus = _shortAssistantError(error);
      });
    }
  }

  Future<void> _refreshActivityContext() async {
    setState(() => _contextBusy = true);
    final snapshot = await _activityService.capture(
      widget.state.profile,
      geolocationEnabled: widget.state.settings.geolocationEnabled,
    );
    if (!mounted) return;
    setState(() {
      _activityContext = snapshot;
      _contextBusy = false;
    });
  }

  void _saveCurrentPlace({required bool home}) {
    final snapshot = _activityContext;
    if (snapshot?.latitude == null || snapshot?.longitude == null) return;
    final profile = home
        ? widget.state.profile.copyWith(
            homeLatitude: snapshot!.latitude,
            homeLongitude: snapshot.longitude,
          )
        : widget.state.profile.copyWith(
            workLatitude: snapshot!.latitude,
            workLongitude: snapshot.longitude,
          );
    widget.onChanged(widget.state.copyWith(profile: profile));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LocalizedText(
          home ? 'Точка дома сохранена' : 'Точка работы сохранена',
        ),
      ),
    );
  }

  Future<void> _refreshModelStatus() async {
    final status = await _llm.status();
    if (mounted) setState(() => _modelStatus = status);
  }

  Future<void> _importModel() async {
    setState(() => _modelBusy = true);
    try {
      final status = await _llm.importModel();
      if (!mounted || status == null) return;
      setState(() => _modelStatus = status);
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Local model import',
      );
      _showError('Не удалось импортировать модель: $error');
    } finally {
      if (mounted) setState(() => _modelBusy = false);
    }
  }

  Future<void> _downloadModel() async {
    if (widget.state.settings.offlineOnly) {
      _showError(
        'Загрузка отключена режимом «Полностью офлайн». Импортируйте GGUF с устройства или временно разрешите сеть.',
      );
      return;
    }
    setState(() => _downloadProgress = 0);
    try {
      final status = await _llm.downloadRecommended(
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _modelStatus = status;
        _downloadProgress = null;
      });
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Local model download',
      );
      if (mounted) setState(() => _downloadProgress = null);
      _showError('Не удалось загрузить модель: $error');
    }
  }

  Future<void> _removeModel() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LocalizedText('Удалить локальную модель?'),
        content: const LocalizedText(
          'Быстрый помощник и инструменты продолжат работать, но свободный диалог станет недоступен.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LocalizedText('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const LocalizedText('Удалить'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    setState(() => _modelBusy = true);
    try {
      await _llm.removeInstalledModel();
      await _refreshModelStatus();
    } finally {
      if (mounted) setState(() => _modelBusy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: LocalizedText(message)));
  }
}

class _AssistantMessageBubble extends StatelessWidget {
  const _AssistantMessageBubble({required this.message, this.onOpenSection});

  final AssistantMessage message;
  final VoidCallback? onOpenSection;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    final attachmentExists =
        message.attachmentPath.isNotEmpty &&
        File(message.attachmentPath).existsSync();
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width < 720 ? 620 : 720,
        ),
        child: Card(
          color: isUser
              ? scheme.primaryContainer.withValues(alpha: 0.62)
              : scheme.surfaceContainerLow,
          margin: EdgeInsets.only(
            left: isUser ? 38 : 0,
            right: isUser ? 0 : 38,
            bottom: 8,
          ),
          child: InkWell(
            onTap: onOpenSection,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _messageIcon(message),
                        size: 18,
                        color: isUser ? scheme.primary : scheme.secondary,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: LocalizedText(
                          isUser ? 'Вы' : 'Ассистент',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Text(
                        _compactDateTime(message.createdAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  if (message.kind == 'voice') ...[
                    const SizedBox(height: 9),
                    if (attachmentExists)
                      _AssistantVoicePlayer(message: message)
                    else
                      Row(
                        children: [
                          const Icon(Icons.graphic_eq, size: 22),
                          const SizedBox(width: 7),
                          Expanded(
                            child: LocalizedText(
                              'Голосовое сообщение${message.durationSeconds > 0 ? ' · ${message.durationSeconds} с' : ''}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                  ],
                  if (message.isImage && attachmentExists) ...[
                    const SizedBox(height: 9),
                    Semantics(
                      button: true,
                      label: 'Открыть изображение на весь экран',
                      child: InkWell(
                        onTap: () => _showAssistantImage(context, message),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(
                              message.thumbnailPath.isNotEmpty &&
                                      File(message.thumbnailPath).existsSync()
                                  ? message.thumbnailPath
                                  : message.attachmentPath,
                            ),
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox(
                                  height: 80,
                                  child: Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (message.hasAttachment &&
                      !message.isImage &&
                      message.kind != 'voice') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.description_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.attachmentName.isEmpty
                                ? 'Вложенный файл'
                                : message.attachmentName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        LocalizedIconButton(
                          tooltip: 'Открыть файл',
                          onPressed: attachmentExists
                              ? () => OpenFilex.open(message.attachmentPath)
                              : null,
                          icon: const Icon(Icons.open_in_new),
                        ),
                        LocalizedIconButton(
                          tooltip: 'Поделиться файлом',
                          onPressed: attachmentExists
                              ? () => _shareAssistantAttachment(message)
                              : null,
                          icon: const Icon(Icons.share_outlined),
                        ),
                      ],
                    ),
                  ],
                  if (message.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SelectableText(message.text.trim()),
                  ],
                  if (message.transcript.isNotEmpty &&
                      message.transcript.trim() != message.text.trim()) ...[
                    const SizedBox(height: 6),
                    LocalizedText(
                      'Расшифровка: ${message.transcript}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (message.analysis.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.visibility_outlined, size: 19),
                      title: const LocalizedText('Описание и распознавание'),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            message.analysis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (message.actionSummary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: LocalizedText(
                            message.actionSummary,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (message.isImage && attachmentExists) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 2,
                        children: [
                          LocalizedIconButton(
                            tooltip: 'На весь экран',
                            onPressed: () =>
                                _showAssistantImage(context, message),
                            icon: const Icon(Icons.fullscreen),
                          ),
                          LocalizedIconButton(
                            tooltip: 'Поделиться изображением',
                            onPressed: () => _shareAssistantAttachment(message),
                            icon: const Icon(Icons.share_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantVoicePlayer extends StatefulWidget {
  const _AssistantVoicePlayer({required this.message});

  final AssistantMessage message;

  @override
  State<_AssistantVoicePlayer> createState() => _AssistantVoicePlayerState();
}

class _AssistantVoicePlayerState extends State<_AssistantVoicePlayer> {
  static final AudioPlayer _player = AudioPlayer();
  static final ValueNotifier<String?> _activePath = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _activePath,
      builder: (context, activePath, _) {
        final active = activePath == widget.message.attachmentPath;
        return StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, playerSnapshot) {
            final playerState = playerSnapshot.data;
            final playing = active && playerState?.playing == true;
            return Row(
              children: [
                LocalizedIconButton.filledTonal(
                  tooltip: playing ? 'Пауза' : 'Воспроизвести',
                  onPressed: _toggle,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        'Голосовое сообщение${widget.message.durationSeconds > 0 ? ' · ${widget.message.durationSeconds} с' : ''}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 5),
                      StreamBuilder<Duration>(
                        stream: _player.positionStream,
                        builder: (context, positionSnapshot) {
                          final totalMilliseconds = active
                              ? (_player.duration?.inMilliseconds ??
                                    widget.message.durationSeconds * 1000)
                              : widget.message.durationSeconds * 1000;
                          final positionMilliseconds = active
                              ? (positionSnapshot.data?.inMilliseconds ?? 0)
                              : 0;
                          final progress = totalMilliseconds <= 0
                              ? 0.0
                              : (positionMilliseconds / totalMilliseconds)
                                    .clamp(0.0, 1.0);
                          return LinearProgressIndicator(value: progress);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                LocalizedIconButton(
                  tooltip: 'Поделиться голосовым',
                  onPressed: () => _shareAssistantAttachment(widget.message),
                  icon: const Icon(Icons.share_outlined),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggle() async {
    final path = widget.message.attachmentPath;
    if (!File(path).existsSync()) return;
    try {
      if (_activePath.value == path) {
        if (_player.playing) {
          await _player.pause();
        } else {
          if (_player.processingState == ProcessingState.completed) {
            await _player.seek(Duration.zero);
          }
          unawaited(_player.play());
        }
        return;
      }
      await _player.stop();
      await _player.setFilePath(path);
      _activePath.value = path;
      unawaited(
        _player.play().whenComplete(() {
          if (_activePath.value == path &&
              _player.processingState == ProcessingState.completed) {
            _activePath.value = null;
          }
        }),
      );
    } catch (error, stackTrace) {
      await ErrorLogService.instance.recordError(
        error,
        stackTrace,
        source: 'Voice message playback',
      );
      if (_activePath.value == path) _activePath.value = null;
    }
  }
}

IconData _messageIcon(AssistantMessage message) {
  if (message.kind == 'voice') return Icons.mic_none_outlined;
  if (message.kind == 'image') return Icons.image_outlined;
  if (message.kind == 'file') return Icons.attach_file;
  if (message.kind == 'action') return Icons.check_circle_outline;
  return message.role == 'user'
      ? Icons.person_outline
      : Icons.psychology_outlined;
}

Future<void> _shareAssistantAttachment(AssistantMessage message) async {
  if (message.attachmentPath.isEmpty ||
      !File(message.attachmentPath).existsSync()) {
    return;
  }
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(message.attachmentPath, mimeType: message.mimeType)],
      text: message.analysis.isEmpty ? null : message.analysis,
      subject: message.attachmentName,
    ),
  );
}

Future<void> _showAssistantImage(
  BuildContext context,
  AssistantMessage message,
) async {
  if (!File(message.attachmentPath).existsSync()) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            message.attachmentName.isEmpty
                ? 'Изображение'
                : message.attachmentName,
          ),
          actions: [
            LocalizedIconButton(
              tooltip: 'Поделиться',
              onPressed: () => _shareAssistantAttachment(message),
              icon: const Icon(Icons.share_outlined),
            ),
            LocalizedIconButton(
              tooltip: 'Закрыть',
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: InteractiveViewer(
          minScale: 0.5,
          maxScale: 6,
          child: Center(
            child: Image.file(
              File(message.attachmentPath),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}

AppSection _assistantSection(String value) {
  return switch (value) {
    'health' => AppSection.health,
    'medicines' => AppSection.medicines,
    'workouts' => AppSection.workouts,
    'nutrition' => AppSection.nutrition,
    'labs' => AppSection.labs,
    'symptoms' => AppSection.symptoms,
    'documents' => AppSection.documents,
    'sleep' => AppSection.sleep,
    'calendar' => AppSection.calendar,
    'trips' => AppSection.trips,
    'vacation' => AppSection.vacation,
    'climate' => AppSection.climate,
    _ => AppSection.today,
  };
}

String _compactDateTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '${displayDateKey(todayKey(parsed))} $hour:$minute';
}

String _shortAssistantError(Object error) {
  final text = '$error'.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.length <= 180 ? text : '${text.substring(0, 177)}...';
}

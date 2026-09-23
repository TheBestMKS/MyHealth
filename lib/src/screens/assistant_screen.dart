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
  final _tools = const AssistantToolEngine();
  final _activityService = const ActivityContextService();
  final _media = MediaImportService();
  final _llm = LocalLlmService.instance;
  final _speech = SpeechInputService.instance;

  LocalModelStatus? _modelStatus;
  ActivityContextSnapshot? _activityContext;
  double? _downloadProgress;
  bool _busy = false;
  bool _contextBusy = false;
  bool _listening = false;
  String _speechStatus = '';
  String _voicePrefix = '';

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
    final messages = state.assistantMessages.take(20).toList();
    final lowStock = state.medications.where((item) => item.stockIsLow).length;
    return PageBand(
      title: AppText.get(state.localeCode, 'assistant'),
      subtitle:
          'Локальный помощник по дневнику, питанию, здоровью, расписанию и тренировкам',
      trailing: state.assistantMessages.isEmpty
          ? null
          : LocalizedIconButton.filledTonal(
              tooltip: 'Очистить диалог',
              onPressed: _busy
                  ? null
                  : () => widget.onChanged(
                      state.copyWith(assistantMessages: const []),
                    ),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
      children: [
        const MedicalDisclaimerBanner(),
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
                Text(
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
            (message) => InfoTile(
              icon: message.role == 'user'
                  ? Icons.person_outline
                  : Icons.psychology_outlined,
              title: message.role == 'user' ? 'Вы' : 'Ассистент',
              subtitle:
                  '${_compactDateTime(message.createdAt)}\n${message.text}',
              onTap: message.role == 'assistant'
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

  Widget _buildModelCard(BuildContext context) {
    final status = _modelStatus;
    final installed = status?.isInstalled == true;
    final downloading = _downloadProgress != null;
    final subtitle = status == null
        ? 'Проверяем локальную модель...'
        : installed
        ? '${status.name} · ${status.sizeLabel}. Модель загружается в память только на время ответа.'
        : 'Быстрый анализ уже работает без модели. Для свободного диалога установите Qwen2.5 0.5B Q4_K_M (около 491 MB) или импортируйте совместимый GGUF.';
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
                  child: Text(
                    installed
                        ? 'Локальная языковая модель готова'
                        : 'Локальная языковая модель',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Pill(
                  label: installed ? 'офлайн' : 'быстрый режим',
                  icon: installed ? Icons.offline_bolt_outlined : Icons.bolt,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            if (downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 6),
              Text(
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
                    label: const Text('Установить'),
                  ),
                FilledButton.tonalIcon(
                  onPressed: downloading || _busy ? null : _importModel,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Импорт GGUF'),
                ),
                if (installed)
                  LocalizedIconButton(
                    tooltip: 'Удалить локальную модель',
                    onPressed: _busy ? null : _removeModel,
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
                  child: Text(
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
            Text(
              snapshot?.summary ??
                  'Движение и местоположение проверяются только по нажатию. Фоновое слежение не используется.',
            ),
            if (snapshot != null && snapshot.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
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
                Text('радиус ${profile.placeRadiusMeters} м'),
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
                  label: const Text('Это дом'),
                ),
                FilledButton.tonalIcon(
                  onPressed: snapshot?.latitude == null
                      ? null
                      : () => _saveCurrentPlace(home: false),
                  icon: const Icon(Icons.work_outline),
                  label: const Text('Это работа'),
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
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: 'Вопрос или команда',
                  hintText:
                      'Например: оцени сон и подбери безопасную тренировку',
                  helperText: _speechStatus.isEmpty
                      ? 'Все данные остаются на устройстве'
                      : _speechStatus,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            LocalizedIconButton.filledTonal(
              tooltip: 'Заполнить по фото',
              onPressed: _busy ? null : _captureFromPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
            ),
            const SizedBox(width: 8),
            LocalizedIconButton.filledTonal(
              tooltip: _listening
                  ? 'Остановить диктовку'
                  : 'Диктовать по-русски офлайн',
              onPressed: _busy ? null : _toggleSpeech,
              icon: Icon(_listening ? Icons.mic : Icons.mic_none_outlined),
            ),
            const SizedBox(width: 8),
            LocalizedIconButton.filled(
              tooltip: 'Отправить',
              onPressed: _busy ? null : _send,
              icon: _busy
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
      label: Text(text),
      onPressed: _busy
          ? null
          : () {
              _controller.text = text;
              unawaited(_send());
            },
    );
  }

  Future<void> _captureFromPhoto() async {
    final kind = await showModalBottomSheet<_AssistantCaptureKind>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: const Text('Еда и напитки'),
              subtitle: const Text('Фото, название, калории и БЖУ'),
              onTap: () =>
                  Navigator.pop(sheetContext, _AssistantCaptureKind.food),
            ),
            ListTile(
              leading: const Icon(Icons.biotech_outlined),
              title: const Text('Результаты анализов'),
              subtitle: const Text('OCR показателей с обязательной проверкой'),
              onTap: () =>
                  Navigator.pop(sheetContext, _AssistantCaptureKind.lab),
            ),
            ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: const Text('Рецепт или назначение'),
              subtitle: const Text('Препараты, дозы и расписание приёма'),
              onTap: () => Navigator.pop(
                sheetContext,
                _AssistantCaptureKind.prescription,
              ),
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final candidates = switch (kind) {
        _AssistantCaptureKind.food => await _media.importForRecognitionBatch(
          source: 'фото еды',
          requiresMedicalReview: false,
          camera: true,
        ),
        _AssistantCaptureKind.lab => await _media.importForRecognitionBatch(
          source: 'OCR анализа',
          requiresMedicalReview: true,
          camera: true,
        ),
        _AssistantCaptureKind.prescription =>
          await _media.importPrescriptionBatch(camera: true),
      };
      if (!mounted || candidates.isEmpty) return;
      widget.onChanged(
        widget.state.copyWith(
          confirmationQueue: [...candidates, ...widget.state.confirmationQueue],
        ),
      );
      final section = switch (kind) {
        _AssistantCaptureKind.food => AppSection.nutrition,
        _AssistantCaptureKind.lab => AppSection.labs,
        _AssistantCaptureKind.prescription => AppSection.medicines,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            candidates.length == 1
                ? 'Фото распознано и ожидает подтверждения.'
                : 'Распознано записей: ${candidates.length}. Проверьте каждую перед сохранением.',
          ),
        ),
      );
      widget.onSelect(section);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обработать фото: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _busy) return;
    if (_listening) await _speech.stop();
    setState(() {
      _busy = true;
      _listening = false;
      _speechStatus = '';
    });

    final initial = widget.state;
    final now = DateTime.now().toIso8601String();
    final toolResult = _tools.execute(initial, query);
    var effectiveState = toolResult?.state ?? initial;
    final deterministic = buildAssistantAnswer(effectiveState, query);
    var answerText = toolResult?.message ?? deterministic.text;
    var answerSource = toolResult == null
        ? 'Быстрый локальный анализ'
        : 'Инструмент дневника';

    if (toolResult == null && _modelStatus?.isInstalled == true) {
      try {
        final localContext = await buildLocalAssistantContext(
          effectiveState,
          query,
          activityContext: _activityContext?.summary ?? '',
        );
        answerText = await _llm.answer(
          query: query,
          localContext: localContext,
          localeCode: effectiveState.localeCode,
        );
        answerSource = 'Локальная языковая модель';
      } catch (error) {
        answerText =
            '${deterministic.text}\n\nЛокальная модель не ответила, поэтому использован быстрый анализ: ${_shortAssistantError(error)}';
      }
    }

    final related = toolResult?.relatedSection ?? deterministic.relatedSection;
    final userMessage = AssistantMessage(
      id: newId(),
      createdAt: now,
      role: 'user',
      text: query,
      relatedSection: related,
    );
    final assistantMessage = AssistantMessage(
      id: '${newId()}-assistant',
      createdAt: DateTime.now().toIso8601String(),
      role: 'assistant',
      text: '$answerSource\n$answerText',
      relatedSection: related,
    );
    effectiveState = effectiveState.copyWith(
      assistantMessages: [
        assistantMessage,
        userMessage,
        ...effectiveState.assistantMessages,
      ].take(80).toList(),
    );
    if (!mounted) return;
    _controller.clear();
    widget.onChanged(effectiveState);
    setState(() => _busy = false);
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
          _speechStatus = 'Слушаю по-русски на устройстве...';
        });
      }
    } catch (error) {
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
        content: Text(home ? 'Точка дома сохранена' : 'Точка работы сохранена'),
      ),
    );
  }

  Future<void> _refreshModelStatus() async {
    final status = await _llm.status();
    if (mounted) setState(() => _modelStatus = status);
  }

  Future<void> _importModel() async {
    try {
      final status = await _llm.importModel();
      if (!mounted || status == null) return;
      setState(() => _modelStatus = status);
    } catch (error) {
      _showError('Не удалось импортировать модель: $error');
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
    } catch (error) {
      if (mounted) setState(() => _downloadProgress = null);
      _showError('Не удалось загрузить модель: $error');
    }
  }

  Future<void> _removeModel() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить локальную модель?'),
        content: const Text(
          'Быстрый помощник и инструменты продолжат работать, но свободный диалог станет недоступен.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await _llm.removeInstalledModel();
    await _refreshModelStatus();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AssistantCaptureKind { food, lab, prescription }

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

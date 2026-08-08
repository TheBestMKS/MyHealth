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

  @override
  void dispose() {
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
    final messages = state.assistantMessages.take(12).toList();
    final lowStock = state.medications.where((item) => item.stockIsLow).length;
    return PageBand(
      title: AppText.get(state.localeCode, 'assistant'),
      subtitle:
          'Локальный помощник по дневнику, графику, лекарствам, документам и тренировкам',
      trailing: state.assistantMessages.isEmpty
          ? null
          : LocalizedIconButton.filledTonal(
              tooltip: 'Очистить диалог',
              onPressed: () =>
                  widget.onChanged(state.copyWith(assistantMessages: const [])),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
      children: [
        const MedicalDisclaimerBanner(),
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
                    _assistantPromptChip('Подбери тренировку по готовности'),
                    _assistantPromptChip('Оцени питание за сегодня'),
                    _assistantPromptChip('Что показать врачу?'),
                    _assistantPromptChip('Какие документы связаны с лечением?'),
                    _assistantPromptChip('Учти поездку и климат'),
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
                'Задайте вопрос о данных дневника, лекарствах, графике, тренировках или документах.',
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: LocalizedTextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Вопрос',
                      hintText:
                          'Например: проверь сон, лекарства и тренировку на сегодня',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                LocalizedIconButton.filled(
                  tooltip: 'Отправить',
                  onPressed: _send,
                  icon: const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _assistantPromptChip(String text) {
    return ActionChip(
      avatar: const Icon(Icons.bolt_outlined),
      label: Text(text),
      onPressed: () {
        _controller.text = text;
        _send();
      },
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    final state = widget.state;
    final now = DateTime.now().toIso8601String();
    final answer = buildAssistantAnswer(state, text);
    final userMessage = AssistantMessage(
      id: newId(),
      createdAt: now,
      role: 'user',
      text: text,
      relatedSection: answer.relatedSection,
    );
    final assistantMessage = AssistantMessage(
      id: newId(),
      createdAt: now,
      role: 'assistant',
      text: answer.text,
      relatedSection: answer.relatedSection,
    );
    _controller.clear();
    widget.onChanged(
      state.copyWith(
        assistantMessages: [
          assistantMessage,
          userMessage,
          ...state.assistantMessages,
        ].take(80).toList(),
      ),
    );
  }
}

AppSection _assistantSection(String value) {
  return switch (value) {
    'medicines' => AppSection.medicines,
    'workouts' => AppSection.workouts,
    'nutrition' => AppSection.nutrition,
    'labs' => AppSection.labs,
    'symptoms' => AppSection.symptoms,
    'documents' => AppSection.documents,
    'sleep' => AppSection.sleep,
    'trips' => AppSection.trips,
    'vacation' => AppSection.vacation,
    'climate' => AppSection.climate,
    _ => AppSection.today,
  };
}

String _compactDateTime(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso;
  }
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '${displayDateKey(todayKey(parsed))} $hour:$minute';
}

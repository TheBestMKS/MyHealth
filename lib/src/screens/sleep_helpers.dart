part of '../screens.dart';

Future<void> _editSleepRecord(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  SleepRecord? existing,
]) async {
  final date = TextEditingController(
    text: dateInputText(existing?.date ?? state.today.date),
  );
  final bedTime = TextEditingController(text: existing?.bedTime ?? '23:00');
  final wakeTime = TextEditingController(text: existing?.wakeTime ?? '07:00');
  final awakenings = TextEditingController(
    text: (existing?.awakenings ?? 0).toString(),
  );
  final notes = TextEditingController(text: existing?.notes ?? '');
  var quality = existing?.quality ?? 3;
  var source = existing?.source ?? 'manual';
  var error = '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(existing == null ? 'Добавить запись сна' : 'Изменить сон'),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedTextField(
                  controller: date,
                  decoration: InputDecoration(
                    labelText: 'Дата пробуждения',
                    hintText: 'ДД.ММ.ГГГГ',
                    suffixIcon: LocalizedIconButton(
                      tooltip: 'Выбрать дату',
                      onPressed: () async {
                        final picked = await _pickDateValue(context, date.text);
                        if (picked != null) {
                          setDialogState(
                            () => date.text = dateInputText(todayKey(picked)),
                          );
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  inputFormatters: dateInputFormatters,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _timeField(
                        context,
                        bedTime,
                        'Время засыпания',
                        setDialogState,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _timeField(
                        context,
                        wakeTime,
                        'Время пробуждения',
                        setDialogState,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Качество сна: $quality из 5'),
                Slider(
                  min: 1,
                  max: 5,
                  divisions: 4,
                  value: quality.toDouble(),
                  label: '$quality',
                  onChanged: (value) =>
                      setDialogState(() => quality = value.round()),
                ),
                _numberField(awakenings, 'Ночных пробуждений'),
                LocalizedDropdownButtonFormField<String>(
                  initialValue: source,
                  decoration: const InputDecoration(labelText: 'Источник'),
                  items: const [
                    DropdownMenuItem(value: 'manual', child: Text('Вручную')),
                    DropdownMenuItem(value: 'phone', child: Text('Телефон')),
                    DropdownMenuItem(
                      value: 'wearable',
                      child: Text('Браслет или часы'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => source = value ?? source),
                ),
                const SizedBox(height: 10),
                LocalizedTextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Заметки',
                    hintText: 'Пробуждения, шум, перелёт, самочувствие утром',
                  ),
                ),
                if (error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final minutes = _sleepDurationMinutes(
                bedTime.text,
                wakeTime.text,
              );
              if (minutes <= 0 || minutes > 20 * 60) {
                setDialogState(
                  () => error = 'Проверьте время сна и пробуждения.',
                );
                return;
              }
              final targetDate = dateStorageText(
                date.text,
                fallback: state.today.date,
              );
              final record =
                  (existing ??
                          SleepRecord(
                            id: newId(),
                            date: targetDate,
                            bedTime: bedTime.text,
                            wakeTime: wakeTime.text,
                            durationMinutes: minutes,
                            quality: quality,
                          ))
                      .copyWith(
                        date: targetDate,
                        bedTime: bedTime.text.trim(),
                        wakeTime: wakeTime.text.trim(),
                        durationMinutes: minutes,
                        quality: quality,
                        awakenings: _parseInt(awakenings.text, 0).clamp(0, 30),
                        source: source,
                        timeZone: state.profile.city,
                        notes: notes.text.trim(),
                      );
              final records = existing == null
                  ? [record, ...state.sleepRecords]
                  : state.sleepRecords
                        .map((item) => item.id == existing.id ? record : item)
                        .toList();
              final metrics = state
                  .metricsFor(targetDate)
                  .copyWith(sleepHours: minutes / 60);
              onChanged(
                state
                    .updateMetricsFor(targetDate, metrics)
                    .copyWith(sleepRecords: records),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}

Widget _timeField(
  BuildContext context,
  TextEditingController controller,
  String label,
  StateSetter setDialogState,
) {
  return LocalizedTextField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'ЧЧ:ММ',
      suffixIcon: LocalizedIconButton(
        tooltip: 'Выбрать время',
        onPressed: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: _timeOfDayFromText(controller.text) ?? TimeOfDay.now(),
          );
          if (picked != null) {
            setDialogState(() => controller.text = _formatTimeOfDay(picked));
          }
        },
        icon: const Icon(Icons.schedule_outlined),
      ),
    ),
  );
}

int _sleepDurationMinutes(String bed, String wake) {
  final bedValue = _timeOfDayFromText(bed);
  final wakeValue = _timeOfDayFromText(wake);
  if (bedValue == null || wakeValue == null) return 0;
  final bedMinutes = bedValue.hour * 60 + bedValue.minute;
  var wakeMinutes = wakeValue.hour * 60 + wakeValue.minute;
  if (wakeMinutes <= bedMinutes) wakeMinutes += 24 * 60;
  return wakeMinutes - bedMinutes;
}

String _vacationSubtitle(VacationPeriod item) {
  final travel = item.travelMinutes > 0
      ? '${item.travelMinutes ~/ 60} ч ${item.travelMinutes % 60} мин'
      : 'дорога не указана';
  final facilities = <String>[
    if (item.gymAvailable) 'зал',
    if (item.poolAvailable) 'бассейн',
    if (item.walkingAvailable) 'прогулки',
  ];
  return '${displayDateKey(item.startDate)}-${displayDateKey(item.endDate)} · ${item.country}, ${item.city}\n'
      '$travel · ${item.transport} · ${facilities.isEmpty ? 'спорт не указан' : facilities.join(', ')}'
      '${item.nightTravel ? ' · ночная дорога' : ''}'
      '${item.notes.isEmpty ? '' : '\n${item.notes}'}';
}

part of '../screens.dart';

Future<void> _editSymptomEntry(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  SymptomEntry? existing,
]) async {
  final date = TextEditingController(
    text: dateInputText(existing?.date ?? state.today.date),
  );
  final time = TextEditingController(
    text: existing?.time.isNotEmpty == true
        ? existing!.time
        : _formatTimeOfDay(TimeOfDay.now()),
  );
  final notes = TextEditingController(text: existing?.notes ?? '');
  final temperature = TextEditingController(
    text: existing?.temperatureC?.toString() ?? '',
  );
  final systolic = TextEditingController(
    text: existing?.systolic?.toString() ?? '',
  );
  final diastolic = TextEditingController(
    text: existing?.diastolic?.toString() ?? '',
  );
  final pulse = TextEditingController(text: existing?.pulse?.toString() ?? '');
  final pendingCustomOptions = <CustomOption>[];
  var symptom = existing?.symptom.isNotEmpty == true
      ? existing!.symptom
      : 'головная боль';
  var intensity = existing?.intensity ?? 4;
  final mealIds = {...?existing?.linkedMealIds};
  final medicationIds = {...?existing?.linkedMedicationIds};
  final workoutIds = {...?existing?.linkedWorkoutIds};
  var sleepId = existing?.linkedSleepRecordId ?? '';
  var tripId = existing?.linkedTripId ?? '';
  var vacationId = existing?.linkedVacationId ?? '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final symptomItems = {
          'температура',
          'давление',
          'головная боль',
          'боль',
          'усталость',
          'стресс',
          'сонливость',
          'тошнота',
          'слабость',
          'кашель',
          'головокружение',
          'боль в груди',
          'одышка',
          'онемение',
          symptom,
          ...state.customLabels('symptomTypes'),
          ...pendingCustomOptions
              .where((item) => item.group == 'symptomTypes')
              .map((item) => item.label),
        }.where((item) => item.trim().isNotEmpty).toList();

        return AlertDialog(
          title: Text(
            existing == null ? 'Добавить симптом' : 'Изменить симптом',
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: LocalizedTextField(
                          controller: date,
                          decoration: InputDecoration(
                            labelText: 'Дата',
                            hintText: 'ДД.ММ.ГГГГ',
                            suffixIcon: LocalizedIconButton(
                              tooltip: 'Выбрать дату',
                              onPressed: () async {
                                final picked = await _pickDateValue(
                                  context,
                                  date.text,
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => date.text = dateInputText(
                                      todayKey(picked),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.calendar_month_outlined),
                            ),
                          ),
                          inputFormatters: dateInputFormatters,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LocalizedTextField(
                          controller: time,
                          decoration: InputDecoration(
                            labelText: 'Время',
                            hintText: 'ЧЧ:ММ',
                            suffixIcon: LocalizedIconButton(
                              tooltip: 'Выбрать время',
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime:
                                      _timeOfDayFromText(time.text) ??
                                      TimeOfDay.now(),
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => time.text = _formatTimeOfDay(picked),
                                  );
                                }
                              },
                              icon: const Icon(Icons.schedule_outlined),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: symptom,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Симптом'),
                    items: [
                      for (final item in symptomItems)
                        DropdownMenuItem(value: item, child: Text(item)),
                      const DropdownMenuItem(
                        value: _customDropdownValue,
                        child: Text('Свой вариант'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      if (value == _customDropdownValue) {
                        final custom = await _promptCustomOptionLabel(
                          context,
                          title: 'Свой симптом',
                          label: 'Симптом',
                        );
                        if (custom == null) return;
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'symptomTypes',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() => symptom = custom);
                        return;
                      }
                      setDialogState(() => symptom = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Интенсивность: $intensity из 10'),
                  Slider(
                    min: 1,
                    max: 10,
                    divisions: 9,
                    value: intensity.toDouble(),
                    label: '$intensity',
                    onChanged: (value) =>
                        setDialogState(() => intensity = value.round()),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Показатели',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 155,
                        child: _numberField(temperature, 'Температура, °C'),
                      ),
                      SizedBox(
                        width: 155,
                        child: _numberField(systolic, 'Давление верхнее'),
                      ),
                      SizedBox(
                        width: 155,
                        child: _numberField(diastolic, 'Давление нижнее'),
                      ),
                      SizedBox(width: 155, child: _numberField(pulse, 'Пульс')),
                    ],
                  ),
                  LocalizedTextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Заметка',
                      hintText: 'Когда началось, что усиливает или облегчает',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Связать с событиями',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (state.meals.isNotEmpty) ...[
                    const Text('Еда'),
                    Wrap(
                      spacing: 6,
                      children: state.meals
                          .take(12)
                          .map(
                            (item) => FilterChip(
                              label: Text(
                                '${item.title} · ${displayDateKey(item.date)}',
                              ),
                              selected: mealIds.contains(item.id),
                              onSelected: (selected) => setDialogState(
                                () => selected
                                    ? mealIds.add(item.id)
                                    : mealIds.remove(item.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (state.medications.isNotEmpty) ...[
                    const Text('Лекарства'),
                    Wrap(
                      spacing: 6,
                      children: state.medications
                          .map(
                            (item) => FilterChip(
                              label: Text(item.name),
                              selected: medicationIds.contains(item.id),
                              onSelected: (selected) => setDialogState(
                                () => selected
                                    ? medicationIds.add(item.id)
                                    : medicationIds.remove(item.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (state.workouts.isNotEmpty) ...[
                    const Text('Тренировки'),
                    Wrap(
                      spacing: 6,
                      children: state.workouts
                          .take(12)
                          .map(
                            (item) => FilterChip(
                              label: Text(item.title),
                              selected: workoutIds.contains(item.id),
                              onSelected: (selected) => setDialogState(
                                () => selected
                                    ? workoutIds.add(item.id)
                                    : workoutIds.remove(item.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (state.sleepRecords.isNotEmpty)
                    LocalizedDropdownButtonFormField<String>(
                      initialValue: sleepId.isEmpty ? null : sleepId,
                      decoration: const InputDecoration(labelText: 'Сон'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Не связывать'),
                        ),
                        for (final item in state.sleepRecords.take(20))
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${displayDateKey(item.date)} · ${item.durationHours.toStringAsFixed(1)} ч',
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => sleepId = value ?? ''),
                    ),
                  if (state.trips.isNotEmpty)
                    LocalizedDropdownButtonFormField<String>(
                      initialValue: tripId.isEmpty ? null : tripId,
                      decoration: const InputDecoration(
                        labelText: 'Командировка',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Не связывать'),
                        ),
                        for (final item in state.trips)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(item.title),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => tripId = value ?? ''),
                    ),
                  if (state.workSchedule.vacations.isNotEmpty)
                    LocalizedDropdownButtonFormField<String>(
                      initialValue: vacationId.isEmpty ? null : vacationId,
                      decoration: const InputDecoration(labelText: 'Отпуск'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Не связывать'),
                        ),
                        for (final item in state.workSchedule.vacations)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(item.title),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => vacationId = value ?? ''),
                    ),
                  const SizedBox(height: 8),
                  const MedicalDisclaimerBanner(),
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
                final targetDate = dateStorageText(
                  date.text,
                  fallback: state.today.date,
                );
                final temperatureValue = double.tryParse(
                  temperature.text.replaceAll(',', '.'),
                );
                final systolicValue = int.tryParse(systolic.text.trim());
                final diastolicValue = int.tryParse(diastolic.text.trim());
                final pulseValue = int.tryParse(pulse.text.trim());
                final attention =
                    _isAlarmingSymptom(symptom) ||
                    intensity >= 8 ||
                    (temperatureValue != null && temperatureValue >= 39) ||
                    (systolicValue != null &&
                        (systolicValue >= 180 || systolicValue < 85)) ||
                    (diastolicValue != null &&
                        (diastolicValue >= 120 || diastolicValue < 50)) ||
                    (pulseValue != null &&
                        (pulseValue >= 130 || pulseValue < 40));
                final entry =
                    (existing ??
                            SymptomEntry(
                              id: newId(),
                              symptom: symptom,
                              date: targetDate,
                              time: time.text.trim(),
                              intensity: intensity,
                            ))
                        .copyWith(
                          symptom: symptom,
                          date: targetDate,
                          time: time.text.trim(),
                          intensity: intensity,
                          notes: notes.text.trim(),
                          temperatureC: temperatureValue,
                          systolic: systolicValue,
                          diastolic: diastolicValue,
                          pulse: pulseValue,
                          linkedMealIds: mealIds.toList(),
                          linkedMedicationIds: medicationIds.toList(),
                          linkedWorkoutIds: workoutIds.toList(),
                          linkedSleepRecordId: sleepId,
                          linkedTripId: tripId,
                          linkedVacationId: vacationId,
                          climateSnapshot: [
                            state.profile.city,
                            state.profile.climate,
                          ].where((value) => value.isNotEmpty).join(' · '),
                          needsAttention: attention,
                        );
                final entries = existing == null
                    ? [entry, ...state.symptomEntries]
                    : state.symptomEntries
                          .map((item) => item.id == existing.id ? entry : item)
                          .toList();
                final metrics = state.metricsFor(targetDate);
                onChanged(
                  state
                      .updateMetricsFor(
                        targetDate,
                        metrics.copyWith(
                          symptoms: metrics.symptoms.contains(symptom)
                              ? metrics.symptoms
                              : [symptom, ...metrics.symptoms],
                        ),
                      )
                      .copyWith(
                        symptomEntries: entries,
                        customOptions: [
                          ...pendingCustomOptions,
                          ...state.customOptions,
                        ],
                      ),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    ),
  );
}

String _symptomEntrySubtitle(HealthAppState state, SymptomEntry item) {
  final values = <String>[
    '${displayDateKey(item.date)} ${item.time}',
    if (item.temperatureC != null) '${item.temperatureC} °C',
    if (item.systolic != null || item.diastolic != null)
      '${item.systolic ?? '-'}/${item.diastolic ?? '-'} мм рт. ст.',
    if (item.pulse != null) 'пульс ${item.pulse}',
    if (item.linkedMealIds.isNotEmpty) 'еда ${item.linkedMealIds.length}',
    if (item.linkedMedicationIds.isNotEmpty)
      'лекарства ${item.linkedMedicationIds.length}',
    if (item.linkedWorkoutIds.isNotEmpty)
      'тренировки ${item.linkedWorkoutIds.length}',
    if (item.linkedSleepRecordId.isNotEmpty) 'сон связан',
    if (item.linkedTripId.isNotEmpty) 'командировка связана',
    if (item.linkedVacationId.isNotEmpty) 'отпуск связан',
  ];
  final first = values.join(' · ');
  return item.notes.isEmpty ? first : '$first\n${item.notes}';
}

String? _repeatingSymptomWarning(HealthAppState state) {
  if (state.symptomEntries.length < 3) return null;
  final cutoff = DateTime.now().subtract(const Duration(days: 4));
  final counts = <String, int>{};
  for (final item in state.symptomEntries) {
    final date = parseDateKey(item.date);
    if (date != null && !date.isBefore(cutoff)) {
      counts.update(
        item.symptom.toLowerCase(),
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
  }
  final repeated = counts.entries.where((item) => item.value >= 3).toList();
  if (repeated.isEmpty) return null;
  return '${repeated.map((item) => '${item.key}: ${item.value} записи').join(', ')}. Если состояние сохраняется или усиливается, обсудите его со специалистом.';
}

HealthAppState _deleteSymptomFromDate(
  HealthAppState state,
  String date,
  String symptom,
) {
  final metrics = state.metricsFor(date);
  return state.updateMetricsFor(
    date,
    metrics.copyWith(symptoms: _removeFirstString(metrics.symptoms, symptom)),
  );
}

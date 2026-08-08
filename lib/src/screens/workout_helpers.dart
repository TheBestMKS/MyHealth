part of '../screens.dart';

Future<void> _addWorkout(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  WorkoutSession? workout,
]) async {
  final title = TextEditingController(text: workout?.title ?? '');
  final date = TextEditingController(
    text: dateInputText(workout?.scheduledDate ?? state.today.date),
  );
  final minutes = TextEditingController(
    text: workout == null ? '' : workout.minutes.toString(),
  );
  final notes = TextEditingController(text: workout?.notes ?? '');
  var focus = workout?.focus.trim().isNotEmpty == true
      ? workout!.focus
      : 'силовая';
  var intensity = workout?.intensity.trim().isNotEmpty == true
      ? workout!.intensity
      : state.readinessScore < 55
      ? 'низкая'
      : 'средняя';
  final selectedExerciseIds = (workout?.exerciseIds ?? const <String>[])
      .toSet();
  final pendingCustomOptions = <CustomOption>[];
  var error = '';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final focusItems = {
          'силовая',
          'кардио',
          'мобильность',
          'восстановление',
          'корпус',
          'баланс',
          focus,
          ...state.customLabels('workoutFocus'),
          ...pendingCustomOptions
              .where((item) => item.group == 'workoutFocus')
              .map((item) => item.label),
        }.toList();
        final intensityItems = {
          'низкая',
          'средняя',
          'высокая',
          'восстановительная',
          intensity,
          ...state.customLabels('workoutIntensity'),
          ...pendingCustomOptions
              .where((item) => item.group == 'workoutIntensity')
              .map((item) => item.label),
        }.toList();

        return AlertDialog(
          title: Text(
            workout == null
                ? 'Добавить тренировку'
                : 'Редактировать тренировку',
          ),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: силовая дома',
                    ),
                  ),
                  LocalizedTextField(
                    controller: date,
                    decoration: InputDecoration(
                      labelText: 'Дата',
                      hintText: 'ДД.ММ.ГГГГ',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      suffixIcon: LocalizedIconButton(
                        tooltip: 'Выбрать дату',
                        onPressed: () async {
                          final picked = await _pickDateValue(
                            context,
                            date.text,
                          );
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
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: focus,
                    decoration: const InputDecoration(labelText: 'Фокус'),
                    items: [
                      for (final item in focusItems)
                        DropdownMenuItem(value: item, child: Text(item)),
                      const DropdownMenuItem(
                        value: _customDropdownValue,
                        child: Text('Свой вариант'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }
                      if (value == _customDropdownValue) {
                        final custom = await _promptCustomOptionLabel(
                          context,
                          title: 'Свой фокус тренировки',
                          label: 'Фокус',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'workoutFocus',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() => focus = custom);
                        return;
                      }
                      setDialogState(() => focus = value);
                    },
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: intensity,
                    decoration: const InputDecoration(
                      labelText: 'Интенсивность',
                    ),
                    items: [
                      for (final item in intensityItems)
                        DropdownMenuItem(value: item, child: Text(item)),
                      const DropdownMenuItem(
                        value: _customDropdownValue,
                        child: Text('Свой вариант'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }
                      if (value == _customDropdownValue) {
                        final custom = await _promptCustomOptionLabel(
                          context,
                          title: 'Своя интенсивность',
                          label: 'Интенсивность',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'workoutIntensity',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() => intensity = custom);
                        return;
                      }
                      setDialogState(() => intensity = value);
                    },
                  ),
                  LocalizedTextField(
                    controller: minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Минуты'),
                  ),
                  LocalizedTextField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Заметки'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Упражнения',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final exercise in exerciseCatalog)
                        FilterChip(
                          label: Text(exercise.titleFor(state.localeCode)),
                          selected: selectedExerciseIds.contains(exercise.id),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedExerciseIds.add(exercise.id);
                              } else {
                                selectedExerciseIds.remove(exercise.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                final workoutMinutes = _parseInt(
                  minutes.text,
                  workout?.minutes ?? 0,
                ).clamp(0, 600).toInt();
                final targetDate = dateStorageText(
                  date.text,
                  fallback: state.today.date,
                );
                final normalizedTitle = title.text.trim();
                if (workout == null &&
                    normalizedTitle.isEmpty &&
                    selectedExerciseIds.isEmpty &&
                    workoutMinutes == 0) {
                  setDialogState(
                    () => error =
                        'Укажите название, минуты или выберите упражнения.',
                  );
                  return;
                }
                final updatedWorkout =
                    (workout ??
                            WorkoutSession(
                              id: newId(),
                              title: '',
                              focus: '',
                              minutes: 0,
                              intensity: '',
                              scheduledDate: targetDate,
                              exerciseIds: const [],
                            ))
                        .copyWith(
                          title: normalizedTitle.isEmpty
                              ? 'Тренировка: $focus'
                              : normalizedTitle,
                          focus: focus,
                          minutes: workoutMinutes,
                          intensity: intensity,
                          scheduledDate: targetDate,
                          exerciseIds: selectedExerciseIds.toList(),
                          notes: notes.text.trim(),
                        );
                var nextState = state.copyWith(
                  customOptions: [
                    ...pendingCustomOptions,
                    ...state.customOptions,
                  ],
                );
                if (workout != null) {
                  nextState = _removeWorkoutMinutes(nextState, workout);
                  nextState = _addWorkoutMinutes(nextState, updatedWorkout);
                  nextState = nextState.copyWith(
                    workouts: state.workouts
                        .map(
                          (item) =>
                              item.id == workout.id ? updatedWorkout : item,
                        )
                        .toList(),
                  );
                } else {
                  nextState = _addWorkoutMinutes(
                    nextState,
                    updatedWorkout,
                  ).copyWith(workouts: [updatedWorkout, ...state.workouts]);
                }
                onChanged(nextState);
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

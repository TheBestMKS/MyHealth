part of '../screens.dart';

Future<void> _addMedicationIntake(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  MedicationIntake? intake,
]) async {
  final knownMedicationIds = state.medications.map((item) => item.id).toSet();
  final initialMedicationId =
      intake?.medicationId.isNotEmpty == true &&
          knownMedicationIds.contains(intake!.medicationId)
      ? intake.medicationId
      : (state.medications.isEmpty
            ? _customDropdownValue
            : state.medications.first.id);
  final customName = TextEditingController(
    text: initialMedicationId == _customDropdownValue
        ? intake?.medicationName ?? ''
        : '',
  );
  final dose = TextEditingController();
  final date = TextEditingController(
    text: dateInputText(intake?.date ?? state.today.date),
  );
  final time = TextEditingController(text: intake?.time ?? '');
  final notes = TextEditingController(text: intake?.notes ?? '');
  var selectedMedicationId = initialMedicationId;
  var status = intake?.status.isNotEmpty == true ? intake!.status : 'принято';
  final pendingCustomOptions = <CustomOption>[];
  if (intake != null) {
    dose.text = intake.dose;
  } else if (state.medications.isNotEmpty) {
    dose.text = state.medications.first.dose;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final statusItems = {
          'принято',
          'пропущено',
          'перенесено',
          'отменено врачом',
          ...state.customLabels('medicationIntakeStatuses'),
          ...pendingCustomOptions
              .where((item) => item.group == 'medicationIntakeStatuses')
              .map((item) => item.label),
        }.toList();
        final selectedMedication = state.medications
            .where((item) => item.id == selectedMedicationId)
            .firstOrNull;
        if (!statusItems.contains(status)) {
          statusItems.insert(0, status);
        }
        return AlertDialog(
          title: Text(
            intake == null ? 'Отметить приём' : 'Редактировать приём',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: selectedMedicationId,
                    decoration: const InputDecoration(labelText: 'Препарат'),
                    items: [
                      for (final medication in state.medications)
                        DropdownMenuItem(
                          value: medication.id,
                          child: Text(
                            '${medication.name} · ${medication.dose}',
                          ),
                        ),
                      const DropdownMenuItem(
                        value: _customDropdownValue,
                        child: Text('Свой вариант'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedMedicationId = value;
                        final medication = state.medications
                            .where((item) => item.id == value)
                            .firstOrNull;
                        dose.text = medication?.dose ?? '';
                      });
                    },
                  ),
                  if (selectedMedicationId == _customDropdownValue)
                    LocalizedTextField(
                      controller: customName,
                      decoration: const InputDecoration(
                        labelText: 'Название препарата',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                    ),
                  LocalizedTextField(
                    controller: dose,
                    decoration: const InputDecoration(labelText: 'Доза'),
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
                  LocalizedTextField(
                    controller: time,
                    decoration: InputDecoration(
                      labelText: 'Время',
                      hintText: 'Например: 08:30',
                      suffixIcon: LocalizedIconButton(
                        tooltip: 'Выбрать время',
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                _timeOfDayFromText(time.text) ??
                                const TimeOfDay(hour: 8, minute: 30),
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
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Статус'),
                    items: [
                      for (final item in statusItems)
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
                          title: 'Свой статус приёма',
                          label: 'Статус',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'medicationIntakeStatuses',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() => status = custom);
                        return;
                      }
                      setDialogState(() => status = value);
                    },
                  ),
                  LocalizedTextField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Заметка'),
                    minLines: 1,
                    maxLines: 3,
                  ),
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
                final medicationName =
                    selectedMedication?.name ?? customName.text.trim();
                if (medicationName.isEmpty) {
                  return;
                }
                final targetDate = dateStorageText(
                  date.text,
                  fallback: state.today.date,
                );
                final updatedIntake =
                    (intake ??
                            MedicationIntake(
                              id: newId(),
                              medicationId: selectedMedication?.id ?? '',
                              medicationName: medicationName,
                              dose: dose.text.trim(),
                              date: targetDate,
                              time: time.text.trim(),
                              status: status,
                              notes: notes.text.trim(),
                            ))
                        .copyWith(
                          medicationId: selectedMedication?.id ?? '',
                          medicationName: medicationName,
                          dose: dose.text.trim(),
                          date: targetDate,
                          time: time.text.trim(),
                          status: status,
                          notes: notes.text.trim(),
                        );
                final nextIntakes = intake == null
                    ? [updatedIntake, ...state.medicationIntakes]
                    : state.medicationIntakes
                          .map(
                            (item) =>
                                item.id == intake.id ? updatedIntake : item,
                          )
                          .toList();
                onChanged(
                  state.copyWith(
                    customOptions: [
                      ...pendingCustomOptions,
                      ...state.customOptions,
                    ],
                    medicationIntakes: nextIntakes,
                    today: state.today.copyWith(
                      medicationTaken: _allMedicationTakenOnDate(
                        state.medications,
                        nextIntakes,
                        state.today.date,
                      ),
                    ),
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

Future<void> _addMedication(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  Medication? medication,
]) async {
  final name = TextEditingController(text: medication?.name ?? '');
  final dose = TextEditingController(text: medication?.dose ?? '');
  final schedule = TextEditingController(text: medication?.schedule ?? '');
  final date = TextEditingController(
    text: dateInputText(medication?.loggedDate ?? state.today.date),
  );
  final notes = TextEditingController(text: medication?.notes ?? '');
  final form = TextEditingController(text: medication?.form ?? '');
  final courseStart = TextEditingController(
    text: medication?.courseStart.isNotEmpty == true
        ? dateInputText(medication!.courseStart)
        : '',
  );
  final courseEnd = TextEditingController(
    text: medication?.courseEnd.isNotEmpty == true
        ? dateInputText(medication!.courseEnd)
        : '',
  );
  final foodRule = TextEditingController(text: medication?.foodRule ?? '');
  final prescribingDoctor = TextEditingController(
    text: medication?.prescribingDoctor ?? '',
  );
  final linkedCondition = TextEditingController(
    text: medication?.linkedCondition ?? '',
  );
  final remainingUnits = TextEditingController(
    text: medication?.remainingUnits == null || medication!.remainingUnits == 0
        ? ''
        : '${medication.remainingUnits}',
  );
  final lowStockThreshold = TextEditingController(
    text:
        medication?.lowStockThreshold == null ||
            medication!.lowStockThreshold == 0
        ? ''
        : '${medication.lowStockThreshold}',
  );
  final sideEffects = TextEditingController(
    text: medication?.sideEffects ?? '',
  );
  var purchaseReminder = medication?.purchaseReminder ?? false;
  var category = medication?.category.isNotEmpty == true
      ? medication!.category
      : 'лекарство';
  var schedulePreset = medication?.schedule.isNotEmpty == true
      ? medication!.schedule
      : 'утром';
  final pendingCustomOptions = <CustomOption>[];
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final categoryItems = {
          'лекарство',
          'витамин',
          'БАД',
          'процедура',
          ...state.customLabels('medicationCategories'),
          ...pendingCustomOptions
              .where((item) => item.group == 'medicationCategories')
              .map((item) => item.label),
        }.toList();
        final scheduleItems = {
          'утром',
          'днём',
          'вечером',
          'после еды',
          'перед сном',
          'по назначению',
          ...state.customLabels('medicationSchedules'),
          ...pendingCustomOptions
              .where((item) => item.group == 'medicationSchedules')
              .map((item) => item.label),
        }.toList();
        if (!categoryItems.contains(category)) {
          categoryItems.insert(0, category);
        }
        if (!scheduleItems.contains(schedulePreset)) {
          scheduleItems.insert(0, schedulePreset);
        }
        return AlertDialog(
          title: Text(
            medication == null ? 'Новое лекарство' : 'Редактировать лекарство',
          ),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Категория'),
                    items: [
                      for (final item in categoryItems)
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
                          title: 'Своя категория',
                          label: 'Категория лекарства',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'medicationCategories',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() => category = custom);
                        return;
                      }
                      setDialogState(() => category = value);
                    },
                  ),
                  LocalizedTextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                  LocalizedTextField(
                    controller: dose,
                    decoration: const InputDecoration(labelText: 'Доза'),
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: schedulePreset,
                    decoration: const InputDecoration(labelText: 'Расписание'),
                    items: [
                      for (final item in scheduleItems)
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
                          title: 'Своё расписание',
                          label: 'Расписание',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'medicationSchedules',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() {
                          schedulePreset = custom;
                          schedule.text = custom;
                        });
                        return;
                      }
                      setDialogState(() {
                        schedulePreset = value;
                        schedule.text = value;
                      });
                    },
                  ),
                  LocalizedTextField(
                    controller: schedule,
                    decoration: const InputDecoration(
                      labelText: 'Уточнение расписания',
                      helperText: 'Например: после завтрака или через день',
                    ),
                  ),
                  LocalizedTextField(
                    controller: date,
                    decoration: InputDecoration(
                      labelText: 'Дата первой отметки',
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
                  LocalizedTextField(
                    controller: form,
                    decoration: const InputDecoration(
                      labelText: 'Форма',
                      hintText: 'таблетки, капсулы, раствор, инъекция',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: LocalizedTextField(
                          controller: courseStart,
                          decoration: InputDecoration(
                            labelText: 'Начало курса',
                            hintText: 'ДД.ММ.ГГГГ',
                            suffixIcon: LocalizedIconButton(
                              tooltip: 'Выбрать дату',
                              onPressed: () async {
                                final picked = await _pickDateValue(
                                  context,
                                  courseStart.text,
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => courseStart.text = dateInputText(
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
                          controller: courseEnd,
                          decoration: InputDecoration(
                            labelText: 'Окончание курса',
                            hintText: 'ДД.ММ.ГГГГ',
                            suffixIcon: LocalizedIconButton(
                              tooltip: 'Выбрать дату',
                              onPressed: () async {
                                final picked = await _pickDateValue(
                                  context,
                                  courseEnd.text,
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => courseEnd.text = dateInputText(
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
                    ],
                  ),
                  LocalizedTextField(
                    controller: foodRule,
                    decoration: const InputDecoration(
                      labelText: 'Правило относительно еды',
                      hintText: 'до еды, после еды, независимо от еды',
                    ),
                  ),
                  LocalizedTextField(
                    controller: prescribingDoctor,
                    decoration: InputDecoration(
                      labelText: 'Назначивший врач',
                      suffixIcon: PopupMenuButton<String>(
                        tooltip: 'Выбрать врача',
                        icon: const Icon(Icons.badge_outlined),
                        onSelected: (value) => setDialogState(
                          () => prescribingDoctor.text = value,
                        ),
                        itemBuilder: (context) => [
                          for (final item in state.careProviders)
                            PopupMenuItem(
                              value: item.name,
                              child: Text(item.name),
                            ),
                        ],
                      ),
                    ),
                  ),
                  LocalizedTextField(
                    controller: linkedCondition,
                    decoration: InputDecoration(
                      labelText: 'Связанное состояние',
                      suffixIcon: PopupMenuButton<String>(
                        tooltip: 'Выбрать состояние',
                        icon: const Icon(Icons.favorite_border),
                        onSelected: (value) =>
                            setDialogState(() => linkedCondition.text = value),
                        itemBuilder: (context) => [
                          for (final item in state.chronicConditions)
                            PopupMenuItem(value: item, child: Text(item)),
                          for (final item in state.medicalEvents)
                            PopupMenuItem(
                              value: item.title,
                              child: Text(item.title),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: LocalizedTextField(
                          controller: remainingUnits,
                          decoration: const InputDecoration(
                            labelText: 'Остаток',
                            hintText: 'например: 20',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LocalizedTextField(
                          controller: lowStockThreshold,
                          decoration: const InputDecoration(
                            labelText: 'Порог закупки',
                            hintText: 'например: 5',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Напоминать о покупке'),
                    subtitle: const Text(
                      'Карточка подсветит низкий остаток при достижении порога.',
                    ),
                    value: purchaseReminder,
                    onChanged: (value) =>
                        setDialogState(() => purchaseReminder = value),
                  ),
                  LocalizedTextField(
                    controller: sideEffects,
                    decoration: const InputDecoration(
                      labelText: 'Побочные эффекты и реакции',
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  LocalizedTextField(
                    controller: notes,
                    decoration: const InputDecoration(labelText: 'Заметка'),
                    minLines: 1,
                    maxLines: 3,
                  ),
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
                if (name.text.trim().isNotEmpty) {
                  final scheduleValue = schedule.text.trim().isEmpty
                      ? schedulePreset
                      : schedule.text.trim();
                  final loggedDate = dateStorageText(
                    date.text,
                    fallback: state.today.date,
                  );
                  final courseStartDate = courseStart.text.trim().isEmpty
                      ? ''
                      : dateStorageText(
                          courseStart.text,
                          fallback: medication?.courseStart ?? '',
                        );
                  final courseEndDate = courseEnd.text.trim().isEmpty
                      ? ''
                      : dateStorageText(
                          courseEnd.text,
                          fallback: medication?.courseEnd ?? '',
                        );
                  final notesValue = notes.text.trim().isEmpty
                      ? 'Добавлено вручную.'
                      : notes.text.trim();
                  final updatedMedication =
                      (medication ??
                              Medication(
                                id: newId(),
                                name: name.text.trim(),
                                dose: dose.text.trim(),
                                schedule: scheduleValue,
                                takenToday: false,
                                notes: notesValue,
                                category: category,
                                loggedDate: loggedDate,
                              ))
                          .copyWith(
                            name: name.text.trim(),
                            dose: dose.text.trim(),
                            schedule: scheduleValue,
                            notes: notesValue,
                            category: category,
                            loggedDate: loggedDate,
                            form: form.text.trim(),
                            courseStart: courseStartDate,
                            courseEnd: courseEndDate,
                            foodRule: foodRule.text.trim(),
                            prescribingDoctor: prescribingDoctor.text.trim(),
                            linkedCondition: linkedCondition.text.trim(),
                            remainingUnits:
                                int.tryParse(remainingUnits.text.trim()) ?? 0,
                            lowStockThreshold:
                                int.tryParse(lowStockThreshold.text.trim()) ??
                                0,
                            sideEffects: sideEffects.text.trim(),
                            purchaseReminder: purchaseReminder,
                          );
                  final medications = medication == null
                      ? [updatedMedication, ...state.medications]
                      : state.medications
                            .map(
                              (item) => item.id == medication.id
                                  ? updatedMedication
                                  : item,
                            )
                            .toList();
                  final intakes = medication == null
                      ? state.medicationIntakes
                      : state.medicationIntakes
                            .map(
                              (item) => item.medicationId == medication.id
                                  ? item.copyWith(
                                      medicationName: updatedMedication.name,
                                      dose: updatedMedication.dose,
                                    )
                                  : item,
                            )
                            .toList();
                  onChanged(
                    state.copyWith(
                      customOptions: [
                        ...pendingCustomOptions,
                        ...state.customOptions,
                      ],
                      medications: medications,
                      medicationIntakes: intakes,
                      today: state.today.copyWith(
                        medicationTaken: _allMedicationTakenOnDate(
                          medications,
                          intakes,
                          state.today.date,
                        ),
                      ),
                    ),
                  );
                }
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

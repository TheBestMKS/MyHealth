part of '../screens.dart';

Future<void> showAlarmChallenge(
  BuildContext context,
  AlarmGroup alarm, {
  String? dateKey,
  bool wakefulnessCheck = false,
}) async {
  Future<void> dismiss(BuildContext dialogContext) async {
    await HealthNotificationService.instance.dismissAlarmOccurrence(
      alarm,
      dateKey: dateKey,
    );
    await WakefulnessMonitorService.instance.start(
      alarm,
      dateKey: dateKey,
      resetWindow: !wakefulnessCheck,
    );
    if (dialogContext.mounted) Navigator.pop(dialogContext);
  }

  if (alarm.unlockMode == 'simple') {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(alarm.title),
          content: Text('Время подъёма: ${alarm.wakeTime}'),
          actions: [
            FilledButton.icon(
              onPressed: () async {
                await dismiss(context);
              },
              icon: const Icon(Icons.alarm_off_outlined),
              label: const Text('Отключить'),
            ),
          ],
        ),
      ),
    );
    return;
  }
  final hard = alarm.unlockMode == 'math_hard';
  final now = DateTime.now().millisecondsSinceEpoch;
  final first = hard ? 17 + now % 29 : 3 + now % 7;
  final second = hard ? 12 + (now ~/ 7) % 31 : 2 + (now ~/ 5) % 8;
  final multiplier = hard ? 2 + (now ~/ 11) % 7 : 1;
  final expected = hard ? first * multiplier + second : first + second;
  final task = hard ? '$first × $multiplier + $second' : '$first + $second';
  final answer = TextEditingController();
  var error = '';
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(alarm.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Решите задачу, чтобы отключить будильник',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              Text(task, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 10),
              LocalizedTextField(
                controller: answer,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Ответ',
                  errorText: error.isEmpty ? null : error,
                ),
                onSubmitted: (_) {
                  if (int.tryParse(answer.text.trim()) == expected) {
                    unawaited(dismiss(dialogContext));
                  } else {
                    setDialogState(() => error = 'Ответ неверный');
                  }
                },
              ),
            ],
          ),
          actions: [
            FilledButton.icon(
              onPressed: () async {
                if (int.tryParse(answer.text.trim()) == expected) {
                  await dismiss(dialogContext);
                } else {
                  setDialogState(() => error = 'Ответ неверный');
                }
              },
              icon: const Icon(Icons.alarm_off_outlined),
              label: const Text('Проверить и отключить'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _editAlarmGroup(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  AlarmGroup? group,
]) async {
  final title = TextEditingController(text: group?.title ?? '');
  final wakeTime = TextEditingController(
    text: group?.wakeTime.isNotEmpty == true ? group!.wakeTime : '07:30',
  );
  final bedTime = TextEditingController(
    text: group?.bedTime.isNotEmpty == true ? group!.bedTime : '23:00',
  );
  final specificDate = TextEditingController(
    text: group?.specificDate.isNotEmpty == true
        ? dateInputText(group!.specificDate)
        : '',
  );
  final smartWindow = TextEditingController(
    text: '${group?.smartWakeWindowMinutes ?? 0}',
  );
  final gradualWakeMinutes = TextEditingController(
    text: '${group?.gradualWakeMinutes ?? 3}',
  );
  final wakefulnessWindowMinutes = TextEditingController(
    text: '${group?.wakefulnessWindowMinutes ?? 30}',
  );
  final wakefulnessInactivityMinutes = TextEditingController(
    text: '${group?.wakefulnessInactivityMinutes ?? 5}',
  );
  final pendingCustomOptions = <CustomOption>[];
  var days = group?.days.isNotEmpty == true ? group!.days : 'будни';
  var adaptive = group?.adaptive ?? true;
  var contextMode = group?.context ?? 'обычный';
  var priority = group?.priority ?? 2;
  var unlockMode = group?.unlockMode ?? 'simple';
  var dutyAware = group?.dutyAware ?? false;
  var vacationAware = group?.vacationAware ?? false;
  var useWearableSleepCycle = group?.useWearableSleepCycle ?? false;
  var vibrationEnabled = group?.vibrationEnabled ?? true;
  var gradualWakeEnabled = group?.gradualWakeEnabled ?? true;
  var wakefulnessCheckEnabled = group?.wakefulnessCheckEnabled ?? false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final dayItems = {
          'будни',
          'каждый день',
          'выходные',
          'понедельник-пятница',
          'плавающий график',
          'по сменам',
          'по необходимости',
          ...state.customLabels('alarmDays'),
          ...pendingCustomOptions
              .where((item) => item.group == 'alarmDays')
              .map((item) => item.label),
        }.where((item) => item.trim().isNotEmpty).toList();
        if (!dayItems.contains(days)) {
          dayItems.insert(0, days);
        }

        Future<void> pickTime(
          TextEditingController controller,
          TimeOfDay fallback,
        ) async {
          final picked = await showTimePicker(
            context: context,
            initialTime: _timeOfDayFromText(controller.text) ?? fallback,
          );
          if (picked != null) {
            setDialogState(() => controller.text = _formatTimeOfDay(picked));
          }
        }

        return AlertDialog(
          title: Text(
            group == null
                ? 'Добавить группу будильников'
                : 'Редактировать группу',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: title,
                    autofocus: group == null,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: рабочие дни',
                    ),
                  ),
                  LocalizedTextField(
                    controller: wakeTime,
                    decoration: InputDecoration(
                      labelText: 'Подъём',
                      hintText: 'ЧЧ:ММ',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      suffixIcon: LocalizedIconButton(
                        tooltip: 'Выбрать время',
                        onPressed: () => pickTime(
                          wakeTime,
                          const TimeOfDay(hour: 7, minute: 30),
                        ),
                        icon: const Icon(Icons.wb_sunny_outlined),
                      ),
                    ),
                  ),
                  LocalizedTextField(
                    controller: bedTime,
                    decoration: InputDecoration(
                      labelText: 'Отбой',
                      hintText: 'ЧЧ:ММ',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      suffixIcon: LocalizedIconButton(
                        tooltip: 'Выбрать время',
                        onPressed: () => pickTime(
                          bedTime,
                          const TimeOfDay(hour: 23, minute: 0),
                        ),
                        icon: const Icon(Icons.nightlight_round),
                      ),
                    ),
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: days,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Дни'),
                    items: [
                      for (final item in dayItems)
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
                          title: 'Свои дни будильника',
                          label: 'Дни или график',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'alarmDays',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() => days = custom);
                        return;
                      }
                      setDialogState(() => days = value);
                    },
                  ),
                  LocalizedTextField(
                    controller: specificDate,
                    decoration: InputDecoration(
                      labelText: 'Конкретная дата',
                      hintText: 'ДД.ММ.ГГГГ',
                      suffixIcon: LocalizedIconButton(
                        tooltip: 'Выбрать дату',
                        onPressed: () async {
                          final picked = await _pickDateValue(
                            context,
                            specificDate.text,
                          );
                          if (picked != null) {
                            setDialogState(
                              () => specificDate.text = dateInputText(
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
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: contextMode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Контекст'),
                    items: const [
                      DropdownMenuItem(
                        value: 'обычный',
                        child: Text('обычный'),
                      ),
                      DropdownMenuItem(
                        value: 'рабочий',
                        child: Text('рабочий'),
                      ),
                      DropdownMenuItem(
                        value: 'дежурство',
                        child: Text('дежурство'),
                      ),
                      DropdownMenuItem(value: 'отпуск', child: Text('отпуск')),
                      DropdownMenuItem(
                        value: 'командировка',
                        child: Text('командировка'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => contextMode = value);
                      }
                    },
                  ),
                  LocalizedDropdownButtonFormField<int>(
                    initialValue: priority.clamp(1, 5).toInt(),
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Приоритет'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 низкий')),
                      DropdownMenuItem(value: 2, child: Text('2 обычный')),
                      DropdownMenuItem(value: 3, child: Text('3 важный')),
                      DropdownMenuItem(value: 4, child: Text('4 высокий')),
                      DropdownMenuItem(value: 5, child: Text('5 критичный')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => priority = value);
                      }
                    },
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: unlockMode,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Отключение'),
                    items: const [
                      DropdownMenuItem(value: 'simple', child: Text('простое')),
                      DropdownMenuItem(
                        value: 'math_easy',
                        child: Text('математика лёгкая'),
                      ),
                      DropdownMenuItem(
                        value: 'math_hard',
                        child: Text('математика сложная'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => unlockMode = value);
                      }
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Адаптивный будильник'),
                    subtitle: const Text(
                      'Учитывать сон, стресс и восстановление при подсказках.',
                    ),
                    value: adaptive,
                    onChanged: (value) =>
                        setDialogState(() => adaptive = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Привязать к дежурствам'),
                    subtitle: const Text(
                      'В день дежурства рабочие будильники не включаются автоматически.',
                    ),
                    value: dutyAware,
                    onChanged: (value) =>
                        setDialogState(() => dutyAware = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Учитывать отпуск'),
                    value: vacationAware,
                    onChanged: (value) =>
                        setDialogState(() => vacationAware = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Учитывать циклы сна с браслета'),
                    subtitle: const Text(
                      'Будить в пределах допустимого смещения, если есть данные сна.',
                    ),
                    value: useWearableSleepCycle,
                    onChanged: (value) =>
                        setDialogState(() => useWearableSleepCycle = value),
                  ),
                  _numberField(smartWindow, 'Допустимое смещение, мин'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Вибрация'),
                    subtitle: const Text(
                      'Использовать вибрацию на поддерживаемых устройствах.',
                    ),
                    value: vibrationEnabled,
                    onChanged: (value) =>
                        setDialogState(() => vibrationEnabled = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Постепенное пробуждение'),
                    subtitle: const Text(
                      'Сначала тихий сигнал, затем обычный и полный будильник.',
                    ),
                    value: gradualWakeEnabled,
                    onChanged: (value) =>
                        setDialogState(() => gradualWakeEnabled = value),
                  ),
                  if (gradualWakeEnabled)
                    _numberField(gradualWakeMinutes, 'Время усиления, мин'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Контроль бодрствования'),
                    subtitle: const Text(
                      'Повторять сигнал при отсутствии движения после подъёма.',
                    ),
                    value: wakefulnessCheckEnabled,
                    onChanged: (value) =>
                        setDialogState(() => wakefulnessCheckEnabled = value),
                  ),
                  if (wakefulnessCheckEnabled) ...[
                    _numberField(
                      wakefulnessInactivityMinutes,
                      'Проверять через, мин',
                    ),
                    _numberField(
                      wakefulnessWindowMinutes,
                      'Период контроля, мин',
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
                final titleValue = title.text.trim();
                if (titleValue.isEmpty) {
                  return;
                }
                final wakeValue = wakeTime.text.trim().isEmpty
                    ? '07:30'
                    : wakeTime.text.trim();
                final bedValue = bedTime.text.trim().isEmpty
                    ? '23:00'
                    : bedTime.text.trim();
                final daysValue = days.trim().isEmpty
                    ? 'по необходимости'
                    : days.trim();
                final updatedGroup =
                    (group ??
                            AlarmGroup(
                              id: newId(),
                              title: titleValue,
                              wakeTime: wakeValue,
                              bedTime: bedValue,
                              days: daysValue,
                              adaptive: adaptive,
                              context: contextMode,
                              priority: priority,
                              unlockMode: unlockMode,
                              specificDate: specificDate.text.trim().isEmpty
                                  ? ''
                                  : dateStorageText(
                                      specificDate.text,
                                      fallback: state.today.date,
                                    ),
                              dutyAware: dutyAware,
                              vacationAware: vacationAware,
                              smartWakeWindowMinutes: _parseInt(
                                smartWindow.text,
                                0,
                              ).clamp(0, 120).toInt(),
                              useWearableSleepCycle: useWearableSleepCycle,
                              vibrationEnabled: vibrationEnabled,
                              gradualWakeEnabled: gradualWakeEnabled,
                              gradualWakeMinutes: _parseInt(
                                gradualWakeMinutes.text,
                                3,
                              ).clamp(1, 15).toInt(),
                              wakefulnessCheckEnabled: wakefulnessCheckEnabled,
                              wakefulnessWindowMinutes: _parseInt(
                                wakefulnessWindowMinutes.text,
                                30,
                              ).clamp(5, 120).toInt(),
                              wakefulnessInactivityMinutes: _parseInt(
                                wakefulnessInactivityMinutes.text,
                                5,
                              ).clamp(2, 30).toInt(),
                            ))
                        .copyWith(
                          title: titleValue,
                          wakeTime: wakeValue,
                          bedTime: bedValue,
                          days: daysValue,
                          adaptive: adaptive,
                          context: contextMode,
                          priority: priority,
                          unlockMode: unlockMode,
                          specificDate: specificDate.text.trim().isEmpty
                              ? ''
                              : dateStorageText(
                                  specificDate.text,
                                  fallback: state.today.date,
                                ),
                          dutyAware: dutyAware,
                          vacationAware: vacationAware,
                          smartWakeWindowMinutes: _parseInt(
                            smartWindow.text,
                            0,
                          ).clamp(0, 120).toInt(),
                          useWearableSleepCycle: useWearableSleepCycle,
                          vibrationEnabled: vibrationEnabled,
                          gradualWakeEnabled: gradualWakeEnabled,
                          gradualWakeMinutes: _parseInt(
                            gradualWakeMinutes.text,
                            3,
                          ).clamp(1, 15).toInt(),
                          wakefulnessCheckEnabled: wakefulnessCheckEnabled,
                          wakefulnessWindowMinutes: _parseInt(
                            wakefulnessWindowMinutes.text,
                            30,
                          ).clamp(5, 120).toInt(),
                          wakefulnessInactivityMinutes: _parseInt(
                            wakefulnessInactivityMinutes.text,
                            5,
                          ).clamp(2, 30).toInt(),
                          lastWakefulnessConfirmedDate: '',
                          wakefulnessMonitorStartedAt: '',
                          wakefulnessLastActivityAt: '',
                        );
                final alarmGroups = group == null
                    ? [updatedGroup, ...state.alarmGroups]
                    : state.alarmGroups
                          .map(
                            (item) => item.id == group.id ? updatedGroup : item,
                          )
                          .toList();
                onChanged(
                  state.copyWith(
                    alarmGroups: alarmGroups,
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

Future<void> _editReminder(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  ReminderItem? reminder,
  String? initialDate,
]) async {
  final title = TextEditingController(text: reminder?.title ?? '');
  final date = TextEditingController(
    text: dateInputText(
      reminder?.date.isNotEmpty == true
          ? reminder!.date
          : (initialDate ?? state.today.date),
    ),
  );
  final time = TextEditingController(
    text: reminder?.time.isNotEmpty == true ? reminder!.time : '09:00',
  );
  final pendingCustomOptions = <CustomOption>[];
  var category = reminder?.category.isNotEmpty == true
      ? reminder!.category
      : 'здоровье';
  var repeat = reminder?.repeat ?? 'none';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final categoryItems = {
          'здоровье',
          'лекарства',
          'вода',
          'сон',
          'тренировка',
          'питание',
          'анализы',
          'документы',
          'поездка',
          'прочее',
          ...state.customLabels('reminderCategories'),
          ...pendingCustomOptions
              .where((item) => item.group == 'reminderCategories')
              .map((item) => item.label),
        }.where((item) => item.trim().isNotEmpty).toList();
        if (!categoryItems.contains(category)) {
          categoryItems.insert(0, category);
        }

        return AlertDialog(
          title: Text(
            reminder == null
                ? 'Добавить напоминание'
                : 'Редактировать напоминание',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: title,
                    autofocus: reminder == null,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: принять витамин D',
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
                  LocalizedTextField(
                    controller: time,
                    decoration: InputDecoration(
                      labelText: 'Время',
                      hintText: 'ЧЧ:ММ',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      suffixIcon: LocalizedIconButton(
                        tooltip: 'Выбрать время',
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                _timeOfDayFromText(time.text) ??
                                const TimeOfDay(hour: 9, minute: 0),
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
                    initialValue: category,
                    isExpanded: true,
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
                          title: 'Своя категория напоминания',
                          label: 'Категория',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'reminderCategories',
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
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: repeat,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Повтор'),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('один раз')),
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text('каждый день'),
                      ),
                      DropdownMenuItem(
                        value: 'weekdays',
                        child: Text('по будням'),
                      ),
                      DropdownMenuItem(
                        value: 'weekends',
                        child: Text('по выходным'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => repeat = value);
                    },
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
                final titleValue = title.text.trim();
                if (titleValue.isEmpty) {
                  return;
                }
                final targetDate = dateStorageText(
                  date.text,
                  fallback: state.today.date,
                );
                final timeValue = time.text.trim().isEmpty
                    ? '09:00'
                    : time.text.trim();
                final normalizedCategory = category.trim().isEmpty
                    ? 'прочее'
                    : category.trim();
                final updatedReminder =
                    (reminder ??
                            ReminderItem(
                              id: newId(),
                              title: titleValue,
                              time: timeValue,
                              category: normalizedCategory,
                              done: false,
                              date: targetDate,
                              repeat: repeat,
                            ))
                        .copyWith(
                          title: titleValue,
                          time: timeValue,
                          category: normalizedCategory,
                          date: targetDate,
                          repeat: repeat,
                        );
                final reminders = reminder == null
                    ? [updatedReminder, ...state.reminders]
                    : state.reminders
                          .map(
                            (item) =>
                                item.id == reminder.id ? updatedReminder : item,
                          )
                          .toList();
                onChanged(
                  state.copyWith(
                    reminders: reminders,
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

TimeOfDay? _timeOfDayFromText(String source) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(source.trim());
  if (match == null) {
    return null;
  }
  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTimeOfDay(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

HealthAppState _deleteAlarmGroupFromState(
  HealthAppState state,
  AlarmGroup group,
) {
  return state.copyWith(
    alarmGroups: state.alarmGroups
        .where((candidate) => candidate.id != group.id)
        .toList(),
  );
}

HealthAppState _deleteReminderFromState(
  HealthAppState state,
  ReminderItem reminder,
) {
  return state.copyWith(
    reminders: state.reminders
        .where((candidate) => candidate.id != reminder.id)
        .toList(),
  );
}

HealthAppState _deleteMedicationIntakeFromState(
  HealthAppState state,
  MedicationIntake intake,
) {
  final nextIntakes = state.medicationIntakes
      .where((candidate) => candidate.id != intake.id)
      .toList();
  return state.copyWith(
    medicationIntakes: nextIntakes,
    today: state.today.copyWith(
      medicationTaken: _allMedicationTakenOnDate(
        state.medications,
        nextIntakes,
        state.today.date,
      ),
    ),
  );
}

HealthAppState _setMedicationIntakeStatusToday(
  HealthAppState state,
  Medication medication,
  String status,
) {
  final date = state.today.date;
  final nextIntakes = [...state.medicationIntakes];
  final index = nextIntakes.indexWhere(
    (item) =>
        item.date == date &&
        (item.medicationId == medication.id ||
            item.medicationName == medication.name),
  );
  final intake = MedicationIntake(
    id: index >= 0 ? nextIntakes[index].id : newId(),
    medicationId: medication.id,
    medicationName: medication.name,
    dose: medication.dose,
    date: date,
    time: index >= 0 ? nextIntakes[index].time : '',
    status: status,
    notes: index >= 0
        ? nextIntakes[index].notes
        : 'Быстрая отметка из карточки препарата.',
  );
  if (index >= 0) {
    nextIntakes[index] = intake;
  } else {
    nextIntakes.insert(0, intake);
  }
  return state.copyWith(
    medicationIntakes: nextIntakes,
    today: state.today.copyWith(
      medicationTaken: _allMedicationTakenOnDate(
        state.medications,
        nextIntakes,
        date,
      ),
    ),
  );
}

String _medicationSubtitle(Medication item) {
  final course = [
    item.courseStart.isEmpty ? '' : displayDateKey(item.courseStart),
    item.courseEnd.isEmpty ? '' : displayDateKey(item.courseEnd),
  ].where((value) => value.isNotEmpty).join(' - ');
  final lines = <String>[
    [
      displayDateKey(item.loggedDate),
      item.schedule,
      item.form,
      item.foodRule,
    ].where((value) => value.isNotEmpty).join(' · '),
    if (course.isNotEmpty) 'Курс: $course',
    if (item.prescribingDoctor.isNotEmpty)
      'Назначил: ${item.prescribingDoctor}',
    if (item.linkedCondition.isNotEmpty) 'Связано: ${item.linkedCondition}',
    if (item.remainingUnits > 0)
      'Остаток: ${item.remainingUnits}${item.stockIsLow ? ' · нужно пополнить' : ''}',
    if (item.sideEffects.isNotEmpty) 'Побочные эффекты: ${item.sideEffects}',
    item.notes,
  ].where((value) => value.trim().isNotEmpty).toList();
  return lines.join('\n');
}

bool _allMedicationTakenOnDate(
  List<Medication> medications,
  List<MedicationIntake> intakes,
  String date,
) {
  if (medications.isEmpty) {
    return false;
  }
  return medications.every(
    (medication) => _medicationTakenInList(medication, intakes, date),
  );
}

bool _medicationTakenInList(
  Medication medication,
  List<MedicationIntake> intakes,
  String date,
) {
  return intakes.any(
    (item) =>
        item.date == date &&
        (item.medicationId == medication.id ||
            item.medicationName == medication.name) &&
        item.status == 'принято',
  );
}

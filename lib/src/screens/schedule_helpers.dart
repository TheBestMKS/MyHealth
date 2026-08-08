part of '../screens.dart';

Future<void> _editWorkSchedule(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  final schedule = state.workSchedule;
  final workStart = TextEditingController(text: schedule.workStart);
  final workEnd = TextEditingController(text: schedule.workEnd);
  final commute = TextEditingController(text: '${schedule.commuteMinutes}');
  final lunchStart = TextEditingController(text: schedule.lunchStart);
  final lunchEnd = TextEditingController(text: schedule.lunchEnd);
  final lunchCommute = TextEditingController(
    text: '${schedule.lunchCommuteMinutes}',
  );
  final shiftCycle = TextEditingController(text: schedule.shiftCycle);
  final shiftAnchorDate = TextEditingController(
    text: dateInputText(
      schedule.shiftAnchorDate.isEmpty
          ? state.today.date
          : schedule.shiftAnchorDate,
    ),
  );
  final shiftWorkDays = TextEditingController(
    text: '${schedule.shiftWorkDays}',
  );
  final shiftRestDays = TextEditingController(
    text: '${schedule.shiftRestDays}',
  );
  final dutyDate = TextEditingController(text: dateInputText(state.today.date));
  final dutyStart = TextEditingController();
  final dutyEnd = TextEditingController();
  final dutyArrival = TextEditingController();
  final dutyRest = TextEditingController();
  final dutyNotes = TextEditingController();
  var leavesForLunch = schedule.leavesForLunch;
  var pattern = schedule.pattern;
  final workDays = schedule.workDays.toSet();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Рабочий график'),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LocalizedTextField(
                        controller: workStart,
                        decoration: const InputDecoration(
                          labelText: 'Начало работы',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LocalizedTextField(
                        controller: workEnd,
                        decoration: const InputDecoration(
                          labelText: 'Окончание работы',
                        ),
                      ),
                    ),
                  ],
                ),
                _numberField(commute, 'Средняя дорога до работы, мин'),
                Row(
                  children: [
                    Expanded(
                      child: LocalizedTextField(
                        controller: lunchStart,
                        decoration: const InputDecoration(labelText: 'Обед с'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LocalizedTextField(
                        controller: lunchEnd,
                        decoration: const InputDecoration(labelText: 'Обед до'),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  value: leavesForLunch,
                  title: const Text('Езжу на обед'),
                  onChanged: (value) =>
                      setDialogState(() => leavesForLunch = value),
                ),
                _numberField(lunchCommute, 'Дорога до места приёма пищи, мин'),
                LocalizedDropdownButtonFormField<String>(
                  initialValue: pattern,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Как работает график',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'weekdays',
                      child: Text('по дням недели'),
                    ),
                    DropdownMenuItem(
                      value: 'shift',
                      child: Text('сутки через ...'),
                    ),
                    DropdownMenuItem(
                      value: 'floating',
                      child: Text('плавающий график'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => pattern = value);
                    }
                  },
                ),
                LocalizedTextField(
                  controller: shiftCycle,
                  decoration: const InputDecoration(
                    labelText: 'Цикл смен',
                    hintText: 'Например: сутки через трое',
                  ),
                ),
                if (pattern == 'shift') ...[
                  LocalizedTextField(
                    controller: shiftAnchorDate,
                    decoration: InputDecoration(
                      labelText: 'Первый рабочий день цикла',
                      hintText: 'ДД.ММ.ГГГГ',
                      suffixIcon: LocalizedIconButton(
                        tooltip: 'Выбрать дату',
                        onPressed: () async {
                          final picked = await _pickDateValue(
                            context,
                            shiftAnchorDate.text,
                          );
                          if (picked != null) {
                            setDialogState(
                              () => shiftAnchorDate.text = dateInputText(
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
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(
                          shiftWorkDays,
                          'Рабочих суток подряд',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numberField(
                          shiftRestDays,
                          'Суток отдыха подряд',
                        ),
                      ),
                    ],
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Цикл применяется к рабочим будильникам и календарю.',
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Рабочие дни',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final day in const [
                      'пн',
                      'вт',
                      'ср',
                      'чт',
                      'пт',
                      'сб',
                      'вс',
                    ])
                      FilterChip(
                        label: Text(day),
                        selected: workDays.contains(day),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            workDays.add(day);
                          } else {
                            workDays.remove(day);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Добавить дежурство на месяц',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                LocalizedTextField(
                  controller: dutyDate,
                  decoration: InputDecoration(
                    labelText: 'Дата дежурства',
                    hintText: 'ДД.ММ.ГГГГ',
                    suffixIcon: LocalizedIconButton(
                      tooltip: 'Выбрать дату',
                      onPressed: () async {
                        final picked = await _pickDateValue(
                          context,
                          dutyDate.text,
                        );
                        if (picked != null) {
                          setDialogState(
                            () =>
                                dutyDate.text = dateInputText(todayKey(picked)),
                          );
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  inputFormatters: dateInputFormatters,
                  keyboardType: TextInputType.number,
                ),
                Row(
                  children: [
                    Expanded(
                      child: LocalizedTextField(
                        controller: dutyStart,
                        decoration: const InputDecoration(
                          labelText: 'Дежурство с',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LocalizedTextField(
                        controller: dutyEnd,
                        decoration: const InputDecoration(
                          labelText: 'Дежурство до',
                        ),
                      ),
                    ),
                  ],
                ),
                LocalizedTextField(
                  controller: dutyArrival,
                  decoration: const InputDecoration(labelText: 'Прибыть к'),
                ),
                LocalizedTextField(
                  controller: dutyRest,
                  decoration: const InputDecoration(
                    labelText: 'Отдых',
                    hintText: 'Например: 02:00-06:00 или 4 часа',
                  ),
                ),
                LocalizedTextField(
                  controller: dutyNotes,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Заметка к дежурству',
                  ),
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
              final duties = [...schedule.duties];
              if (dutyStart.text.trim().isNotEmpty ||
                  dutyEnd.text.trim().isNotEmpty) {
                duties.insert(
                  0,
                  WorkDuty(
                    id: newId(),
                    date: dateStorageText(
                      dutyDate.text,
                      fallback: state.today.date,
                    ),
                    startTime: dutyStart.text.trim(),
                    endTime: dutyEnd.text.trim(),
                    arrivalTime: dutyArrival.text.trim(),
                    restWindow: dutyRest.text.trim(),
                    notes: dutyNotes.text.trim(),
                  ),
                );
              }
              onChanged(
                state.copyWith(
                  workSchedule: schedule.copyWith(
                    workStart: workStart.text.trim(),
                    workEnd: workEnd.text.trim(),
                    commuteMinutes: _parseInt(
                      commute.text,
                      schedule.commuteMinutes,
                    ),
                    lunchStart: lunchStart.text.trim(),
                    lunchEnd: lunchEnd.text.trim(),
                    leavesForLunch: leavesForLunch,
                    lunchCommuteMinutes: _parseInt(
                      lunchCommute.text,
                      schedule.lunchCommuteMinutes,
                    ),
                    pattern: pattern,
                    workDays: workDays.toList(),
                    shiftCycle: shiftCycle.text.trim(),
                    shiftAnchorDate: dateStorageText(
                      shiftAnchorDate.text,
                      fallback: state.today.date,
                    ),
                    shiftWorkDays: _parseInt(
                      shiftWorkDays.text,
                      schedule.shiftWorkDays,
                    ).clamp(1, 31).toInt(),
                    shiftRestDays: _parseInt(
                      shiftRestDays.text,
                      schedule.shiftRestDays,
                    ).clamp(0, 31).toInt(),
                    duties: duties,
                  ),
                ),
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

Future<void> _editVacationPeriod(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  VacationPeriod? vacation,
]) async {
  final title = TextEditingController(text: vacation?.title ?? 'Отпуск');
  final startDate = TextEditingController(
    text: dateInputText(vacation?.startDate ?? state.today.date),
  );
  final endDate = TextEditingController(
    text: dateInputText(vacation?.endDate ?? state.today.date),
  );
  final country = TextEditingController(text: vacation?.country ?? '');
  final city = TextEditingController(text: vacation?.city ?? '');
  final notes = TextEditingController(text: vacation?.notes ?? '');
  final lodging = TextEditingController(text: vacation?.lodging ?? '');
  final climate = TextEditingController(text: vacation?.climate ?? '');
  final timeZone = TextEditingController(text: vacation?.timeZone ?? '');
  final restType = TextEditingController(text: vacation?.restType ?? '');
  final transport = TextEditingController(text: vacation?.transport ?? '');
  final distanceKm = TextEditingController(
    text: vacation == null ? '' : '${vacation.distanceKm}',
  );
  final travelMinutes = TextEditingController(
    text: vacation == null ? '' : '${vacation.travelMinutes}',
  );
  final transfers = TextEditingController(
    text: vacation == null ? '' : '${vacation.transfers}',
  );
  final waitMinutes = TextEditingController(
    text: vacation == null ? '' : '${vacation.waitMinutes}',
  );
  var nightTravel = vacation?.nightTravel ?? false;
  var sleepInTransit = vacation?.sleepInTransit ?? false;
  var gymAvailable = vacation?.gymAvailable ?? false;
  var poolAvailable = vacation?.poolAvailable ?? false;
  var walkingAvailable = vacation?.walkingAvailable ?? true;
  var alarmGroupId = vacation?.alarmGroupId ?? '';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
          vacation == null ? 'Добавить отпуск' : 'Редактировать отпуск',
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LocalizedTextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                LocalizedTextField(
                  controller: startDate,
                  decoration: InputDecoration(
                    labelText: 'С какого числа',
                    hintText: 'ДД.ММ.ГГГГ',
                    suffixIcon: LocalizedIconButton(
                      tooltip: 'Выбрать дату',
                      onPressed: () async {
                        final picked = await _pickDateValue(
                          context,
                          startDate.text,
                        );
                        if (picked != null) {
                          startDate.text = dateInputText(todayKey(picked));
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  inputFormatters: dateInputFormatters,
                  keyboardType: TextInputType.number,
                ),
                LocalizedTextField(
                  controller: endDate,
                  decoration: InputDecoration(
                    labelText: 'По какое число',
                    hintText: 'ДД.ММ.ГГГГ',
                    suffixIcon: LocalizedIconButton(
                      tooltip: 'Выбрать дату',
                      onPressed: () async {
                        final picked = await _pickDateValue(
                          context,
                          endDate.text,
                        );
                        if (picked != null) {
                          endDate.text = dateInputText(todayKey(picked));
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ),
                  inputFormatters: dateInputFormatters,
                  keyboardType: TextInputType.number,
                ),
                LocalizedTextField(
                  controller: country,
                  decoration: const InputDecoration(labelText: 'Страна'),
                ),
                LocalizedTextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'Город'),
                ),
                LocalizedTextField(
                  controller: lodging,
                  decoration: const InputDecoration(
                    labelText: 'Место проживания',
                  ),
                ),
                LocalizedTextField(
                  controller: climate,
                  decoration: const InputDecoration(labelText: 'Климат'),
                ),
                LocalizedTextField(
                  controller: timeZone,
                  decoration: const InputDecoration(labelText: 'Часовой пояс'),
                ),
                LocalizedTextField(
                  controller: restType,
                  decoration: const InputDecoration(
                    labelText: 'Тип отдыха',
                    hintText: 'Пляжный, экскурсионный, активный',
                  ),
                ),
                LocalizedTextField(
                  controller: transport,
                  decoration: const InputDecoration(labelText: 'Транспорт'),
                ),
                Row(
                  children: [
                    Expanded(child: _numberField(distanceKm, 'Расстояние, км')),
                    const SizedBox(width: 8),
                    Expanded(child: _numberField(travelMinutes, 'В пути, мин')),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _numberField(transfers, 'Пересадок')),
                    const SizedBox(width: 8),
                    Expanded(child: _numberField(waitMinutes, 'Ожидание, мин')),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ночная дорога или перелёт'),
                  value: nightTravel,
                  onChanged: (value) =>
                      setDialogState(() => nightTravel = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Можно спать в дороге'),
                  value: sleepInTransit,
                  onChanged: (value) =>
                      setDialogState(() => sleepInTransit = value),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Доступен спортзал'),
                  value: gymAvailable,
                  onChanged: (value) =>
                      setDialogState(() => gymAvailable = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Доступен бассейн'),
                  value: poolAvailable,
                  onChanged: (value) =>
                      setDialogState(() => poolAvailable = value ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Доступны прогулки'),
                  value: walkingAvailable,
                  onChanged: (value) =>
                      setDialogState(() => walkingAvailable = value ?? true),
                ),
                if (state.alarmGroups.isNotEmpty)
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: alarmGroupId.isEmpty ? null : alarmGroupId,
                    decoration: const InputDecoration(
                      labelText: 'Группа будильников для отпуска',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Без отдельной группы'),
                      ),
                      for (final group in state.alarmGroups)
                        DropdownMenuItem(
                          value: group.id,
                          child: Text(group.title),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => alarmGroupId = value ?? ''),
                  ),
                LocalizedTextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'План отдыха',
                    hintText:
                        'Транспорт, сон в дороге, спортзал, бассейн, режим',
                  ),
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
              final updated = VacationPeriod(
                id: vacation?.id ?? newId(),
                title: title.text.trim().isEmpty ? 'Отпуск' : title.text.trim(),
                startDate: dateStorageText(
                  startDate.text,
                  fallback: state.today.date,
                ),
                endDate: dateStorageText(
                  endDate.text,
                  fallback: state.today.date,
                ),
                country: country.text.trim(),
                city: city.text.trim(),
                notes: notes.text.trim(),
                lodging: lodging.text.trim(),
                climate: climate.text.trim(),
                timeZone: timeZone.text.trim(),
                restType: restType.text.trim(),
                transport: transport.text.trim(),
                distanceKm: _parseInt(distanceKm.text, 0),
                travelMinutes: _parseInt(travelMinutes.text, 0),
                transfers: _parseInt(transfers.text, 0),
                waitMinutes: _parseInt(waitMinutes.text, 0),
                nightTravel: nightTravel,
                sleepInTransit: sleepInTransit,
                gymAvailable: gymAvailable,
                poolAvailable: poolAvailable,
                walkingAvailable: walkingAvailable,
                alarmGroupId: alarmGroupId,
              );
              final vacations = vacation == null
                  ? [updated, ...state.workSchedule.vacations]
                  : state.workSchedule.vacations
                        .map((item) => item.id == vacation.id ? updated : item)
                        .toList();
              onChanged(
                state.copyWith(
                  workSchedule: state.workSchedule.copyWith(
                    vacations: vacations,
                  ),
                ),
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

part of '../screens.dart';

Future<void> _showCustomOptionsManager(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Пользовательские варианты',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (state.customOptions.isEmpty)
                const ListTile(
                  leading: Icon(Icons.tune_outlined),
                  title: Text('Список пуст'),
                  subtitle: Text(
                    'Добавляйте свои варианты в мастере и выпадающих списках.',
                  ),
                )
              else
                ...state.customOptions.map(
                  (item) => ListTile(
                    leading: const Icon(Icons.label_outline),
                    title: Text(item.label),
                    subtitle: Text(_customOptionGroupTitle(item.group)),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        LocalizedIconButton(
                          tooltip: 'Редактировать',
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _editCustomOption(context, state, item, onChanged);
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        LocalizedIconButton(
                          tooltip: 'Удалить',
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            onChanged(
                              state.copyWith(
                                customOptions: state.customOptions
                                    .where(
                                      (candidate) => candidate.id != item.id,
                                    )
                                    .toList(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _editCustomOption(
  BuildContext context,
  HealthAppState state,
  CustomOption option,
  HealthStateChanged onChanged,
) async {
  final controller = TextEditingController(text: option.label);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Редактировать вариант'),
      content: LocalizedTextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: _customOptionGroupTitle(option.group),
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) {
              return;
            }
            final updated = state.customOptions
                .map(
                  (item) => item.id == option.id
                      ? CustomOption(
                          id: item.id,
                          group: item.group,
                          label: value,
                          metadata: item.metadata,
                        )
                      : item,
                )
                .toList();
            onChanged(state.copyWith(customOptions: updated));
            Navigator.pop(dialogContext);
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

Future<void> _showAboutProgram(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('О программе'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Моё здоровье'),
          SizedBox(height: 8),
          Text('Версия: 1.8.1+10'),
          Text('Создатель: Редин Максим Юрьевич'),
          Text('Контактная информация: info@thebestmks.ru'),
          SizedBox(height: 12),
          Text(
            'Локальное кроссплатформенное приложение для дневника здоровья, питания, тренировок, медицинских документов, BLE-устройств и ручного подтверждения AI/OCR-распознавания.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}

String _customOptionGroupTitle(String group) {
  return switch (group) {
    'conditions' => 'Хронические состояния',
    'allergies' => 'Аллергии',
    'contraindications' => 'Противопоказания',
    'inventory' => 'Инвентарь',
    'cities' => 'Города и климат',
    'medicationCategories' => 'Категории лекарств',
    'medicationSchedules' => 'Расписания лекарств',
    'labMarkers' => 'Показатели анализов',
    'labUnits' => 'Единицы анализов',
    'labReferences' => 'Референсы анализов',
    'mealKinds' => 'Типы питания',
    'workoutFocus' => 'Фокусы тренировок',
    'workoutIntensity' => 'Интенсивность тренировок',
    'medicationIntakeStatuses' => 'Статусы приёма лекарств',
    'reminderCategories' => 'Категории напоминаний',
    'alarmDays' => 'Графики будильников',
    'documentKinds' => 'Типы документов',
    'symptomTypes' => 'Типы симптомов',
    'symptomSeverity' => 'Интенсивность симптомов',
    'tripClimates' => 'Климаты поездок',
    'tripAdjustments' => 'Планы адаптации поездок',
    _ => group.isEmpty ? 'Общий список' : group,
  };
}

const _conditionOptions = [
  'гипертония',
  'астма',
  'диабет',
  'гипотиреоз',
  'мигрень',
  'гастрит',
  'анемия',
  'остеохондроз',
  'тревожное расстройство',
  'нарушение сна',
  'нет хронических состояний',
];

const _allergyOptions = [
  'пыльца',
  'пыль',
  'шерсть животных',
  'орехи',
  'молочные продукты',
  'глютен',
  'цитрусовые',
  'морепродукты',
  'пенициллин',
  'НПВС',
  'латекс',
  'нет известных аллергий',
];

const _contraindicationOptions = [
  'интенсивные нагрузки',
  'прыжковые упражнения',
  'тяжёлые веса',
  'длительный бег',
  'перегрев',
  'переохлаждение',
  'голодные тренировки',
  'кофеин вечером',
  'высокоинтенсивное кардио',
  'нет противопоказаний',
];

const _inventoryOptions = [
  'коврик',
  'гантели',
  'резинки',
  'турник',
  'фитбол',
  'велотренажёр',
  'беговая дорожка',
  'скакалка',
  'пульсометр',
  'тонометр',
  'глюкометр',
  'пульсоксиметр',
];

Future<void> _addCatalogListItem(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, {
  required String title,
  required String group,
  required List<String> options,
  required List<String> values,
  required HealthAppState Function(HealthAppState state, String value)
  addToState,
}) async {
  final pendingCustomOptions = <CustomOption>[];
  var selected = {
    ...options,
    ...state.customLabels(group),
  }.where((item) => item.trim().isNotEmpty).firstOrNull;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final items = {
          ...options,
          ...state.customLabels(group),
          ...pendingCustomOptions
              .where((item) => item.group == group)
              .map((item) => item.label),
        }.where((item) => item.trim().isNotEmpty).toList();
        selected ??= items.isEmpty ? null : items.first;

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 480,
            child: LocalizedDropdownButtonFormField<String>(
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Выберите вариант'),
              items: [
                for (final item in items)
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
                    title: 'Свой вариант',
                    label: title,
                  );
                  if (custom == null) {
                    return;
                  }
                  pendingCustomOptions.add(
                    CustomOption(
                      id: newId(),
                      group: group,
                      label: custom,
                      metadata: const {},
                    ),
                  );
                  setDialogState(() => selected = custom);
                  return;
                }
                setDialogState(() => selected = value);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final value = selected?.trim() ?? '';
                if (value.isEmpty || value == _customDropdownValue) {
                  return;
                }
                var nextState = state;
                if (!values.contains(value)) {
                  nextState = addToState(nextState, value);
                }
                onChanged(
                  nextState.copyWith(
                    customOptions: [
                      ...pendingCustomOptions,
                      ...nextState.customOptions,
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

Widget _stringListBlock(
  BuildContext context, {
  required String title,
  required IconData icon,
  required List<String> values,
  required ValueChanged<String> onAdd,
  ValueChanged<String>? onRemove,
  VoidCallback? onAddPressed,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(
        title,
        action: LocalizedIconButton.filledTonal(
          tooltip: 'Добавить',
          onPressed:
              onAddPressed ??
              () => _addTextItem(
                context,
                title: title,
                label: 'Новая запись',
                onSave: onAdd,
              ),
          icon: const Icon(Icons.add),
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in values)
            _stringListChip(
              context,
              title: title,
              icon: icon,
              value: item,
              onRemove: onRemove,
            ),
        ],
      ),
    ],
  );
}

Widget _stringListChip(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String value,
  ValueChanged<String>? onRemove,
}) {
  void requestDelete() {
    _confirmDelete(
      context,
      title: '$title: $value',
      onDelete: () => onRemove?.call(value),
    );
  }

  return GestureDetector(
    onLongPress: onRemove == null ? null : requestDelete,
    child: Chip(
      avatar: Icon(icon, size: 16),
      label: Text(value),
      onDeleted: onRemove == null ? null : requestDelete,
      deleteIcon: const Icon(Icons.close, size: 18),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

List<String> _removeFirstString(List<String> values, String value) {
  final next = [...values];
  next.remove(value);
  return next;
}

Future<void> _addTextItem(
  BuildContext context, {
  required String title,
  required String label,
  required ValueChanged<String> onSave,
}) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: LocalizedTextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        minLines: 1,
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) {
              onSave(value);
            }
            Navigator.pop(dialogContext);
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

const String _customDropdownValue = '__custom__';

Future<String?> _promptCustomOptionLabel(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: LocalizedTextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) {
              return;
            }
            Navigator.pop(dialogContext, value);
          },
          child: const Text('Добавить'),
        ),
      ],
    ),
  );
}

Future<void> _editTrip(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, [
  TripPlan? trip,
]) async {
  final title = TextEditingController(text: trip?.title ?? '');
  final startDate = TextEditingController(
    text: dateInputText(
      trip?.startDate ?? todayKey(DateTime.now().add(const Duration(days: 7))),
    ),
  );
  final endDate = TextEditingController(
    text: dateInputText(
      trip?.endDate ?? todayKey(DateTime.now().add(const Duration(days: 10))),
    ),
  );
  final notes = TextEditingController(text: trip?.adjustment ?? '');
  final country = TextEditingController(text: trip?.country ?? '');
  final city = TextEditingController(text: trip?.city ?? '');
  final lodgingAddress = TextEditingController(
    text: trip?.lodgingAddress ?? '',
  );
  final workplace = TextEditingController(text: trip?.workplace ?? '');
  final transport = TextEditingController(text: trip?.transport ?? '');
  final travelMinutes = TextEditingController(
    text: trip == null ? '' : '${trip.travelMinutes}',
  );
  final transfers = TextEditingController(
    text: trip == null ? '' : '${trip.transfers}',
  );
  final waitMinutes = TextEditingController(
    text: trip == null ? '' : '${trip.waitMinutes}',
  );
  final workSchedule = TextEditingController(text: trip?.workSchedule ?? '');
  final mealPlan = TextEditingController(text: trip?.mealPlan ?? '');
  final pendingCustomOptions = <CustomOption>[];
  final baseClimate = state.profile.climate.isEmpty
      ? 'умеренный'
      : state.profile.climate;
  var climate = trip?.climate.isNotEmpty == true ? trip!.climate : baseClimate;
  var adjustment = trip?.adjustment.isNotEmpty == true
      ? trip!.adjustment
      : 'Сохранить сон, воду и короткие тренировки 10-20 минут.';
  var timeZoneShift = trip?.timeZoneShift ?? 0;
  var nightTravel = trip?.nightTravel ?? false;
  var sleepInTransit = trip?.sleepInTransit ?? false;
  var gymAvailable = trip?.gymAvailable ?? false;
  var poolAvailable = trip?.poolAvailable ?? false;
  var roomWorkoutAvailable = trip?.roomWorkoutAvailable ?? true;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final climateItems = {
          baseClimate,
          'как дома',
          'жаркий сухой',
          'жаркий влажный',
          'умеренный',
          'холодный',
          'горный',
          ...state.customLabels('tripClimates'),
          ...pendingCustomOptions
              .where((item) => item.group == 'tripClimates')
              .map((item) => item.label),
        }.where((item) => item.trim().isNotEmpty).toList();
        final adjustmentItems = {
          'Сохранить сон, воду и короткие тренировки 10-20 минут.',
          'Снизить интенсивность тренировок на 25% и добавить прогулки.',
          'После перелёта сделать восстановительный день без тяжёлых нагрузок.',
          'Увеличить воду и электролиты, тренироваться утром или вечером.',
          ...state.customLabels('tripAdjustments'),
          ...pendingCustomOptions
              .where((item) => item.group == 'tripAdjustments')
              .map((item) => item.label),
        }.toList();
        if (!climateItems.contains(climate)) {
          climateItems.insert(0, climate);
        }
        if (!adjustmentItems.contains(adjustment)) {
          adjustmentItems.insert(0, adjustment);
        }

        return AlertDialog(
          title: Text(
            trip == null ? 'Добавить поездку' : 'Редактировать поездку',
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: title,
                    autofocus: trip == null,
                    decoration: const InputDecoration(
                      labelText: 'Название',
                      hintText: 'Например: командировка в Казань',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: LocalizedTextField(
                          controller: startDate,
                          decoration: InputDecoration(
                            labelText: 'Начало',
                            hintText: 'ДД.ММ.ГГГГ',
                            suffixIcon: LocalizedIconButton(
                              tooltip: 'Выбрать дату',
                              onPressed: () async {
                                final picked = await _pickDateValue(
                                  context,
                                  startDate.text,
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => startDate.text = dateInputText(
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
                          controller: endDate,
                          decoration: InputDecoration(
                            labelText: 'Окончание',
                            hintText: 'ДД.ММ.ГГГГ',
                            suffixIcon: LocalizedIconButton(
                              tooltip: 'Выбрать дату',
                              onPressed: () async {
                                final picked = await _pickDateValue(
                                  context,
                                  endDate.text,
                                );
                                if (picked != null) {
                                  setDialogState(
                                    () => endDate.text = dateInputText(
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
                  Row(
                    children: [
                      Expanded(
                        child: LocalizedTextField(
                          controller: country,
                          decoration: const InputDecoration(
                            labelText: 'Страна',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LocalizedTextField(
                          controller: city,
                          decoration: const InputDecoration(labelText: 'Город'),
                        ),
                      ),
                    ],
                  ),
                  LocalizedTextField(
                    controller: lodgingAddress,
                    decoration: const InputDecoration(
                      labelText: 'Адрес проживания или отель',
                    ),
                  ),
                  LocalizedTextField(
                    controller: workplace,
                    decoration: const InputDecoration(
                      labelText: 'Место работы или мероприятия',
                    ),
                  ),
                  LocalizedTextField(
                    controller: transport,
                    decoration: const InputDecoration(
                      labelText: 'Транспорт и перелёты',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _numberField(travelMinutes, 'В пути, мин'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _numberField(transfers, 'Пересадок')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _numberField(waitMinutes, 'Ожидание, мин'),
                      ),
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
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Спортзал'),
                        selected: gymAvailable,
                        onSelected: (value) =>
                            setDialogState(() => gymAvailable = value),
                      ),
                      FilterChip(
                        label: const Text('Бассейн'),
                        selected: poolAvailable,
                        onSelected: (value) =>
                            setDialogState(() => poolAvailable = value),
                      ),
                      FilterChip(
                        label: const Text('Тренировка в номере'),
                        selected: roomWorkoutAvailable,
                        onSelected: (value) =>
                            setDialogState(() => roomWorkoutAvailable = value),
                      ),
                    ],
                  ),
                  LocalizedTextField(
                    controller: workSchedule,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Расписание рабочих мероприятий',
                    ),
                  ),
                  LocalizedTextField(
                    controller: mealPlan,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Питание в дороге и на месте',
                    ),
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: climate,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Климат'),
                    items: [
                      for (final item in climateItems)
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
                          title: 'Свой климат поездки',
                          label: 'Климат',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'tripClimates',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() => climate = custom);
                        return;
                      }
                      setDialogState(() => climate = value);
                    },
                  ),
                  LocalizedDropdownButtonFormField<int>(
                    initialValue: timeZoneShift.clamp(-12, 14).toInt(),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Сдвиг часового пояса',
                    ),
                    items: [
                      for (var value = -12; value <= 14; value++)
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == 0
                                ? '0 часов'
                                : '${value > 0 ? '+' : ''}$value ч',
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => timeZoneShift = value);
                      }
                    },
                  ),
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: adjustment,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'План адаптации',
                    ),
                    items: [
                      for (final item in adjustmentItems)
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
                          title: 'Свой план адаптации',
                          label: 'План',
                        );
                        if (custom == null) {
                          return;
                        }
                        pendingCustomOptions.add(
                          CustomOption(
                            id: newId(),
                            group: 'tripAdjustments',
                            label: custom,
                            metadata: const {},
                          ),
                        );
                        setDialogState(() {
                          adjustment = custom;
                          notes.text = custom;
                        });
                        return;
                      }
                      setDialogState(() {
                        adjustment = value;
                        notes.text = value;
                      });
                    },
                  ),
                  LocalizedTextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Заметки и уточнения',
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
                final normalizedTitle = title.text.trim().isEmpty
                    ? 'Поездка ${startDate.text.trim()}'
                    : title.text.trim();
                final normalizedStartDate = dateStorageText(
                  startDate.text,
                  fallback: todayKey(),
                );
                final normalizedEndDate = dateStorageText(
                  endDate.text,
                  fallback: normalizedStartDate,
                );
                final updated = TripPlan(
                  id: trip?.id ?? newId(),
                  title: normalizedTitle,
                  startDate: normalizedStartDate,
                  endDate: normalizedEndDate,
                  climate: climate,
                  timeZoneShift: timeZoneShift,
                  adjustment: notes.text.trim().isEmpty
                      ? adjustment
                      : notes.text.trim(),
                  country: country.text.trim(),
                  city: city.text.trim(),
                  lodgingAddress: lodgingAddress.text.trim(),
                  workplace: workplace.text.trim(),
                  transport: transport.text.trim(),
                  travelMinutes: _parseInt(travelMinutes.text, 0),
                  transfers: _parseInt(transfers.text, 0),
                  waitMinutes: _parseInt(waitMinutes.text, 0),
                  nightTravel: nightTravel,
                  sleepInTransit: sleepInTransit,
                  gymAvailable: gymAvailable,
                  poolAvailable: poolAvailable,
                  roomWorkoutAvailable: roomWorkoutAvailable,
                  workSchedule: workSchedule.text.trim(),
                  mealPlan: mealPlan.text.trim(),
                );
                final trips = trip == null
                    ? [updated, ...state.trips]
                    : state.trips
                          .map((item) => item.id == trip.id ? updated : item)
                          .toList();
                onChanged(
                  state.copyWith(
                    trips: trips,
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

Future<DateTime?> _pickDateValue(BuildContext context, String source) {
  final initial = parseDateKey(source) ?? DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(DateTime.now().year + 5),
  );
}

Future<void> _editProfile(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  final name = TextEditingController(text: state.profile.name);
  final birthDate = TextEditingController(
    text: dateInputText(state.profile.birthDate),
  );
  final goal = TextEditingController(text: state.profile.goal);
  var gender = state.profile.gender.isEmpty
      ? 'не указано'
      : state.profile.gender;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Профиль'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LocalizedTextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            LocalizedTextField(
              controller: birthDate,
              decoration: InputDecoration(
                labelText: 'Дата рождения',
                hintText: 'ДД.ММ.ГГГГ',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixIcon: LocalizedIconButton(
                  tooltip: 'Выбрать дату',
                  onPressed: () async {
                    final picked = await _pickDateValue(
                      context,
                      birthDate.text,
                    );
                    if (picked != null) {
                      birthDate.text = dateInputText(todayKey(picked));
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
              inputFormatters: dateInputFormatters,
              keyboardType: TextInputType.number,
            ),
            LocalizedDropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(labelText: 'Пол для расчётов'),
              items: const [
                DropdownMenuItem(
                  value: 'не указано',
                  child: Text('не указано'),
                ),
                DropdownMenuItem(value: 'мужской', child: Text('мужской')),
                DropdownMenuItem(value: 'женский', child: Text('женский')),
              ],
              onChanged: (value) {
                if (value != null) {
                  gender = value;
                }
              },
            ),
            LocalizedTextField(
              controller: goal,
              decoration: const InputDecoration(labelText: 'Цель'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            onChanged(
              state.copyWith(
                profile: state.profile.copyWith(
                  name: name.text.trim().isEmpty
                      ? state.profile.name
                      : name.text.trim(),
                  birthDate: dateStorageText(
                    birthDate.text,
                    fallback: state.profile.birthDate,
                  ),
                  goal: goal.text.trim().isEmpty
                      ? state.profile.goal
                      : goal.text.trim(),
                  trainingGoals: goal.text
                      .split(RegExp(r'[,;]'))
                      .map((item) => item.trim())
                      .where((item) => item.isNotEmpty)
                      .toList(),
                  gender: gender == 'не указано' ? '' : gender,
                ),
              ),
            );
            Navigator.pop(dialogContext);
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

Future<void> _editActivityReminders(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  var settings = state.activityReminders;
  final warmup = TextEditingController(
    text: '${settings.warmupIntervalMinutes}',
  );
  final water = TextEditingController(text: '${settings.waterIntervalMinutes}');
  final target = TextEditingController(text: '${settings.activeMinutesTarget}');
  final quietStart = TextEditingController(text: settings.quietStart);
  final quietEnd = TextEditingController(text: settings.quietEnd);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Напоминания активности'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: settings.warmupEnabled,
                  title: const Text('Разминка'),
                  subtitle: const Text(
                    'Напоминать встать, пройтись, размяться',
                  ),
                  onChanged: (value) => setDialogState(
                    () => settings = settings.copyWith(warmupEnabled: value),
                  ),
                ),
                _numberField(warmup, 'Интервал разминки, мин'),
                SwitchListTile(
                  value: settings.waterEnabled,
                  title: const Text('Вода'),
                  subtitle: const Text(
                    'Напоминать пить воду с учётом тихого режима',
                  ),
                  onChanged: (value) => setDialogState(
                    () => settings = settings.copyWith(waterEnabled: value),
                  ),
                ),
                _numberField(water, 'Интервал воды, мин'),
                SwitchListTile(
                  value: settings.medicineEnabled,
                  title: const Text('Лекарства'),
                  subtitle: const Text(
                    'Показывать профильные напоминания о приёме',
                  ),
                  onChanged: (value) => setDialogState(
                    () => settings = settings.copyWith(medicineEnabled: value),
                  ),
                ),
                _numberField(target, 'Цель активности, мин/день'),
                LocalizedTextField(
                  controller: quietStart,
                  decoration: const InputDecoration(labelText: 'Тихий режим с'),
                ),
                LocalizedTextField(
                  controller: quietEnd,
                  decoration: const InputDecoration(
                    labelText: 'Тихий режим до',
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
              onChanged(
                state.copyWith(
                  activityReminders: settings.copyWith(
                    warmupIntervalMinutes: _parseInt(
                      warmup.text,
                      settings.warmupIntervalMinutes,
                    ).clamp(15, 240).toInt(),
                    waterIntervalMinutes: _parseInt(
                      water.text,
                      settings.waterIntervalMinutes,
                    ).clamp(15, 240).toInt(),
                    activeMinutesTarget: _parseInt(
                      target.text,
                      settings.activeMinutesTarget,
                    ).clamp(5, 240).toInt(),
                    quietStart: quietStart.text.trim().isEmpty
                        ? settings.quietStart
                        : quietStart.text.trim(),
                    quietEnd: quietEnd.text.trim().isEmpty
                        ? settings.quietEnd
                        : quietEnd.text.trim(),
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

Future<void> _editActivityPlaces(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  var homeLatitude = state.profile.homeLatitude;
  var homeLongitude = state.profile.homeLongitude;
  var workLatitude = state.profile.workLatitude;
  var workLongitude = state.profile.workLongitude;
  var radius = state.profile.placeRadiusMeters.toDouble();
  var loading = false;
  var status = state.settings.geolocationEnabled
      ? 'Координаты используются только на устройстве для определения контекста.'
      : 'Геолокация отключена в настройках.';
  const service = ActivityContextService();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> capture({required bool home}) async {
          if (!state.settings.geolocationEnabled) {
            setDialogState(
              () => status = 'Сначала включите геолокацию в настройках.',
            );
            return;
          }
          setDialogState(() {
            loading = true;
            status = 'Получаем текущую позицию...';
          });
          final position = await service.currentPosition();
          if (!dialogContext.mounted) return;
          setDialogState(() {
            loading = false;
            if (position == null) {
              status =
                  'Позиция не получена. Проверьте разрешение и системную геолокацию.';
              return;
            }
            if (home) {
              homeLatitude = position.latitude;
              homeLongitude = position.longitude;
              status = 'Текущая точка сохранена как дом после подтверждения.';
            } else {
              workLatitude = position.latitude;
              workLongitude = position.longitude;
              status =
                  'Текущая точка сохранена как место работы после подтверждения.';
            }
          });
        }

        String coordinate(double? latitude, double? longitude) =>
            latitude == null || longitude == null
            ? 'не задано'
            : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

        return AlertDialog(
          title: const Text('Дом и работа'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoTile(
                  icon: Icons.home_outlined,
                  title: 'Дом',
                  subtitle: coordinate(homeLatitude, homeLongitude),
                  trailing: LocalizedIconButton.filledTonal(
                    tooltip: 'Запомнить текущую точку как дом',
                    onPressed: loading ? null : () => capture(home: true),
                    icon: const Icon(Icons.my_location),
                  ),
                ),
                InfoTile(
                  icon: Icons.work_outline,
                  title: 'Работа',
                  subtitle: coordinate(workLatitude, workLongitude),
                  trailing: LocalizedIconButton.filledTonal(
                    tooltip: 'Запомнить текущую точку как работу',
                    onPressed: loading ? null : () => capture(home: false),
                    icon: const Icon(Icons.my_location),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Радиус места: ${radius.round()} м'),
                Slider(
                  value: radius,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  label: '${radius.round()} м',
                  onChanged: loading
                      ? null
                      : (value) => setDialogState(() => radius = value),
                ),
                if (loading) const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(status, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () {
                      onChanged(
                        state.copyWith(
                          profile: state.profile.copyWith(
                            homeLatitude: homeLatitude,
                            homeLongitude: homeLongitude,
                            workLatitude: workLatitude,
                            workLongitude: workLongitude,
                            placeRadiusMeters: radius.round(),
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

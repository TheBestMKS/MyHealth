part of '../screens.dart';

typedef HealthStateChanged = void Function(HealthAppState state);
typedef SectionSelected = void Function(AppSection section);

Widget buildSectionScreen(
  AppSection section,
  HealthAppState state,
  HealthStateChanged onChanged,
  SectionSelected onSelect,
) {
  return switch (section) {
    AppSection.home => TodayScreen(
      state: state,
      onChanged: onChanged,
      onSelect: onSelect,
    ),
    AppSection.today => TodayScreen(
      state: state,
      onChanged: onChanged,
      onSelect: onSelect,
    ),
    AppSection.health => HealthScreen(
      state: state,
      onChanged: onChanged,
      onSelect: onSelect,
    ),
    AppSection.profile => ProfileScreen(
      state: state,
      onChanged: onChanged,
      onSelect: onSelect,
    ),
    AppSection.medicalCard => MedicalCardScreen(
      state: state,
      onChanged: onChanged,
    ),
    AppSection.labs => LabsScreen(state: state, onChanged: onChanged),
    AppSection.medicines => MedicinesScreen(state: state, onChanged: onChanged),
    AppSection.symptoms => SymptomsScreen(state: state, onChanged: onChanged),
    AppSection.knowledge => KnowledgeScreen(
      state: state,
      onChanged: onChanged,
      onSelect: onSelect,
    ),
    AppSection.workouts => WorkoutsScreen(state: state, onChanged: onChanged),
    AppSection.exercises => ExercisesScreen(state: state),
    AppSection.nutrition => NutritionScreen(state: state, onChanged: onChanged),
    AppSection.recipes => RecipesScreen(state: state, onChanged: onChanged),
    AppSection.foodPhoto => FoodPhotoScreen(state: state, onChanged: onChanged),
    AppSection.sleep => SleepScreen(state: state, onChanged: onChanged),
    AppSection.calendar => CalendarHubScreen(
      state: state,
      onChanged: onChanged,
    ),
    AppSection.vacation => VacationScreen(state: state, onChanged: onChanged),
    AppSection.trips => TripsScreen(state: state, onChanged: onChanged),
    AppSection.climate => ClimateScreen(state: state, onChanged: onChanged),
    AppSection.analytics => AnalyticsScreen(state: state),
    AppSection.assistant => AssistantScreen(
      state: state,
      onChanged: onChanged,
      onSelect: onSelect,
    ),
    AppSection.devices => DevicesScreen(state: state, onChanged: onChanged),
    AppSection.documents => DocumentsScreen(state: state, onChanged: onChanged),
    AppSection.settings => SettingsScreen(state: state, onChanged: onChanged),
  };
}

Future<void> showQuickAddDialog(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, {
  String? initialDate,
}) async {
  final date = TextEditingController(
    text: dateInputText(initialDate ?? state.today.date),
  );
  final metrics = state.metricsFor(
    dateStorageText(date.text, fallback: state.today.date),
  );
  final weight = TextEditingController(
    text: metrics.weightKg == 0 ? '' : metrics.weightKg.toStringAsFixed(1),
  );
  final sleep = TextEditingController(
    text: metrics.sleepHours == 0 ? '' : metrics.sleepHours.toStringAsFixed(1),
  );
  final steps = TextEditingController(
    text: metrics.steps == 0 ? '' : '${metrics.steps}',
  );
  final water = TextEditingController(
    text: metrics.waterLiters == 0
        ? ''
        : metrics.waterLiters.toStringAsFixed(1),
  );
  final calories = TextEditingController(
    text: metrics.calories == 0 ? '' : '${metrics.calories}',
  );
  final workout = TextEditingController(
    text: metrics.workoutMinutes == 0 ? '' : '${metrics.workoutMinutes}',
  );
  final mealTitle = TextEditingController();
  final mealCalories = TextEditingController();
  final mealProtein = TextEditingController();
  final mealCarbs = TextEditingController();
  final mealFat = TextEditingController();
  final mealNotes = TextEditingController();
  var mealKind = 'перекус';
  final pendingCustomOptions = <CustomOption>[];

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(AppText.get(state.localeCode, 'quickAdd')),
        content: SizedBox(
          width: 520,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final mealKindItems = {
                'завтрак',
                'обед',
                'ужин',
                'перекус',
                'после тренировки',
                'напиток',
                mealKind,
                ...state.customLabels('mealKinds'),
                ...pendingCustomOptions
                    .where((item) => item.group == 'mealKinds')
                    .map((item) => item.label),
              }.toList();
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LocalizedTextField(
                      controller: date,
                      decoration: InputDecoration(
                        labelText: 'Дата',
                        hintText: 'ДД.ММ.ГГГГ',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        helperText: 'Точки подставляются автоматически',
                        suffixIcon: LocalizedIconButton(
                          tooltip: 'Выбрать дату',
                          onPressed: () async {
                            final picked = await _pickDateValue(
                              context,
                              date.text,
                            );
                            if (picked != null) {
                              setDialogState(
                                () =>
                                    date.text = dateInputText(todayKey(picked)),
                              );
                            }
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ),
                      inputFormatters: dateInputFormatters,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    _numberField(weight, 'Вес, кг'),
                    _numberField(sleep, 'Сон, часов'),
                    _numberField(steps, 'Шаги'),
                    _numberField(water, 'Вода, л'),
                    _numberField(calories, 'Калории за день'),
                    _numberField(workout, 'Тренировка, мин'),
                    const SizedBox(height: 8),
                    LocalizedDropdownButtonFormField<String>(
                      initialValue: mealKind,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Тип еды'),
                      items: [
                        for (final item in mealKindItems)
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
                            title: 'Свой тип питания',
                            label: 'Тип приёма пищи',
                          );
                          if (custom == null) {
                            return;
                          }
                          pendingCustomOptions.add(
                            CustomOption(
                              id: newId(),
                              group: 'mealKinds',
                              label: custom,
                              metadata: const {},
                            ),
                          );
                          setDialogState(() => mealKind = custom);
                          return;
                        }
                        setDialogState(() => mealKind = value);
                      },
                    ),
                    LocalizedTextField(
                      controller: mealTitle,
                      decoration: const InputDecoration(
                        labelText: 'Добавить еду',
                        hintText: 'Например: творог с ягодами',
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(child: _numberField(mealCalories, 'Ккал еды')),
                        const SizedBox(width: 8),
                        Expanded(child: _numberField(mealProtein, 'Белок, г')),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _numberField(mealCarbs, 'Углеводы, г')),
                        const SizedBox(width: 8),
                        Expanded(child: _numberField(mealFat, 'Жиры, г')),
                      ],
                    ),
                    LocalizedTextField(
                      controller: mealNotes,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Заметка к еде',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppText.get(state.localeCode, 'cancel')),
          ),
          FilledButton.icon(
            onPressed: () {
              final targetDate = dateStorageText(
                date.text,
                fallback: state.today.date,
              );
              final sourceMetrics = state.metricsFor(targetDate);
              final updatedMetrics = sourceMetrics.copyWith(
                date: targetDate,
                weightKg: _parseDouble(weight.text, sourceMetrics.weightKg),
                sleepHours: _parseDouble(sleep.text, sourceMetrics.sleepHours),
                steps: _parseInt(steps.text, sourceMetrics.steps),
                waterLiters: _parseDouble(
                  water.text,
                  sourceMetrics.waterLiters,
                ),
                calories: _parseInt(calories.text, sourceMetrics.calories),
                workoutMinutes: _parseInt(
                  workout.text,
                  sourceMetrics.workoutMinutes,
                ),
              );
              var finalMetrics = updatedMetrics;
              final newMeals = [...state.meals];
              if (mealTitle.text.trim().isNotEmpty) {
                final enteredMealCalories = _parseInt(
                  mealCalories.text,
                  0,
                ).clamp(0, 20000).toInt();
                if (calories.text.trim().isEmpty && enteredMealCalories > 0) {
                  finalMetrics = updatedMetrics.copyWith(
                    calories: (updatedMetrics.calories + enteredMealCalories)
                        .clamp(0, 20000)
                        .toInt(),
                  );
                }
                newMeals.insert(
                  0,
                  MealEntry(
                    id: newId(),
                    title: mealTitle.text.trim(),
                    kind: mealKind,
                    calories: enteredMealCalories,
                    protein: _parseInt(
                      mealProtein.text,
                      0,
                    ).clamp(0, 1000).toInt(),
                    carbs: _parseInt(mealCarbs.text, 0).clamp(0, 1000).toInt(),
                    fat: _parseInt(mealFat.text, 0).clamp(0, 1000).toInt(),
                    confirmed: true,
                    date: targetDate,
                    notes: mealNotes.text.trim().isEmpty
                        ? 'Добавлено вручную из быстрого ввода без автоматических оценок.'
                        : mealNotes.text.trim(),
                  ),
                );
              }
              onChanged(
                state
                    .updateMetricsFor(targetDate, finalMetrics)
                    .copyWith(
                      customOptions: [
                        ...pendingCustomOptions,
                        ...state.customOptions,
                      ],
                      meals: newMeals,
                    ),
              );
              Navigator.pop(dialogContext);
            },
            icon: const Icon(Icons.save_outlined),
            label: Text(AppText.get(state.localeCode, 'save')),
          ),
        ],
      );
    },
  );
}

Future<void> showGlobalSearch(
  BuildContext context,
  HealthAppState state,
  SectionSelected onSelect,
) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final query = controller.text.toLowerCase();
          final items = _searchItems(
            state,
          ).where((item) => item.text.toLowerCase().contains(query)).toList();
          return AlertDialog(
            title: Text(AppText.get(state.localeCode, 'search')),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedTextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Лекарства, анализы, рецепты, тренировки',
                    ),
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          leading: Icon(sectionInfo(item.section).icon),
                          title: Text(item.text),
                          subtitle: Text(
                            sectionInfo(item.section).label(state.localeCode),
                          ),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            onSelect(item.section);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppText.get(state.localeCode, 'cancel')),
              ),
            ],
          );
        },
      );
    },
  );
}

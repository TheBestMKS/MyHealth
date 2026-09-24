part of '../screens.dart';

Future<void> _addMeal(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async => _editMeal(context, state, onChanged);

Future<void> _editMeal(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged, {
  MealEntry? meal,
}) async {
  final isExisting =
      meal != null && state.meals.any((candidate) => candidate.id == meal.id);
  final title = TextEditingController(text: meal?.title ?? '');
  final date = TextEditingController(
    text: dateInputText(meal?.date ?? state.today.date),
  );
  final time = TextEditingController(
    text: meal?.time.isNotEmpty == true
        ? meal!.time
        : _formatTimeOfDay(TimeOfDay.now()),
  );
  final calories = TextEditingController(
    text: meal == null ? '' : '${meal.calories}',
  );
  final protein = TextEditingController(
    text: meal == null ? '' : '${meal.protein}',
  );
  final carbs = TextEditingController(
    text: meal == null ? '' : '${meal.carbs}',
  );
  final fat = TextEditingController(text: meal == null ? '' : '${meal.fat}');
  final portion = TextEditingController(
    text: meal == null || meal.portionGrams == 0 ? '' : '${meal.portionGrams}',
  );
  final fiber = TextEditingController(
    text: meal == null || meal.fiber == 0 ? '' : '${meal.fiber}',
  );
  final sugar = TextEditingController(
    text: meal == null || meal.sugar == 0 ? '' : '${meal.sugar}',
  );
  final salt = TextEditingController(
    text: meal == null || meal.salt == 0 ? '' : '${meal.salt}',
  );
  final notes = TextEditingController(text: meal?.notes ?? '');
  var kind = meal?.kind.isNotEmpty == true ? meal!.kind : 'обед';
  final pendingCustomOptions = <CustomOption>[];
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final kindItems = {
          'завтрак',
          'обед',
          'ужин',
          'перекус',
          'после тренировки',
          'напиток',
          ...state.customLabels('mealKinds'),
          ...pendingCustomOptions
              .where((item) => item.group == 'mealKinds')
              .map((item) => item.label),
        }.toList();
        return AlertDialog(
          title: Text(isExisting ? 'Редактировать еду' : 'Добавить еду'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalizedDropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: [
                      for (final item in kindItems)
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
                        setDialogState(() => kind = custom);
                        return;
                      }
                      setDialogState(() => kind = value);
                    },
                  ),
                  LocalizedTextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Название'),
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
                  LocalizedTextField(
                    controller: portion,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Порция, г'),
                  ),
                  LocalizedTextField(
                    controller: calories,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ккал'),
                  ),
                  LocalizedTextField(
                    controller: protein,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Белок, г'),
                  ),
                  LocalizedTextField(
                    controller: carbs,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Углеводы, г'),
                  ),
                  LocalizedTextField(
                    controller: fat,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Жиры, г'),
                  ),
                  LocalizedTextField(
                    controller: fiber,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Клетчатка, г',
                    ),
                  ),
                  LocalizedTextField(
                    controller: sugar,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Сахар, г'),
                  ),
                  LocalizedTextField(
                    controller: salt,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Соль, г'),
                  ),
                  LocalizedTextField(
                    controller: notes,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Заметка'),
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
                if (title.text.trim().isNotEmpty) {
                  final mealCalories = _parseInt(
                    calories.text,
                    meal?.calories ?? 0,
                  ).clamp(0, 20000).toInt();
                  final targetDate = dateStorageText(
                    date.text,
                    fallback: state.today.date,
                  );
                  var nextState = state;
                  if (isExisting) {
                    nextState = _removeMealCalories(nextState, meal);
                  }
                  final metrics = nextState.metricsFor(targetDate);
                  final updatedMeal =
                      (meal ??
                              MealEntry(
                                id: newId(),
                                title: title.text.trim(),
                                kind: kind,
                                calories: mealCalories,
                                protein: _parseInt(
                                  protein.text,
                                  meal?.protein ?? 0,
                                ).clamp(0, 1000).toInt(),
                                carbs: _parseInt(
                                  carbs.text,
                                  meal?.carbs ?? 0,
                                ).clamp(0, 1000).toInt(),
                                fat: _parseInt(
                                  fat.text,
                                  meal?.fat ?? 0,
                                ).clamp(0, 1000).toInt(),
                                confirmed: true,
                                notes: notes.text.trim().isEmpty
                                    ? 'Пользователь подтвердил вручную.'
                                    : notes.text.trim(),
                                date: targetDate,
                                time: time.text.trim(),
                                portionGrams: _parseInt(portion.text, 0),
                                fiber: _parseInt(fiber.text, 0),
                                sugar: _parseInt(sugar.text, 0),
                                salt: _parseDouble(salt.text, 0),
                              ))
                          .copyWith(
                            title: title.text.trim(),
                            kind: kind,
                            calories: mealCalories,
                            protein: _parseInt(
                              protein.text,
                              meal?.protein ?? 0,
                            ).clamp(0, 1000).toInt(),
                            carbs: _parseInt(
                              carbs.text,
                              meal?.carbs ?? 0,
                            ).clamp(0, 1000).toInt(),
                            fat: _parseInt(
                              fat.text,
                              meal?.fat ?? 0,
                            ).clamp(0, 1000).toInt(),
                            confirmed: true,
                            notes: notes.text.trim().isEmpty
                                ? 'Пользователь подтвердил вручную.'
                                : notes.text.trim(),
                            date: targetDate,
                            time: time.text.trim(),
                            portionGrams: _parseInt(portion.text, 0),
                            fiber: _parseInt(fiber.text, 0),
                            sugar: _parseInt(sugar.text, 0),
                            salt: _parseDouble(salt.text, 0),
                          );
                  final meals = !isExisting
                      ? [updatedMeal, ...nextState.meals]
                      : nextState.meals
                            .map(
                              (item) => item.id == meal.id ? updatedMeal : item,
                            )
                            .toList();
                  onChanged(
                    nextState
                        .updateMetricsFor(
                          targetDate,
                          metrics.copyWith(
                            calories: metrics.calories + mealCalories,
                          ),
                        )
                        .copyWith(
                          customOptions: [
                            ...pendingCustomOptions,
                            ...nextState.customOptions,
                          ],
                          meals: meals,
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

HealthAppState _deleteMealFromState(HealthAppState state, MealEntry meal) {
  final nextState = _removeMealCalories(state, meal);
  return nextState.copyWith(
    meals: nextState.meals
        .where((candidate) => candidate.id != meal.id)
        .toList(),
  );
}

HealthAppState _removeMealCalories(HealthAppState state, MealEntry meal) {
  final date = _itemDate(meal.date, state);
  final metrics = state.metricsFor(date);
  return state.updateMetricsFor(
    date,
    metrics.copyWith(
      calories: (metrics.calories - meal.calories).clamp(0, 20000).toInt(),
    ),
  );
}

Future<void> _editNutritionPreferences(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  final favorites = TextEditingController(
    text: state.profile.favoriteFoods.join(', '),
  );
  final disliked = TextEditingController(
    text: state.profile.dislikedFoods.join(', '),
  );
  final cookingMinutes = TextEditingController(
    text: '${state.profile.maxCookingMinutes}',
  );
  var dietType = state.profile.dietType;
  var budget = state.profile.foodBudget;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Параметры питания'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LocalizedDropdownButtonFormField<String>(
                  initialValue: dietType,
                  decoration: const InputDecoration(labelText: 'Тип питания'),
                  items: const [
                    DropdownMenuItem(
                      value: 'обычное питание',
                      child: Text('Обычное питание'),
                    ),
                    DropdownMenuItem(
                      value: 'вегетарианское',
                      child: Text('Вегетарианское'),
                    ),
                    DropdownMenuItem(
                      value: 'веганское',
                      child: Text('Веганское'),
                    ),
                    DropdownMenuItem(
                      value: 'безлактозное',
                      child: Text('Безлактозное'),
                    ),
                    DropdownMenuItem(
                      value: 'безглютеновое',
                      child: Text('Безглютеновое'),
                    ),
                    DropdownMenuItem(
                      value: 'низкоуглеводное',
                      child: Text('Низкоуглеводное'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => dietType = value ?? dietType),
                ),
                LocalizedDropdownButtonFormField<String>(
                  initialValue: budget,
                  decoration: const InputDecoration(labelText: 'Бюджет'),
                  items: const [
                    DropdownMenuItem(
                      value: 'экономный',
                      child: Text('Экономный'),
                    ),
                    DropdownMenuItem(value: 'средний', child: Text('Средний')),
                    DropdownMenuItem(
                      value: 'без ограничений',
                      child: Text('Без ограничений'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => budget = value ?? budget),
                ),
                _numberField(cookingMinutes, 'Максимальное время готовки, мин'),
                LocalizedTextField(
                  controller: favorites,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Любимые продукты и блюда',
                    hintText: 'Через запятую',
                  ),
                ),
                LocalizedTextField(
                  controller: disliked,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Нелюбимые продукты',
                    hintText: 'Через запятую',
                  ),
                ),
                if (state.allergies.isNotEmpty)
                  InfoTile(
                    icon: Icons.no_food_outlined,
                    title: 'Аллергии из медкарты',
                    subtitle: state.allergies.join(', '),
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
              List<String> values(String source) => source
                  .split(RegExp(r'[,;]'))
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();
              onChanged(
                state.copyWith(
                  profile: state.profile.copyWith(
                    favoriteFoods: values(favorites.text),
                    dislikedFoods: values(disliked.text),
                    dietType: dietType,
                    foodBudget: budget,
                    maxCookingMinutes: _parseInt(
                      cookingMinutes.text,
                      45,
                    ).clamp(0, 600),
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

List<FoodCatalogItem> _nutritionSuggestions(
  HealthAppState state,
  List<FoodCatalogItem> foods,
) {
  final blocked = [
    ...state.profile.dislikedFoods,
    ...state.allergies,
  ].map((item) => item.toLowerCase()).where((item) => item.isNotEmpty).toList();
  final maxCost = switch (state.profile.foodBudget) {
    'экономный' => 2,
    'средний' => 4,
    _ => 1000,
  };
  final filtered = foods.where((item) {
    final blob =
        '${item.titleRu} ${item.titleEn} ${item.composition} ${item.compositionRu} ${item.ingredients} ${item.ingredientsRu}'
            .toLowerCase();
    if (blocked.any(blob.contains)) return false;
    if (state.profile.maxCookingMinutes > 0 &&
        item.minutes > state.profile.maxCookingMinutes) {
      return false;
    }
    if (item.cost > maxCost) return false;
    if (state.profile.dietType == 'веганское' &&
        RegExp(
          r'мяс|рыб|яйц|молок|сыр|творог|chicken|beef|fish|egg|milk|cheese',
        ).hasMatch(blob)) {
      return false;
    }
    if (state.profile.dietType == 'вегетарианское' &&
        RegExp(r'мяс|рыб|chicken|beef|fish|pork').hasMatch(blob)) {
      return false;
    }
    return item.healthLevel >= 6;
  }).toList();
  filtered.sort((a, b) {
    final aScore = a.healthLevel * 10 + a.protein - a.sugar;
    final bScore = b.healthLevel * 10 + b.protein - b.sugar;
    return bScore.compareTo(aScore);
  });
  final result = <FoodCatalogItem>[];
  final usedKinds = <String>{};
  for (final item in filtered) {
    if (result.length >= 6) break;
    if (usedKinds.add(item.kind) || result.length >= 3) result.add(item);
  }
  return result;
}

Future<void> _showNutritionSuggestions(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  showDialog<void>(
    context: context,
    builder: (context) => const AlertDialog(
      content: SizedBox(
        width: 360,
        child: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Подбираем блюда из каталога...')),
          ],
        ),
      ),
    ),
  );
  final foods = await ExpandedCatalogRepository.instance.foods();
  final suggestions = _nutritionSuggestions(state, foods);
  if (!context.mounted) return;
  Navigator.pop(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Подбор на сегодня'),
      content: SizedBox(
        width: 680,
        height: 520,
        child: ListView(
          children: suggestions
              .map(
                (item) => ListTile(
                  leading: const Icon(Icons.restaurant_menu_outlined),
                  title: Text(
                    '${item.titleFor(state.localeCode)} · ${item.calories} ккал',
                  ),
                  subtitle: Text(
                    '${item.kindFor(state.localeCode)} · ${item.minutes} мин · полезность ${item.healthLevel}/10 · Б ${item.protein} / Ж ${item.fat} / У ${item.carbs}',
                  ),
                  trailing: LocalizedIconButton(
                    tooltip: 'Добавить в дневник',
                    onPressed: () =>
                        _addCatalogFoodToDiary(context, state, onChanged, item),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  onTap: () => _showFoodCatalogDetails(
                    context,
                    item,
                    state.localeCode,
                    offlineOnly: state.settings.offlineOnly,
                  ),
                ),
              )
              .toList(),
        ),
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

Future<void> _addCatalogFoodToDiary(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
  FoodCatalogItem item,
) {
  return _editMeal(
    context,
    state,
    onChanged,
    meal: MealEntry(
      id: newId(),
      title: item.titleFor(state.localeCode),
      kind: item.kindFor(state.localeCode),
      calories: item.calories,
      protein: item.protein,
      carbs: item.carbs,
      fat: item.fat,
      confirmed: true,
      notes: 'Добавлено из каталога. Значения указаны для каталожной порции.',
      date: state.today.date,
      fiber: item.fiber,
      sugar: item.sugar,
      salt: item.salt,
      source: 'catalog',
    ),
  );
}

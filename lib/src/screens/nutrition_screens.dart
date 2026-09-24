part of '../screens.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final todayMeals = state.meals
        .where((item) => _itemDate(item.date, state) == state.today.date)
        .toList();
    final protein = todayMeals.fold<int>(0, (sum, item) => sum + item.protein);
    final fat = todayMeals.fold<int>(0, (sum, item) => sum + item.fat);
    final carbs = todayMeals.fold<int>(0, (sum, item) => sum + item.carbs);
    final fiber = todayMeals.fold<int>(0, (sum, item) => sum + item.fiber);
    final sugar = todayMeals.fold<int>(0, (sum, item) => sum + item.sugar);
    final expenditure =
        state.profile.restingCaloriesBurnedSoFar() + state.today.activeCalories;
    final calorieBalance = state.today.calories - expenditure;
    return PageBand(
      title: AppText.get(state.localeCode, 'nutrition'),
      subtitle: 'Дневник питания, БЖУ, рецепты и ручное подтверждение фото',
      trailing: FilledButton.icon(
        onPressed: () => _addMeal(context, state, onChanged),
        icon: const Icon(Icons.add),
        label: const Text('Еда'),
      ),
      children: [
        ResponsiveGrid(
          children: [
            MetricCard(
              title: 'Калории',
              value: '${state.today.calories}',
              subtitle: 'ориентир 2100',
              icon: Icons.local_fire_department_outlined,
              color: Colors.orange,
              progress: state.today.calories / 2100,
            ),
            MetricCard(
              title: 'Белок',
              value: '$protein г',
              subtitle: 'цель 110 г',
              icon: Icons.egg_alt_outlined,
              color: Colors.green,
              progress: protein / 110,
            ),
            MetricCard(
              title: 'Клетчатка',
              value: '$fiber г',
              subtitle: 'ориентир 25-30 г',
              icon: Icons.grass_outlined,
              color: Colors.lightGreen,
              progress: fiber / 28,
            ),
            MetricCard(
              title: 'БЖУ',
              value: '$protein / $fat / $carbs г',
              subtitle: 'сахара $sugar г',
              icon: Icons.pie_chart_outline,
              color: Colors.indigo,
            ),
            MetricCard(
              title: 'Баланс сейчас',
              value: '${calorieBalance >= 0 ? '+' : ''}$calorieBalance ккал',
              subtitle:
                  'съедено ${state.today.calories} · расход $expenditure (базовый + активный)',
              icon: Icons.balance_outlined,
              color: calorieBalance > 500
                  ? Colors.deepOrange
                  : calorieBalance < -900
                  ? Colors.red
                  : Colors.teal,
            ),
          ],
        ),
        SectionTitle(
          'Параметры питания',
          action: LocalizedIconButton.filledTonal(
            tooltip: 'Настроить питание',
            onPressed: () =>
                _editNutritionPreferences(context, state, onChanged),
            icon: const Icon(Icons.tune_outlined),
          ),
        ),
        InfoTile(
          icon: Icons.restaurant_menu_outlined,
          title: state.profile.dietType,
          subtitle:
              'Бюджет: ${state.profile.foodBudget} · готовка до ${state.profile.maxCookingMinutes} мин\n'
              'Любимые: ${state.profile.favoriteFoods.isEmpty ? 'не указаны' : state.profile.favoriteFoods.join(', ')} · '
              'Не люблю: ${state.profile.dislikedFoods.isEmpty ? 'не указано' : state.profile.dislikedFoods.join(', ')}',
          onTap: () => _editNutritionPreferences(context, state, onChanged),
        ),
        SectionTitle('Подбор на сегодня'),
        InfoTile(
          icon: Icons.recommend_outlined,
          title: 'Составить подборку из каталога',
          subtitle:
              'Учитываются аллергии, нелюбимые продукты, бюджет, время готовки и цель.',
          onTap: () => _showNutritionSuggestions(context, state, onChanged),
        ),
        if (state.today.calories > 2400)
          const InfoTile(
            icon: Icons.directions_walk_outlined,
            title: 'Калорийность выше ориентира',
            subtitle:
                'Без жёстких ограничений: можно добавить спокойную прогулку и оценивать недельный баланс.',
          )
        else if (state.today.calories > 0 && state.today.calories < 1200)
          const InfoTile(
            icon: Icons.warning_amber_outlined,
            title: 'Питания может быть недостаточно',
            subtitle:
                'Слишком низкая калорийность может ухудшать восстановление. Добавьте полноценный приём пищи.',
          ),
        SectionTitle('Приёмы пищи'),
        ...todayMeals.map(
          (item) => InfoTile(
            icon: item.confirmed
                ? Icons.check_circle_outline
                : Icons.pending_actions_outlined,
            title: '${item.title} · ${item.calories} ккал',
            subtitle:
                '${displayDateKey(item.date)} ${item.time} · ${item.kind} · ${item.portionGrams > 0 ? '${item.portionGrams} г · ' : ''}Б ${item.protein} / Ж ${item.fat} / У ${item.carbs} · клетчатка ${item.fiber} · сахар ${item.sugar}\n${item.notes}',
            onTap: () => _editMeal(context, state, onChanged, meal: item),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () => onChanged(_deleteMealFromState(state, item)),
            ),
          ),
        ),
      ],
    );
  }
}

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.state.localeCode;
    return PageBand(
      title: AppText.get(locale, 'recipes'),
      subtitle: '10000 продуктов, блюд, напитков и рецептов из CSV',
      children: [
        LocalizedTextField(
          controller: _query,
          decoration: const InputDecoration(
            labelText: 'Поиск еды, продукта или напитка',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        FutureBuilder<List<FoodCatalogItem>>(
          future: ExpandedCatalogRepository.instance.foods(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final query = _query.text.toLowerCase().trim();
            final items = snapshot.data!
                .where(
                  (item) =>
                      query.isEmpty ||
                      item.titleFor(locale).toLowerCase().contains(query) ||
                      item.kindFor(locale).toLowerCase().contains(query) ||
                      item.categoryFor(locale).toLowerCase().contains(query),
                )
                .take(120)
                .toList();
            return Column(
              children: [
                InfoTile(
                  icon: Icons.dataset_outlined,
                  title: 'Загружено ${snapshot.data!.length} наименований',
                  subtitle:
                      'Показано ${items.length}; уточните поиск по блюду, продукту или напитку.',
                ),
                ...items.map(
                  (item) => InfoTile(
                    icon: Icons.menu_book_outlined,
                    title:
                        '${item.titleFor(locale)} · ${item.calories} ${AppText.get(locale, 'kcalShort')}',
                    subtitle:
                        '${item.kindFor(locale)} · полезность ${item.healthLevel}/10 · Б ${item.protein} / Ж ${item.fat} / У ${item.carbs}, сахар ${item.sugar}\n${item.compositionFor(locale)}',
                    onTap: () => _showFoodCatalogDetails(
                      context,
                      item,
                      locale,
                      offlineOnly: widget.state.settings.offlineOnly,
                    ),
                    trailing: LocalizedIconButton(
                      tooltip: 'Добавить в дневник',
                      onPressed: () => _addCatalogFoodToDiary(
                        context,
                        widget.state,
                        widget.onChanged,
                        item,
                      ),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class FoodPhotoScreen extends StatelessWidget {
  const FoodPhotoScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'foodPhoto'),
      subtitle: 'Все AI/OCR-результаты проходят ручное подтверждение',
      trailing: PopupMenuButton<_MediaImportAction>(
        tooltip: 'Импортировать фото или файл',
        icon: const Icon(Icons.add_a_photo_outlined),
        onSelected: (action) => _importMedia(context, action),
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _MediaImportAction.foodFile,
            child: ListTile(
              leading: Icon(Icons.image_outlined),
              title: Text('Фото еды из файла'),
            ),
          ),
          PopupMenuItem(
            value: _MediaImportAction.foodCamera,
            child: ListTile(
              leading: Icon(Icons.photo_camera_outlined),
              title: Text('Снимок еды камерой'),
            ),
          ),
          PopupMenuItem(
            value: _MediaImportAction.labFile,
            child: ListTile(
              leading: Icon(Icons.description_outlined),
              title: Text('Анализ или документ из файла'),
            ),
          ),
          PopupMenuItem(
            value: _MediaImportAction.labCamera,
            child: ListTile(
              leading: Icon(Icons.document_scanner_outlined),
              title: Text('Снимок анализа камерой'),
            ),
          ),
        ],
      ),
      children: [
        const MedicalDisclaimerBanner(),
        ...state.confirmationQueue
            .where((item) => !_isPrescriptionCandidate(item))
            .map((item) => _confirmationTile(item, state, onChanged)),
      ],
    );
  }

  Future<void> _importMedia(
    BuildContext context,
    _MediaImportAction action,
  ) async {
    final source = switch (action) {
      _MediaImportAction.foodFile ||
      _MediaImportAction.foodCamera => 'фото еды',
      _MediaImportAction.labFile ||
      _MediaImportAction.labCamera => 'OCR анализа',
    };
    final candidates = await MediaImportService().importForRecognitionBatch(
      source: source,
      requiresMedicalReview:
          action == _MediaImportAction.labFile ||
          action == _MediaImportAction.labCamera,
      camera:
          action == _MediaImportAction.foodCamera ||
          action == _MediaImportAction.labCamera,
    );
    if (!context.mounted) {
      return;
    }
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Импорт отменён')));
      return;
    }
    onChanged(
      state.copyWith(
        confirmationQueue: [...candidates, ...state.confirmationQueue],
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          candidates.length == 1
              ? 'Результат добавлен на ручную проверку.'
              : 'На ручную проверку добавлено показателей: ${candidates.length}.',
        ),
      ),
    );
  }
}

enum _MediaImportAction { foodFile, foodCamera, labFile, labCamera }

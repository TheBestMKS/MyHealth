part of '../screens.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({
    super.key,
    required this.state,
    required this.onChanged,
    required this.onSelect,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;
  final SectionSelected onSelect;

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final _search = TextEditingController();
  late final Future<MedicalKnowledgeCatalog> _medical;
  late final Future<List<FoodCatalogItem>> _foods;
  late final Future<List<WorkoutCatalogItem>> _workouts;
  int _tab = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _medical = MedicalKnowledgeRepository.instance.load();
    _foods = ExpandedCatalogRepository.instance.foods();
    _workouts = ExpandedCatalogRepository.instance.workouts();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: PageBand(
        title: AppText.get(widget.state.localeCode, 'knowledge'),
        subtitle:
            'Болезни, лекарства, витамины, продукты, блюда и тренировки из локальных источников',
        trailing: LocalizedIconButton.filledTonal(
          tooltip: 'Спросить помощника',
          onPressed: () => widget.onSelect(AppSection.assistant),
          icon: const Icon(Icons.psychology_outlined),
        ),
        children: [
          const MedicalDisclaimerBanner(),
          LocalizedTextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Поиск по локальной базе',
              hintText: 'Название, симптом, препарат, продукт или мышца',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          TabBar(
            isScrollable: true,
            onTap: (value) => setState(() => _tab = value),
            tabs: const [
              Tab(
                icon: Icon(Icons.medical_information_outlined),
                text: 'Болезни',
              ),
              Tab(icon: Icon(Icons.medication_outlined), text: 'Лекарства'),
              Tab(icon: Icon(Icons.restaurant_menu_outlined), text: 'Еда'),
              Tab(
                icon: Icon(Icons.fitness_center_outlined),
                text: 'Тренировки',
              ),
            ],
          ),
          const SizedBox(height: 4),
          switch (_tab) {
            0 => _buildTopics(),
            1 => _buildSubstances(),
            2 => _buildFoods(),
            _ => _buildWorkouts(),
          },
        ],
      ),
    );
  }

  Widget _buildTopics() {
    return FutureBuilder<MedicalKnowledgeCatalog>(
      future: _medical,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InfoTile(
            icon: Icons.error_outline,
            title: 'Не удалось открыть медицинский справочник',
            subtitle: '${snapshot.error}',
          );
        }
        final catalog = snapshot.data;
        if (catalog == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final matches = _rankTopics(catalog.topics, _query);
        final visible = matches.take(120).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultHeader(
              found: matches.length,
              shown: visible.length,
              source:
                  '${catalog.attribution} · русские проверочные карточки ${catalog.updated}',
            ),
            if (visible.isEmpty)
              const InfoTile(
                icon: Icons.search_off_outlined,
                title: 'Совпадений нет',
                subtitle:
                    'Попробуйте английское название или более короткую часть слова.',
              ),
            ...visible.map(
              (item) => InfoTile(
                icon: _topicMatchesProfile(item)
                    ? Icons.link_outlined
                    : Icons.medical_information_outlined,
                title: item.titleFor(widget.state.localeCode),
                subtitle: [
                  item.category,
                  if (item.aliases.isNotEmpty) item.aliases.take(3).join(', '),
                  if (!item.hasRussianText)
                    'Полная карточка MedlinePlus на английском',
                ].join('\n'),
                trailing: Pill(
                  label: item.hasRussianText ? 'RU' : 'EN',
                  icon: item.hasRussianText ? Icons.translate : Icons.public,
                ),
                onTap: () => _showTopic(item),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubstances() {
    return FutureBuilder<MedicalKnowledgeCatalog>(
      future: _medical,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InfoTile(
            icon: Icons.error_outline,
            title: 'Не удалось открыть базу препаратов',
            subtitle: '${snapshot.error}',
          );
        }
        final catalog = snapshot.data;
        if (catalog == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final query = _query.toLowerCase();
        final matches = catalog.substances
            .where((item) => query.isEmpty || item.searchText.contains(query))
            .toList();
        final visible = matches.take(120).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultHeader(
              found: matches.length,
              shown: visible.length,
              source: 'MedlinePlus Drug Information, NIH ODS и FDA NDC',
            ),
            ...visible.map((item) {
              final warning = _substancePersonalWarning(item);
              return InfoTile(
                icon: warning.isEmpty
                    ? Icons.medication_outlined
                    : Icons.warning_amber_outlined,
                title: item.titleFor(widget.state.localeCode),
                subtitle: [
                  item.category,
                  item.purpose,
                  if (warning.isNotEmpty) warning,
                ].join('\n'),
                onTap: () => _showSubstance(item, warning),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildFoods() {
    return FutureBuilder<List<FoodCatalogItem>>(
      future: _foods,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InfoTile(
            icon: Icons.error_outline,
            title: 'Не удалось открыть базу питания',
            subtitle: '${snapshot.error}',
          );
        }
        final foods = snapshot.data;
        if (foods == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final query = _query.toLowerCase();
        final matches = foods.where((item) {
          if (query.isEmpty) return true;
          return '${item.titleRu} ${item.titleEn} ${item.categoryFor(widget.state.localeCode)} ${item.kindFor(widget.state.localeCode)} ${item.compositionFor(widget.state.localeCode)}'
              .toLowerCase()
              .contains(query);
        }).toList();
        final visible = matches.take(120).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultHeader(
              found: matches.length,
              shown: visible.length,
              source: 'Локальный CSV-каталог продуктов, напитков и блюд',
            ),
            ...visible.map((item) {
              final allergen = _foodAllergy(item);
              return InfoTile(
                icon: allergen.isEmpty
                    ? Icons.restaurant_outlined
                    : Icons.warning_amber_outlined,
                title: item.titleFor(widget.state.localeCode),
                subtitle:
                    '${item.categoryFor(widget.state.localeCode)} · ${item.calories} ккал · Б/Ж/У ${item.protein}/${item.fat}/${item.carbs}'
                    '${allergen.isEmpty ? '' : '\nВозможное совпадение с аллергией: $allergen'}',
                trailing: Pill(
                  label: '${item.healthLevel}/10',
                  icon: Icons.favorite_border,
                ),
                onTap: () => _showFoodCatalogDetails(
                  context,
                  item,
                  widget.state.localeCode,
                  offlineOnly: widget.state.settings.offlineOnly,
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildWorkouts() {
    return FutureBuilder<List<WorkoutCatalogItem>>(
      future: _workouts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return InfoTile(
            icon: Icons.error_outline,
            title: 'Не удалось открыть базу тренировок',
            subtitle: '${snapshot.error}',
          );
        }
        final workouts = snapshot.data;
        if (workouts == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final query = _query.toLowerCase();
        final matches = workouts.where((item) {
          if (query.isEmpty) return true;
          return '${item.titleRu} ${item.titleEn} ${item.focusFor(widget.state.localeCode)} ${item.equipmentFor(widget.state.localeCode)} ${item.descriptionFor(widget.state.localeCode)}'
              .toLowerCase()
              .contains(query);
        }).toList();
        final visible = matches.take(120).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _resultHeader(
              found: matches.length,
              shown: visible.length,
              source: 'Локальный CSV-каталог упражнений и тренировок',
            ),
            ...visible.map((item) {
              final warning = _workoutPersonalWarning(item);
              return InfoTile(
                icon: warning.isEmpty
                    ? Icons.fitness_center_outlined
                    : Icons.warning_amber_outlined,
                title: item.titleFor(widget.state.localeCode),
                subtitle:
                    '${item.focusFor(widget.state.localeCode)} · ${item.equipmentFor(widget.state.localeCode)} · ${item.minutes} мин · ${item.calories} ккал'
                    '${warning.isEmpty ? '' : '\n$warning'}',
                onTap: () => _showWorkoutCatalogDetails(
                  context,
                  item,
                  widget.state.localeCode,
                  offlineOnly: widget.state.settings.offlineOnly,
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _resultHeader({
    required int found,
    required int shown,
    required String source,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              found > shown
                  ? 'Найдено $found · показаны первые $shown. Уточните поиск для полного списка.'
                  : 'Найдено $found',
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              source,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  List<MedicalTopic> _rankTopics(List<MedicalTopic> source, String query) {
    final value = query.toLowerCase().trim();
    if (value.isEmpty) return source;
    final result = source
        .where((item) => item.searchText.contains(value))
        .toList();
    result.sort((left, right) {
      int score(MedicalTopic item) {
        final title = '${item.titleRu} ${item.titleEn}'.toLowerCase();
        if (title == value) return 0;
        if (title.startsWith(value)) return 1;
        if (title.contains(value)) return 2;
        return 3;
      }

      return score(left).compareTo(score(right));
    });
    return result;
  }

  bool _topicMatchesProfile(MedicalTopic item) {
    final profileTerms = [
      ...widget.state.chronicConditions,
      ...widget.state.contraindications,
    ].map((value) => value.toLowerCase()).where((value) => value.length >= 3);
    return profileTerms.any(
      (value) =>
          item.searchText.contains(value) ||
          (item.titleRu.isNotEmpty &&
              value.contains(item.titleRu.toLowerCase())),
    );
  }

  String _substancePersonalWarning(SubstanceKnowledge item) {
    final text = item.searchText;
    final warnings = <String>[];
    final conditions = [
      ...widget.state.chronicConditions,
      ...widget.state.contraindications,
      ...widget.state.allergies,
    ].join(' ').toLowerCase();
    if ((text.contains('нпвп') ||
            text.contains('ibuprofen') ||
            text.contains('aspirin')) &&
        (conditions.contains('почек') ||
            conditions.contains('язв') ||
            conditions.contains('кровот'))) {
      warnings.add('Ваши ограничения могут быть значимы для этого средства.');
    }
    final anticoagulants = widget.state.medications.any((medicine) {
      final value = medicine.name.toLowerCase();
      return value.contains('варфар') ||
          value.contains('апикс') ||
          value.contains('риварокс') ||
          value.contains('дабигатр');
    });
    if (anticoagulants &&
        (text.contains('кровотеч') ||
            text.contains('нпвп') ||
            text.contains('витамин k'))) {
      warnings.add(
        'В списке есть антикоагулянт: взаимодействие нужно проверить у врача или фармацевта.',
      );
    }
    return warnings.join(' ');
  }

  String _foodAllergy(FoodCatalogItem item) {
    final text =
        '${item.titleRu} ${item.titleEn} ${item.composition} ${item.compositionRu} ${item.ingredients} ${item.ingredientsRu}'
            .toLowerCase();
    return widget.state.allergies.firstWhere((allergy) {
      final value = allergy.toLowerCase().trim();
      return value.length >= 3 && text.contains(value);
    }, orElse: () => '');
  }

  String _workoutPersonalWarning(WorkoutCatalogItem item) {
    final text =
        '${item.focus} ${item.focusRu} ${item.requirements} ${item.requirementsRu} ${item.warnings} ${item.warningsRu}'
            .toLowerCase();
    final match = widget.state.contraindications.firstWhere((value) {
      final term = value.toLowerCase().trim();
      return term.length >= 4 && text.contains(term);
    }, orElse: () => '');
    return match.isEmpty
        ? ''
        : 'Проверьте ограничение «$match» перед выполнением.';
  }

  Future<void> _showTopic(MedicalTopic item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.titleFor(widget.state.localeCode)),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(label: item.category),
                    Pill(
                      label: item.hasRussianText
                          ? 'русская карточка'
                          : 'English',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(item.summary),
                if (item.symptoms.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Возможные симптомы',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...item.symptoms.map((value) => Text('• $value')),
                ],
                if (item.care.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Как обычно ведут состояние',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(item.care),
                ],
                if (item.urgent.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Когда нужна срочная помощь',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(item.urgent),
                ],
                if (item.prevention.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Профилактика и самоконтроль',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(item.prevention),
                ],
                const SizedBox(height: 14),
                Text(
                  'Источник',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SelectableText('${item.source}\n${item.sourceUrl}'),
              ],
            ),
          ),
        ),
        actions: [
          if (item.hasRussianText &&
              !widget.state.chronicConditions.contains(item.titleRu))
            FilledButton.tonalIcon(
              onPressed: () {
                widget.onChanged(
                  widget.state.copyWith(
                    chronicConditions: [
                      ...widget.state.chronicConditions,
                      item.titleRu,
                    ],
                  ),
                );
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.add),
              label: const Text('В медкарту'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubstance(
    SubstanceKnowledge item,
    String personalWarning,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.titleFor(widget.state.localeCode)),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Pill(label: item.category, icon: Icons.category_outlined),
                if (personalWarning.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InfoTile(
                    icon: Icons.warning_amber_outlined,
                    title: 'Персональная проверка',
                    subtitle: personalWarning,
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Для чего применяется',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(item.purpose),
                const SizedBox(height: 14),
                Text(
                  'Предупреждения',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(item.warnings),
                const SizedBox(height: 14),
                Text(
                  'Взаимодействия',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(item.interactions),
                const SizedBox(height: 14),
                Text(
                  'Частота и приём',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(item.frequencyNote),
                const SizedBox(height: 14),
                Text(
                  'Источник',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SelectableText(item.sourceUrl),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onSelect(AppSection.medicines);
            },
            icon: const Icon(Icons.medication_outlined),
            label: const Text('Открыть лекарства'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

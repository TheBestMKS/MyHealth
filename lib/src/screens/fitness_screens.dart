part of '../screens.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'workouts'),
      subtitle: 'План по инвентарю, готовности и ограничениям',
      trailing: FilledButton.icon(
        onPressed: () => _addWorkout(context, state, onChanged),
        icon: const Icon(Icons.add),
        label: const Text('Тренировка'),
      ),
      children: [
        ResponsiveGrid(
          children: [
            MetricCard(
              title: 'Сегодня',
              value: '${state.today.workoutMinutes} мин',
              subtitle:
                  'интенсивность по готовности ${state.readinessScore}/100',
              icon: Icons.timer_outlined,
              color: Colors.indigo,
              progress: state.today.workoutMinutes / 45,
            ),
            MetricCard(
              title: 'Инвентарь',
              value: '${state.inventory.length}',
              subtitle: state.inventory.take(2).join(', '),
              icon: Icons.home_repair_service_outlined,
              color: Colors.teal,
            ),
          ],
        ),
        GeoWorkoutPanel(state: state, onChanged: onChanged),
        ActionRow(
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _generateWorkout(state, onChanged),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Собрать план по готовности'),
            ),
          ],
        ),
        SectionTitle('Планы тренировок'),
        ...state.workouts.map(
          (item) => InfoTile(
            icon: Icons.fitness_center_outlined,
            title: '${item.title} · ${item.minutes} мин',
            subtitle:
                '${item.focus} · ${item.intensity} · ${item.scheduledDate}\n'
                '${_exerciseNames(item.exerciseIds, state.localeCode)}'
                '${item.notes.isEmpty ? '' : '\n${item.notes}'}',
            onTap: () => _openWorkoutPlayer(context, state, onChanged, item),
            trailing: LocalizedIconButton(
              tooltip: item.status == 'completed'
                  ? 'Выполнена'
                  : 'Начать тренировку',
              onPressed: () =>
                  _openWorkoutPlayer(context, state, onChanged, item),
              icon: Icon(
                item.status == 'completed'
                    ? Icons.check_circle_outline
                    : Icons.play_circle_outline,
              ),
            ),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () => onChanged(_deleteWorkoutFromState(state, item)),
            ),
          ),
        ),
        _stringListBlock(
          context,
          title: 'Инвентарь',
          icon: Icons.home_repair_service_outlined,
          values: state.inventory,
          onAddPressed: () => _addCatalogListItem(
            context,
            state,
            onChanged,
            title: 'Инвентарь',
            group: 'inventory',
            options: _inventoryOptions,
            values: state.inventory,
            addToState: (nextState, value) =>
                nextState.copyWith(inventory: [...nextState.inventory, value]),
          ),
          onAdd: (value) =>
              onChanged(state.copyWith(inventory: [...state.inventory, value])),
          onRemove: (value) => onChanged(
            state.copyWith(
              inventory: _removeFirstString(state.inventory, value),
            ),
          ),
        ),
      ],
    );
  }
}

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key, required this.state});

  final HealthAppState state;

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
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
      title: AppText.get(locale, 'exercises'),
      subtitle:
          '1000 тренировок с техникой, требованиями, расходом калорий и медиа',
      children: [
        LocalizedTextField(
          controller: _query,
          decoration: const InputDecoration(
            labelText: 'Поиск тренировки',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        FutureBuilder<List<WorkoutCatalogItem>>(
          future: ExpandedCatalogRepository.instance.workouts(),
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
                      item.focus.toLowerCase().contains(query) ||
                      item.equipment.toLowerCase().contains(query),
                )
                .take(120)
                .toList();
            return Column(
              children: [
                InfoTile(
                  icon: Icons.dataset_outlined,
                  title: 'Загружено ${snapshot.data!.length} тренировок',
                  subtitle:
                      'Показано ${items.length}; уточните поиск для точного выбора.',
                ),
                ...items.map(
                  (item) => InfoTile(
                    icon: Icons.list_alt_outlined,
                    title:
                        '${item.titleFor(locale)} · ${item.minutes} ${AppText.get(locale, 'minShort')}',
                    subtitle:
                        '${item.focus} · ${item.equipment} · ${item.level}\n${item.description}',
                    onTap: () =>
                        _showWorkoutCatalogDetails(context, item, locale),
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

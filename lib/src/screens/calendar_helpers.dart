part of '../screens.dart';

Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required VoidCallback onDelete,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить'),
              subtitle: const Text('Запись будет удалена из локального сейфа'),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Отмена'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pickCalendarDate(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  final initial = parseDateKey(state.today.date) ?? DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1900),
    lastDate: DateTime(DateTime.now().year + 5),
  );
  if (picked == null || !context.mounted) {
    return;
  }
  await _showDayDetails(context, state, onChanged, todayKey(picked));
}

Future<void> _showDayDetails(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
  String date,
) async {
  final metrics = state.metricsFor(date);
  final meals = state.meals
      .where((item) => _itemDate(item.date, state) == date)
      .toList();
  final medIntakes = state.medicationIntakesFor(date);
  final labs = state.labResults.where((item) => item.date == date).toList();
  final workouts = state.workouts
      .where((item) => item.scheduledDate == date)
      .toList();
  final reminders = state.reminders
      .where((item) => _itemDate(item.date, state) == date)
      .toList();

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      date,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      showQuickAddDialog(
                        context,
                        state,
                        onChanged,
                        initialDate: date,
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Изменить'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Pill(
                    label: 'шаги ${metrics.steps}',
                    icon: Icons.directions_walk_outlined,
                  ),
                  Pill(
                    label: 'сон ${metrics.sleepHours.toStringAsFixed(1)} ч',
                    icon: Icons.bedtime_outlined,
                  ),
                  Pill(
                    label: 'вода ${metrics.waterLiters.toStringAsFixed(1)} л',
                    icon: Icons.water_drop_outlined,
                  ),
                  Pill(
                    label: 'калории ${metrics.calories}',
                    icon: Icons.local_fire_department_outlined,
                  ),
                  Pill(
                    label: 'расход ${metrics.totalCaloriesBurned}',
                    icon: Icons.energy_savings_leaf_outlined,
                  ),
                  Pill(
                    label: 'тренировка ${metrics.workoutMinutes} мин',
                    icon: Icons.fitness_center_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _dayList(
                'Питание',
                meals.map((item) => '${item.title} · ${item.calories} ккал'),
              ),
              _dayList(
                'Лекарства',
                medIntakes.map(
                  (item) =>
                      '${item.medicationName} · ${item.dose} · ${item.time} · ${item.status}',
                ),
              ),
              _dayList(
                'Анализы',
                labs.map(
                  (item) => '${item.marker} · ${item.value} ${item.unit}',
                ),
              ),
              _dayList(
                'Тренировки',
                workouts.map((item) => '${item.title} · ${item.minutes} мин'),
              ),
              _dayList(
                'Напоминания',
                reminders.map((item) => '${item.time} · ${item.title}'),
              ),
              _dayList('Симптомы', metrics.symptoms),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _dayList(String title, Iterable<String> values) {
  final list = values.toList();
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (list.isEmpty)
          const Text('Нет записей за этот день.')
        else
          ...list.map((item) => Text('• $item')),
      ],
    ),
  );
}

String _itemDate(String value, HealthAppState state) {
  return value.trim().isEmpty ? state.today.date : value.trim();
}

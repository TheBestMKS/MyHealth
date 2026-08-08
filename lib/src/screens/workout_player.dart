part of '../screens.dart';

Future<void> _openWorkoutPlayer(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
  WorkoutSession workout,
) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => _WorkoutPlayerScreen(
        state: state,
        workout: workout,
        onChanged: onChanged,
      ),
    ),
  );
}

class _WorkoutPlayerScreen extends StatefulWidget {
  const _WorkoutPlayerScreen({
    required this.state,
    required this.workout,
    required this.onChanged,
  });

  final HealthAppState state;
  final WorkoutSession workout;
  final HealthStateChanged onChanged;

  @override
  State<_WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<_WorkoutPlayerScreen> {
  Timer? _timer;
  late List<Exercise> _exercises;
  final List<WorkoutExerciseResult> _results = [];
  int _index = 0;
  int _elapsedSeconds = 0;
  int _exerciseSeconds = 0;
  int _sets = 0;
  int _repetitions = 10;
  int _restSeconds = 0;
  bool _running = false;
  bool _resting = false;
  bool _pain = false;
  String _difficulty = 'нормально';

  Exercise get _current => _exercises[_index];

  @override
  void initState() {
    super.initState();
    _exercises = widget.workout.exerciseIds
        .map((id) => exerciseCatalog.where((item) => item.id == id).firstOrNull)
        .whereType<Exercise>()
        .toList();
    if (_exercises.isEmpty) {
      _exercises = [
        Exercise(
          id: 'manual-${widget.workout.id}',
          title: widget.workout.title,
          focus: widget.workout.focus,
          equipment: 'по плану пользователя',
          level: widget.workout.intensity,
          minutes: widget.workout.minutes,
          instructions: widget.workout.notes.isEmpty
              ? 'Выполняйте тренировку по своему плану и отмечайте подходы.'
              : widget.workout.notes,
          warning:
              'Остановитесь при боли, головокружении, одышке или резком ухудшении самочувствия.',
        ),
      ];
    }
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _running = true;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_running) return;
      setState(() {
        _elapsedSeconds++;
        if (_resting) {
          if (_restSeconds > 0) _restSeconds--;
          if (_restSeconds == 0) _resting = false;
        } else {
          _exerciseSeconds++;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.state.localeCode;
    final pulse = _currentPulse();
    final next = _index + 1 < _exercises.length ? _exercises[_index + 1] : null;
    final progress = (_index + (_sets > 0 ? 0.5 : 0)) / _exercises.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.title),
        actions: [
          LocalizedIconButton(
            tooltip: _running ? 'Пауза' : 'Продолжить',
            onPressed: () => setState(() => _running = !_running),
            icon: Icon(_running ? Icons.pause : Icons.play_arrow),
          ),
          LocalizedIconButton(
            tooltip: 'Завершить',
            onPressed: _finish,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LinearProgressIndicator(value: progress.clamp(0, 1)),
            const SizedBox(height: 16),
            ResponsiveGrid(
              minTileWidth: 180,
              children: [
                MetricCard(
                  title: 'Общее время',
                  value: _formatPlayerElapsed(_elapsedSeconds),
                  subtitle: 'план ${widget.workout.minutes} мин',
                  icon: Icons.timer_outlined,
                  color: Colors.indigo,
                ),
                MetricCard(
                  title: _resting ? 'Отдых' : 'Упражнение',
                  value: _resting
                      ? _formatPlayerElapsed(_restSeconds)
                      : _formatPlayerElapsed(_exerciseSeconds),
                  subtitle: '${_index + 1} из ${_exercises.length}',
                  icon: _resting
                      ? Icons.hourglass_bottom
                      : Icons.fitness_center,
                  color: _resting ? Colors.orange : Colors.teal,
                ),
                MetricCard(
                  title: 'Калории',
                  value: '${_estimatedWorkoutCalories()} ккал',
                  subtitle: 'оценка по времени и массе тела',
                  icon: Icons.local_fire_department_outlined,
                  color: Colors.deepOrange,
                ),
                MetricCard(
                  title: 'Пульс',
                  value: pulse == null ? 'нет данных' : '$pulse уд/мин',
                  subtitle: pulse == null
                      ? 'подключите датчик или внесите измерение'
                      : 'последнее доступное измерение сегодня',
                  icon: Icons.monitor_heart_outlined,
                  color: pulse == null ? Colors.blueGrey : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _current.titleFor(locale),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '${_current.focusFor(locale)} · ${_current.equipmentFor(locale)} · ${_current.levelFor(locale)}',
            ),
            const SizedBox(height: 14),
            InfoTile(
              icon: Icons.format_list_numbered_outlined,
              title: 'Техника выполнения',
              subtitle: _current.instructionsFor(locale),
            ),
            InfoTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Безопасность',
              subtitle: _current.warningFor(locale),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Подходы: $_sets',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                LocalizedIconButton(
                  tooltip: 'Уменьшить повторения',
                  onPressed: _repetitions > 1
                      ? () => setState(() => _repetitions--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_repetitions повторений'),
                LocalizedIconButton(
                  tooltip: 'Увеличить повторения',
                  onPressed: () => setState(() => _repetitions++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _resting ? null : _completeSet,
                  icon: const Icon(Icons.check),
                  label: const Text('Подход выполнен'),
                ),
                OutlinedButton.icon(
                  onPressed: _replaceExercise,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Заменить'),
                ),
                OutlinedButton.icon(
                  onPressed: _completeExercise,
                  icon: const Icon(Icons.skip_next),
                  label: Text(
                    _index + 1 < _exercises.length ? 'Следующее' : 'Завершить',
                  ),
                ),
                ChoiceChip(
                  label: const Text('Слишком легко'),
                  selected: _difficulty == 'слишком легко',
                  onSelected: (_) =>
                      setState(() => _difficulty = 'слишком легко'),
                ),
                ChoiceChip(
                  label: const Text('Слишком тяжело'),
                  selected: _difficulty == 'слишком тяжело',
                  onSelected: (_) =>
                      setState(() => _difficulty = 'слишком тяжело'),
                ),
                FilterChip(
                  avatar: const Icon(Icons.warning_amber_outlined),
                  label: const Text('Боль или плохое самочувствие'),
                  selected: _pain,
                  onSelected: (value) => setState(() {
                    _pain = value;
                    if (value) _running = false;
                  }),
                ),
              ],
            ),
            if (_pain)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: InfoTile(
                  icon: Icons.emergency_outlined,
                  title: 'Тренировка поставлена на паузу',
                  subtitle:
                      'Не продолжайте через боль. При резком ухудшении самочувствия обратитесь за медицинской помощью.',
                ),
              ),
            if (next != null) ...[
              const SizedBox(height: 16),
              SectionTitle('Следующее упражнение'),
              InfoTile(
                icon: Icons.skip_next_outlined,
                title: next.titleFor(locale),
                subtitle: next.instructionsFor(locale),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _completeSet() {
    setState(() {
      _sets++;
      _resting = true;
      _restSeconds = 60;
    });
  }

  void _completeExercise() {
    _saveCurrentResult();
    if (_index + 1 >= _exercises.length) {
      _finish(saveCurrent: false);
      return;
    }
    setState(() {
      _index++;
      _exerciseSeconds = 0;
      _sets = 0;
      _repetitions = 10;
      _restSeconds = 0;
      _resting = false;
      _pain = false;
      _difficulty = 'нормально';
    });
  }

  Future<void> _replaceExercise() async {
    final replacement = await showDialog<Exercise>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заменить упражнение'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: ListView(
            children: exerciseCatalog
                .where((item) => item.id != _current.id)
                .map(
                  (item) => ListTile(
                    leading: const Icon(Icons.fitness_center_outlined),
                    title: Text(item.titleFor(widget.state.localeCode)),
                    subtitle: Text(
                      '${item.focusFor(widget.state.localeCode)} · ${item.equipmentFor(widget.state.localeCode)}',
                    ),
                    onTap: () => Navigator.pop(context, item),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (replacement != null && mounted) {
      setState(() => _exercises[_index] = replacement);
    }
  }

  void _saveCurrentResult() {
    _results.add(
      WorkoutExerciseResult(
        exerciseId: _current.id,
        title: _current.titleFor(widget.state.localeCode),
        setsCompleted: _sets,
        repetitions: _repetitions,
        seconds: _exerciseSeconds,
        difficulty: _difficulty,
        pain: _pain,
      ),
    );
  }

  Future<void> _finish({bool saveCurrent = true}) async {
    _running = false;
    final effort = await showDialog<int>(
      context: context,
      builder: (context) {
        var value = _pain ? 9 : 6;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Завершение тренировки'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Оцените нагрузку: $value из 10'),
                Slider(
                  min: 1,
                  max: 10,
                  divisions: 9,
                  value: value.toDouble(),
                  onChanged: (next) =>
                      setDialogState(() => value = next.round()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Продолжить тренировку'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, value),
                child: const Text('Сохранить результат'),
              ),
            ],
          ),
        );
      },
    );
    if (effort == null) {
      setState(() => _running = true);
      return;
    }
    if (saveCurrent) _saveCurrentResult();
    final actualMinutes = (_elapsedSeconds / 60).ceil().clamp(1, 600);
    final completed = widget.workout.copyWith(
      minutes: actualMinutes,
      elapsedSeconds: _elapsedSeconds,
      caloriesBurned: _estimatedWorkoutCalories(),
      exerciseIds: _exercises.map((item) => item.id).toList(),
      status: 'completed',
      completedAt: DateTime.now().toIso8601String(),
      perceivedEffort: effort,
      feedback: _pain
          ? 'Отмечена боль или плохое самочувствие. Будущую нагрузку следует снизить.'
          : _difficulty,
      exerciseResults: _results,
    );
    var nextState = widget.state;
    final previous = widget.state.workouts
        .where((item) => item.id == widget.workout.id)
        .firstOrNull;
    if (previous != null) {
      nextState = _removeWorkoutMinutes(nextState, previous);
    }
    var updatedWorkouts = widget.state.workouts
        .map((item) => item.id == completed.id ? completed : item)
        .toList();
    updatedWorkouts = adaptFutureWorkoutPlan(updatedWorkouts, completed);
    nextState = _addWorkoutMinutes(
      nextState,
      completed,
    ).copyWith(workouts: updatedWorkouts);
    widget.onChanged(nextState);
    if (mounted) Navigator.pop(context);
  }

  int _estimatedWorkoutCalories() {
    final weight = widget.state.profile.weightKg > 0
        ? widget.state.profile.weightKg
        : 70;
    final intensity = widget.workout.intensity.toLowerCase();
    final focus = widget.workout.focus.toLowerCase();
    final met = intensity.contains('выс') || intensity.contains('high')
        ? 8.0
        : intensity.contains('низ') ||
              intensity.contains('восстанов') ||
              intensity.contains('low') ||
              focus.contains('мобиль') ||
              focus.contains('растяж')
        ? 3.5
        : 5.5;
    return (met * weight * (_elapsedSeconds / 3600)).round();
  }

  int? _currentPulse() {
    final today = widget.state.today.date;
    final symptomValues =
        widget.state.symptomEntries
            .where((item) => item.date == today && item.pulse != null)
            .toList()
          ..sort((a, b) => b.time.compareTo(a.time));
    if (symptomValues.isNotEmpty) return symptomValues.first.pulse;
    final measurements = widget.state.labResults
        .where(
          (item) =>
              item.date == today &&
              (item.marker.toLowerCase().contains('пульс') ||
                  item.marker.toLowerCase().contains('heart rate')),
        )
        .toList();
    for (final item in measurements) {
      final value = double.tryParse(item.value.replaceAll(',', '.'))?.round();
      if (value != null && value > 0) return value;
    }
    return null;
  }
}

String _formatPlayerElapsed(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

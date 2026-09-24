part of '../screens.dart';

Widget _weatherTodayBlock(HealthAppState state) {
  final latitude = state.profile.latitude;
  final longitude = state.profile.longitude;
  if (latitude == null || longitude == null) {
    return const InfoTile(
      icon: Icons.location_off_outlined,
      title: 'Погода недоступна',
      subtitle: 'Выберите город в профиле, чтобы учитывать погоду и воздух.',
    );
  }
  if (state.settings.offlineOnly) {
    return InfoTile(
      icon: Icons.cloud_off_outlined,
      title: '${state.profile.city} · ${state.profile.climate}',
      subtitle:
          'Сетевые данные отключены режимом «Полностью офлайн». Климатический профиль продолжает работать.',
    );
  }
  return FutureBuilder<WeatherSnapshot>(
    future: WeatherService.instance.load(latitude, longitude),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const InfoTile(
          icon: Icons.cloud_sync_outlined,
          title: 'Получаем погоду и качество воздуха',
          subtitle: 'Источник: Open-Meteo.',
        );
      }
      if (snapshot.hasError || !snapshot.hasData) {
        return InfoTile(
          icon: Icons.cloud_off_outlined,
          title: 'Не удалось обновить погоду',
          subtitle: '${snapshot.error ?? 'Проверьте подключение к сети.'}',
        );
      }
      final weather = snapshot.data!;
      if (!weather.isAvailable) {
        return InfoTile(
          icon: Icons.cloud_off_outlined,
          title: 'Погода временно недоступна',
          subtitle: weather.errorMessage,
        );
      }
      return InfoTile(
        icon: Icons.cloud_outlined,
        title:
            '${formatTemperature(weather.temperatureC, state.settings)} · ${weather.condition}',
        subtitle:
            'Ощущается ${formatTemperature(weather.apparentTemperatureC, state.settings)} · влажность ${weather.humidity}% · ветер ${formatSpeed(weather.windKmh, state.settings)}\n'
            'Воздух: ${weather.airQuality}, AQI ${weather.europeanAqi}, PM2.5 ${weather.pm25.toStringAsFixed(1)} · пыльца ${weather.pollen.toStringAsFixed(1)}\n'
            '${weather.workoutAdvice()}',
      );
    },
  );
}

Widget _analyticsBar(
  BuildContext context,
  String title,
  double value,
  Color color,
) {
  final bounded = value.clamp(0, 1).toDouble();
  return Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('${(bounded * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: bounded,
            minHeight: 10,
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    ),
  );
}

Widget _switchTile({
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    ),
  );
}

String _reminderRepeatLabel(String value) => switch (value) {
  'daily' => 'каждый день',
  'weekdays' => 'по будням',
  'weekends' => 'по выходным',
  _ => 'один раз',
};

Widget _settingsChoice({
  required String label,
  required String value,
  required Map<String, String> options,
  required ValueChanged<String> onChanged,
}) {
  final currentValue = options.containsKey(value) ? value : options.keys.first;
  return LocalizedDropdownButtonFormField<String>(
    initialValue: currentValue,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items: [
      for (final entry in options.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: (next) {
      if (next != null) {
        onChanged(next);
      }
    },
  );
}

void _generateWorkout(HealthAppState state, HealthStateChanged onChanged) {
  final now = DateTime.now();
  final today = todayKey(now);
  final yesterday = todayKey(now.subtract(const Duration(days: 1)));
  final lowerInventory = state.inventory.join(' ').toLowerCase();
  final healthRestrictions = [
    ...state.contraindications,
    ...state.injuries.map((item) => '${item.title} ${item.bodyArea}'),
  ].join(' ').toLowerCase();
  final recentSymptoms = state.symptomEntries.where((item) {
    final date = parseDateKey(item.date);
    return date != null && now.difference(date).inDays <= 2;
  }).toList();
  final alarming = recentSymptoms.any(
    (item) =>
        item.needsAttention ||
        item.intensity >= 8 ||
        (item.temperatureC ?? 0) >= 38 ||
        _isAlarmingSymptom('${item.symptom} ${item.notes}'),
  );
  final activeTrip = state.trips
      .where(
        (item) =>
            item.startDate.compareTo(today) <= 0 &&
            item.endDate.compareTo(today) >= 0,
      )
      .firstOrNull;
  final activeVacation = state.workSchedule.vacations
      .where(
        (item) =>
            item.startDate.compareTo(today) <= 0 &&
            item.endDate.compareTo(today) >= 0,
      )
      .firstOrNull;
  final travelRecovery =
      activeTrip?.nightTravel == true ||
      activeTrip?.sleepInTransit == true ||
      activeTrip != null && activeTrip.timeZoneShift.abs() >= 3 ||
      activeVacation?.nightTravel == true ||
      activeVacation?.sleepInTransit == true;
  final previousHeavy = state.workouts.any(
    (item) =>
        item.scheduledDate == yesterday &&
        item.status == 'completed' &&
        (item.intensity == 'высокая' || item.perceivedEffort >= 8),
  );
  final missed = state.workouts
      .where(
        (item) =>
            item.status == 'missed' ||
            item.status == 'planned' && item.scheduledDate.compareTo(today) < 0,
      )
      .length;
  final lowReadiness =
      state.readinessScore < 55 ||
      state.today.sleepHours > 0 && state.today.sleepHours < 6;
  final climate = state.profile;
  final poorAir = _airQualityIsPoor(climate.airQuality);
  final climateStress =
      poorAir ||
      climate.typicalTemperatureC >= 30 ||
      climate.typicalTemperatureC <= -10 ||
      climate.humidityPercent >= 80 ||
      climate.altitudeMeters >= 1500;
  final recovery =
      alarming ||
      travelRecovery ||
      previousHeavy ||
      lowReadiness ||
      climateStress;
  final goalText = [
    state.profile.goal,
    ...state.profile.trainingGoals,
  ].join(' ').toLowerCase();
  final muscleGoal =
      goalText.contains('мыш') ||
      goalText.contains('мас') ||
      goalText.contains('сил');
  final weightGoal =
      goalText.contains('похуд') ||
      goalText.contains('вес') ||
      goalText.contains('fat');

  bool equipmentAvailable(Exercise exercise) {
    final equipment = exercise.equipment.toLowerCase();
    if (equipment.contains('без')) return true;
    if (equipment.contains('коврик')) {
      return lowerInventory.contains('коврик') || state.inventory.isEmpty;
    }
    if (equipment.contains('гантел')) return lowerInventory.contains('гантел');
    if (equipment.contains('эспанд')) {
      return lowerInventory.contains('эспанд') ||
          lowerInventory.contains('резин');
    }
    if (equipment.contains('опора')) return true;
    return lowerInventory.contains(equipment);
  }

  bool allowedByInjuries(Exercise exercise) {
    final id = exercise.id;
    if ((healthRestrictions.contains('колен') ||
            healthRestrictions.contains('голеностоп')) &&
        const {'goblet-squat', 'split-squat', 'step-up'}.contains(id)) {
      return false;
    }
    if ((healthRestrictions.contains('поясниц') ||
            healthRestrictions.contains('спин')) &&
        const {'romanian-deadlift', 'plank'}.contains(id)) {
      return false;
    }
    if ((healthRestrictions.contains('плеч') ||
            healthRestrictions.contains('запяст')) &&
        const {'push-up', 'shoulder-press'}.contains(id)) {
      return false;
    }
    return true;
  }

  final preferredIds = recovery
      ? const [
          'box-breathing',
          'cat-cow',
          'hip-flexor-stretch',
          'bird-dog',
          'glute-bridge',
        ]
      : muscleGoal
      ? const [
          'goblet-squat',
          'romanian-deadlift',
          'push-up',
          'band-row',
          'shoulder-press',
          'farmer-walk',
          'dead-bug',
        ]
      : weightGoal
      ? const [
          'low-impact-interval',
          'step-up',
          'goblet-squat',
          'push-up',
          'band-row',
          'dead-bug',
        ]
      : const [
          'goblet-squat',
          'push-up',
          'band-row',
          'glute-bridge',
          'dead-bug',
          'low-impact-interval',
        ];
  final available = exerciseCatalog
      .where(equipmentAvailable)
      .where(allowedByInjuries)
      .toList();
  final matching = <Exercise>[];
  for (final id in preferredIds) {
    final exercise = available.where((item) => item.id == id).firstOrNull;
    if (exercise != null) matching.add(exercise);
  }
  if (matching.length < 4) {
    matching.addAll(
      available
          .where((item) => !matching.contains(item))
          .take(4 - matching.length),
    );
  }
  final shortPlan = missed >= 2;
  final minutes = alarming
      ? 12
      : recovery
      ? 20
      : shortPlan
      ? 15
      : muscleGoal
      ? 45
      : 35;
  final locale = state.localeCode;
  final reasons = <String>[
    if (alarming) 'есть тревожные симптомы: только мягкое восстановление',
    if (lowReadiness) 'нагрузка снижена из-за сна или готовности',
    if (travelRecovery)
      'учтены дорога, ночной переезд или смена часового пояса',
    if (previousHeavy) 'вчера уже была тяжёлая тренировка',
    if (shortPlan) 'после пропусков предложена короткая версия',
    if (healthRestrictions.isNotEmpty)
      'исключены движения по указанным травмам и ограничениям',
    if (poorAir) 'из-за плохого воздуха выбрана домашняя нагрузка',
    if (climate.typicalTemperatureC >= 30)
      'из-за жары снижена интенсивность; лучше заниматься утром или вечером',
    if (climate.typicalTemperatureC <= -10)
      'из-за холода выбран домашний вариант с более длинной разминкой',
    if (climate.humidityPercent >= 80) 'из-за высокой влажности уменьшен темп',
    if (climate.altitudeMeters >= 1500)
      'учтена адаптация к высоте над уровнем моря',
    if (!recovery && muscleGoal) 'цель: развитие силы и мышц',
    if (!recovery && weightGoal) 'цель: безопасное увеличение активности',
  ];
  final generated = WorkoutSession(
    id: newId(),
    title: recovery
        ? (locale == 'ru'
              ? 'Восстановительная тренировка по готовности'
              : 'Recovery workout by readiness')
        : shortPlan
        ? (locale == 'ru'
              ? 'Короткая тренировка после пропусков'
              : 'Short workout after missed sessions')
        : (locale == 'ru'
              ? 'Силовая тренировка по инвентарю'
              : 'Strength workout by equipment'),
    focus: matching.map((item) => item.focusFor(locale)).take(3).join(', '),
    minutes: minutes,
    intensity: recovery ? 'восстановительная' : 'средняя',
    scheduledDate: today,
    exerciseIds: matching.map((item) => item.id).toList(),
    notes:
        '${reasons.isEmpty ? 'План составлен по цели, доступному инвентарю и текущей готовности.' : reasons.join('. ')}. '
        'При боли, головокружении, необычной одышке или ухудшении самочувствия остановитесь.',
  );
  final recalculated = state.workouts.map((item) {
    if (item.status == 'planned' && item.scheduledDate.compareTo(today) < 0) {
      return item.copyWith(status: 'missed');
    }
    return item;
  }).toList();
  onChanged(state.copyWith(workouts: [generated, ...recalculated]));
}

HealthAppState _addWorkoutMinutes(
  HealthAppState state,
  WorkoutSession workout,
) {
  if (workout.status != 'completed') return state;
  final metrics = state.metricsFor(workout.scheduledDate);
  final updatedMinutes = (metrics.workoutMinutes + workout.minutes)
      .clamp(0, 24 * 60)
      .toInt();
  return state.updateMetricsFor(
    workout.scheduledDate,
    metrics.copyWith(
      workoutMinutes: updatedMinutes,
      activeCalories: (metrics.activeCalories + workout.caloriesBurned)
          .clamp(0, 10000)
          .toInt(),
    ),
  );
}

HealthAppState _removeWorkoutMinutes(
  HealthAppState state,
  WorkoutSession workout,
) {
  if (workout.status != 'completed') return state;
  final metrics = state.metricsFor(workout.scheduledDate);
  final updatedMinutes = (metrics.workoutMinutes - workout.minutes)
      .clamp(0, 24 * 60)
      .toInt();
  return state.updateMetricsFor(
    workout.scheduledDate,
    metrics.copyWith(
      workoutMinutes: updatedMinutes,
      activeCalories: (metrics.activeCalories - workout.caloriesBurned)
          .clamp(0, 10000)
          .toInt(),
    ),
  );
}

HealthAppState _deleteWorkoutFromState(
  HealthAppState state,
  WorkoutSession workout,
) {
  return _removeWorkoutMinutes(state, workout).copyWith(
    workouts: state.workouts
        .where((candidate) => candidate.id != workout.id)
        .toList(),
  );
}

List<_SearchItem> _searchItems(HealthAppState state) {
  final locale = state.localeCode;
  return [
    ...allSections.map((item) => _SearchItem(item.label(locale), item.section)),
    ...state.medications.map(
      (item) => _SearchItem(item.name, AppSection.medicines),
    ),
    ...state.labResults.map(
      (item) => _SearchItem(item.marker, AppSection.labs),
    ),
    ...state.careProviders.map(
      (item) => _SearchItem(item.name, AppSection.medicalCard),
    ),
    ...state.medicalEvents.map(
      (item) => _SearchItem(item.title, AppSection.medicalCard),
    ),
    ...state.injuries.map(
      (item) => _SearchItem(item.title, AppSection.medicalCard),
    ),
    ...state.meals.map((item) => _SearchItem(item.title, AppSection.nutrition)),
    ...state.workouts.map(
      (item) => _SearchItem(item.title, AppSection.workouts),
    ),
    ...state.documents.map(
      (item) => _SearchItem(item.title, AppSection.documents),
    ),
    ...state.documents.expand(
      (item) => item.tags.map((tag) => _SearchItem(tag, AppSection.documents)),
    ),
    ...exerciseCatalog.map(
      (item) => _SearchItem(item.titleFor(locale), AppSection.exercises),
    ),
    ...recipeCatalog.map(
      (item) => _SearchItem(item.titleFor(locale), AppSection.recipes),
    ),
  ];
}

String _exerciseNames(List<String> ids, String locale) {
  return ids
      .map(
        (id) => exerciseCatalog
            .where((exercise) => exercise.id == id)
            .map((exercise) => exercise.titleFor(locale))
            .firstOrNull,
      )
      .whereType<String>()
      .join(', ');
}

String _readinessText(int score) {
  if (score >= 80) {
    return 'можно плановую нагрузку';
  }
  if (score >= 60) {
    return 'лучше умеренный день';
  }
  return 'приоритет восстановлению';
}

bool _isAlarmingSymptom(String text) {
  final lower = text.toLowerCase();
  const tokens = [
    'сильная боль',
    'груд',
    'одыш',
    'онем',
    'потер',
    'кров',
    'речь',
    'обмор',
  ];
  return tokens.any(lower.contains);
}

int _parseInt(String value, int fallback) {
  return int.tryParse(value.trim()) ??
      double.tryParse(value.trim())?.round() ??
      fallback;
}

double _parseDouble(String value, double fallback) {
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? fallback;
}

class _SearchItem {
  const _SearchItem(this.text, this.section);

  final String text;
  final AppSection section;
}

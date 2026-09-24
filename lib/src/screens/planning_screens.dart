part of '../screens.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key, required this.state, required this.onChanged});

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'sleep'),
      subtitle: 'Сон, группы будильников и восстановление',
      trailing: FilledButton.icon(
        onPressed: () => _editSleepRecord(context, state, onChanged),
        icon: const Icon(Icons.add),
        label: const Text('Запись сна'),
      ),
      children: [
        ResponsiveGrid(
          children: [
            MetricCard(
              title: 'Сон прошлой ночи',
              value: '${state.today.sleepHours.toStringAsFixed(1)} ч',
              subtitle: 'цель 7.5-8.5 ч',
              icon: Icons.bedtime_outlined,
              color: Colors.blue,
              progress: state.today.sleepHours / 8,
              onTap: () => showQuickAddDialog(context, state, onChanged),
            ),
            MetricCard(
              title: 'Стресс',
              value: '${state.today.stress}/5',
              subtitle: 'чем ниже, тем лучше',
              icon: Icons.self_improvement_outlined,
              color: Colors.purple,
              progress: 1 - (state.today.stress / 5),
            ),
          ],
        ),
        SectionTitle('Дневник сна'),
        if (state.sleepRecords.isEmpty)
          const InfoTile(
            icon: Icons.bedtime_outlined,
            title: 'Записей сна пока нет',
            subtitle:
                'Добавьте время сна, пробуждения, качество и ночные пробуждения.',
          ),
        ...([
          ...state.sleepRecords,
        ]..sort((a, b) => b.date.compareTo(a.date))).map(
          (item) => InfoTile(
            icon: item.quality >= 4
                ? Icons.nights_stay_outlined
                : Icons.bedtime_off_outlined,
            title:
                '${displayDateKey(item.date)} · ${item.durationHours.toStringAsFixed(1)} ч',
            subtitle:
                '${item.bedTime}-${item.wakeTime} · качество ${item.quality}/5 · пробуждений ${item.awakenings} · ${item.source}'
                '${item.notes.isEmpty ? '' : '\n${item.notes}'}',
            onTap: () => _editSleepRecord(context, state, onChanged, item),
            onLongPress: () => _confirmDelete(
              context,
              title: 'Сон ${displayDateKey(item.date)}',
              onDelete: () => onChanged(
                state.copyWith(
                  sleepRecords: state.sleepRecords
                      .where((candidate) => candidate.id != item.id)
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        SectionTitle(
          'Группы будильников',
          action: LocalizedIconButton.filledTonal(
            tooltip: 'Добавить группу',
            onPressed: () => _editAlarmGroup(context, state, onChanged),
            icon: const Icon(Icons.add_alarm_outlined),
          ),
        ),
        if (state.alarmGroups.isEmpty)
          const InfoTile(
            icon: Icons.alarm_off_outlined,
            title: 'Групп пока нет',
            subtitle: 'Добавьте расписание сна, подъёма и адаптивности.',
          ),
        ...state.alarmGroups.map(
          (item) => InfoTile(
            icon: Icons.alarm_outlined,
            title: '${item.title}: ${item.wakeTime}',
            subtitle:
                'Сон с ${item.bedTime} · ${item.days} · ${item.context} · приоритет ${item.priority}\n'
                '${item.adaptive ? 'адаптивно' : 'фиксировано'} · ${item.unlockMode} · '
                '${item.dutyAware ? 'дежурства учитываются' : 'без дежурств'} · '
                '${item.vacationAware ? 'отпуск учитывается' : 'без отпуска'} · '
                'сон-браслет ${item.useWearableSleepCycle ? 'да' : 'нет'} ${item.smartWakeWindowMinutes} мин · '
                '${item.vibrationEnabled ? 'вибрация' : 'без вибрации'} · '
                '${item.gradualWakeEnabled ? 'усиление ${item.gradualWakeMinutes} мин' : 'один сигнал'} · '
                '${item.wakefulnessCheckEnabled ? 'контроль бодрствования ${item.wakefulnessWindowMinutes} мин' : 'без контроля бодрствования'}',
            onTap: () => _editAlarmGroup(context, state, onChanged, item),
            trailing: LocalizedIconButton(
              tooltip: 'Проверить отключение',
              onPressed: () => showAlarmChallenge(context, item),
              icon: const Icon(Icons.alarm_on_outlined),
            ),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () =>
                  onChanged(_deleteAlarmGroupFromState(state, item)),
            ),
          ),
        ),
      ],
    );
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final days = [...state.dailyHistory]
      ..sort((a, b) => b.date.compareTo(a.date));
    return PageBand(
      title: AppText.get(state.localeCode, 'calendar'),
      subtitle: 'Тренировки, лекарства, анализы, поездки и восстановление',
      children: [
        SectionTitle(
          'Дни',
          action: LocalizedIconButton.filledTonal(
            tooltip: 'Выбрать дату',
            onPressed: () => _pickCalendarDate(context, state, onChanged),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ),
        ...days.map(
          (item) => InfoTile(
            icon: Icons.event_note_outlined,
            title: item.date,
            subtitle:
                'Шаги ${item.steps} · сон ${item.sleepHours.toStringAsFixed(1)} ч · вода ${item.waterLiters.toStringAsFixed(1)} л · питание ${item.calories} ккал · расход ${item.totalCaloriesBurned} ккал',
            onTap: () => _showDayDetails(context, state, onChanged, item.date),
          ),
        ),
        if (days.isEmpty)
          const InfoTile(
            icon: Icons.event_note_outlined,
            title: 'Данных пока нет',
            subtitle: 'Выберите дату и добавьте первые показатели дня.',
          ),
        SectionTitle(
          'Напоминания',
          action: LocalizedIconButton.filledTonal(
            tooltip: 'Добавить напоминание',
            onPressed: () => _editReminder(context, state, onChanged),
            icon: const Icon(Icons.add_alert_outlined),
          ),
        ),
        ...state.reminders.map(
          (item) => InfoTile(
            icon: item.done ? Icons.done_outline : Icons.event_outlined,
            title: item.title,
            subtitle:
                '${item.date} · ${item.category} · ${item.time}${item.repeat == 'none' ? '' : ' · ${_reminderRepeatLabel(item.repeat)}'}',
            onTap: () => _editReminder(context, state, onChanged, item),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () => onChanged(_deleteReminderFromState(state, item)),
            ),
            trailing: Checkbox(
              value: item.done,
              onChanged: (value) {
                final reminders = state.reminders
                    .map(
                      (candidate) => candidate.id == item.id
                          ? candidate.copyWith(done: value)
                          : candidate,
                    )
                    .toList();
                onChanged(state.copyWith(reminders: reminders));
              },
            ),
          ),
        ),
        SectionTitle('Тренировки'),
        ...state.workouts.map(
          (item) => InfoTile(
            icon: Icons.fitness_center_outlined,
            title: item.title,
            subtitle:
                '${item.scheduledDate} · ${item.minutes} мин · перенос доступен',
            onTap: () => _showWorkoutDetails(context, item, state.localeCode),
            trailing: LocalizedIconButton(
              tooltip: 'Редактировать',
              onPressed: () => _addWorkout(context, state, onChanged, item),
              icon: const Icon(Icons.edit_outlined),
            ),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () => onChanged(_deleteWorkoutFromState(state, item)),
            ),
          ),
        ),
        SectionTitle('Поездки'),
        ...state.trips.map(
          (item) => InfoTile(
            icon: Icons.business_center_outlined,
            title: item.title,
            subtitle: '${item.startDate}-${item.endDate} · ${item.adjustment}',
            onTap: () => _editTrip(context, state, onChanged, item),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () => onChanged(
                state.copyWith(
                  trips: state.trips
                      .where((candidate) => candidate.id != item.id)
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class VacationScreen extends StatelessWidget {
  const VacationScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'vacation'),
      subtitle: 'План отдыха без перегруза и с адаптацией сна',
      trailing: FilledButton.icon(
        onPressed: () => _editVacationPeriod(context, state, onChanged),
        icon: const Icon(Icons.add),
        label: const Text('Отпуск'),
      ),
      children: [
        if (state.workSchedule.vacations.isEmpty)
          const InfoTile(
            icon: Icons.beach_access_outlined,
            title: 'Отпуск не запланирован',
            subtitle:
                'Добавьте даты, дорогу, место, доступный спорт и группу будильников.',
          ),
        ...state.workSchedule.vacations.map(
          (item) => InfoTile(
            icon: Icons.beach_access_outlined,
            title: item.title,
            subtitle: _vacationSubtitle(item),
            onTap: () => _editVacationPeriod(context, state, onChanged, item),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () => onChanged(
                state.copyWith(
                  workSchedule: state.workSchedule.copyWith(
                    vacations: state.workSchedule.vacations
                        .where((candidate) => candidate.id != item.id)
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        const InfoTile(
          icon: Icons.beach_access_outlined,
          title: 'Автоматическая адаптация',
          subtitle:
              'После ночной дороги, долгого пути или смены часового пояса план предлагает восстановление, воду и лёгкую активность.',
        ),
        const InfoTile(
          icon: Icons.restaurant_outlined,
          title: 'Питание вне дома',
          subtitle:
              'Сначала белок и овощи, затем гарнир; сладкое как дополнение, не основной приём пищи.',
        ),
        const InfoTile(
          icon: Icons.bedtime_outlined,
          title: 'Сон',
          subtitle:
              'Будильники мягкие, цель сна не ниже 7 часов, восстановительные дни отмечаются отдельно.',
        ),
      ],
    );
  }
}

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key, required this.state, required this.onChanged});

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'trips'),
      subtitle: 'Командировки с учётом перелётов, климата, сна и тренировок',
      trailing: FilledButton.icon(
        onPressed: () => _editTrip(context, state, onChanged),
        icon: const Icon(Icons.add),
        label: const Text('Поездка'),
      ),
      children: [
        ...state.trips.map(
          (item) => InfoTile(
            icon: Icons.business_center_outlined,
            title: item.title,
            subtitle:
                '${item.startDate}-${item.endDate} · климат: ${item.climate} · часовой сдвиг ${item.timeZoneShift}\n${item.adjustment}',
            onTap: () => _editTrip(context, state, onChanged, item),
            onLongPress: () => _confirmDelete(
              context,
              title: item.title,
              onDelete: () => onChanged(
                state.copyWith(
                  trips: state.trips
                      .where((candidate) => candidate.id != item.id)
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ClimateScreen extends StatelessWidget {
  const ClimateScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final HealthAppState state;
  final HealthStateChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final profile = state.profile;
    final hasLocation = profile.country.isNotEmpty && profile.city.isNotEmpty;
    final climateProfile = profile.latitude == null
        ? null
        : climateProfileFor(profile.latitude!);
    final solar = profile.solarPhenomena.isEmpty
        ? 'Особые солнечные явления для выбранной локации не отмечены.'
        : profile.solarPhenomena.join(', ');
    return PageBand(
      title: AppText.get(state.localeCode, 'climate'),
      subtitle: hasLocation
          ? '${profile.country}, ${profile.city} · ${profile.climate}'
          : 'Выберите страну и город в профиле, чтобы включить климатический учёт',
      trailing: FilledButton.icon(
        onPressed: () => _editClimateDetails(context, state, onChanged),
        icon: const Icon(Icons.tune_outlined),
        label: const Text('Условия'),
      ),
      children: [
        ResponsiveGrid(
          children: [
            MetricCard(
              title: 'Лето',
              value: profile.climateSummer.isEmpty
                  ? 'не выбрано'
                  : profile.climateSummer,
              subtitle: 'используется для воды, прогулок и нагрузки',
              icon: Icons.wb_sunny_outlined,
              color: Colors.amber,
              progress: hasLocation ? 0.75 : 0,
            ),
            MetricCard(
              title: 'Зима',
              value: profile.climateWinter.isEmpty
                  ? 'не выбрано'
                  : profile.climateWinter,
              subtitle: 'учитывается для сна, света и тренировок',
              icon: Icons.ac_unit_outlined,
              color: Colors.blue,
              progress: hasLocation ? 0.65 : 0,
            ),
            MetricCard(
              title: 'Воздух',
              value: profile.airQuality.isEmpty
                  ? 'не указано'
                  : profile.airQuality,
              subtitle: profile.humidityPercent <= 0
                  ? 'влажность не указана'
                  : 'влажность ${profile.humidityPercent}%',
              icon: Icons.air_outlined,
              color: _airQualityIsPoor(profile.airQuality)
                  ? Colors.deepOrange
                  : Colors.teal,
            ),
            MetricCard(
              title: 'Местные условия',
              value: profile.timeZone.isEmpty ? 'нет данных' : profile.timeZone,
              subtitle:
                  '${profile.typicalTemperatureC.toStringAsFixed(1)} °C · высота ${profile.altitudeMeters} м',
              icon: Icons.public_outlined,
              color: Colors.indigo,
            ),
          ],
        ),
        InfoTile(
          icon: Icons.light_mode_outlined,
          title: 'Солнечный режим',
          subtitle: climateProfile == null
              ? solar
              : '$solar\nСамый длинный день: ${climateProfile.longestDay}; самый короткий: ${climateProfile.shortestDay}.',
        ),
        InfoTile(
          icon: Icons.location_on_outlined,
          title: 'Координаты',
          subtitle: profile.latitude == null || profile.longitude == null
              ? 'Добавьте координаты пользовательского города в мастере профиля.'
              : '${profile.latitude!.toStringAsFixed(2)}, ${profile.longitude!.toStringAsFixed(2)}',
        ),
        InfoTile(
          icon: Icons.fitness_center_outlined,
          title: 'Тренировки',
          subtitle: _climateTrainingGuidance(profile),
        ),
        InfoTile(
          icon: Icons.eco_outlined,
          title: 'Аллергены и личные реакции',
          subtitle: [
            if (profile.regionalAllergens.isNotEmpty)
              'Регион: ${profile.regionalAllergens.join(', ')}',
            if (profile.climateReactions.isNotEmpty)
              'Реакции: ${profile.climateReactions.join(', ')}',
            if (profile.regionalAllergens.isEmpty &&
                profile.climateReactions.isEmpty)
              'Не указаны',
          ].join('\n'),
          onTap: () => _editClimateDetails(context, state, onChanged),
        ),
      ],
    );
  }
}

Future<void> _editClimateDetails(
  BuildContext context,
  HealthAppState state,
  HealthStateChanged onChanged,
) async {
  final profile = state.profile;
  final timeZone = TextEditingController(text: profile.timeZone);
  final temperature = TextEditingController(
    text: profile.typicalTemperatureC == 0
        ? ''
        : '${profile.typicalTemperatureC}',
  );
  final humidity = TextEditingController(
    text: profile.humidityPercent == 0 ? '' : '${profile.humidityPercent}',
  );
  final altitude = TextEditingController(
    text: profile.altitudeMeters == 0 ? '' : '${profile.altitudeMeters}',
  );
  final allergens = TextEditingController(
    text: profile.regionalAllergens.join(', '),
  );
  final reactions = TextEditingController(
    text: profile.climateReactions.join(', '),
  );
  var airQuality = profile.airQuality.isEmpty
      ? 'не указано'
      : profile.airQuality;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Климатический профиль'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LocalizedTextField(
                  controller: timeZone,
                  decoration: const InputDecoration(
                    labelText: 'Часовой пояс',
                    hintText: 'Например: Europe/Moscow или UTC+3',
                  ),
                ),
                _numberField(temperature, 'Обычная температура, °C'),
                _numberField(humidity, 'Обычная влажность, %'),
                _numberField(altitude, 'Высота над уровнем моря, м'),
                LocalizedDropdownButtonFormField<String>(
                  initialValue: airQuality,
                  decoration: const InputDecoration(
                    labelText: 'Обычное качество воздуха',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'не указано',
                      child: Text('Не указано'),
                    ),
                    DropdownMenuItem(value: 'хорошее', child: Text('Хорошее')),
                    DropdownMenuItem(
                      value: 'умеренное',
                      child: Text('Умеренное'),
                    ),
                    DropdownMenuItem(value: 'плохое', child: Text('Плохое')),
                    DropdownMenuItem(
                      value: 'очень плохое',
                      child: Text('Очень плохое'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => airQuality = value ?? airQuality),
                ),
                LocalizedTextField(
                  controller: allergens,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Аллергены региона',
                    hintText: 'Пыльца берёзы, амброзия, пыль; через запятую',
                  ),
                ),
                LocalizedTextField(
                  controller: reactions,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Личные реакции на климат',
                    hintText: 'Жара, холод, влажность, духота; через запятую',
                  ),
                ),
                const InfoTile(
                  icon: Icons.info_outline,
                  title: 'Город и координаты',
                  subtitle:
                      'Страна, город, координаты и сезонность меняются в мастере профиля через базу городов.',
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
              List<String> split(String source) => source
                  .split(RegExp(r'[,;]'))
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toSet()
                  .toList();
              onChanged(
                state.copyWith(
                  profile: profile.copyWith(
                    timeZone: timeZone.text.trim(),
                    typicalTemperatureC: _parseDouble(
                      temperature.text,
                      0,
                    ).clamp(-80, 60).toDouble(),
                    humidityPercent: _parseInt(
                      humidity.text,
                      0,
                    ).clamp(0, 100).toInt(),
                    altitudeMeters: _parseInt(
                      altitude.text,
                      0,
                    ).clamp(-500, 9000).toInt(),
                    airQuality: airQuality == 'не указано' ? '' : airQuality,
                    regionalAllergens: split(allergens.text),
                    climateReactions: split(reactions.text),
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
  timeZone.dispose();
  temperature.dispose();
  humidity.dispose();
  altitude.dispose();
  allergens.dispose();
  reactions.dispose();
}

bool _airQualityIsPoor(String value) {
  final lower = value.toLowerCase();
  return lower.contains('плох') ||
      lower.contains('poor') ||
      lower.contains('hazard');
}

String _climateTrainingGuidance(UserProfile profile) {
  final advice = <String>[];
  if (_airQualityIsPoor(profile.airQuality)) {
    advice.add('Плохой воздух: замените уличное кардио домашней тренировкой.');
  }
  if (profile.typicalTemperatureC >= 30) {
    advice.add(
      'Жара: тренируйтесь утром или вечером, снизьте интенсивность и добавьте воду.',
    );
  } else if (profile.typicalTemperatureC <= -10) {
    advice.add('Холод: выберите зал или домашний вариант и удлините разминку.');
  }
  if (profile.humidityPercent >= 80) {
    advice.add(
      'Высокая влажность: уменьшите темп и контролируйте самочувствие.',
    );
  }
  if (profile.altitudeMeters >= 1500) {
    advice.add(
      'Высота: первые дни уменьшите объём и оставьте больше времени на восстановление.',
    );
  }
  if (advice.isEmpty) {
    advice.add(
      'Условия не требуют специального снижения нагрузки; контролируйте самочувствие и воду.',
    );
  }
  return advice.join('\n');
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, required this.state});

  final HealthAppState state;

  @override
  Widget build(BuildContext context) {
    return PageBand(
      title: AppText.get(state.localeCode, 'analytics'),
      subtitle: 'Динамика показателей и объяснение изменений',
      children: [
        _analyticsBar(
          context,
          'Готовность',
          state.readinessScore / 100,
          Colors.teal,
        ),
        _analyticsBar(
          context,
          'Энергия',
          state.energyScore / 100,
          Colors.indigo,
        ),
        _analyticsBar(context, 'Сон', state.today.sleepHours / 8, Colors.blue),
        _analyticsBar(context, 'Шаги', state.today.steps / 9000, Colors.green),
        _analyticsBar(
          context,
          'Вода',
          state.today.waterLiters / 2.4,
          Colors.cyan,
        ),
        SectionTitle('Динамика'),
        _HealthTrendChart(
          title: 'Вес',
          unit: 'кг',
          color: Colors.teal,
          points: state.dailyHistory
              .where((item) => item.weightKg > 0)
              .map((item) => _TrendPoint(item.date, item.weightKg))
              .toList(),
        ),
        _HealthTrendChart(
          title: 'Сон',
          unit: 'ч',
          color: Colors.blue,
          target: 8,
          points: state.dailyHistory
              .where((item) => item.sleepHours > 0)
              .map((item) => _TrendPoint(item.date, item.sleepHours))
              .toList(),
        ),
        _HealthTrendChart(
          title: 'Шаги',
          unit: '',
          color: Colors.green,
          target: 9000,
          points: state.dailyHistory
              .where((item) => item.steps > 0)
              .map((item) => _TrendPoint(item.date, item.steps.toDouble()))
              .toList(),
        ),
        _HealthTrendChart(
          title: 'Калории питания',
          unit: 'ккал',
          color: Colors.orange,
          target: 2100,
          points: state.dailyHistory
              .where((item) => item.calories > 0)
              .map((item) => _TrendPoint(item.date, item.calories.toDouble()))
              .toList(),
        ),
        _HealthTrendChart(
          title: 'Индекс массы тела',
          unit: '',
          color: Colors.purple,
          points: state.profile.heightCm <= 0
              ? const []
              : state.dailyHistory
                    .where((item) => item.weightKg > 0)
                    .map(
                      (item) => _TrendPoint(
                        item.date,
                        item.weightKg /
                            ((state.profile.heightCm / 100) *
                                (state.profile.heightCm / 100)),
                      ),
                    )
                    .toList(),
        ),
        _HealthTrendChart(
          title: 'Вода',
          unit: 'л',
          color: Colors.cyan,
          target: 2.4,
          points: state.dailyHistory
              .where((item) => item.waterLiters > 0)
              .map((item) => _TrendPoint(item.date, item.waterLiters))
              .toList(),
        ),
        _HealthTrendChart(
          title: 'Активный расход',
          unit: 'ккал',
          color: Colors.deepOrange,
          points: state.dailyHistory
              .where((item) => item.activeCalories > 0)
              .map(
                (item) =>
                    _TrendPoint(item.date, item.activeCalories.toDouble()),
              )
              .toList(),
        ),
        _HealthTrendChart(
          title: 'Тренировки',
          unit: 'мин',
          color: Colors.indigo,
          target: 30,
          points: state.dailyHistory
              .where((item) => item.workoutMinutes > 0)
              .map(
                (item) =>
                    _TrendPoint(item.date, item.workoutMinutes.toDouble()),
              )
              .toList(),
        ),
        _HealthTrendChart(
          title: 'Симптомы',
          unit: '',
          color: Colors.red,
          target: 0,
          points: _symptomTrendPoints(state),
        ),
        _HealthTrendChart(
          title: 'Соблюдение приёма лекарств',
          unit: '%',
          color: Colors.green,
          target: 100,
          points: _medicationAdherencePoints(state),
        ),
        _HealthTrendChart(
          title: 'Белок',
          unit: 'г',
          color: Colors.blueGrey,
          points: _mealNutrientPoints(state, (meal) => meal.protein),
        ),
        _HealthTrendChart(
          title: 'Клетчатка',
          unit: 'г',
          color: Colors.lightGreen,
          target: 25,
          points: _mealNutrientPoints(state, (meal) => meal.fiber),
        ),
        if (state.labResults.isNotEmpty) ...[
          SectionTitle('Динамика анализов'),
          ..._labTrendCharts(state.labResults),
        ],
        SectionTitle('Интерпретация'),
        ..._analyticsInterpretations(state).map(
          (item) => InfoTile(
            icon: Icons.query_stats_outlined,
            title: item,
            subtitle: 'Вывод рассчитан по сохранённой истории.',
          ),
        ),
        ...state.insights.map(
          (item) => InfoTile(
            icon: Icons.insights_outlined,
            title: item,
            subtitle: medicalDisclaimer,
          ),
        ),
      ],
    );
  }
}
